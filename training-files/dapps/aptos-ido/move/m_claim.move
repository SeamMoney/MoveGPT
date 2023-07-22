module m_claim::mclaim {
    use std::signer;
    use aptos_framework::coin;
    use std::timestamp;
	use std::vector;
	use aptos_std::table::{Self, Table};

    struct Pool<phantom CoinType, phantom CoinRefund> has key {
        claim_coins: coin::Coin<CoinType>,
        refund_coins: coin::Coin<CoinRefund>,
        total_claimed_amount: u64,
        total_refunded_amount: u64,
        wls_claim: Table<address, UserInfo<CoinType, CoinRefund>>,
        start_claim: u64, //start_claim moment when releasing the first_release of the tokens
        end_refund: u64, // in timestamp
        first_release: u64, // first_release in percent for percent of total tokens that user will receive at first claim, 100 = 1%
        total_periods: u64, // total amount of vesting periods
        time_per_period: u64, // time in seconds for every vesting period
        cliff: u64 // cliff delay (seconds) from start_claim after that monthly vesting starts
    }

    struct UserInfo<phantom CoinType, phantom CoinRefund> has key, drop, store {
        amount: u64,
        refund_amount: u64,
		claimed_amount: u64,
        refunded_amount: u64
    }

    const ENOT_ADMIN: u64 = 1;
    /// Pool does not exists
    const ENO_POOLS: u64 = 2;
    // const EDEPOSIT_TIME: u64 = 3;
	const EPOOL_DUPLICATES: u64 = 4;
    const ELOW_BALANCE: u64 = 5;
    const ETIME_ORDER: u64 = 6;

    // const ECAP: u64 = 7;
    const EFUND_WALLET: u64 = 8;
	const EALREADY_CLAIMED: u64 = 9;
	const EINVALID_AMOUNT: u64 = 10;
	const ENOT_WHITELIST: u64 = 11;
	const EINVALID_CLAIM_TIME: u64 = 12;
	const EINVALID_WL: u64 = 13;
    const EREFUNED: u64 = 14;
    const EFULL_CLAIMED: u64 = 15;
    const EINVALID_REFUND: u64 = 16;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const PRICE_PRECISION: u128 = 1000000000000; // 1e12

    public fun assert_admin(account: &signer) {
        assert!(signer::address_of(account) == @m_claim, ENOT_ADMIN);
    }

    public entry fun create_pool<CoinType, CoinRefund>(
        admin: &signer,
		start_claim: u64,
		end_refund: u64,
        total_claim_coins: u64,
        total_refund_coins: u64,
        cliff: u64,
        first_release: u64,
        time_per_period: u64,
        total_periods: u64
    ) {
        assert_admin(admin);
        assert!(end_refund > start_claim, ETIME_ORDER);
        // create pool
        move_to(admin, Pool<CoinType, CoinRefund>{
            claim_coins: coin::withdraw(admin, total_claim_coins),
            refund_coins: coin::withdraw(admin, total_refund_coins),
            total_claimed_amount: 0,
            total_refunded_amount: 0,
            wls_claim: table::new(),
            start_claim: start_claim,
            end_refund: end_refund,
            cliff: cliff,
            first_release: first_release,
            time_per_period: time_per_period,
            total_periods: total_periods
        })

    }


    public entry fun admin_deposit_pool<CoinType, CoinRefund>(
        admin: &signer,
        total_claim_coins: u64,
        total_refund_coins: u64
    ) 
        acquires Pool
    {
        assert_admin(admin);
        if (total_claim_coins > 0) {
            let claim_pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
            let cl_coins = coin::withdraw<CoinType>(admin, total_claim_coins);
            coin::merge<CoinType>(&mut claim_pool.claim_coins, cl_coins);
        };

        if(total_refund_coins > 0) {
            let rf_pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
            let rf_coins = coin::withdraw<CoinRefund>(admin, total_refund_coins);
            coin::merge<CoinRefund>(&mut rf_pool.refund_coins, rf_coins);
        };
    }

	public fun create_user<CoinType, CoinRefund>(
        amount: u64,
        refund_amount: u64,
	): UserInfo<CoinType, CoinRefund>{
        let claimed_amount: u64 = 0;
        let refunded_amount: u64 = 0;
		UserInfo<CoinType, CoinRefund> {
			amount,
			refund_amount,
			claimed_amount,
            refunded_amount
		}
	}

	public entry fun add_whitelists<CoinType, CoinRefund>(
        admin: &signer, addresses: vector<address>, amounts: vector<u64>, rf_amounts: vector<u64>) acquires Pool{
        assert_admin(admin);

        assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);
        let ido_pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);

        let a_len = vector::length(&addresses);
        let b_len = vector::length(&amounts);
        assert!(a_len == b_len, EINVALID_WL);

        let i = 0;

        while (i < a_len) {
            let addr = *vector::borrow(&addresses, i);
			let amt = *vector::borrow(&amounts, i);
			let rf_amt = *vector::borrow(&rf_amounts, i);
            let record = create_user<CoinType, CoinRefund>(amt, rf_amt);
            table::add(&mut ido_pool.wls_claim, addr, record);
            i = i+1;
        };
    }

    public entry fun add_whitelist_single<CoinType, CoinRefund>(admin: &signer, addr: address, amount: u64, rf_amount: u64) acquires Pool{
        assert_admin(admin);
        assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);

		let record = create_user<CoinType, CoinRefund>(amount, rf_amount);

        let ido_pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
        table::add(&mut ido_pool.wls_claim, addr, record);
    }

    public entry fun update_whitelist_single<CoinType, CoinRefund>(admin: &signer, addr: address, amount: u64, rf_amount: u64) acquires Pool{
        assert_admin(admin);
        assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);
        let ido_pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
        let wl = table::borrow_mut(&mut ido_pool.wls_claim, addr);
         wl.amount = amount;
         wl.refund_amount = rf_amount;
    }

    public entry fun update_pool<CoinType, CoinRefund>(
        admin: &signer, 
        start_claim: u64, 
        end_refund: u64,
        cliff: u64,
        first_release: u64,
        time_per_period: u64,
        total_periods: u64
        ) acquires Pool {
    	assert_admin(admin);
    	assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);
    	assert!(end_refund>start_claim, ETIME_ORDER);
    	let pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
    	pool.start_claim = start_claim;
    	pool.end_refund = end_refund;
    	pool.cliff = cliff;
    	pool.first_release = first_release;
    	pool.time_per_period = time_per_period;
    	pool.total_periods = total_periods;
    }

	public entry fun claim<CoinType, CoinRefund> (account: &signer) acquires Pool {
		let user = signer::address_of(account);
        // Check pool
        assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);
        let pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
        assert!(table::contains(&mut pool.wls_claim, user), ENOT_WHITELIST);

        let now = timestamp::now_seconds();
        assert!(pool.start_claim <= now , EINVALID_CLAIM_TIME);

        let wls = table::borrow_mut(&mut pool.wls_claim, user);
        assert!(wls.amount > (wls.claimed_amount + 1), EFULL_CLAIMED);
        assert!(wls.amount > 0, EINVALID_AMOUNT);
        assert!(wls.refunded_amount == 0, EREFUNED);
        
        // calculating tokens to claim
        let amt_to_claim = 0u64;
        if ((wls.claimed_amount + 1) > wls.amount ||pool.start_claim > now || wls.amount < 1000000) {
            amt_to_claim = 0;
        };

        let time_passed = now -pool.start_claim;
        let first_claim = wls.amount *pool.first_release / 10000;

        if (time_passed <pool.cliff) {
            if (wls.claimed_amount == 0) {
                amt_to_claim = first_claim;
            };
        } else {
            time_passed = time_passed -pool.cliff;
            let time = (time_passed /pool.time_per_period)+ 1;
            if (time >pool.total_periods) {
                time =pool.total_periods;
            };

            let _amount = wls.amount - first_claim;
            amt_to_claim = (_amount* time /pool.total_periods) + first_claim - wls.claimed_amount;

        };
         // calculating tokens to claim
         
        let user_claimed_amt = wls.claimed_amount + amt_to_claim;
        pool.total_claimed_amount = pool.total_claimed_amount + amt_to_claim;
        wls.claimed_amount = user_claimed_amt;

        // make sure user able to receive coin
        if(!coin::is_account_registered<CoinType>(user)) {
            coin::register<CoinType>(account);
        };

        let tokens_claimmable = coin::extract(&mut pool.claim_coins, amt_to_claim);
        coin::deposit<CoinType>(user, tokens_claimmable);

        if(!exists<UserInfo<CoinType, CoinRefund>>(user)){
            let refunded_amount = 0;
            move_to(account, UserInfo<CoinType, CoinRefund>{
                refund_amount: wls.refund_amount,
                amount: wls.amount,
                claimed_amount: user_claimed_amt,
                refunded_amount: refunded_amount
            });
      	} 
    }


    public entry fun refund<CoinType, CoinRefund> (account: &signer) acquires Pool {
			let user = signer::address_of(account);
        // Check pool
        assert!(exists<Pool<CoinType, CoinRefund>>(@m_claim), ENO_POOLS);

		let pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(@m_claim);
		assert!(table::contains(&mut pool.wls_claim, user), ENOT_WHITELIST);

        let now = timestamp::now_seconds();
        assert!(pool.end_refund >= now , EINVALID_REFUND);

        let wls = table::borrow_mut(&mut pool.wls_claim, user);
        assert!(wls.claimed_amount == 0, EALREADY_CLAIMED);
        assert!(wls.refunded_amount == 0, EREFUNED);
        assert!(wls.refund_amount > 0, ENOT_WHITELIST);

        pool.total_refunded_amount = pool.total_refunded_amount + wls.refund_amount;
        wls.refunded_amount = wls.refund_amount;

        // make sure user able to receive coin
        if(!coin::is_account_registered<CoinRefund>(user)) {
            coin::register<CoinRefund>(account);
        };

        // distribute the coin
        let tokens_refund = coin::extract(&mut pool.refund_coins, wls.refund_amount);
        coin::deposit<CoinRefund>(user, tokens_refund);

        if(!exists<UserInfo<CoinType, CoinRefund>>(user)){
            let claimed_amount = 0;
            move_to(account, UserInfo<CoinType, CoinRefund>{
                refund_amount: wls.refund_amount,
                amount: wls.amount,
                claimed_amount: claimed_amount,
                refunded_amount: wls.refund_amount
            });
      	} 
    }

	public entry fun admin_withdraw<CoinType, CoinRefund>(admin: &signer) acquires Pool{
		let admin_addr = signer::address_of(admin);
		assert_admin(admin);
		// assert!(exists<Pool<CoinType, CoinRefund>>(admin_addr), ENO_POOLS);

		let pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(admin_addr);

		if(!coin::is_account_registered<CoinType>(admin_addr)) {
				coin::register<CoinType>(admin);
		};

		let withdraw_amt = coin::extract_all<CoinType>(&mut pool.claim_coins);
	    // transfer the payment
		coin::deposit<CoinType>(admin_addr, withdraw_amt);
	}

    public entry fun admin_withdraw_stablecoin<CoinType, CoinRefund>(admin: &signer) acquires Pool{
		let admin_addr = signer::address_of(admin);
		assert_admin(admin);
		assert!(exists<Pool<CoinType, CoinRefund>>(admin_addr), ENO_POOLS);

		let pool = borrow_global_mut<Pool<CoinType, CoinRefund>>(admin_addr);

		if(!coin::is_account_registered<CoinRefund>(admin_addr)) {
				coin::register<CoinRefund>(admin);
		};

		let withdraw_amt = coin::extract_all<CoinRefund>(&mut pool.refund_coins);
	    // transfer the payment
		coin::deposit<CoinRefund>(admin_addr, withdraw_amt);
	}

}
module MasterChefDepolyer::BubbleMasterChefV1 {
    use std::signer;
    use std::string::utf8;
    use std::type_info::{Self, TypeInfo};
    use std::event;
    use std::vector;
    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};
    // use std::debug;    // For debug

    /// When user is not admin.
    const ERR_FORBIDDEN: u64 = 103;
    /// When Coin not registerd by admin.
    const ERR_LPCOIN_NOT_EXIST: u64 = 104;
    /// When Coin already registerd by adin.
    const ERR_LPCOIN_ALREADY_EXIST: u64 = 105;
    /// When not enough amount.
    const ERR_INSUFFICIENT_AMOUNT: u64 = 106;
    /// When need waiting for more blocks.
    const ERR_WAIT_FOR_NEW_BLOCK: u64 = 107;

    const ACC_ANI_PRECISION: u128 = 1000000000000;  // 1e12
    const DEPLOYER: address = @MasterChefDepolyer;
    const RESOURCE_ACCOUNT_ADDRESS: address = @MasterChefResourceAccount;   // gas saving

    // ANI coin
    struct ANI {}
    struct Caps has key {
        direct_mint: bool,
        mint: MintCapability<ANI>,
        freeze: FreezeCapability<ANI>,
        burn: BurnCapability<ANI>,
    }

    /**
     * ANI mint & burn
     */
    public entry fun mint_ANI(
        admin: &signer,
        amount: u64,
        to: address
    ) acquires MasterChefData, Caps {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        let caps = borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS);
        let direct_mint = caps.direct_mint;
        assert!(direct_mint == true, ERR_FORBIDDEN);
        let coins = coin::mint<ANI>(amount, &caps.mint);
        coin::deposit(to, coins);
    }

    public entry fun burn_ANI(
        account: &signer,
        amount: u64
    ) acquires Caps {
        let coin_b = &borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS).burn;
        let coins = coin::withdraw<ANI>(account, amount);
        coin::burn(coins, coin_b)
    }

    // events
    struct Events<phantom X> has key {
        add_event: event::EventHandle<CoinMeta<X>>,
        set_event: event::EventHandle<CoinMeta<X>>,
        deposit_event: event::EventHandle<DepositWithdrawEvent<X>>,
        withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
        emergency_withdraw_event: event::EventHandle<DepositWithdrawEvent<X>>,
    }

    // add/set event data
    struct CoinMeta<phantom X> has drop, store, copy {
        alloc_point: u64,
    }

    // deposit/withdraw event data
    struct DepositWithdrawEvent<phantom X> has drop, store {
        amount: u64,
        amount_ANI: u64,
    }

    // info of each user, store at user's address
    struct UserInfo<phantom X> has key, store, copy {
        amount: u64,    // `amount` LP coin amount the user has provided.
        reward_debt: u128,    // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ANIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.acc_ANI_per_share) - user.reward_debt
        //
        // Whenever a user deposits or withdraws LP coins to a pool. Here's what happens:
        //   1. The pool's `acc_ANI_per_share` (and `last_reward_timestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `reward_debt` gets updated.
    }

    // info of each pool, store at deployer's address
    struct PoolInfo<phantom X> has key, store {
        acc_ANI_per_share: u128,    // times ACC_ANI_PRECISION
        last_reward_timestamp: u64,
        alloc_point: u64,
    }

    struct MasterChefData has drop, key {
        signer_cap: SignerCapability,
        total_alloc_point: u64,
        admin_address: address,
        dao_address: address,   // dao fee to address
        dao_percent: u64,   // dao fee percent
        bonus_multiplier: u64,  // Bonus muliplier for early ANI makers.
        last_timestamp_dao_withdraw: u64,  // Last timestamp then develeper withdraw dao fee
        start_timestamp: u64,   // mc mint ANI start from this ts
        per_second_ANI: u128, // default ANI per second, 1 ANI/second = 86400 ANI/day, remember times bonus_multiplier
    }

    // all added lp
    struct LPInfo has key {
        lp_list: vector<TypeInfo>,
    }

    // resource account signer
    fun get_resource_account(): signer acquires MasterChefData {
        let signer_cap = &borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    // initialize
    fun init_module(admin: &signer) acquires MasterChefData, LPInfo {
        // create resource account
        let (resource_account, capability) = account::create_resource_account(admin, x"CF");
        // init ANI Coin
        let (coin_b, coin_f, coin_m) =
            coin::initialize<ANI>(admin, utf8(b"Bubble"), utf8(b"ANI"), 8, true);
        move_to(&resource_account, Caps { direct_mint: true, mint: coin_m, freeze: coin_f, burn: coin_b });
        register_coin<ANI>(&resource_account);
        // MasterChefData
        move_to(&resource_account, MasterChefData {
            signer_cap: capability,
            total_alloc_point: 0,
            admin_address: DEPLOYER,
            dao_address: DEPLOYER,
            dao_percent: 10,    // 10%
            bonus_multiplier: 10,   // 10x
            last_timestamp_dao_withdraw: timestamp::now_seconds(),
            start_timestamp: timestamp::now_seconds(),
            per_second_ANI: 10000000,   // 0.1 ANI
        });
        // init lp info
        move_to(&resource_account, LPInfo{
            lp_list: vector::empty()
        });
        // ANI staking
        add<ANI>(admin, 1000);
    }

    // user should call this first, for approve ANI 
    public entry fun register_ANI(account: &signer) {
        register_coin<ANI>(account);
    }

    fun register_coin<X>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<X>(account_addr)) {
            coin::register<X>(account);
        };
    }

    fun get_multiplier(
        from: u64,
        to: u64,
        bonus_multiplier: u64
    ): u128 {
        ((to - from) as u128) * (bonus_multiplier as u128)
    }

    // anyone can call this
    public entry fun withdraw_dao_fee() acquires MasterChefData, Caps {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(mc_data.last_timestamp_dao_withdraw < timestamp::now_seconds(), ERR_WAIT_FOR_NEW_BLOCK);

        let multiplier = get_multiplier(mc_data.last_timestamp_dao_withdraw, timestamp::now_seconds(), mc_data.bonus_multiplier);
        let reward_ANI = multiplier * mc_data.per_second_ANI * (mc_data.dao_percent as u128) / 100u128;
        let coin_m = &borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS).mint;
        let coins = coin::mint<ANI>((reward_ANI as u64), coin_m);
        coin::deposit(mc_data.dao_address, coins);
        mc_data.last_timestamp_dao_withdraw = timestamp::now_seconds();
    }

    // Add a new LP to the pool. Can only be called by the owner.
    // DO NOT add the same LP coin more than once. Rewards will be messed up if you do.
    public entry fun add<X>(
        admin: &signer,
        new_alloc_point: u64
    ) acquires MasterChefData, LPInfo {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        let resource_account_signer = account::create_signer_with_capability(&mc_data.signer_cap);
        assert!(!exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_ALREADY_EXIST);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);

        // change mc data
        mc_data.total_alloc_point = mc_data.total_alloc_point + new_alloc_point;
        let last_reward_timestamp = (if (timestamp::now_seconds() > mc_data.start_timestamp) timestamp::now_seconds() else mc_data.start_timestamp);
        move_to(&resource_account_signer, PoolInfo<X> {
            acc_ANI_per_share: 0,
            last_reward_timestamp,
            alloc_point: new_alloc_point,
        });
        // register coin
        register_coin<X>(&resource_account_signer);
        // add lp_info
        let lp_info = borrow_global_mut<LPInfo>(RESOURCE_ACCOUNT_ADDRESS);
        vector::push_back<TypeInfo>(&mut lp_info.lp_list, type_info::type_of<X>());
        // event
        let events = Events<X> {
            add_event: account::new_event_handle<CoinMeta<X>>(&resource_account_signer),
            set_event: account::new_event_handle<CoinMeta<X>>(&resource_account_signer),
            deposit_event: account::new_event_handle<DepositWithdrawEvent<X>>(&resource_account_signer),
            withdraw_event: account::new_event_handle<DepositWithdrawEvent<X>>(&resource_account_signer),
            emergency_withdraw_event: account::new_event_handle<DepositWithdrawEvent<X>>(&resource_account_signer),
        };
        event::emit_event(&mut events.add_event, CoinMeta<X> {
            alloc_point: new_alloc_point,
        });
        move_to(&resource_account_signer, events);
    }

    // Update the given pool's ANI allocation point
    public entry fun set<X>(
        admin: &signer,
        new_alloc_point: u64
    ) acquires MasterChefData, PoolInfo, Events {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_NOT_EXIST);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        let pool_info = borrow_global_mut<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);

        mc_data.total_alloc_point = mc_data.total_alloc_point - pool_info.alloc_point + new_alloc_point;
        pool_info.alloc_point = new_alloc_point;
        // event
        let events = borrow_global_mut<Events<X>>(RESOURCE_ACCOUNT_ADDRESS);
        event::emit_event(&mut events.set_event, CoinMeta<X> {
            alloc_point: new_alloc_point,
        });
    }

    // Update reward variables of the given pool.
    public entry fun update_pool<X>() acquires MasterChefData, PoolInfo, Caps {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_NOT_EXIST);
        let pool = borrow_global_mut<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        if (timestamp::now_seconds() <= pool.last_reward_timestamp) return;
        let lp_supply = coin::balance<X>(RESOURCE_ACCOUNT_ADDRESS);
        if (lp_supply <= 0) {
            pool.last_reward_timestamp = timestamp::now_seconds();
            return
        };
        let multipler = get_multiplier(pool.last_reward_timestamp, timestamp::now_seconds(), mc_data.bonus_multiplier);
        let reward_ANI = multipler * mc_data.per_second_ANI * (pool.alloc_point as u128) / (mc_data.total_alloc_point as u128) * ((100 - mc_data.dao_percent) as u128) / 100u128;
        let coin_m = &borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS).mint;
        let coins = coin::mint<ANI>((reward_ANI as u64), coin_m);
        coin::deposit(RESOURCE_ACCOUNT_ADDRESS, coins);
        pool.acc_ANI_per_share = pool.acc_ANI_per_share + reward_ANI * ACC_ANI_PRECISION / (lp_supply as u128);
        pool.last_reward_timestamp = timestamp::now_seconds();
    }

    // Deposit LP coins to MC for ANI allocation.
    public entry fun deposit<X>(
        account: &signer,
        amount: u64
    ) acquires MasterChefData, PoolInfo, UserInfo, Caps, Events {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        let resource_account_signer = account::create_signer_with_capability(&mc_data.signer_cap);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_NOT_EXIST);

        update_pool<X>();
        let acc_addr = signer::address_of(account);
        let pool = borrow_global<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);

        register_ANI(account);
        let pending: u64 = 0;
        // exist user, check acc
        if (exists<UserInfo<X>>(acc_addr)) {
            let user_info = borrow_global_mut<UserInfo<X>>(acc_addr);
            // transfer earned ANI
            if (user_info.amount > 0) {
                pending = (((user_info.amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION - user_info.reward_debt) as u64);
                safe_transfer_ANI(&resource_account_signer, signer::address_of(account), pending);
            };
            user_info.amount = user_info.amount + amount;
            user_info.reward_debt = (user_info.amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION;
        } else {
            let user_info = UserInfo<X> {
                amount: amount,
                reward_debt: (amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION,
            };
            move_to(account, user_info);
        };
        coin::transfer<X>(account, RESOURCE_ACCOUNT_ADDRESS, amount);
        // event
        let events = borrow_global_mut<Events<X>>(RESOURCE_ACCOUNT_ADDRESS);
        event::emit_event(&mut events.deposit_event, DepositWithdrawEvent<X> {
            amount,
            amount_ANI: pending,
        });
    }

    // Withdraw LP coins from MC.
    public entry fun withdraw<X>(
        account: &signer,
        amount: u64
    ) acquires MasterChefData, PoolInfo, UserInfo, Caps, Events {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        let resource_account_signer = account::create_signer_with_capability(&mc_data.signer_cap);
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_NOT_EXIST);

        update_pool<X>();
        let acc_addr = signer::address_of(account);
        let pool = borrow_global<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(exists<UserInfo<X>>(acc_addr), ERR_INSUFFICIENT_AMOUNT);
        let user_info = borrow_global_mut<UserInfo<X>>(acc_addr);
        assert!(user_info.amount >= amount, ERR_INSUFFICIENT_AMOUNT);

        register_ANI(account);
        let pending = (((user_info.amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION - user_info.reward_debt) as u64);
        safe_transfer_ANI(&resource_account_signer, signer::address_of(account), pending);

        user_info.amount = user_info.amount - amount;
        user_info.reward_debt = (user_info.amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION;
        coin::transfer<X>(&resource_account_signer, acc_addr, amount);
        // event
        let events = borrow_global_mut<Events<X>>(RESOURCE_ACCOUNT_ADDRESS);
        event::emit_event(&mut events.withdraw_event, DepositWithdrawEvent<X> {
            amount,
            amount_ANI: pending,
        });
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    public entry fun emergency_withdraw<X>(
        account: &signer
    ) acquires MasterChefData, UserInfo, Events {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        let resource_account_signer = account::create_signer_with_capability(&mc_data.signer_cap);

        let acc_addr = signer::address_of(account);
        assert!(exists<UserInfo<X>>(acc_addr), ERR_INSUFFICIENT_AMOUNT);
        let user_info = borrow_global_mut<UserInfo<X>>(acc_addr);

        register_ANI(account);
        let amount = user_info.amount;
        coin::transfer<X>(&resource_account_signer, acc_addr, amount);
        user_info.amount = 0;
        user_info.reward_debt = 0;

        // event
        let events = borrow_global_mut<Events<X>>(RESOURCE_ACCOUNT_ADDRESS);
        event::emit_event(&mut events.emergency_withdraw_event, DepositWithdrawEvent<X> {
            amount,
            amount_ANI: 0,
        });
    }

    // Stake ANI coins to MC
    public entry fun enter_staking(
        account: &signer,
        amount: u64
    ) acquires MasterChefData, PoolInfo, UserInfo, Caps, Events {
        deposit<ANI>(account, amount);
    }

    // Withdraw ANI coins from STAKING.
    public entry fun leave_staking(
        account: &signer,
        amount: u64
    ) acquires MasterChefData, PoolInfo, UserInfo, Caps, Events {
        withdraw<ANI>(account, amount);
    }

    fun safe_transfer_ANI(
        resource_account_signer: &signer,
        to: address,
        amount: u64
    ) {
        let balance = coin::balance<ANI>(signer::address_of(resource_account_signer));
        if (amount > balance) {
            coin::transfer<ANI>(resource_account_signer, to, balance);
        } else {
            coin::transfer<ANI>(resource_account_signer, to, amount);
        };
    }

    public entry fun set_admin_address(
        admin: &signer,
        new_admin_address: address
    ) acquires MasterChefData {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        mc_data.admin_address = new_admin_address;
    }

    public entry fun set_dao_address(
        admin: &signer,
        new_dao_address: address
    ) acquires MasterChefData {
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        mc_data.dao_address = new_dao_address;
    }

    public entry fun set_dao_percent(
        admin: &signer,
        new_dao_percent: u64
    ) acquires MasterChefData {
        assert!(new_dao_percent <= 100, ERR_FORBIDDEN);
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        mc_data.dao_percent = new_dao_percent;
    }

    public entry fun set_per_second_ANI(
        admin: &signer,
        per_second_ANI: u128
    ) acquires MasterChefData {
        assert!(per_second_ANI >= 1000000 && per_second_ANI <= 10000000000, ERR_FORBIDDEN);   // 0.01 - 100 ANI/s
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        mc_data.per_second_ANI = per_second_ANI;
    }

    public entry fun set_bonus_multiplier(
        admin: &signer,
        bonus_multiplier: u64
    ) acquires MasterChefData {
        assert!(bonus_multiplier >= 1 && bonus_multiplier <= 10, ERR_FORBIDDEN);
        let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        mc_data.bonus_multiplier = bonus_multiplier;
    }

    // after call this, direct mint will be disabled forever
    public entry fun set_disable_direct_mint(
        admin: &signer
    ) acquires MasterChefData, Caps {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(signer::address_of(admin) == mc_data.admin_address, ERR_FORBIDDEN);
        let caps = borrow_global_mut<Caps>(RESOURCE_ACCOUNT_ADDRESS);
        caps.direct_mint = false;
    }

    /**
     *  public functions for other contract
     */

    // vie function to see deposit amount
    public fun get_user_info_amount<X>(
        acc_addr: address
    ): u64 acquires UserInfo {
        if (exists<UserInfo<X>>(acc_addr)) {
            let user_info = borrow_global<UserInfo<X>>(acc_addr);
            return user_info.amount
        } else {
            return 0
        }
    }

    // View function to see pending ANIs
    public fun pending_ANI<X>(
        acc_addr: address
    ): u64 acquires MasterChefData, PoolInfo, UserInfo, Caps {
        assert!(exists<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS), ERR_LPCOIN_NOT_EXIST);

        update_pool<X>();
        let pool = borrow_global<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        assert!(exists<UserInfo<X>>(acc_addr), ERR_INSUFFICIENT_AMOUNT);
        let user_info = borrow_global<UserInfo<X>>(acc_addr);

        let pending = (user_info.amount as u128) * pool.acc_ANI_per_share / ACC_ANI_PRECISION - user_info.reward_debt;
        (pending as u64)
    }

    public fun get_mc_data(): (u64, u64, u64, u64, u128) acquires MasterChefData {
        let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
        (mc_data.total_alloc_point, mc_data.dao_percent, mc_data.bonus_multiplier, mc_data.start_timestamp, mc_data.per_second_ANI)
    }

    public fun get_pool_info<X>(): (u128, u64, u64) acquires PoolInfo {
        let pool_info = borrow_global<PoolInfo<X>>(RESOURCE_ACCOUNT_ADDRESS);
        (pool_info.acc_ANI_per_share, pool_info.last_reward_timestamp, pool_info.alloc_point)
    }

    public fun get_user_info<X>(acc_addr: address): (u64, u128) acquires UserInfo {
        let user_info = borrow_global<UserInfo<X>>(acc_addr);
        (user_info.amount, user_info.reward_debt)
    }

    public fun get_lp_list(): vector<TypeInfo> acquires LPInfo {
        let lp_info = borrow_global<LPInfo>(RESOURCE_ACCOUNT_ADDRESS);
        lp_info.lp_list
    }

    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::account::create_account_for_test;
    #[test_only]
    const INIT_COIN:u64 = 100000000000000000;
    #[test_only]
    const TEST_ERROR:u64 = 10000;
    #[test_only]
    struct LPCoin1 has store {}
    #[test_only]
    struct LPCoin2 has store {}
    #[test_only]
    struct CapsTest<phantom X> has key {
        mint: MintCapability<X>,
        freeze: FreezeCapability<X>,
        burn: BurnCapability<X>,
    }

    #[test_only]
    public fun test_init(creator: &signer, someone_else: &signer) acquires MasterChefData, LPInfo, Caps {
        genesis::setup();
        create_account_for_test(signer::address_of(creator));
        create_account_for_test(signer::address_of(someone_else));
        {
            init_module(creator);
        };
        {
            let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            mc_data.start_timestamp = 0;
        };
        // init LPCoin
        {
            let (coin_b, coin_f, coin_m) =
                coin::initialize<LPCoin1>(creator, utf8(b"LPCoin1"), utf8(b"LPCoin1"), 6, true);
            register_coin<LPCoin1>(someone_else);
            let coins = coin::mint<LPCoin1>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(someone_else), coins);
            move_to(creator, CapsTest<LPCoin1> { mint: coin_m, freeze: coin_f, burn: coin_b });
        };
        {
            let (coin_b, coin_f, coin_m) =
                coin::initialize<LPCoin2>(creator, utf8(b"LPCoin2"), utf8(b"LPCoin2"), 6, true);
            register_coin<LPCoin2>(someone_else);
            let coins = coin::mint<LPCoin2>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(someone_else), coins);
            move_to(creator, CapsTest<LPCoin2> { mint: coin_m, freeze: coin_f, burn: coin_b });
        };
        {
            let caps = borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS);
            register_coin<ANI>(someone_else);
            let coins = coin::mint<ANI>(INIT_COIN, &caps.mint);
            coin::deposit(signer::address_of(someone_else), coins);
        }
    }

    #[test_only]
    public fun test_init_another(creator: &signer, someone_else: &signer, another_one: &signer) acquires MasterChefData, LPInfo, Caps {
        genesis::setup();
        create_account_for_test(signer::address_of(creator));
        create_account_for_test(signer::address_of(someone_else));
        create_account_for_test(signer::address_of(another_one));
        {
            init_module(creator);
        };
        {
            let mc_data = borrow_global_mut<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            mc_data.start_timestamp = 0;
        };
        // init LPCoin
        {
            let (coin_b, coin_f, coin_m) =
                coin::initialize<LPCoin1>(creator, utf8(b"LPCoin1"), utf8(b"LPCoin1"), 6, true);
            register_coin<LPCoin1>(someone_else);
            let coins = coin::mint<LPCoin1>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(someone_else), coins);
            register_coin<LPCoin1>(another_one);
            let coins = coin::mint<LPCoin1>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(another_one), coins);
            move_to(creator, CapsTest<LPCoin1> { mint: coin_m, freeze: coin_f, burn: coin_b });
        };
        {
            let (coin_b, coin_f, coin_m) =
                coin::initialize<LPCoin2>(creator, utf8(b"LPCoin2"), utf8(b"LPCoin2"), 6, true);
            register_coin<LPCoin2>(someone_else);
            let coins = coin::mint<LPCoin2>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(someone_else), coins);
            register_coin<LPCoin2>(another_one);
            let coins = coin::mint<LPCoin2>(INIT_COIN, &coin_m);
            coin::deposit(signer::address_of(another_one), coins);
            move_to(creator, CapsTest<LPCoin2> { mint: coin_m, freeze: coin_f, burn: coin_b });
        };
        {
            let caps = borrow_global<Caps>(RESOURCE_ACCOUNT_ADDRESS);
            register_coin<ANI>(someone_else);
            let coins = coin::mint<ANI>(INIT_COIN, &caps.mint);
            coin::deposit(signer::address_of(someone_else), coins);
            register_coin<ANI>(another_one);
            let coins = coin::mint<ANI>(INIT_COIN, &caps.mint);
            coin::deposit(signer::address_of(another_one), coins);
        }
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_deposit_1(creator: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 500/(500+1000) = 1/3 reward
        deposit<LPCoin1>(someone_else, 1000000);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);
        deposit<LPCoin1>(someone_else, 0);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 3 * 9 / 10, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_deposit_2(creator: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<LPCoin1>(someone_else, 123456);
        deposit<LPCoin2>(someone_else, 111111);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);
        deposit<LPCoin2>(someone_else, 0);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10
                || coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10 - 1,
                TEST_ERROR);
        deposit<LPCoin1>(someone_else, 0);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10 * 2
                || coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + (bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10 - 1) * 2,
                TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_withdraw(creator: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<LPCoin1>(someone_else, 123456);
        deposit<LPCoin2>(someone_else, 111111);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);

        withdraw<LPCoin1>(someone_else, 123456);
        withdraw<LPCoin2>(someone_else, 111111);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10* 2
                || coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + (bonus_multiplier * (per_second_ANI as u64) * 1111 / 4* 9 / 10 - 1) * 2,
                TEST_ERROR);
        assert!(coin::balance<LPCoin1>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
        assert!(coin::balance<LPCoin2>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_multiple_user(creator: &signer, someone_else: &signer, another_one: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init_another(creator, someone_else, another_one);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<LPCoin1>(someone_else, 123456);
        deposit<LPCoin2>(someone_else, 111111);
        deposit<LPCoin1>(another_one, 123456);
        deposit<LPCoin2>(another_one, 111111);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);

        withdraw<LPCoin1>(someone_else, 123456);
        withdraw<LPCoin2>(someone_else, 111111);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 / 4 * 9 / 10 / 2 * 2
                || coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + (bonus_multiplier * (per_second_ANI as u64) * 1111 / 4* 9 / 10 - 1) / 2 * 2,
                TEST_ERROR);
        assert!(coin::balance<LPCoin1>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
        assert!(coin::balance<LPCoin2>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_multiple_user_2(creator: &signer, someone_else: &signer, another_one: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init_another(creator, someone_else, another_one);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<LPCoin1>(someone_else, 100000);
        deposit<LPCoin2>(someone_else, 100000);
        // 1000 seconds pass
        timestamp::fast_forward_seconds(1000);
        deposit<LPCoin1>(another_one, 100000);
        deposit<LPCoin2>(another_one, 100000);
        // 1000 seconds pass
        timestamp::fast_forward_seconds(1000);

        deposit<LPCoin1>(someone_else, 0);
        deposit<LPCoin2>(someone_else, 0);
        assert!(coin::balance<ANI>(signer::address_of(someone_else))
                    == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10 * 2
                    + bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10,
                TEST_ERROR);

        let pending1 = pending_ANI<LPCoin1>(signer::address_of(another_one));
        let pending2 = pending_ANI<LPCoin2>(signer::address_of(another_one));
        assert!(pending1 == bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10 / 2,
                TEST_ERROR);
        assert!(pending2 == bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10 / 2,
                TEST_ERROR);

        deposit<LPCoin1>(another_one, 0);
        deposit<LPCoin2>(another_one, 0);
        assert!(coin::balance<ANI>(signer::address_of(another_one))
                    == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10,
                TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_multiple_user_3(creator: &signer, someone_else: &signer, another_one: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init_another(creator, someone_else, another_one);
        let amount = 100000;
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<ANI>(someone_else, amount);
        deposit<ANI>(another_one, amount);
        // 1000 seconds pass
        timestamp::fast_forward_seconds(1000);
        deposit<ANI>(someone_else, amount);
        deposit<ANI>(another_one, amount);

        assert!(coin::balance<ANI>(signer::address_of(someone_else))
                    == INIT_COIN - 2 * amount + bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10,
                TEST_ERROR);
        assert!(coin::balance<ANI>(signer::address_of(another_one))
                    == INIT_COIN - 2 * amount + bonus_multiplier * (per_second_ANI as u64) * 1000 / 4 * 9 / 10,
                TEST_ERROR);

        // 1000 seconds pass
        timestamp::fast_forward_seconds(1000);
        deposit<ANI>(someone_else, amount);
        deposit<ANI>(another_one, amount);
        // 1000 seconds pass
        timestamp::fast_forward_seconds(1000);
        withdraw<ANI>(someone_else, amount * 3);
        withdraw<ANI>(another_one, amount * 3);

        let pending1 = pending_ANI<ANI>(signer::address_of(someone_else));
        let pending2 = pending_ANI<ANI>(signer::address_of(another_one));
        assert!(pending1 == 0, TEST_ERROR);
        assert!(pending2 == 0, TEST_ERROR);

        assert!(coin::balance<ANI>(signer::address_of(someone_else))
                    == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 3000 / 4 * 9 / 10,
                TEST_ERROR);
        assert!(coin::balance<ANI>(signer::address_of(another_one))
                    == INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 3000 / 4 * 9 / 10,
                TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_emergency_withdraw(creator: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        deposit<LPCoin1>(someone_else, 123456);
        deposit<LPCoin2>(someone_else, 111111);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);

        emergency_withdraw<LPCoin1>(someone_else);
        emergency_withdraw<LPCoin2>(someone_else);
        assert!(coin::balance<LPCoin1>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
        assert!(coin::balance<LPCoin2>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_staking(creator: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
        };

        add<LPCoin1>(creator, 500);    // 1/4
        add<LPCoin2>(creator, 500);    // 1/4
        enter_staking(someone_else, 100000);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) ==
                INIT_COIN - 100000,
                TEST_ERROR);

        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);
        leave_staking(someone_else, 0);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) ==
                INIT_COIN - 100000 + bonus_multiplier * (per_second_ANI as u64) * 1111 * 9 / 10 / 2,
                TEST_ERROR);

        // another 1111 seconds pass
        timestamp::fast_forward_seconds(1111);
        leave_staking(someone_else, 100000);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) ==
                INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 * 9 / 10 / 2 * 2,
                TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, new_admin = @0x99, someone_else = @0x11)]
    #[expected_failure(abort_code = 103)]
    public entry fun test_dao_setting_error(creator: &signer, new_admin: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, Caps {
        test_init(creator, someone_else);
        create_account_for_test(signer::address_of(new_admin));
        set_dao_address(new_admin, signer::address_of(new_admin));
    }

    #[test(creator = @MasterChefDepolyer, new_admin = @0x99, someone_else = @0x11)]
    public entry fun test_dao_setting(creator: &signer, new_admin: &signer, someone_else: &signer)
            acquires MasterChefData, LPInfo, PoolInfo, UserInfo, Caps, Events {
        test_init(creator, someone_else);
        set_bonus_multiplier(creator, 4);
        set_per_second_ANI(creator, 111111111);
        let bonus_multiplier;
        let per_second_ANI;
        {
            let mc_data = borrow_global<MasterChefData>(RESOURCE_ACCOUNT_ADDRESS);
            bonus_multiplier = mc_data.bonus_multiplier;
            per_second_ANI = mc_data.per_second_ANI;
            assert!(bonus_multiplier == 4, TEST_ERROR);
            assert!(per_second_ANI == 111111111, TEST_ERROR);
        };
        create_account_for_test(signer::address_of(new_admin));
        set_admin_address(creator, signer::address_of(new_admin));
        set_dao_address(new_admin, signer::address_of(new_admin));
        set_dao_percent(new_admin, 20);
        register_coin<ANI>(new_admin);

        add<LPCoin1>(new_admin, 1000);    // 1/2
        enter_staking(someone_else, 100000);
        // 1111 seconds pass
        timestamp::fast_forward_seconds(1111);
        leave_staking(someone_else, 100000);

        // user balance
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) ==
                INIT_COIN + bonus_multiplier * (per_second_ANI as u64) * 1111 * 8 / 10 / 2,
                TEST_ERROR);

        // admin fee
        withdraw_dao_fee();
        assert!(coin::balance<ANI>(signer::address_of(new_admin)) ==
                bonus_multiplier * (per_second_ANI as u64) * 1111 * 2 / 10,
                TEST_ERROR);
    }

    #[test(deployer = @MasterChefDepolyer)]
    public entry fun test_resource_account(deployer: &signer) {
        genesis::setup();
        create_account_for_test(signer::address_of(deployer));
        let addr = account::create_resource_address(&signer::address_of(deployer), x"CF");
        assert!(addr == @MasterChefResourceAccount, TEST_ERROR);
    }
}
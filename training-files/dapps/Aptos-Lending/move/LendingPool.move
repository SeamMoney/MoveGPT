address Quantum {

module LendingPool {
    
    use std::event;
    use std::signer;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::type_info;

    use Quantum::Rebase;
    use Quantum::SafeMathU64;
    use Quantum::PoolOracle;

    // config
    // liquidate * 10% -> fees_earned
    const DISTRIBUTION_PART: u64 = 10;
    const DISTRIBUTION_PRECISION: u64 = 100;
    // borrow_opening_fee = 1000  => 1%
    const BORROW_OPENING_FEE_PRECISION: u64 = 100 * 1000;
    // liquidation_multiplier = 105000 => 105%
    const LIQUIDATION_MULTIPLIER_PRECISION: u64 = 100 * 1000;
    // ltv collaterization_rate = 90000 => 90%
    const COLLATERIZATION_RATE_PRECISION: u64 = 100 * 1000;
    // liquidation_threshold = 95000 => 95% (threshold > ltv)
    const LIQUIDATION_THRESHOLD_PRECISION: u64 = 100 * 1000;
    // 1e18
    const INTEREST_PRECISION: u64 = 1000000000000000000;
    // 2.5 * (1e18 /365.25 * 3600 * 24 /100 ) => 2.5%
    // interest_per_second = 2500 => 2.5%
    const INTEREST_CONVERSION: u64 = 365250 * 3600 * 24 * 100;
    // EXCHANGE_RATE_PRECISION == PoolOracle.PRECISION
    const EXCHANGE_RATE_PRECISION: u64 = 1000000 * 1000000;

    struct AccrueEvent has drop, store { amount: u64 }
    struct FeeToEvent has drop, store { fee_to: address }

    struct PoolInfo<phantom PoolType> has key, store {
        collaterization_rate: u64,
        liquidation_threshold: u64,
        liquidation_multiplier: u64,
        borrow_opening_fee: u64,
        interest_per_second: u64,
        fee_to: address,
        fees_earned: u64,
        last_accrued: u64,
        fee_to_events: event::EventHandle<FeeToEvent>,
        accrue_events: event::EventHandle<AccrueEvent>,
        deprecated: bool,
    }

    struct PoolMinBorrow<phantom PoolType> has key, store {
        min_borrow: u64,
    }

    // Collateral
    struct RemoveCollateralEvent has drop, store { from: address, to: address, amount: u64 }
    struct AddCollateralEvent has drop, store { account: address, amount: u64 }
    struct LiquidateCollateralEvent has drop, store { account: address, amount: u64 }
    struct TotalCollateral<phantom PoolType, phantom CollateralTokenType> has key, store {
        balance: Coin<CollateralTokenType>,    // user deposited
        add_events: event::EventHandle<AddCollateralEvent>,
        remove_events: event::EventHandle<RemoveCollateralEvent>,
        liquidate_events: event::EventHandle<LiquidateCollateralEvent>,
    }

    // borrow
    struct BorrowEvent has drop, store { from: address, to: address, amount: u64, part: u64 }
    struct RepayEvent has drop, store { from: address, to: address, amount: u64, part: u64 }
    struct LiquidateEvent has drop, store { account: address, amount: u64 }
    struct DepositEvent has drop, store { account: address, amount: u64 }
    struct WithdrawEvent has drop, store { account: address, amount: u64 }
    struct TotalBorrow<phantom PoolType, phantom BorrowTokenType> has key, store {
        balance: Coin<BorrowTokenType>,    // left to borrow
        borrow_events: event::EventHandle<BorrowEvent>,
        repay_events: event::EventHandle<RepayEvent>,
        liquidate_events: event::EventHandle<LiquidateEvent>,
        withdraw_events: event::EventHandle<WithdrawEvent>,
        deposit_events: event::EventHandle<DepositEvent>,
    }

    // user position
    struct Position<phantom PoolType> has key, store { collateral: u64, borrow: u64 }

    // error code
    const ERR_ALREADY_DEPRECATED: u64 = 100;
    const ERR_NOT_AUTHORIZED: u64 = 101;
    const ERR_USER_INSOLVENT: u64 = 102;
    const ERR_ACCEPT_TOKEN: u64 = 103;
    const ERR_LENGTH_NOT_EQUAL: u64 = 104;
    const ERR_EMPTY: u64 = 105;

    const ERR_NOT_EXIST: u64 = 111;
    const ERR_BORROW_NOT_EXIST: u64 = 112;
    const ERR_BORROW_TOO_BIG_AMOUNT: u64 = 113;
    const ERR_BORROW_TOO_LITTLE_AMOUNT: u64 = 114;

    const ERR_ZERO_AMOUNT: u64 = 121;
    const ERR_TOO_BIG_AMOUNT: u64 = 122;

    // cap
    struct SharedRebaseModifyCapability<phantom T> has key, store { cap: Rebase::ModifyCapability<T> }

    // =================== private fun ===================

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    // get T issuer
    fun t_address<T: store>(): address { coin_address<T>() }

    fun assert_owner<T: store>(account: &signer): address {
        let owner = t_address<T>();
        assert!(signer::address_of(account) == owner, ERR_NOT_AUTHORIZED);
        owner
    }

    fun assert_total_borrow<PoolType: store, BorrowTokenType: store>(): address {
        let pool_owner = t_address<PoolType>();
        assert!(exists<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner), ERR_NOT_EXIST);
        pool_owner
    }

    fun assert_total_collateral<PoolType: store, CollateralTokenType>(): address {
        let pool_owner = t_address<PoolType>();
        assert!(exists<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner), ERR_NOT_EXIST);
        pool_owner
    }

    // =================== initialize ===================
    // only PoolType issuer can initialize
    public fun initialize<PoolType: store, CollateralTokenType, BorrowTokenType: store>(
        account: &signer,
        collaterization_rate: u64,
        liquidation_threshold: u64,
        liquidation_multiplier: u64,
        borrow_opening_fee: u64,
        interest_per_second: u64,
        amount: u64,
        oracle_name: vector<u8>,
    ) acquires TotalBorrow {
        let owner = assert_owner<PoolType>(account);

        // init PoolInfo
        move_to(
            account,
            PoolInfo<PoolType> {
                collaterization_rate: collaterization_rate,
                liquidation_threshold: liquidation_threshold,
                liquidation_multiplier: liquidation_multiplier,
                borrow_opening_fee: borrow_opening_fee,
                interest_per_second: interest_per_second,
                fee_to: owner,
                fees_earned: 0,
                last_accrued: timestamp::now_seconds(),
                accrue_events: account::new_event_handle<AccrueEvent>(account),
                fee_to_events: account::new_event_handle<FeeToEvent>(account),
                deprecated: false,
            },
        );

        // init collateral
        move_to(
            account,
            TotalCollateral<PoolType, CollateralTokenType> {
                balance: coin::zero<CollateralTokenType>(),
                add_events: account::new_event_handle<AddCollateralEvent>(account),
                remove_events: account::new_event_handle<RemoveCollateralEvent>(account),
                liquidate_events: account::new_event_handle<LiquidateCollateralEvent>(account),
            },
        );

        // init borrow
        move_to(
            account,
            TotalBorrow<PoolType, BorrowTokenType> {
                balance: coin::zero<BorrowTokenType>(),
                borrow_events: account::new_event_handle<BorrowEvent>(account),
                repay_events: account::new_event_handle<RepayEvent>(account),
                liquidate_events: account::new_event_handle<LiquidateEvent>(account),
                withdraw_events: account::new_event_handle<WithdrawEvent>(account),
                deposit_events: account::new_event_handle<DepositEvent>(account)
            },
        );
        Rebase::initialize<TotalBorrow<PoolType, BorrowTokenType>>(account);
        move_to(
            account,
            SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>> {
                cap: Rebase::remove_modify_capability<TotalBorrow<PoolType, BorrowTokenType>>(account),
            },
        );

        // deposit borrow token
        if (amount > 0) {
            deposit<PoolType, BorrowTokenType>(account, amount);
        };

        // oracle
        PoolOracle::register<PoolType>(account, oracle_name);
    }

    public fun init_min_borrow<PoolType: store>(account: &signer, value: u64) {
        assert_owner<PoolType>(account);
        move_to(account, PoolMinBorrow<PoolType> { min_borrow: value });
    }

    public fun set_min_borrow<PoolType: store>(account: &signer, value: u64) acquires PoolMinBorrow {
        let settings = borrow_global_mut<PoolMinBorrow<PoolType>>(signer::address_of(account));
        settings.min_borrow = value;
    }

    public fun get_min_borrow<PoolType: store>(): u64 acquires PoolMinBorrow {
        let addr = t_address<PoolType>();
        if (!exists<PoolMinBorrow<PoolType>>(addr)) {
            0
        } else {
            borrow_global<PoolMinBorrow<PoolType>>(addr).min_borrow
        }
    }

    // =================== borrowToken deposit and withdraw ===================
    // deposit borrowToken
    public fun deposit<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        amount: u64,
    ) acquires TotalBorrow {
        assert_owner<PoolType>(account);
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        coin::merge(&mut total_borrow.balance, coin::withdraw<BorrowTokenType>(account, amount));
        event::emit_event(
            &mut total_borrow.deposit_events,
            DepositEvent {
                account: signer::address_of(account),
                amount: amount,
            },
        );
    }

    public fun withdraw<PoolType: store, BorrowTokenType: store>()
    acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow {
        accrue<PoolType, BorrowTokenType>();
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        let to = info.fee_to;
        let fees = info.fees_earned;
        assert!(coin::is_account_registered<BorrowTokenType>(to), ERR_ACCEPT_TOKEN);
        assert!(fees > 0, ERR_ZERO_AMOUNT);

        // transfer borrow token
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        coin::deposit(to, coin::extract(&mut total_borrow.balance, fees));
        event::emit_event(
            &mut total_borrow.withdraw_events,
            WithdrawEvent { account: to, amount: fees },
        );

        // Affect info
        info.fees_earned = 0;
        event::emit_event(&mut info.accrue_events, AccrueEvent { amount: 0 });
    }

    // =================== oracle ===================
    // Gets the exchange rate. I.e how much collateral to buy 1 asset.
    public fun update_exchange_rate<PoolType: store>(): u64 {
        let (exchange_rate, _) = PoolOracle::update<PoolType>();
        exchange_rate
    }

    // =================== tools fun ===================
    // get user's position (collateral, borrowed part)
    public fun position<PoolType: store>(addr: address): (u64, u64) acquires Position {
        if (!exists<Position<PoolType>>(addr)) {
            (0, 0)
        } else {
            let user_info = borrow_global<Position<PoolType>>(addr);
            (user_info.collateral, user_info.borrow)
        }
    }

    public fun get_exchange_rate<PoolType: store>(): (u64, u64) {
        let (exchange_rate, _, _) = PoolOracle::get<PoolType>();
        (exchange_rate, EXCHANGE_RATE_PRECISION)
    }

    public fun latest_exchange_rate<PoolType: store>(): (u64, u64) {
        PoolOracle::latest_exchange_rate<PoolType>()
    }

    // return base config (Maximum collateral ratio, Liquidation threshold, Liquidation fee, Borrow fee, Interest)
    public fun pool_info<PoolType: store>(): (u64, u64, u64, u64, u64) acquires PoolInfo {
        let info = borrow_global<PoolInfo<PoolType>>(t_address<PoolType>());
        (
            info.collaterization_rate,
            info.liquidation_threshold,
            info.liquidation_multiplier,
            info.borrow_opening_fee,
            info.interest_per_second,
        )
    }

    public fun is_deprecated<PoolType: store>(): bool acquires PoolInfo {
        borrow_global<PoolInfo<PoolType>>(t_address<PoolType>()).deprecated
    }

    // return collateral deposited amount
    public fun collateral_info<PoolType: store, CollateralTokenType>(): u64 acquires TotalCollateral {
        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();
        let total_collateral = borrow_global<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);
        coin::value(&total_collateral.balance)
    }

    // return borrow info (total borrowed part, total borrowed amount, left to borrow)
    public fun borrow_info<PoolType: store, BorrowTokenType: store>(): (u64, u64, u64) acquires TotalBorrow {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let total_borrow = borrow_global<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        let (elastic, base) = Rebase::get<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        (base, elastic, coin::value(&total_borrow.balance))
    }

    public fun set_fee_to<PoolType: store>(account: &signer, new_fee_to: address) acquires PoolInfo {
        let owner = assert_owner<PoolType>(account);
        let info = borrow_global_mut<PoolInfo<PoolType>>(owner);
        // Affect fee_to
        info.fee_to = new_fee_to;
        event::emit_event(&mut info.fee_to_events, FeeToEvent { fee_to: new_fee_to });
    }

    // return fee config (Maximum collateral ratio, Liquidation fee, Borrow fee, Interest)
    public fun fee_info<PoolType: store>(): (address, u64, u64) acquires PoolInfo {
        let info = borrow_global<PoolInfo<PoolType>>(t_address<PoolType>());
        (
            info.fee_to,
            info.fees_earned,
            info.last_accrued,
        )
    }

    // part <=> amount
    public fun toAmount<PoolType: store, BorrowTokenType: store>(part: u64, roundUp: bool): u64 {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, part, roundUp)
    }

    public fun toPart<PoolType: store, BorrowTokenType: store>(amount: u64, roundUp: bool): u64 {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        Rebase::toBase<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, amount, roundUp)
    }

    // =================== accumulation of fees ===================
    // Accrues the interest on the borrowed tokens and handles the accumulation of fees.
    public fun accrue<PoolType: store, BorrowTokenType: store>() acquires SharedRebaseModifyCapability, PoolInfo {
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        assert!(exists<PoolInfo<PoolType>>(pool_owner), ERR_NOT_EXIST);

        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        let elapsedTime = (timestamp::now_seconds() - info.last_accrued);
        if (elapsedTime == 0) {
            return
        };
        info.last_accrued = timestamp::now_seconds();

        let (elastic, base) = Rebase::get<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        if (base == 0) {
            return
        };

        // Accrue interest
        let interest = SafeMathU64::safe_mul_div(info.interest_per_second, INTEREST_PRECISION, INTEREST_CONVERSION);
        let amount = SafeMathU64::safe_mul_div(elastic, interest * elapsedTime, INTEREST_PRECISION);

        // Affect elastic
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        Rebase::addElasticWithCapability<TotalBorrow<PoolType, BorrowTokenType>>(&cap.cap, amount);

        // Affect fee
        info.fees_earned = info.fees_earned + amount;
        event::emit_event(&mut info.accrue_events, AccrueEvent { amount });
    }

    // =================== user solvent ===================
    // Concrete implementation of `is_solvent`. Includes a third parameter to allow caching `exchange_rate`.
    // exchange_rate The exchange rate. Used to cache the `exchange_rate` between calls.
    public fun is_solvent<PoolType: store, BorrowTokenType: store>(
        addr: address,
        exchange_rate: u64,
    ): bool acquires PoolInfo, Position {
        // accrue must have already been called!
        // user have no Collateral and borrow
        if (!exists<Position<PoolType>>(addr)) {
            return true
        };
        let user_info = borrow_global<Position<PoolType>>(addr);
        if (user_info.borrow == 0) { return true };
        if (user_info.collateral == 0) { return false };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        // user_total_collateral = user_info.collateral * (EXCHANGE_RATE_PRECISION * info.liquidation_threshold / LIQUIDATION_THRESHOLD_PRECISION)
        // user_total_borrow = Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, user_info.borrow, true) * exchange_rate
        // user_total_collateral >= user_total_borrow
        SafeMathU64::safe_more_than_or_equal(
            user_info.collateral,
            EXCHANGE_RATE_PRECISION * info.liquidation_threshold / LIQUIDATION_THRESHOLD_PRECISION,
            Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, user_info.borrow, true),
            exchange_rate,
        )
    }

    // Checks if the user is solvent in the closed liquidation case at the end of the function body
    fun assert_is_solvent<PoolType: store, BorrowTokenType: store>(addr: address) acquires PoolInfo, Position {
        // let (exchange_rate, _, _) = PoolOracle::get<PoolType>();
        let (exchange_rate, _) = latest_exchange_rate<PoolType>();
        assert!(is_solvent<PoolType, BorrowTokenType>(addr, exchange_rate), ERR_USER_INSOLVENT);
    }

    // =================== add collateral ===================
    // Adds `collateral` to the account
    public fun add_collateral<PoolType: store, CollateralTokenType>(
        account: &signer,
        amount: u64,
    ) acquires TotalCollateral, Position, PoolInfo {
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        let account_addr = signer::address_of(account);
        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();

        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        assert!(!info.deprecated, ERR_ALREADY_DEPRECATED);

        // Affect TotalCollateral
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);
        coin::merge(&mut total_collateral.balance, coin::withdraw<CollateralTokenType>(account, amount));
        event::emit_event(
            &mut total_collateral.add_events,
            AddCollateralEvent {
                account: signer::address_of(account),
                amount: amount,
            },
        );

        // Affect user info
        if (!exists<Position<PoolType>>(account_addr)) {
            move_to(account, Position<PoolType> { collateral: amount, borrow: 0 });
        } else {
            let user_info = borrow_global_mut<Position<PoolType>>(account_addr);
            user_info.collateral = user_info.collateral + amount;
        };
    }

    // =================== remove collateral ===================
    // Removes `amount` amount of collateral and transfers it to `receiver`.
    public fun remove_collateral<PoolType: store, CollateralTokenType, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        amount: u64,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, Position {
        let account_addr = signer::address_of(account);
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        do_remove_collateral<PoolType, CollateralTokenType>(account_addr, receiver, amount);
        assert_is_solvent<PoolType, BorrowTokenType>(account_addr);
    }

    fun do_remove_collateral<PoolType: store, CollateralTokenType>(
        from: address,
        to: address,
        amount: u64,
    ) acquires TotalCollateral, Position {
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        assert!(exists<Position<PoolType>>(from), ERR_NOT_EXIST);
        let user_info = borrow_global_mut<Position<PoolType>>(from);
        assert!(amount <= user_info.collateral, ERR_TOO_BIG_AMOUNT);
        assert!(coin::is_account_registered<CollateralTokenType>(to), ERR_ACCEPT_TOKEN);

        let pool_owner = assert_total_collateral<PoolType, CollateralTokenType>();
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);

        // Affect user info
        user_info.collateral = user_info.collateral - amount;
        if (user_info.collateral == 0 && user_info.borrow == 0) {
            let Position<PoolType> {collateral: _, borrow: _} = move_from<Position<PoolType>>(from);
        };

        // transfer collateral
        coin::deposit(to, coin::extract(&mut total_collateral.balance, amount));
        event::emit_event(
            &mut total_collateral.remove_events,
            RemoveCollateralEvent { from: from, to: to, amount: amount },
        );
    }

    // =================== borrow ===================
    // Sender borrows `amount` and transfers it to `receiver`.
    public fun borrow<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        amount: u64,
    ): u64 acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow, Position, PoolMinBorrow {
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        do_borrow<PoolType, BorrowTokenType>(account, receiver, amount)
    }

    fun do_borrow<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        to: address,
        amount: u64,
    ): u64 acquires SharedRebaseModifyCapability, TotalBorrow, PoolInfo, Position, PoolMinBorrow {
        let from = signer::address_of(account);
        assert!(amount > 0, ERR_ZERO_AMOUNT);
        assert!(amount >= get_min_borrow<PoolType>(), ERR_BORROW_TOO_LITTLE_AMOUNT);
        // add_collateral will move_to<Position>
        assert!(exists<Position<PoolType>>(from), ERR_NOT_EXIST);
        if (!coin::is_account_registered<BorrowTokenType>(to)) {
            if (from == to) {
                coin::register<BorrowTokenType>(account);
            } else {
                assert!(false, ERR_ACCEPT_TOKEN);
            };
        };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        assert!(amount <= coin::value(&total_borrow.balance), ERR_TOO_BIG_AMOUNT);

        let position = borrow_global_mut<Position<PoolType>>(from);

        // borrow fee
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        assert!(!info.deprecated, ERR_ALREADY_DEPRECATED);
        let fee_amount = SafeMathU64::safe_mul_div(amount, info.borrow_opening_fee, BORROW_OPENING_FEE_PRECISION);

        // Checks if the user can borrow
        let (exchange_rate, _) = latest_exchange_rate<PoolType>();
        assert!(
            SafeMathU64::safe_more_than_or_equal(
                position.collateral,
                EXCHANGE_RATE_PRECISION * info.collaterization_rate / COLLATERIZATION_RATE_PRECISION,
                toAmount<PoolType, BorrowTokenType>(position.borrow, true) + amount + fee_amount,
                exchange_rate,
            ),
            ERR_BORROW_TOO_BIG_AMOUNT,
        );

        // Affect total borrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        let part = Rebase::addByElasticWithCapability(&cap.cap, amount + fee_amount, true);

        // Affect accrue info
        info.fees_earned = info.fees_earned + fee_amount;
        event::emit_event(&mut info.accrue_events, AccrueEvent { amount: fee_amount });

        // Affect user position
        position.borrow = position.borrow + part;

        // Affect borrow
        coin::deposit(to, coin::extract(&mut total_borrow.balance, amount));
        event::emit_event(
            &mut total_borrow.borrow_events,
            BorrowEvent { from: from, to: to, amount: amount, part: part },
        );
        part
    }

    // =================== repay ===================
    // Repays a loan
    public fun repay<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        receiver: address,
        part: u64,
    ): u64 acquires SharedRebaseModifyCapability, PoolInfo, TotalBorrow, Position {
        // accrue must be called because we check solvency
        accrue<PoolType, BorrowTokenType>();
        do_repay<PoolType, BorrowTokenType>(account, receiver, part)
    }

    fun do_repay<PoolType: store, BorrowTokenType: store>(
        account: &signer,
        to: address,
        part: u64,
    ): u64 acquires SharedRebaseModifyCapability, TotalBorrow, Position {
        assert!(part > 0, ERR_ZERO_AMOUNT);
        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();
        let position = borrow_global_mut<Position<PoolType>>(to);
        assert!(part <= position.borrow, ERR_TOO_BIG_AMOUNT);

        // Affect total borrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        let amount = Rebase::subByBaseWithCapability(&cap.cap, part, true);

        // Affect user position
        position.borrow = position.borrow - part;

        // Affect borrow token
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        coin::merge(&mut total_borrow.balance, coin::withdraw<BorrowTokenType>(account, amount));
        event::emit_event(
            &mut total_borrow.repay_events,
            RepayEvent { from: signer::address_of(account), to: to, amount: amount, part: part },
        );
        amount
    }

    // =================== liquidate ===================
    // only script function
    // Handles the liquidation of users' balances, once the users' amount of collateral is too low
    // @param users An array of user addresses.
    // @param max_parts A one-to-one mapping to `users`, contains maximum (partial) borrow amounts (to liquidate) of the respective user.
    // @param to Address of the receiver in open liquidations.
    public fun liquidate<PoolType: store, CollateralTokenType, BorrowTokenType: store>(
        account: &signer,
        users: &vector<address>,
        max_parts: &vector<u64>,
        to: address,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, TotalBorrow, Position {
        let account_addr = signer::address_of(account);
        let user_len = vector::length<address>(users);
        assert!(user_len > 0, ERR_EMPTY);
        assert!(user_len == vector::length<u64>(max_parts), ERR_LENGTH_NOT_EQUAL);
        if (!coin::is_account_registered<CollateralTokenType>(to)) {
            if (account_addr == to) {
                coin::register<BorrowTokenType>(account);
            } else {
                assert!(false, ERR_ACCEPT_TOKEN);
            };
        };

        let pool_owner = assert_total_borrow<PoolType, BorrowTokenType>();

        // update exchange and accrue
        // let exchange_rate = update_exchange_rate<PoolType>();
        let (exchange_rate, _) = latest_exchange_rate<PoolType>();
        accrue<PoolType, BorrowTokenType>();

        let info = borrow_global<PoolInfo<PoolType>>(pool_owner);
        let liquidation_multiplier = info.liquidation_multiplier;
        let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner);
        let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(pool_owner);

        let allCollateral: u64 = 0;
        let allBorrowAmount: u64 = 0;
        let allBorrowPart: u64 = 0;
        let i = 0;
        while (i < user_len) {
            let addr = *vector::borrow<address>(users, i);
            let max_part = *vector::borrow<u64>(max_parts, i);
            if (!is_solvent<PoolType, BorrowTokenType>(addr, exchange_rate)) {

                // get borrow part
                let position = borrow_global_mut<Position<PoolType>>(addr);
                let part = position.borrow;
                if (max_part < position.borrow) { part = max_part; };

                // get borrow amount
                let amount = Rebase::toElastic<TotalBorrow<PoolType, BorrowTokenType>>(pool_owner, part, false);

                // get collateral
                //amount.mul(LIQUIDATION_MULTIPLIER).mul(_exchangeRate) / (LIQUIDATION_MULTIPLIER_PRECISION*EXCHANGE_RATE_PRECISION)
                let collateral = SafeMathU64::safe_mul_div(
                    amount,
                    liquidation_multiplier * exchange_rate,
                    LIQUIDATION_MULTIPLIER_PRECISION * EXCHANGE_RATE_PRECISION,
                );

                // Affect position
                position.borrow = position.borrow - part;
                position.collateral = position.collateral - collateral;
                event::emit_event(
                    &mut total_borrow.repay_events,
                    RepayEvent { from: account_addr, to: addr, amount: amount, part: part },
                );
                event::emit_event(
                    &mut total_collateral.remove_events,
                    RemoveCollateralEvent { from: addr, to: to, amount: collateral },
                );

                // keeps total
                allCollateral = allCollateral + collateral;
                allBorrowAmount = allBorrowAmount + amount;
                allBorrowPart = allBorrowPart + part;
            };
            i = i + 1;
        };
        assert!(allBorrowAmount > 0, ERR_ZERO_AMOUNT);

        // Affect total botrrow
        let cap = borrow_global<SharedRebaseModifyCapability<TotalBorrow<PoolType, BorrowTokenType>>>(pool_owner);
        Rebase::subWithCapability(&cap.cap, allBorrowAmount, allBorrowPart);

        // Apply a percentual fee share to sShare holders ( must after `Affect total borrow`)
        // (allBorrowAmount.mul(LIQUIDATION_MULTIPLIER) / LIQUIDATION_MULTIPLIER_PRECISION).sub(allBorrowAmount).mul(DISTRIBUTION_PART) / DISTRIBUTION_PRECISION;
        let distribution_amount = SafeMathU64::safe_mul_div(
            SafeMathU64::safe_mul_div(
                allBorrowAmount,
                liquidation_multiplier,
                LIQUIDATION_MULTIPLIER_PRECISION,
            ) - allBorrowAmount,
            DISTRIBUTION_PART,
            DISTRIBUTION_PRECISION,
        );
        let info = borrow_global_mut<PoolInfo<PoolType>>(pool_owner);
        info.fees_earned = info.fees_earned + distribution_amount;
        event::emit_event(&mut info.accrue_events, AccrueEvent { amount: distribution_amount });

        allBorrowAmount = allBorrowAmount + distribution_amount;

        // Affect tansfer collateral
        coin::deposit(to, coin::extract(&mut total_collateral.balance, allCollateral));

        // Affect tansfer
        coin::merge(&mut total_borrow.balance, coin::withdraw<BorrowTokenType>(account, allBorrowAmount));
        event::emit_event(
            &mut total_borrow.liquidate_events,
            LiquidateEvent { account: account_addr, amount: allBorrowAmount },
        );
    }

    // =================== cook ===================

    const ACTION_ADD_COLLATERAL: u8 = 1;
    const ACTION_REMOVE_COLLATERAL: u8 = 2;
    const ACTION_BORROW: u8 = 3;
    const ACTION_REPAY: u8 = 4;
    // address 0x0 = 0x00000000000000000000000000000000
    public fun cook<PoolType: store, CollateralTokenType, BorrowTokenType: store>(
        account: &signer,
        actions: &vector<u8>,
        collateral_amount: u64,
        remove_collateral_amount: u64,
        remove_collateral_to: address,
        borrow_amount: u64,
        borrow_to: address,
        repay_part: u64,
        repay_to: address,
    ) acquires SharedRebaseModifyCapability, PoolInfo, TotalCollateral, TotalBorrow, Position, PoolMinBorrow {
        // update exchange and accrue
        // update_exchange_rate<PoolType>();
        accrue<PoolType, BorrowTokenType>();

        let account_addr = signer::address_of(account);
        let check_solvent = false;
        let len = vector::length<u8>(actions);
        let i = 0;
        while (i < len) {
            let action = *vector::borrow<u8>(actions, i);
            if (action == ACTION_ADD_COLLATERAL) {
                add_collateral<PoolType, CollateralTokenType>(account, collateral_amount);
            } else if (action == ACTION_REMOVE_COLLATERAL) {
                do_remove_collateral<PoolType, CollateralTokenType>(
                    account_addr,
                    remove_collateral_to,
                    remove_collateral_amount,
                );
                check_solvent = true;
            } else if (action == ACTION_BORROW) {
                do_borrow<PoolType, BorrowTokenType>(account, borrow_to, borrow_amount);
                check_solvent = true;
            } else if (action == ACTION_REPAY) {
                do_repay<PoolType, BorrowTokenType>(account, repay_to, repay_part);
            };
            i = i + 1;
        };
        if (check_solvent) {
            assert_is_solvent<PoolType, BorrowTokenType>(account_addr);
        };
    }

    // =================== deprecated ===================
    public fun deprecated<PoolType: store, CollateralTokenType, BorrowTokenType: store>(
        account: &signer,
        to: address,
        collateral_amount: u64,
        borrow_amount: u64,
    ) acquires PoolInfo, TotalBorrow, TotalCollateral {
        let owner = assert_owner<PoolType>(account);
        let info = borrow_global_mut<PoolInfo<PoolType>>(owner);

        // Affect deprecated
        info.deprecated = true;

        // Affect collateral
        if (collateral_amount > 0) {
            let total_collateral = borrow_global_mut<TotalCollateral<PoolType, CollateralTokenType>>(owner);
            coin::deposit(to, coin::extract(&mut total_collateral.balance, collateral_amount));
        };

        // Affect borrow token
        if (borrow_amount > 0) {
            let total_borrow = borrow_global_mut<TotalBorrow<PoolType, BorrowTokenType>>(owner);
            coin::deposit(to, coin::extract(&mut total_borrow.balance, borrow_amount));
        };
    } 

}
}
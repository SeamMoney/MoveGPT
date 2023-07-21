module launch_pad::offering_v2 {
    use std::error;
    use std::signer::{ address_of};

    use aptos_std::type_info;
    use aptos_std::event::{EventHandle, emit_event, new_event_handle};
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self};

    use launch_pad::math::{calculate_amount_by_price_factor};

    const PAD_OWNER: address = @launch_pad;

    // error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const ECONFIGURED: u64 = 1;
    const EWRONG_TIME_ARGS: u64 = 2;
    const EDENOMINATOR_IS_ZERO: u64 = 3;
    const EFUNDRAISER_IS_ZERO: u64 = 4;
    const EWRONG_FUNDRAISER: u64 = 5;
    const EAMOUNT_IS_ZERO: u64 = 6;
    const ENOT_REGISTERD: u64 = 7;
    const ENOT_CONFIGURED: u64 = 8;
    const EROUND_IS_NOT_READY: u64 = 9;
    const EROUND_IS_FINISHED: u64 = 10;
    const EWRONG_COIN_PAIR: u64 = 11;
    const EREACHED_MAX_PARTICIPATION: u64 = 12;
    const EEXPECT_SALE_AMOUNT_IS_ZERO: u64 = 13;
    const ESALE_AMOUNT_IS_NOT_ENOUGH: u64 = 14;
    const ENUMERATOR_IS_ZERO: u64 = 15;
    const ERESERVES_IS_EMPTY: u64 = 16;

    struct OfferingCoin {}

    struct UserStatus<phantom SaleCoinType, phantom RaiseCoinType> has key {
        // sale coin decimal
        purchased_amount: u64,
        ticket: coin::Coin<OfferingCoin>,
        regiser_events: EventHandle<RegiserEvent>,
        buy_events: EventHandle<BuyEvent>,
        claim_ticket_events: EventHandle<ClaimTicketEvent>,
    }

    struct RegiserEvent has store, drop {
        user: address,
        ticket: u64,
    }

    struct BuyEvent has store, drop {
        user: address,
        purchased: u64,
        payment: u64,
        actual_payment: u64
    }

    struct ClaimTicketEvent has store, drop {
        user: address,
        ticket: u64,
    }

    struct Duration has store {
        start_at: u64,
        duration: u64,
    }

    struct Config<phantom SaleCoinType, phantom RaiseCoinType> has store {
        fundraiser: address,
        registraion_duration: Duration,
        sale_duration: Duration,

        lock_duration: u64,

        //  price: 1 sale_coin / n raise_coin
        ex_numerator: u64,
        ex_denominator: u64,

        // decimal is sale coin
        expect_sale_amount: u64,
    }

    struct Pool<phantom SaleCoinType, phantom RaiseCoinType> has key {
        cfg: Config<SaleCoinType, RaiseCoinType>,
        tickets_amount: u64,
        to_sell: coin::Coin<SaleCoinType>,
        raised: coin::Coin<RaiseCoinType>,
        initialize_pool_events: EventHandle<InitializePoolEvent>,
        deposit_sale_coin_events: EventHandle<DepositToSellEvent>,
        withdraw_raise_funds_events: EventHandle<WithdrawRaiseFundsEvent>,
    }

    struct InitializePoolEvent has store, drop {
        fundraiser: address,
        // decimal is sale coin
        expect_sale_amount: u64,
    }

    struct DepositToSellEvent has store, drop {
        fundraiser: address,
        // decimal is sale coin
        sale_amount: u64,
    }

    struct WithdrawRaiseFundsEvent has store, drop {
        fundraiser: address,
        raised_amount: u64,
        expect_sale_amount: u64,
        sale_refunds_amount: u64,
    }

    public entry fun initialize_pool<SaleCoinType, RaiseCoinType>(
        manager: &signer,
        fundraiser: address,
        start_registraion_at: u64,
        registraion_duration: u64,
        start_sale_at: u64,
        sale_duration: u64,
        lock_duration: u64,
        ex_numerator: u64,
        ex_denominator: u64,
        expect_sale_amount: u64
    ) {
        assert!(type_info::type_of<SaleCoinType>() != type_info::type_of<RaiseCoinType>(), error::invalid_argument(EWRONG_COIN_PAIR));

        let manager_addr = address_of(manager);
        assert!(!exists<Pool<SaleCoinType, RaiseCoinType>>(manager_addr), error::unavailable(ECONFIGURED));

        assert!(manager_addr == PAD_OWNER, error::permission_denied(ENOT_MODULE_OWNER));
        assert!(fundraiser != @0x0, error::invalid_argument(EFUNDRAISER_IS_ZERO));

        assert!(timestamp::now_seconds() <= start_registraion_at, error::invalid_argument(EWRONG_TIME_ARGS));
        assert!(registraion_duration > 0, error::invalid_state(EWRONG_TIME_ARGS));

        assert!(start_registraion_at + registraion_duration <= start_sale_at, error::invalid_state(EWRONG_TIME_ARGS));
        assert!(sale_duration != 0, error::invalid_state(EWRONG_TIME_ARGS));

        assert!(lock_duration != 0, error::invalid_state(EWRONG_TIME_ARGS));

        assert!(ex_numerator != 0, error::invalid_argument(ENUMERATOR_IS_ZERO));
        assert!(ex_denominator != 0, error::invalid_argument(EDENOMINATOR_IS_ZERO));

        assert!(expect_sale_amount != 0, error::invalid_argument(EEXPECT_SALE_AMOUNT_IS_ZERO));

        let pool = Pool<SaleCoinType, RaiseCoinType> {
            cfg: Config<SaleCoinType, RaiseCoinType> {
                fundraiser,
                registraion_duration: Duration {
                    start_at: start_registraion_at,
                    duration: registraion_duration,
                },
                sale_duration: Duration {
                    start_at: start_sale_at,
                    duration: sale_duration,
                },
                lock_duration,
                ex_numerator,
                ex_denominator,
                expect_sale_amount
            },
            tickets_amount: 0,
            to_sell: coin::zero<SaleCoinType>(),
            raised: coin::zero<RaiseCoinType>(),
            initialize_pool_events: new_event_handle<InitializePoolEvent>(manager),
            deposit_sale_coin_events: new_event_handle<DepositToSellEvent>(manager),
            withdraw_raise_funds_events: new_event_handle<WithdrawRaiseFundsEvent>(manager),
        };

        emit_event(
            &mut pool.initialize_pool_events,
            InitializePoolEvent { fundraiser, expect_sale_amount }
        );
        move_to(manager, pool);
    }

    public entry fun deposit_to_sell<SaleCoinType, RaiseCoinType>(fundraiser: &signer, amount_to_sell: u64) acquires Pool {
        assert!(exists<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER), error::unavailable(ENOT_CONFIGURED));

        let pool = borrow_global_mut<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER);
        assert!(address_of(fundraiser) == pool.cfg.fundraiser, error::unauthenticated(EWRONG_FUNDRAISER));
        assert!(coin::value<SaleCoinType>(&pool.to_sell) != pool.cfg.expect_sale_amount, error::unavailable(ECONFIGURED));
        assert!(amount_to_sell == pool.cfg.expect_sale_amount, error::invalid_argument(ESALE_AMOUNT_IS_NOT_ENOUGH));

        let to_sell = coin::withdraw<SaleCoinType>(fundraiser, pool.cfg.expect_sale_amount);
        coin::merge<SaleCoinType>(&mut pool.to_sell, to_sell);
        emit_event(
            &mut pool.deposit_sale_coin_events,
            DepositToSellEvent { fundraiser: address_of(fundraiser), sale_amount: pool.cfg.expect_sale_amount }
        );

        // in case that fundraiser doesn't deposit before registration
        let now = timestamp::now_seconds();
        if (now > pool.cfg.registraion_duration.start_at) {
            pool.cfg.sale_duration.start_at = now - pool.cfg.registraion_duration.start_at + pool.cfg.sale_duration.start_at;
            pool.cfg.registraion_duration.start_at = now;
        };
    }

    public entry fun register<SaleCoinType, RaiseCoinType>(user: &signer, ticket: u64) acquires Pool, UserStatus {
        assert!(ticket != 0, error::invalid_argument(EAMOUNT_IS_ZERO));

        let pool = borrow_global_mut<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER);
        let now = timestamp::now_seconds();
        assert!(now >= pool.cfg.registraion_duration.start_at, error::unavailable(EROUND_IS_NOT_READY));
        assert!(now < duration_end_at(&pool.cfg.registraion_duration), error::unavailable(EROUND_IS_FINISHED));
        assert!(coin::value<SaleCoinType>(&pool.to_sell) != 0, error::unavailable(ERESERVES_IS_EMPTY));

        let user_addr = address_of(user);
        if (!exists<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr)) {
            move_to(user,
                UserStatus<SaleCoinType, RaiseCoinType> {
                    purchased_amount: 0,
                    ticket: coin::zero<OfferingCoin>(),
                    regiser_events: new_event_handle<RegiserEvent>(user),
                    buy_events: new_event_handle<BuyEvent>(user),
                    claim_ticket_events: new_event_handle<ClaimTicketEvent>(user),
                });
        };

        pool.tickets_amount = pool.tickets_amount + ticket;

        let user_status = borrow_global_mut<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr);
        coin::merge<OfferingCoin>(&mut user_status.ticket, coin::withdraw<OfferingCoin>(user, ticket));

        emit_event<RegiserEvent>(
            &mut user_status.regiser_events,
            RegiserEvent {
                user: user_addr,
                ticket,
            });
    }

    fun duration_end_at(duration: &Duration): u64 {
        duration.start_at + duration.duration
    }

    public entry fun buy<SaleCoinType, RaiseCoinType>(user: &signer, payment: u64) acquires Pool, UserStatus {
        assert!(payment != 0, error::invalid_argument(EAMOUNT_IS_ZERO));

        let pool = borrow_global_mut<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER);
        assert!(coin::value<SaleCoinType>(&pool.to_sell) != 0, error::resource_exhausted(ERESERVES_IS_EMPTY));

        let now = timestamp::now_seconds();
        assert!(now >= pool.cfg.sale_duration.start_at, error::unavailable(EROUND_IS_NOT_READY));
        assert!(now < duration_end_at(&pool.cfg.sale_duration), error::unavailable(EROUND_IS_FINISHED));

        let user_addr = address_of(user);
        assert!(exists<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr), error::unauthenticated(ENOT_REGISTERD));

        let user_status = borrow_global_mut<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr);
        let max_purchasable = coin::value<OfferingCoin>(&user_status.ticket) * pool.cfg.expect_sale_amount / pool.tickets_amount;
        assert!(user_status.purchased_amount < max_purchasable, error::resource_exhausted(EREACHED_MAX_PARTICIPATION));

        let purchasable = calculate_amount_by_price_factor<RaiseCoinType, SaleCoinType>(payment, pool.cfg.ex_numerator, pool.cfg.ex_denominator) ;
        if (purchasable + user_status.purchased_amount > max_purchasable) {
            purchasable = max_purchasable - user_status.purchased_amount
        };

        let actual_payment = payment - calculate_amount_by_price_factor<SaleCoinType, RaiseCoinType>(purchasable, pool.cfg.ex_denominator, pool.cfg.ex_numerator);
        user_status.purchased_amount = user_status.purchased_amount + purchasable;

        coin::merge<RaiseCoinType>(&mut pool.raised, coin::withdraw<RaiseCoinType>(user, actual_payment));
        coin::deposit<SaleCoinType>(user_addr, coin::extract<SaleCoinType>(&mut pool.to_sell, purchasable));

        emit_event<BuyEvent>(
            &mut user_status.buy_events,
            BuyEvent {
                user: user_addr,
                purchased: purchasable,
                payment,
                actual_payment,
            });
    }


    public entry fun claim_ticket<SaleCoinType, RaiseCoinType>(user: & signer) acquires Pool, UserStatus {
        let pool = borrow_global_mut<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER);
        assert!(timestamp::now_seconds() >= (duration_end_at(&pool.cfg.sale_duration) + pool.cfg.lock_duration), error::unavailable(EROUND_IS_NOT_READY));

        let user_addr = address_of(user);
        assert!(exists<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr), error::unauthenticated(ENOT_REGISTERD));

        let user_status = borrow_global_mut<UserStatus<SaleCoinType, RaiseCoinType>>(user_addr);
        let ticket = coin::value<OfferingCoin>(&user_status.ticket);
        assert!(ticket > 0, error::resource_exhausted(ERESERVES_IS_EMPTY));

        coin::deposit<OfferingCoin>(user_addr, coin::extract_all(&mut user_status.ticket));

        emit_event<ClaimTicketEvent>(
            &mut user_status.claim_ticket_events,
            ClaimTicketEvent {
                user: user_addr,
                ticket,
            });
    }

    public entry fun withdraw_raise_funds<SaleCoinType, RaiseCoinType>(fundraiser: & signer) acquires Pool {
        assert!(exists<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER), error::unavailable(ENOT_CONFIGURED));

        let pool = borrow_global_mut<Pool<SaleCoinType, RaiseCoinType>>(PAD_OWNER);
        let fundraiser_addr = address_of(fundraiser);
        assert!(pool.cfg.fundraiser == fundraiser_addr, error::unauthenticated(EWRONG_FUNDRAISER));
        assert!(timestamp::now_seconds() >= duration_end_at(&pool.cfg.sale_duration), error::unavailable(EROUND_IS_NOT_READY));

        let sale_refunds_amount = coin::value<SaleCoinType>(&pool.to_sell);
        let raised_amount = coin::value<RaiseCoinType>(&pool.raised);
        assert!(sale_refunds_amount>0 && raised_amount>0, error::resource_exhausted(ERESERVES_IS_EMPTY));

        coin::deposit<SaleCoinType>(fundraiser_addr, coin::extract_all<SaleCoinType>(&mut pool.to_sell));
        coin::deposit<RaiseCoinType>(fundraiser_addr, coin::extract_all<RaiseCoinType>(&mut pool.raised));

        emit_event(
            &mut pool.withdraw_raise_funds_events,
            WithdrawRaiseFundsEvent {
                fundraiser: fundraiser_addr,
                raised_amount,
                expect_sale_amount: pool.cfg.expect_sale_amount,
                sale_refunds_amount,
            }
        );
    }

    // 1. manger set config
    // 2. fundraiser deposit
    // 3. user pay offering-coin to register
    // 4. user buy coin with u
    // 5. fundraiser withdraw all u and coin
    // 6. user wait to release offering-coin
    // todo: 7. deduct part of ticket amount , send nft
    // 8. condering of moving from the user_status storage when user withdraw

    #[test_only]
    struct SaleCoin {}

    #[test_only]
    struct RaiseCoin {}

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 65547)]
    fun test_initialize_pool_same_coin(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, SaleCoin>(manager, @0x1, now + 60, 600, now + 120, 600, 600, 2, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 65538)]
    fun test_wrong_start_registraion_at(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10009999 * 100);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now - 10, 600, now + 120, 600, 600, 2, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 196610)]
    fun test_wrong_zero_registration_duraion(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 0, now + 120, 0, 600, 2, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 196610)]
    fun test_wrong_start_sale_at(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now, 100, 600, 2, 3, 100);
    }


    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 196610)]
    fun test_wrong_zero_sale_duraion(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 720, 0, 600, 2, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 196610)]
    fun test_wrong_zero_lock_duraion(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 820, 100, 0, 2, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 65551)]
    fun test_wrong_zero_ex_numerator(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 720, 1, 100, 0, 3, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 65539)]
    fun test_wrong_zero_ex_denominator(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 720, 100, 100, 1, 0, 100);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    fun expect_initialized_pool_status(aptos_framework: &signer, manager: &signer) acquires Pool {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 820, 500, 100, 20, 10, 100);
        assert!(exists<Pool<SaleCoin, RaiseCoin>>(address_of(manager)), 1);

        let pool = borrow_global<Pool<SaleCoin, RaiseCoin>>(address_of(manager));
        assert!(pool.cfg.fundraiser == @0x1, 2);
        assert!(pool.cfg.lock_duration == 100, 3);
        assert!(pool.cfg.registraion_duration.start_at == now, 4);
        assert!(pool.cfg.registraion_duration.duration == 600, 5);
        assert!(pool.cfg.registraion_duration.start_at == now, 6);
        assert!(pool.cfg.sale_duration.start_at == now + 820, 7);
        assert!(pool.cfg.sale_duration.duration == 500, 8);
        assert!(pool.cfg.expect_sale_amount == 100, 9);
        assert!(pool.cfg.ex_numerator == 20, 10);
        assert!(pool.cfg.ex_denominator == 10, 11);
        assert!(pool.tickets_amount == 0, 12);
        assert!(coin::value(&pool.to_sell) == 0, 13);
        assert!(coin::value(&pool.raised) == 0, 14);
    }

    #[test(aptos_framework = @aptos_framework, manager = @launch_pad)]
    #[expected_failure(abort_code = 851969)]
    fun test_repeat_initialize_pool(aptos_framework: &signer, manager: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let now = timestamp::now_seconds();
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 820, 1, 100, 20, 10, 100);
        initialize_pool<SaleCoin, RaiseCoin>(manager, @0x1, now, 600, now + 820, 1, 100, 20, 10, 100);
    }
}

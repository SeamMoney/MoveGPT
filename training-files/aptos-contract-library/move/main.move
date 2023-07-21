// when need new input coin (swap from C or depoist C), you should call init_coin<C>
module Valkyrie::main {
    use std::signer;
    use std::string::{Self};
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_std::debug;
    use aptos_std::type_info;
    use aptos_framework::account;

    use aptos_std::event;
    //    use test_utils::test_coin::{Self, USDT};
    // use liquidswap::script;

    // event
    struct EventsStore<phantom X, phantom Y, phantom Curve> has key {
        estimate_event_handle: event::EventHandle<EstimateEvent<X, Y, Curve>>,
    }

    struct EstimateEvent<phantom X, phantom Y, phantom Curve> has drop, store {
        x_in: u64,
        y_out: u64,
    }

//    struct AptoswapResource<phantom X, phantom Y> has key {
//        pool: AptoswapPool<X, Y>,
//    }

    const ERR_0: u64 = 0; // not admin

    const ERR_1: u64 = 1; // no profit

    const ERR_2: u64 = 2; // coin already initialized

    const ERR_3: u64 = 3; // invalid dex type

    const ERR_4: u64 = 4; // when swap, start coin and end coin should be same coin

    struct TestCoin has key, drop {}

    struct TestCapabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
        freeze_cap: FreezeCapability<CoinType>,
    }

    struct CoinResource<phantom CoinType> has key {
        coin: Coin<CoinType>,
    }

    struct SwapType<phantom X, phantom Y, phantom Curve> {
        amount_in: u64,
    }

    public entry fun swap_depth_1<C1, C2, C3, C1_C2_Curve, C2_C3_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
    ) acquires CoinResource, EventsStore {
        assert!(type_info::type_of<C1>() == type_info::type_of<C3>(), ERR_4);
        let estimated_c3_amount_out = estimate_depth_2_<C1, C2, C3, C1_C2_Curve, C2_C3_Curve>(account, c1_amount_in, type1, type2, false);
        assert!(estimated_c3_amount_out >= c1_amount_in, ERR_1);

        withdraw_<C1>(signer::address_of(account), c1_amount_in);
        let c2_amount_out = swap_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1);
        let c1_amount_out = swap_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2);
        deposit<C1>(account, c1_amount_out);
    }

    public entry fun swap_depth_2<C1, C2, C3, C4, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
    ) acquires CoinResource, EventsStore {
        assert!(type_info::type_of<C1>() == type_info::type_of<C4>(), ERR_4);
        let estimated_c4_amount_out = estimate_depth_3_<C1, C2, C3, C4, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve>(account, c1_amount_in, type1, type2, type3, false);
        assert!(estimated_c4_amount_out >= c1_amount_in, ERR_1);

        withdraw_<C1>(signer::address_of(account), c1_amount_in);
        let c2_amount_out = swap_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1);
        let c3_amount_out = swap_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2);
        let c1_amount_out = swap_depth_1_<C3, C4, C3_C4_Curve>(account, c3_amount_out, type3);
        assert!(c1_amount_out >= c1_amount_in, ERR_1);
        deposit<C1>(account, c1_amount_out);
    }

    public entry fun swap_depth_3<C1, C2, C3, C4, C5, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve, C4_C5_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
        type4: u64,
    ) acquires CoinResource, EventsStore {
        assert!(type_info::type_of<C1>() == type_info::type_of<C5>(), ERR_4);
        let estimated_c5_amount_out = estimate_depth_4_<C1, C2, C3, C4, C5, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve, C4_C5_Curve>(account, c1_amount_in, type1, type2, type3, type4,false);
        assert!(estimated_c5_amount_out >= c1_amount_in, ERR_1);

        withdraw_<C1>(signer::address_of(account), c1_amount_in);
        let c2_amount_out = swap_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1);
        let c3_amount_out = swap_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2);
        let c4_amount_out = swap_depth_1_<C3, C4, C3_C4_Curve>(account, c3_amount_out, type3);
        let c1_amount_out = swap_depth_1_<C4, C5, C4_C5_Curve>(account, c4_amount_out, type4);
        assert!(c1_amount_out >= c1_amount_in, ERR_1);
        deposit<C1>(account, c1_amount_out);
    }

    public entry fun estimate_depth_1<C1, C2, C1_C2_Curve>(
        account: &signer,
        amount_in: u64,
        type1: u64,
        emit_event: bool,
    ) acquires EventsStore {
        estimate_depth_1_<C1, C2, C1_C2_Curve>(account, amount_in, type1, emit_event);
    }

    fun estimate_depth_1_<X, Y, Curve>(
        account: &signer,
        amount_in: u64,
        type: u64,
        emit_event: bool,
    ): u64 acquires EventsStore {
        dex_type_check(type);
        init_pair<X, Y, Curve>(account);
        let amount_out = 0;
        if (type == 0) {
            use liquidswap::router;
            amount_out = router::get_amount_out<X, Y, Curve>(amount_in);
        } else if (type == 1) {
            use SwapDeployer::AnimeSwapPoolV1;
            amount_out = AnimeSwapPoolV1::get_amounts_out_1_pair<X, Y>(amount_in);
        } else if (type == 2) {
            use aux::amm;
            amount_out = amm::au_out<X, Y>(amount_in);
            //            let aptoswapPool: &mut AptoswapPool<X, Y> = borrow_global_mut<Pool<X, Y>>(@Aptoswap);
            //            amount_out = pool
        } else if (type == 3) {
            abort ERR_3;
        };

        if (emit_event) {
            let events_store = borrow_global_mut<EventsStore<X, Y, Curve>>(signer::address_of(account));
            event::emit_event(
                &mut events_store.estimate_event_handle,
                EstimateEvent<X, Y, Curve> {
                    x_in: amount_in,
                    y_out: amount_out,
                });
        };
        amount_out
    }

    public entry fun estimate_depth_2<C1, C2, C3, C1_C2_Curve, C2_C3_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        emit_event: bool,
    ) acquires EventsStore {
        estimate_depth_2_<C1, C2, C3, C1_C2_Curve, C2_C3_Curve>(account, c1_amount_in, type1, type2, emit_event);
    }

    fun estimate_depth_2_<C1, C2, C3, C1_C2_Curve, C2_C3_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        emit_event: bool,
    ): u64 acquires EventsStore {
        let c2_amount_out = estimate_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1, emit_event);
        let c3_amount_out = estimate_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2, emit_event);
        c3_amount_out
    }

    public entry fun estimate_depth_3<C1, C2, C3, C4, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
        emit_event: bool,
    ) acquires EventsStore {
        estimate_depth_3_<C1, C2, C3, C4, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve>(account, c1_amount_in, type1, type2, type3, emit_event);
    }

    fun estimate_depth_3_<C1, C2, C3, C4, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
        emit_event: bool,
    ): u64 acquires EventsStore {
        let c2_amount_out = estimate_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1, emit_event);
        let c3_amount_out = estimate_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2, emit_event);
        let c4_amount_out = estimate_depth_1_<C3, C4, C3_C4_Curve>(account, c3_amount_out, type3, emit_event);
        c4_amount_out
    }

    public entry fun estimate_depth_4<C1, C2, C3, C4, C5, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve, C4_C5_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
        type4: u64,
        emit_event: bool,
    ) acquires EventsStore {
        estimate_depth_4_<C1, C2, C3, C4, C5, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve, C4_C5_Curve>(account, c1_amount_in, type1, type2, type3, type4, emit_event);
    }

    fun estimate_depth_4_<C1, C2, C3, C4, C5, C1_C2_Curve, C2_C3_Curve, C3_C4_Curve, C4_C5_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type1: u64,
        type2: u64,
        type3: u64,
        type4: u64,
        emit_event: bool,
    ): u64 acquires EventsStore {
        let c2_amount_out = estimate_depth_1_<C1, C2, C1_C2_Curve>(account, c1_amount_in, type1, emit_event);
        let c3_amount_out = estimate_depth_1_<C2, C3, C2_C3_Curve>(account, c2_amount_out, type2, emit_event);
        let c4_amount_out = estimate_depth_1_<C3, C4, C3_C4_Curve>(account, c3_amount_out, type3, emit_event);
        let c5_amount_out = estimate_depth_1_<C4, C5, C4_C5_Curve>(account, c4_amount_out, type4, emit_event);
        c5_amount_out
    }

    fun swap_depth_1_<C1, C2, C1_C2_Curve>(
        account: &signer,
        c1_amount_in: u64,
        type: u64,
    ): u64 {
        dex_type_check(type);
        register_coin_<C1>(account);
        register_coin_<C2>(account);
        let c2BalanceBefore = coin::balance<C2>(signer::address_of(account));
        if (type == 0) {
            liquidswap::scripts::swap<C1, C2, C1_C2_Curve>(
                account,
                c1_amount_in,
                1
            );
        } else if (type == 1) {
            use SwapDeployer::AnimeSwapPoolV1;
            AnimeSwapPoolV1::swap_exact_coins_for_coins_entry<C1, C2>(account, c1_amount_in, 1);
        } else if (type == 2) {
            use aux::amm;
            amm::swap_exact_coin_for_coin_with_signer<C1, C2>(account, c1_amount_in, 1);
        } else if (type == 3) {
            use Aptoswap::pool;
            pool::swap_x_to_y<C1, C2>(account, c1_amount_in, 1);
        };
        let c2BalanceAfter = coin::balance<C2>(signer::address_of(account));
        let res = c2BalanceAfter - c2BalanceBefore;
        res
    }

    fun dex_type_check(type: u64) {
        assert!(type == 0 || type == 1 || type == 2, ERR_3);
    }

    public entry fun init_pair<X, Y, Curve> (
        account: &signer,
    ) {
        if (!exists<EventsStore<X, Y, Curve>>(signer::address_of(account))) {
            let events_store = EventsStore<X, Y, Curve> {
                estimate_event_handle: account::new_event_handle(account),
            };
            move_to(account, events_store);
        };
    }

    public entry fun init_coin<CoinType> (
        valkyrie_admin: &signer,
    ) {
        assert!(signer::address_of(valkyrie_admin) == @admin, ERR_0);
        if (!exists<CoinResource<CoinType>>(signer::address_of(valkyrie_admin))) {
            let coin = coin::zero<CoinType>();
            move_to(valkyrie_admin, CoinResource<CoinType> {
                coin: coin,
            });
        };
    }

    fun register_coin_<CoinType>(
        account: &signer,
    ) {
        if (!coin::is_account_registered<CoinType>(signer::address_of(account))) {
            coin::register<CoinType>(account);
        }
    }

    // when deposit new coin
    // 1. init_coin
    public entry fun deposit<CoinType> (
        account: &signer,
        value: u64,
    ) acquires CoinResource {
        register_coin_<CoinType>(account);
        let coin = coin::withdraw<CoinType>(account, value);
        let coin_resource = borrow_global_mut<CoinResource<CoinType>>(@Valkyrie);

        // deposit to resource
        coin::merge(&mut coin_resource.coin, coin);
    }

     // only valkyrie admin
     public entry fun withdraw<CoinType>(
         valkyrie_admin: &signer,
         to: address,
         value: u64,
     ) acquires CoinResource {
         assert!(signer::address_of(valkyrie_admin) == @admin, ERR_0);
         withdraw_<CoinType>(to, value);
     }

    fun withdraw_<CoinType>(
        to: address,
        value: u64,
    ) acquires CoinResource {
        let coin_resource = borrow_global_mut<CoinResource<CoinType>>(@Valkyrie);
        if (value == 0) {
            value = coin::value<CoinType>(&coin_resource.coin);
        };
        let coin = coin::extract(&mut coin_resource.coin, value);
        coin::deposit<CoinType>(to, coin);
    }

    #[test(account = @admin)]
    fun withdraw_test(account: signer) acquires CoinResource, TestCapabilities {
        account::create_account_for_test(signer::address_of(&account));

        let name = string::utf8(b"name");
        let symbol = string::utf8(b"symbol");
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<TestCoin>(
                &account,
                name,
                symbol,
                18,
                true
            );
        coin::destroy_freeze_cap<TestCoin>(freeze_cap);
        coin::destroy_burn_cap<TestCoin>(burn_cap);
        coin::destroy_mint_cap<TestCoin>(mint_cap);

        init_coin<TestCoin>(&account);

        move_to(&account, TestCapabilities<TestCoin> {
            mint_cap: mint_cap,
            burn_cap: burn_cap,
            freeze_cap: freeze_cap
        });

        let caps = borrow_global<TestCapabilities<TestCoin>>(signer::address_of(&account));

        let deposit_coin = coin::mint<TestCoin>(10, &caps.mint_cap);
        coin::register<TestCoin>(&account);
        coin::deposit<TestCoin>(signer::address_of(&account), deposit_coin);

//        test_coin::register_coin<USDT>(
//            &account,
//            b"USDT",
//            b"USDT",
//            6,
//        );
//        let usdt_coins = test_coin::mint<USDT>(&account, 9000);
        deposit<TestCoin>(&account, 10);

        let destination = account::create_account_for_test(@test_coin_destination);

        coin::register<TestCoin>(&destination);
        withdraw<TestCoin>(&account, signer::address_of(&destination), 0);

        let balance = coin::balance<TestCoin>(signer::address_of(&destination));
        let name = string::utf8(b"hihihihi");
        debug::print(&name);
        debug::print(&balance);
        assert!(balance == 10, 1);
    }
}
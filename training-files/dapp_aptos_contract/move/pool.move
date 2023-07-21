module qve_protocol::pool {
    use std::signer;

    use liquidswap::coin_helper::is_sorted;
    use liquidswap::router_v2;
    use liquidswap::curves::Uncorrelated;
    use liquidswap::curves::Stable;
    use liquidswap_lp::lp_coin::LP;

    use aptos_framework::coin;

    use qve_protocol::coins::{Self, QVE, MQVE, AQVE, USDC, USDT};

    const MODULE_OWNER: address = @qve_protocol;
    const ERR_NOT_MODULE_OWNER: u64 = 0;

    public entry fun create_pool<X,Y>(account: &signer) {
        assert!(signer::address_of(account) == MODULE_OWNER, ERR_NOT_MODULE_OWNER);

        assert!(is_sorted<X, Y>(), 0);
        router_v2::register_pool<X, Y, Uncorrelated>(account);
    }

    public entry fun create_stable_pool<X,Y>(account: &signer) {
        assert!(signer::address_of(account) == MODULE_OWNER, ERR_NOT_MODULE_OWNER);

        assert!(is_sorted<X, Y>(), 0);
        router_v2::register_pool<X, Y, Stable>(account);
    }

    public entry fun add_liquidity_stable<X,Y>(account: &signer, x_amount: u64, y_amount: u64) {
        assert!(is_sorted<X, Y>(), 0);

        let account_addr = signer::address_of(account);

        let (min_x_liq, min_y_liq) = router_v2::calc_optimal_coin_values<X, Y, Stable>(
            x_amount,
            y_amount,
            1,
            1
        );

        let x_liq = coin::withdraw<X>(account, min_x_liq);
        let y_liq = coin::withdraw<Y>(account, min_y_liq);

        let (x_remainder, y_remainder, lp) = router_v2::add_liquidity<X, Y, Stable>(
            x_liq,
            min_x_liq,
            y_liq,
            min_y_liq,
        );

        coin::deposit(account_addr, y_remainder);
        coin::deposit(account_addr, x_remainder);

        if (!coin::is_account_registered<LP<X, Y, Stable>>(account_addr)) {
            coin::register<LP<X, Y, Stable>>(account);
        };

        coin::deposit(account_addr, lp);
    }

    public entry fun add_liquidity_uncorrelated<X,Y>(account: &signer) {
        assert!(is_sorted<X, Y>(), 0);

        let account_addr = signer::address_of(account);

        let (min_x_liq, min_y_liq) = router_v2::calc_optimal_coin_values<X, Y, Uncorrelated>(
            100000000,
            100000000,
            1,
            1
        );

        let x_liq = coin::withdraw<X>(account, min_x_liq);
        let y_liq = coin::withdraw<Y>(account, min_y_liq);

        let (x_remainder, y_remainder, lp) = router_v2::add_liquidity<X, Y, Uncorrelated>(
            x_liq,
            min_x_liq,
            y_liq,
            min_y_liq,
        );

        coin::deposit(account_addr, y_remainder);
        coin::deposit(account_addr, x_remainder);

        if (!coin::is_account_registered<LP<X, Y, Uncorrelated>>(account_addr)) {
            coin::register<LP<X, Y, Uncorrelated>>(account);
        };

        coin::deposit(account_addr, lp);
    }

    public entry fun burn_liquidity<X, Y>(account: &signer, lp_to_burn: u64, min_x_amount: u64, min_y_amount: u64) {
        assert!(is_sorted<X, Y>(), 0);
        let account_addr = signer::address_of(account);

        let lp = coin::withdraw<LP<X, Y, Uncorrelated>>(account, lp_to_burn);
        let (return_x, return_y) = router_v2::remove_liquidity<X, Y, Uncorrelated>(lp, min_x_amount, min_y_amount);

        if (!coin::is_account_registered<X>(account_addr)) {
            coin::register<X>(account);
        };
        coin::deposit(account_addr, return_x);

        if (!coin::is_account_registered<Y>(account_addr)) {
            coin::register<Y>(account);
        };
        coin::deposit(account_addr, return_y);
    }

    public entry fun stable_swap<X, Y>(account: &signer, amount: u64) {
        let x_coins_to_swap = coin::withdraw<X>(account, amount);

        let y_amount_to_get = router_v2::get_amount_out<X, Y, Stable>(
            amount,
        );

        let y_coin = router_v2::swap_exact_coin_for_coin<X, Y, Stable>(
            x_coins_to_swap,
            y_amount_to_get
        );

        let account_addr = signer::address_of(account);

        if (!coin::is_account_registered<Y>(account_addr)) {
            coin::register<Y>(account);
        };
        coin::deposit(account_addr, y_coin);
    }

    #[view]
    public fun get_reserve_stable<X, Y>(): (u64, u64) {
        assert!(is_sorted<X, Y>(), 0);

        let (btc_reserve, usdt_reserve) = router_v2::get_reserves_size<X, Y, Stable>();
        (btc_reserve, usdt_reserve)
    }

    #[view]
    public fun get_reserve_unstable<X, Y>(): (u64, u64) {
        assert!(is_sorted<X, Y>(), 0);

        let (btc_reserve, usdt_reserve) = router_v2::get_reserves_size<X, Y, Uncorrelated>();
        (btc_reserve, usdt_reserve)
    }
}
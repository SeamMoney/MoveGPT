module qve_protocol::qve_usdf_pool {
    use std::signer;

    use liquidswap::coin_helper::is_sorted;
    use liquidswap::router_v2;
    use liquidswap::curves::Uncorrelated;
    use liquidswap_lp::lp_coin::LP;

    use aptos_framework::coin;

    use qve_protocol::qve::QVE;
    use qve_protocol::usdf::USDF;

    public entry fun create_pool(account: &signer) {
        // Check generics sorted.
        assert!(is_sorted<QVE, USDF>(), 0);

        router_v2::register_pool<QVE, USDF, Uncorrelated>(
            account,
        );
    }

    public entry fun add_liquidity(account: &signer) {
        assert!(is_sorted<QVE, USDF>(), 0);

        let account_addr = signer::address_of(account);

        let (min_qve_liq, min_usdf_liq) = router_v2::calc_optimal_coin_values<QVE, USDF, Uncorrelated>(
            100000000,
            100000000,
            1,
            1
        );

        let qve_liq = coin::withdraw<QVE>(account, min_qve_liq);
        let usdf_liq = coin::withdraw<USDF>(account, min_usdf_liq);

        let (qve_remainder, usdf_remainder, lp) = router_v2::add_liquidity<QVE, USDF, Uncorrelated>(
            qve_liq,
            min_qve_liq,
            usdf_liq,
            min_usdf_liq,
        );

        coin::deposit(account_addr, usdf_remainder);
        coin::deposit(account_addr, qve_remainder);

        if (!coin::is_account_registered<LP<QVE, USDF, Uncorrelated>>(account_addr)) {
            coin::register<LP<QVE, USDF, Uncorrelated>>(account);
        };

        coin::deposit(account_addr, lp);
    }

    public entry fun burn_liquidity(account: &signer, lp_to_burn: u64, min_x_amount: u64, min_y_amount: u64) {
        assert!(is_sorted<QVE, USDF>(), 0);
        let account_addr = signer::address_of(account);

        let lp = coin::withdraw<LP<QVE, USDF, Uncorrelated>>(account, lp_to_burn);
        let (qve, usdf) = router_v2::remove_liquidity<QVE, USDF, Uncorrelated>(lp, min_x_amount, min_y_amount);

        if (!coin::is_account_registered<QVE>(account_addr)) {
            coin::register<QVE>(account);
        };
        coin::deposit(account_addr, qve);

        if (!coin::is_account_registered<USDF>(account_addr)) {
            coin::register<USDF>(account);
        };
        coin::deposit(account_addr, usdf);
    }

    // qve -> usdf
    public entry fun test_swap(account: &signer) {
        let qve_amount_to_swap = 1 * 100000000;
        let qve_coins_to_swap = coin::withdraw<QVE>(account, qve_amount_to_swap);

        let usdf_amount_to_get = router_v2::get_amount_out<QVE, USDF, Uncorrelated>(
            qve_amount_to_swap,
        );

        let usdt = router_v2::swap_exact_coin_for_coin<QVE, USDF, Uncorrelated>(
            qve_coins_to_swap,
            usdf_amount_to_get
        );

        let account_addr = signer::address_of(account);

        // Register USDF coin on account in case the account don't have it.
        if (!coin::is_account_registered<USDF>(account_addr)) {
            coin::register<USDF>(account);
        };

        // Deposit on account.
        coin::deposit(account_addr, usdt);
    }

    #[view]
    public fun get_reserve(): (u64, u64) {
        let (btc_reserve, usdt_reserve) = router_v2::get_reserves_size<QVE, USDF, Uncorrelated>();
        (btc_reserve, usdt_reserve)
    }
}
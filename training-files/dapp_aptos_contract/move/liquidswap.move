module qve_protocol::example {
    use std::signer;

    use liquidswap::curves::Stable;
    use liquidswap::coin_helper::is_sorted;
    use liquidswap::router_v2;
    use liquidswap::curves::Uncorrelated;
    use test_coins::coins::{USDT, BTC};

    use liquidswap_lp::lp_coin::LP;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;

    use qve_protocol::coins::USDF;

    public entry fun create_stable_pool(account: &signer) {
        // Check generics sorted.
        assert!(is_sorted<USDF, USDT>(), 0);

        router_v2::register_pool<USDF, USDT, Stable>(
            account,
        );
    }
    public entry fun create_pool(account: &signer) {
        // Check generics sorted.
        assert!(is_sorted<USDF, AptosCoin>(), 0);

        router_v2::register_pool<USDF, AptosCoin, Uncorrelated>(
            account,
        );
    }
    public entry fun add_liquidity(account: &signer) {
        assert!(is_sorted<USDF, AptosCoin>(), 0);

        let account_addr = signer::address_of(account);

        let (min_usdf_liq, min_aptos_coin_liq) = router_v2::calc_optimal_coin_values<USDF, AptosCoin, Uncorrelated>(
            100,
            10,
            1,
            1
        );

        let usdf_liq = coin::withdraw<USDF>(account, min_usdf_liq);
        let aptos_liq = coin::withdraw<AptosCoin>(account, min_aptos_coin_liq);

        let (usdf_remainder, aptos_remainder, lp) = router_v2::add_liquidity<USDF, AptosCoin, Uncorrelated>(
            usdf_liq,
            min_usdf_liq,
            aptos_liq,
            min_aptos_coin_liq,
        );

        coin::deposit(account_addr, usdf_remainder);
        coin::deposit(account_addr, aptos_remainder);

        if (!coin::is_account_registered<LP<USDF, AptosCoin, Uncorrelated>>(account_addr)) {
            coin::register<LP<USDF, AptosCoin, Uncorrelated>>(account);
        };

        coin::deposit(account_addr, lp);
    }

    // change 1 aptos to btc | apt -> btc
    public entry fun test_btc(account: &signer) {
        let aptos_amount_to_swap = 1 * 100000000;
        let aptos_coins_to_swap = coin::withdraw<AptosCoin>(account, aptos_amount_to_swap);

        let btc_amount_to_get = router_v2::get_amount_out<AptosCoin, BTC, Uncorrelated>(
            aptos_amount_to_swap,
        );

        let btc = router_v2::swap_exact_coin_for_coin<AptosCoin, BTC, Uncorrelated>(
            aptos_coins_to_swap,
            btc_amount_to_get
        );

        let account_addr = signer::address_of(account);

        // Register BTC coin on account in case the account don't have it.
        if (!coin::is_account_registered<BTC>(account_addr)) {
            coin::register<BTC>(account);
        };

        // Deposit on account.
        coin::deposit(account_addr, btc);
    }
    public entry fun test_usdt(account: &signer) {
        let aptos_amount_to_swap = 1 * 100000000;
        let aptos_coins_to_swap = coin::withdraw<AptosCoin>(account, aptos_amount_to_swap);

        let usdt_amount_to_get = router_v2::get_amount_out<AptosCoin, USDT, Uncorrelated>(
            aptos_amount_to_swap,
        );

        let usdt = router_v2::swap_exact_coin_for_coin<AptosCoin, USDT, Uncorrelated>(
            aptos_coins_to_swap,
            usdt_amount_to_get
        );

        let account_addr = signer::address_of(account);

        // Register USDT coin on account in case the account don't have it.
        if (!coin::is_account_registered<USDT>(account_addr)) {
            coin::register<USDT>(account);
        };

        // Deposit on account.
        coin::deposit(account_addr, usdt);
    }

    public entry fun buy_btc(account: &signer, btc_min_value_to_get: u64) {
        let aptos_amount_to_swap = 1;
        let aptos_coins_to_swap = coin::withdraw<AptosCoin>(account, aptos_amount_to_swap);

        let btc = router_v2::swap_exact_coin_for_coin<AptosCoin, BTC, Uncorrelated>(
            aptos_coins_to_swap,
            btc_min_value_to_get
        );

        let account_addr = signer::address_of(account);

        // Register BTC coin on account in case the account don't have it.
        if (!coin::is_account_registered<BTC>(account_addr)) {
            coin::register<BTC>(account);
        };

        // Deposit on account.
        coin::deposit(account_addr, btc);
    }
}
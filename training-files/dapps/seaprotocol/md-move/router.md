```rust
/// # Module-level documentation sections
///
/// * [Background](#Background)
/// * [Implementation](#Implementation)
/// * [Basic public functions](#Basic-public-functions)
/// * [Traversal](#Traversal)
///
/// # Background
///
/// router for orderbook and AMM
/// 
module sea::router {
    use std::signer::address_of;
    use aptos_framework::coin::{Self, Coin};

    use sea_spot::lp::{LP};
    
    use sea::amm;
    use sea::escrow;
    use sea::utils;
    use sea::fee;
    
    const E_NO_AUTH:                              u64 = 100;
    const E_POOL_NOT_EXIST:                       u64 = 7000;
    const E_INSUFFICIENT_BASE_AMOUNT:             u64 = 7001;
    const E_INSUFFICIENT_QUOTE_AMOUNT:            u64 = 7002;
    const E_INSUFFICIENT_AMOUNT:                  u64 = 7003;
    const E_INVALID_AMOUNT_OUT:                   u64 = 7004;
    const E_INVALID_AMOUNT_IN:                    u64 = 7005;
    const E_INSUFFICIENT_LIQUIDITY:               u64 = 7006;
    const E_INSUFFICIENT_QUOTE_RESERVE:           u64 = 7007;
    const E_INSUFFICIENT_BASE_RESERVE:            u64 = 7008;

    public entry fun add_liquidity<B, Q>(
        account: &signer,
        amt_base_desired: u64,
        amt_quote_desired: u64,
        amt_base_min: u64,
        amt_quote_min: u64
    ) {
        assert!(amm::pool_exist<B, Q>(), E_POOL_NOT_EXIST);

        let (amount_base,
            amount_quote) = amm::calc_optimal_coin_values<B, Q>(
                amt_base_desired,
                amt_quote_desired,
                amt_base_min,
                amt_quote_min);
        let coin_base = coin::withdraw<B>(account, amount_base);
        let coin_quote = coin::withdraw<Q>(account, amount_quote);
        let lp_coins = amm::mint<B, Q>(coin_base, coin_quote);

        let acc_addr = address_of(account);
        utils::register_coin_if_not_exist<LP<B, Q>>(account);
        coin::deposit(acc_addr, lp_coins);
    }

    public entry fun remove_liquidity<B, Q>(
        account: &signer,
        liquidity: u64,
        amt_base_min: u64,
        amt_quote_min: u64,
    ) {
        assert!(amm::pool_exist<B, Q>(), E_POOL_NOT_EXIST);
        let coins = coin::withdraw<LP<B, Q>>(account, liquidity);
        let (base_out, quote_out) = amm::burn<B, Q>(coins);

        assert!(coin::value(&base_out) >= amt_base_min, E_INSUFFICIENT_BASE_AMOUNT);
        assert!(coin::value(&quote_out) >= amt_quote_min, E_INSUFFICIENT_QUOTE_AMOUNT);

        // transfer
        let account_addr = address_of(account);
        coin::deposit(account_addr, base_out);
        coin::deposit(account_addr, quote_out);
    }

    // user: buy exact quote
    // amount_out: quote amount out of pool
    // amount_in_max: base amount into pool
    public entry fun buy_exact_quote<B, Q>(
        account: &signer,
        amount_out: u64,
        amount_in_max: u64
    ) {
        let base_in_needed = get_amount_in<B, Q>(amount_out, false);
        assert!(base_in_needed <= amount_in_max, E_INSUFFICIENT_BASE_AMOUNT);
        let base_in = coin::withdraw<B>(account, base_in_needed);
        let quote_out;
        quote_out = swap_base_for_quote<B, Q>(base_in, amount_out);
        utils::register_coin_if_not_exist<Q>(account);
        coin::deposit<Q>(address_of(account), quote_out);
    }

    // user: sell exact base
    public entry fun sell_exact_base<B, Q>(
        account: &signer,
        amount_in: u64,
        amount_out_min: u64
    ) {
        let coin_in = coin::withdraw<B>(account, amount_in);
        let coin_out;
        coin_out = swap_base_for_quote<B, Q>(coin_in, amount_out_min);
        assert!(coin::value(&coin_out) >= amount_out_min, E_INSUFFICIENT_QUOTE_AMOUNT);
        utils::register_coin_if_not_exist<Q>(account);
        coin::deposit<Q>(address_of(account), coin_out);
    }

    // user: buy base
    // amount_out: the exact base amount
    public entry fun buy_exact_base<B, Q>(
        account: &signer,
        amount_out: u64,
        amount_in_max: u64
    ) {
        let coin_in_needed = get_amount_in<B, Q>(amount_out, true);
        assert!(coin_in_needed <= amount_in_max, E_INSUFFICIENT_BASE_AMOUNT);
        let coin_in = coin::withdraw<Q>(account, coin_in_needed);
        let coin_out;
        coin_out = swap_quote_for_base<B, Q>(coin_in, amount_out);
        utils::register_coin_if_not_exist<B>(account);
        coin::deposit<B>(address_of(account), coin_out);
    }

    // user: sell exact quote
    public entry fun sell_exact_quote<B, Q>(
        account: &signer,
        amount_in: u64,
        amount_out_min: u64
        ) {
        let coin_in = coin::withdraw<Q>(account, amount_in);
        let coin_out;
        coin_out = swap_quote_for_base<B, Q>(coin_in, amount_out_min);
        assert!(coin::value(&coin_out) >= amount_out_min, E_INSUFFICIENT_QUOTE_AMOUNT);
        utils::register_coin_if_not_exist<B>(account);
        coin::deposit<B>(address_of(account), coin_out);
    }

    public entry fun withdraw_dao_fee<B, Q>(
        account: &signer,
        to: address
    ) {
        assert!(address_of(account) == @sea, E_NO_AUTH);

        let amount = coin::balance<LP<B, Q>>(@sea_spot) - amm::get_min_liquidity();
        assert!(amount > 0, E_INSUFFICIENT_AMOUNT);
        coin::transfer<LP<B, Q>>(&escrow::get_spot_account(), to, amount);
    }

    ////////////////////////////////////////////////////////////////////////////
    /// PUBLIC FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////

    // sell base, buy quote
    public fun swap_base_for_quote<B, Q>(
        coin_in: Coin<B>,
        coin_out_val: u64
    ): Coin<Q> {
        let (zero, coin_out) = amm::swap<B, Q>(coin_in, 0, coin::zero(), coin_out_val);
        coin::destroy_zero(zero);

        coin_out
    }

    // sell quote, buy base
    public fun swap_quote_for_base<B, Q>(
        coin_in: Coin<Q>,
        coin_out_val: u64,
    ): Coin<B> {
        let (coin_out, zero) = amm::swap<B, Q>(coin::zero(), coin_out_val, coin_in, 0);
        coin::destroy_zero(zero);

        coin_out
    }

    /// in_is_quote: by user perspective
    public fun get_amount_in<B, Q>(
        amount_out: u64,
        in_is_quote: bool,
    ): u64 {
        assert!(amount_out > 0, E_INVALID_AMOUNT_OUT);
        let (base_reserve, quote_reserve, fee_ratio) = amm::get_pool_reserve_fee<B, Q>();
        assert!(base_reserve> 0 && quote_reserve > 0, E_INSUFFICIENT_LIQUIDITY);

        let numerator: u128;
        let denominator: u128;
        let fee_deno = fee::get_fee_denominate();
        if (in_is_quote) {
            assert!(base_reserve > amount_out, E_INSUFFICIENT_BASE_RESERVE);
            numerator = (quote_reserve as u128) * (amount_out as u128) * (fee_deno as u128);
            denominator = ((base_reserve - amount_out) as u128) * ((fee_deno - fee_ratio) as u128);
        } else {
            assert!(quote_reserve > amount_out, E_INSUFFICIENT_QUOTE_RESERVE);
            numerator = (base_reserve as u128) * (amount_out as u128) * (fee_deno as u128);
            denominator = ((quote_reserve - amount_out) as u128) * ((fee_deno - fee_ratio) as u128);
        };

        // debug::print(&denominator);
        ((numerator / denominator + 1) as u64)
    }

    public fun get_amount_out<B, Q>(
        amount_in: u64,
        out_is_quote: bool,
    ): u64 {
        assert!(amount_in > 0, E_INVALID_AMOUNT_IN);
        let (base_reserve, quote_reserve, fee_ratio) = amm::get_pool_reserve_fee<B, Q>();
        if (base_reserve  == 0 || quote_reserve == 0) {
            return 0
        };

        let fee_deno = fee::get_fee_denominate();
        let amount_in_with_fee = (amount_in as u128) * ((fee_deno - fee_ratio) as u128);
        let numerator: u128;
        let denominator: u128;
        if (out_is_quote) {
            numerator = amount_in_with_fee * (quote_reserve as u128);
            denominator = (base_reserve as u128) * (fee_deno as u128) + amount_in_with_fee;
        } else {
            numerator = amount_in_with_fee * (base_reserve as u128);
            denominator = (quote_reserve as u128) * (fee_deno as u128) + amount_in_with_fee;
        };

        let amount_out = numerator / denominator;
        // debug::print(&amount_out);
        (amount_out as u64)
    }

    // Tests ==================================================================
    #[test_only]
    use sea::market;
    #[test_only]
    use std::vector;
    // use std::debug;

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_get_amount_in(
        user1: &signer,
        user2: &signer,
        user3: &signer
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let i = 0;
        let out_bases = vector<u64>[10000000, 20000000, 50000000, 80000000, 160000000, 300000000, 600000000, 1100000000];
        let exp_quotes = vector<u64>[151781576407, 304581821112, 769198158402, 1243361406731, 2556771343419, 5042521260631, 11345672836419, 26274189726443];
        // buy exact base
        while (i < vector::length(&out_bases)) {
            let out_base: u64 = *vector::borrow(&out_bases, i);
            let exp_quote = *vector::borrow(&exp_quotes, i);
            let in_amt = get_amount_in<market::T_BTC, market::T_USD>(out_base, true);
            assert!(in_amt == exp_quote, i);

            i = i + 1;
        };

        i = 0;
        // buy exact quote
        let out_quotes = vector<u64>[1000000000, 2000000000, 5000000000, 8000000000, 16000000000, 30000000000, 60000000000, 110000000000];
        let exp_bases = vector<u64>[66173, 132348, 330890, 529459, 1059105, 1986434, 3975498, 7296466];
        while (i < vector::length(&out_quotes)) {
            let out_quote: u64 = *vector::borrow(&out_quotes, i);
            let exp_base = *vector::borrow(&exp_bases, i); // base to sell
            let in_amt = get_amount_in<market::T_BTC, market::T_USD>(out_quote, false);
            assert!(exp_base == in_amt, 1000 + i);

            i = i + 1;
        }
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_get_amount_out(
        user1: &signer,
        user2: &signer,
        user3: &signer
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let i = 0;
        let in_bases = vector<u64>[10000000, 20000000, 50000000, 80000000, 160000000, 300000000, 600000000, 1100000000];
        let exp_quotes = vector<u64>[150622575785, 300248146517, 743240846236, 1177608020883, 2295618623256, 4121761898268, 7556849737478, 12165303150422];
        // sell exact base
        while (i < vector::length(&in_bases)) {
            let in_base: u64 = *vector::borrow(&in_bases, i);
            let out_amt = get_amount_out<market::T_BTC, market::T_USD>(in_base, true);
            let exp_quote = *vector::borrow(&exp_quotes, i);
            assert!(out_amt == exp_quote, i);

            i = i + 1;
        };

        i = 0;
        // sell exact quote
        let in_quotes = vector<u64>[1000000000, 2000000000, 5000000000, 8000000000, 16000000000, 30000000000, 60000000000, 110000000000];
        let exp_bases = vector<u64>[66103, 132203, 330486, 528742, 1057299, 1981824, 3961032, 7253912];
        while (i < vector::length(&in_quotes)) {
            let in_quote: u64 = *vector::borrow(&in_quotes, i);
            let out_amt = get_amount_out<market::T_BTC, market::T_USD>(in_quote, false);
            let exp_base = *vector::borrow(&exp_bases, i); // out base expect
            assert!(exp_base == out_amt, 1000 + i);

            i = i + 1;
        }
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_buy_exact_quote(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        let addr2 = address_of(user2);
        let btc_balance1 = coin::balance<market::T_BTC>(addr2);
        let usd_balance1 = coin::balance<market::T_USD>(addr2);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let amt_out = 1500000000000; // quote usdt
        let amt_in_max = get_amount_in<market::T_BTC, market::T_USD>(amt_out, false);
        buy_exact_quote<market::T_BTC, market::T_USD>(user2, amt_out, amt_in_max);
        let btc_balance2 = coin::balance<market::T_BTC>(addr2);
        let usd_balance2 = coin::balance<market::T_USD>(addr2);
        assert!(btc_balance2 >= btc_balance1 - amt_in_max, 1);
        assert!(usd_balance2 == usd_balance1 + amt_out, 2);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_sell_exact_base(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        let addr2 = address_of(user2);
        let btc_balance1 = coin::balance<market::T_BTC>(addr2);
        let usd_balance1 = coin::balance<market::T_USD>(addr2);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let amt_in = 15000000; // base btc
        let amt_out_min = get_amount_out<market::T_BTC, market::T_USD>(amt_in, true);
        sell_exact_base<market::T_BTC, market::T_USD>(user2, amt_in, amt_out_min);
        let btc_balance2 = coin::balance<market::T_BTC>(addr2);
        let usd_balance2 = coin::balance<market::T_USD>(addr2);
        assert!(btc_balance2 == btc_balance1 - amt_in, 1);
        assert!(usd_balance2 >= usd_balance1 + amt_out_min, 2);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_buy_exact_base(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        let addr2 = address_of(user2);
        let btc_balance1 = coin::balance<market::T_BTC>(addr2);
        let usd_balance1 = coin::balance<market::T_USD>(addr2);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let amt_out = 15000000; // base btc
        let amt_in_max = get_amount_in<market::T_BTC, market::T_USD>(amt_out, true);
        buy_exact_base<market::T_BTC, market::T_USD>(user2, amt_out, amt_in_max);
        let btc_balance2 = coin::balance<market::T_BTC>(addr2);
        let usd_balance2 = coin::balance<market::T_USD>(addr2);

        assert!(btc_balance2 == btc_balance1 + amt_out, 1);
        assert!(usd_balance2 >= usd_balance1 - amt_in_max, 2);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_sell_exact_quote(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        let addr2 = address_of(user2);
        let btc_balance1 = coin::balance<market::T_BTC>(addr2);
        let usd_balance1 = coin::balance<market::T_USD>(addr2);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let amt_in = 1500000000000; // quote usd
        let amt_out_min = get_amount_out<market::T_BTC, market::T_USD>(amt_in, false);
        sell_exact_quote<market::T_BTC, market::T_USD>(user2, amt_in, amt_out_min);
        let btc_balance2 = coin::balance<market::T_BTC>(addr2);
        let usd_balance2 = coin::balance<market::T_USD>(addr2);
        assert!(btc_balance2 == btc_balance1 + amt_out_min, 1);
        assert!(usd_balance2 == usd_balance1 - amt_in, 2);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_remove_liquidity(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);
        // add_liquidity<market::T_BTC, market::T_USD>(user1, 300000, 300000 * 15120, 0, 0);

        let addr1 = address_of(user1);
        let lp_balance = coin::balance<LP<market::T_BTC, market::T_USD>>(addr1);
        remove_liquidity<market::T_BTC, market::T_USD>(user1, lp_balance, 0, 0);
    }

    // flash loan

    // loan base, return base
    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_flash_loan_base_back_base(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let (coin_base, coin_quote, loan) = amm::flash_swap<market::T_BTC, market::T_USD>(100000000, 0);
        coin::merge(&mut coin_base, coin::withdraw<market::T_BTC>(user2, 100000000 * 51 / 100000));
        amm::pay_flash_swap<market::T_BTC, market::T_USD>(coin_base, coin_quote, loan);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_flash_loan_base_back_quote(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let (coin_base, coin_quote, loan) = amm::flash_swap<market::T_BTC, market::T_USD>(100000000, 0);
        coin::merge(&mut coin_quote, coin::withdraw<market::T_USD>(user2, 100000000 * 15120 * 501 / 1000000));
        amm::pay_flash_swap<market::T_BTC, market::T_USD>(coin_base, coin_quote, loan);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_flash_loan_quote_back_quote(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let (coin_base, coin_quote, loan) = amm::flash_swap<market::T_BTC, market::T_USD>(0, 100000000000);
        coin::merge(&mut coin_quote, coin::withdraw<market::T_USD>(user2, 100000000000 * 501 / 1000000));
        amm::pay_flash_swap<market::T_BTC, market::T_USD>(coin_base, coin_quote, loan);
    }

    #[test(
        user1 = @user_1,
        user2 = @user_2,
        user3 = @user_3
    )]
    fun test_flash_loan_quote_back_base(
        user1: &signer,
        user2: &signer,
        user3: &signer,
    ) {
        market::test_register_pair(user1, user2, user3);

        add_liquidity<market::T_BTC, market::T_USD>(user1, 1000000000, 1000000000 * 15120, 0, 0);
        add_liquidity<market::T_BTC, market::T_USD>(user1, 2000000000, 2000000000 * 15120, 0, 0);

        let (coin_base, coin_quote, loan) = amm::flash_swap<market::T_BTC, market::T_USD>(0, 100000000000);
        coin::merge(&mut coin_base, coin::withdraw<market::T_BTC>(user2, 100000000000 * 501 / 15120 / 1000000));
        amm::pay_flash_swap<market::T_BTC, market::T_USD>(coin_base, coin_quote, loan);
    }
}

```
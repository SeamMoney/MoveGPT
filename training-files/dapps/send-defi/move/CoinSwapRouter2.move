address admin {

module CoinSwapRouter2 {
    use admin::CoinSwapRouter;
    use admin::CoinSwapLibrary;
    use admin::CoinSwapConfig;

    const ERROR_ROUTER_PARAMETER_INVALID: u64 = 1001;
    const ERROR_ROUTER_Y_OUT_LESSTHAN_EXPECTED: u64 = 1002;
    const ERROR_ROUTER_X_IN_OVER_LIMIT_MAX: u64 = 1003;

    public fun get_amount_in<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(amount_y_out: u64): (u64, u64) {

        let (fee_numberator, fee_denumerator) = CoinSwapConfig::get_poundage_rate<R, Y>();
        let (reserve_r, reserve_y) = CoinSwapRouter::get_reserves<R, Y>();
        let r_in = CoinSwapLibrary::get_amount_in(amount_y_out, reserve_r, reserve_y, fee_numberator, fee_denumerator);

        let (fee_numberator, fee_denumerator) = CoinSwapConfig::get_poundage_rate<X, R>();
        let (reserve_x, reserve_r) = CoinSwapRouter::get_reserves<X, R>();
        let x_in = CoinSwapLibrary::get_amount_in(r_in, reserve_x, reserve_r, fee_numberator, fee_denumerator);

        (r_in, x_in)
    }

    public fun get_amount_out<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(amount_x_in: u64): (u64, u64) {

        let (fee_numberator, fee_denumerator) = CoinSwapConfig::get_poundage_rate<X, R>();
        let (reserve_x, reserve_r) = CoinSwapRouter::get_reserves<X, R>();
        let r_out = CoinSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_r, fee_numberator, fee_denumerator);

        let (fee_numberator, fee_denumerator) = CoinSwapConfig::get_poundage_rate<R, Y>();
        let (reserve_r, reserve_y) = CoinSwapRouter::get_reserves<R, Y>();
        let y_out = CoinSwapLibrary::get_amount_out(r_out, reserve_r, reserve_y, fee_numberator, fee_denumerator);

        (r_out, y_out)
    }

    public fun swap_exact_token_for_token<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_in: u64,
        amount_y_out_min: u64) {
        // calculate actual y out
        let (r_out, y_out) = get_amount_out<X, R, Y>(amount_x_in);
        assert!(y_out >= amount_y_out_min, ERROR_ROUTER_Y_OUT_LESSTHAN_EXPECTED);

        CoinSwapRouter::swap_exact_token_for_token<X, R>(signer, amount_x_in, r_out);
        CoinSwapRouter::swap_exact_token_for_token<R, Y>(signer, r_out, amount_y_out_min);
    }

    public fun swap_token_for_exact_token<X: copy + drop + store, R: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_in_max: u64,
        amount_y_out: u64) {
        // calculate actual x in
        let (r_in, x_in) = get_amount_in<X, R, Y>(amount_y_out);
        assert!(x_in <= amount_x_in_max, ERROR_ROUTER_X_IN_OVER_LIMIT_MAX);

        // do actual swap
        CoinSwapRouter::swap_token_for_exact_token<X, R>(signer, amount_x_in_max, r_in);
        CoinSwapRouter::swap_token_for_exact_token<R, Y>(signer, r_in, amount_y_out);
    }
}
}
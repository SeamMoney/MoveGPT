module samm::sqrt_price_math {
    public fun get_next_sqrt_price_from_amount0_rounding_up(
        _sqrt_p_x64: u256, 
        _liquidity: u128, 
        _amount: u128, 
        _add: bool): u256 {
        0
    }


    public fun get_next_sqrt_price_from_amount1_rounding_down(
        _sqrt_p_x64: u256,
        _liquidity: u128,
        _amount: u128,
        _add: bool
    ) : u256 {
        0
    }

    public fun get_next_sqrt_price_from_input(_sqrt_p_x64: u256, _liquidity: u128, _amount_in: u128, _zero_for_one: bool) : u256 {
        0
    } 

    public fun get_next_sqrt_price_from_output(_sqrt_p_x64: u256, _liquidity: u128, _amount_out: u128, _zero_for_one: bool): u256 {
        0
    } 

    public fun get_amount0_delta(_sqrt_ratio_0_x64: u256, _sqrt_ratio_1_x64: u256, _liquidity: u128, _round_up: bool) : u128 {
       0
    }

    public fun get_amount1_delta(_sqrt_ratio_0_x64: u256, _sqrt_ratio_1_x64: u256, _liquidity: u128, _round_up: bool) : u128 {
        0
    } 

}

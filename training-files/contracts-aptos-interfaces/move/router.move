module samm::router {
    use samm::i64:: {I64};
    use std::string::{String};
    use std::table::{Table};
    use aptos_std::event;
    use std::type_info;

    const ERR_TX_TOO_OLD: u64 = 301;
    const ERR_TOO_LITTLE_RECEIVED: u64 = 302;
    const ERR_OUT_NOT_GOOD: u64 = 303;
    const ERR_TOO_MUCH_REQUESTED: u64 = 304;
    const ERR_PRICE_SLIPPAGE_CHECK: u64 = 305;
    const ERR_NOT_POSITION_OWNER: u64 = 306;
    const ERR_REMOVE_LIQUIDITY_EXCEED_AVAILABLE: u64 = 307;
    const ERR_SLIPPAGE_CHECK: u64 = 308;
    const ERR_COLLECT_AMOUNT_MUST_POSITIVE: u64 = 309;
    const ERR_INVALID_HEX: u64 = 310;
    const ERR_INVALID_TYPE_IN_OUT: u64 = 311;

    struct LiquidityPosition has store, copy, drop {
        // the nonce for permits
        index: u128,
        t0: type_info::TypeInfo,
        t1: type_info::TypeInfo,
        f: type_info::TypeInfo,
        // the tick range of the position
        tick_lower: I64,
        tick_upper: I64,
        // the liquidity of the position
        liquidity: u128,
        // the fee growth of the aggregate position as of the last action on the individual position
        fee_growth_inside0_last_X128: u256,
        fee_growth_inside1_last_X128: u256,
        // how many uncollected tokens are owed to the position, as of the last computation
        tokens_owed0: u64,
        tokens_owed1: u64
    }

    struct LiquidityPositionBook has key {
        next_index: u128,
        books: Table<u128, LiquidityPosition>,
        increase_liquidity_handle: event::EventHandle<IncreaseLiquidityEvent>,
        decrease_liquidity_handle: event::EventHandle<DecreaseLiquidityEvent>,
        collection_name: String
    }

    public entry fun exact_input_three_hops<T0, T1, T2, T3, T4, T5, F0, F1, F2, Tin, Tout>(
        _account: &signer,
        _amount_in: u64,
        _amount_out_minimum: u64,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) {}

    public entry fun exact_input_two_hops<T0, T1, T2, T3, F0, F1, Tin, Tout>(
        _account: &signer,
        _amount_in: u64,
        _amount_out_minimum: u64,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) {}

    public entry fun exact_input_2<T0, T1, F>(
        _account: &signer,
        _amount_in: u64,
        _amount_out_minimum: u64,
        _zero_for_one: bool,
        _sqrt_price_limit_x64: u256,
        _deadline: u64
    ) {}

    public entry fun exact_input_2_new<T0, T1, F>(
        _account: &signer,
        _amount_in: u64,
        _amount_out_minimum: u64,
        _zero_for_one: bool,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) {}

    public entry fun exact_output_2<T0, T1, F>(
        _account: &signer,
        _amount_in_maximum: u64,
        _amount_out: u64,
        _zero_for_one: bool,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) { }

    public entry fun exact_output_two_hops<T0, T1, T2, T3, F0, F1, Tin, Tout>(
        _account: &signer,
        _amount_in_maximum: u64,
        _amount_out: u64,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) { }

    public entry fun exact_output_three_hops<T0, T1, T2, T3, T4, T5, F0, F1, F2, Tin, Tout>(
        _account: &signer,
        _amount_in_maximum: u64,
        _amount_out: u64,
        _sqrt_price_limit_x64_: u128,
        _deadline: u64
    ) { }

    public fun get_liquidity_for_amounts(
        _sqrt_ratio_x64: u256,
        _sqrt_ratio_a_x64: u256,
        _sqrt_ratio_b_x64: u256,
        _amount0: u64,
        _amount1: u64
    ): u128 {
        0
    }

    public fun get_amount0_for_liquidity(
        _sqrt_ratio_a_x64: u256,
        _sqrt_ratio_b_x64: u256,
        _liquidity: u128
    ): u64 {
        0
    }

    public fun get_amounts_for_liquidity(
        _sqrt_ratio_x64: u256,
        _sqrt_ratio_a_x64: u256,
        _sqrt_ratio_b_x64: u256,
        _liquidity: u128
    ): (u64, u64) {
        (0, 0)
    }

    public entry fun mint<T0, T1, F>(
        _account: &signer,
        _tick_lower_abs: u64,
        _tick_lower_positive: bool,
        _tick_upper_abs: u64,
        _tick_upper_positive: bool,
        _amount0_desired: u64,
        _amount1_desired: u64,
        _amount0_min: u64,
        _amount1_min: u64,
        _sqrt_price_x64_: u128, //0 if minting
        _recipient: address,
        _deadline: u64
    ) { }

    struct IncreaseLiquidityEvent has store, copy, drop {
        _index: u128,
        _t0: type_info::TypeInfo,
        _t1: type_info::TypeInfo,
        _f: type_info::TypeInfo,
        _tick_lower: I64,
        _tick_upper: I64,
        _amount0: u64,
        _amount1: u64,
        _owner: address
    }

    struct DecreaseLiquidityEvent has store, copy, drop {
        _index: u128,
        _t0: type_info::TypeInfo,
        _t1: type_info::TypeInfo,
        _f: type_info::TypeInfo,
        _tick_lower: I64,
        _tick_upper: I64,
        _liquidity: u128,
        _amount0: u64,
        _amount1: u64,
        _owner: address
    }

    public entry fun increase_liquidity<T0, T1, F>(
        _account: &signer,
        _position_index: u128,
        _amount0_desired: u64,
        _amount1_desired: u64,
        _amount0_min: u64,
        _amount1_min: u64,
        _deadline: u64
    ) {
    }

    public entry fun decrease_liquidity<T0, T1, F>(
        _account: &signer,
        _position_index: u128,
        _liquidity: u128,
        _amount0_min: u64,
        _amount1_min: u64,
        _collect_coin: bool,
        _deadline: u64
    ) {
    }

    public entry fun collect<T0, T1, F>(
        _account: &signer,
        _position_index: u128,
        _amount0_max: u64,
        _amount1_max: u64
    ) {
    }

    public entry fun create_pool<T0, T1, F>(
        _account: &signer, 
        _amount0: u64,
        _amount1: u64,
        _tick_lower_abs: u64,
        _tick_lower_positive: bool,
        _tick_upper_abs: u64,
        _tick_upper_positive: bool,
        _sqrt_price_x64_: u128,
        _deadline: u64
    ) {
    }


    public entry fun burn<T0, T1, F>(
        _account: &signer,
        _position_index: u128,
        _collect_coin: bool,
        _deadline: u64
    ) {
    }

    public entry fun collect_protocol<T0, T1, F>(
        _account: &signer,
        _amount0: u64,
        _amount1: u64
    ) {
    }

    public entry fun snapshot_cumulatives_inside<T0, T1, F>(
        _account: &signer,
        _tick_lower_abs: u64,
        _tick_lower_positive: bool,
        _tick_upper_abs: u64,
        _tick_upper_positive: bool,
    ) 
    {
    }

    public entry fun increase_observation_cardinality_next<T0, T1, F>(
        _account: &signer,
        _observation_cardinality_next: u64
    ) {
    }

    public entry fun observe<T0, T1, F>(
        _account: &signer,
        _seconds_agos: vector<u64>
    ) {

    }
}
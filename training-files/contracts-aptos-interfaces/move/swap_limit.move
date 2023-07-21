module swap_limit::swap_limit {
    use std::type_info::{TypeInfo};
    use std::table::{Table};

    const FEE_DIVISOR: u64 = 10000;
    const FEE: u64 = 50;    //0.5%
    const PRICE_MULTIPLE_BITS: u8 = 128;


    const ERR_INSUFFICIENT_PERMISSION: u64 = 512;
    const ERR_INVALID_COIN_TYPE: u64 = 513;
    const ERR_ORDER_ALREADY_CANCELLED: u64 = 514;
    const ERR_PRICE_LOWER_LIMIT: u64 = 515;
    const ERR_AMOUNT_TOO_HIGH: u64 = 516;

    struct SwapLimit has key {
        orders: Table<u64, SwapLimitOrder>,
        orders_count: u64,
    }

    struct SwapLimitOrder has store, copy, drop {
        coin_type_in: TypeInfo,
        coin_type_out: TypeInfo,
        amount_in: u64,
        amount_out: u64,
        filled_amount_in: u64,
        transferred_amount_out: u64,
        price_limit_x128: u256,
        created_time: u64,
        deadline: u64,
        is_cancelled: bool,
        owner: address
    }

    struct SwapLimitOrderUpdatedEvent has store, copy, drop {
        coin_type_in: TypeInfo,
        coin_type_out: TypeInfo,
        amount_in: u64,
        amount_out: u64,
        filled_amount_in: u64,
        transferred_amount_out: u64,
        price_limit_x128: u256,
        created_time: u64,
        deadline: u64,
        is_cancelled: bool,
        owner: address,
        index: u64,
        executed_amount_in: u64,
        executed_amount_out: u64,
        executed_price_x128: u256,
        timestamp: u64
    }

    public entry fun create_limit_order<Tin, Tout>(_account: &signer, _amount_in: u64, _amount_out: u64, _deadline: u64) {
        
    }

    public entry fun cancel_limit_order<Tin, Tout>(_account: &signer, _index: u64) {
        
    }

    public entry fun execute_limit_order_single<T0, T1, F>(
        _account: &signer, 
        _user: address, 
        _index: u64, 
        _executed_amount_in: u64, 
        _min_amount_out: u64, 
        _sqrt_price_limit_x64: u128, 
        _deadline: u64) {
    }

    public entry fun execute_limit_order_two_hops<T0, T1, T2, T3, F0, F1, Tin, Tout>(
        _account: &signer, 
        _user: address, 
        _index: u64, 
        _executed_amount_in: u64, 
        _min_amount_out: u64, 
        _sqrt_price_limit_x64: u128, 
        _deadline: u64) {
    }

    public entry fun execute_limit_order_three_hops<T0, T1, T2, T3, T4, T5, F0, F1, F2, Tin, Tout>(
        _account: &signer, 
        _user: address, 
        _index: u64, 
        _executed_amount_in: u64, 
        _min_amount_out: u64, 
        _sqrt_price_limit_x64: u128, 
        _deadline: u64) {
        
    }
}
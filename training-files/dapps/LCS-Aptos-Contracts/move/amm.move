module aux::amm{
    use aptos_framework::coin;
    use aptos_std::event::{EventHandle};
    use std::string::String;
    use aux::uint256::{
        underlying_mul_to_uint256 as mul256,
        downcast as to128,
    };
    const EPOOL_NOT_FOUND: u64 = 2;
    const EINSUFFICIENT_INPUT_AMOUNT: u64 = 16;
    const EINSUFFICIENT_LIQUIDITY: u64 = 17;
    const EINSUFFICIENT_OUTPUT_AMOUNT: u64 = 19;

    struct LP<phantom X, phantom Y> has store, drop {}

    struct Pool<phantom X, phantom Y> has key {
        // When frozen, no pool operations are permitted.
        frozen: bool,

        timestamp: u64,
        fee_bps: u64,

        // Events
        swap_events: EventHandle<SwapEvent>,
        add_liquidity_events: EventHandle<AddLiquidityEvent>,
        remove_liquidity_events: EventHandle<RemoveLiquidityEvent>,

        // Actual balances of the pool.
        x_reserve: coin::Coin<X>,
        y_reserve: coin::Coin<Y>,

        // LP token handling.
        lp_mint: coin::MintCapability<LP<X, Y>>,
        lp_burn: coin::BurnCapability<LP<X, Y>>,
    }

    struct SwapEvent has store, drop {
        sender_addr: address,
        timestamp: u64,
        in_coin_type: String,
        out_coin_type: String,
        in_reserve: u64,
        out_reserve: u64,
        in_au: u64,
        out_au: u64,
        fee_bps: u64
    }

    struct AddLiquidityEvent has store, drop {
        timestamp: u64,
        x_coin_type: String,    // TODO: should we just put the pool type here?
        y_coin_type: String,
        x_added_au: u64,
        y_added_au: u64,
        lp_minted_au: u64,
    }

    struct RemoveLiquidityEvent has store, drop {
        timestamp: u64,
        x_coin_type: String,    // TODO: should we just put the pool type here?
        y_coin_type: String,
        x_removed_au: u64,
        y_removed_au: u64,
        lp_burned_au: u64,
    }

    public entry fun create_pool<X, Y>(_sender: &signer, _fee_bps: u64){

    }

    public entry fun add_exact_liquidity<X, Y>(
        _sender: &signer,
        _x_au: u64,
        _y_au: u64,
    ){

    }

    public fun swap_exact_coin_for_coin_mut<CoinIn, CoinOut>(
        _sender_addr: address,
        _user_in: &mut coin::Coin<CoinIn>,
        _user_out: &mut coin::Coin<CoinOut>,
        _au_in: u64,
        // may always be zero
        _min_au_out: u64,
        // false
        _use_limit_price: bool,
        // zero
        _max_out_per_in_au_numerator: u128,
        // zero
        _max_out_per_in_au_denominator: u128,
    ): (u64, u64){
        (0,0)
    }
    /// Performs a swap and returns (atomic units CoinOut received, atomic units
    /// CoinIn spent). Debits from coin_in and credits to coin_out.
    ///
    /// See comments for swap_coin_for_exact_coin.
    public fun swap_coin_for_exact_coin_mut<CoinIn, CoinOut>(
        _sender_addr: address,
        _coin_in: &mut coin::Coin<CoinIn>,
        _coin_out: &mut coin::Coin<CoinOut>,
        _max_au_in: u64,
        _au_out: u64,
        _use_limit_price: bool,
        _max_in_per_out_au_numerator: u128,
        _max_in_per_out_au_denominator: u128,
    ): (u64, u64){
        (0, 0)
    }

    /// Returns au of output token received for au of input token
    public fun au_out<CoinIn, CoinOut>(au_in: u64): u64 acquires Pool {
        if (exists<Pool<CoinIn, CoinOut>>(@aux)) {
            let pool = borrow_global<Pool<CoinIn, CoinOut>>(@aux);
            let x_reserve = coin::value(&pool.x_reserve);
            let y_reserve = coin::value(&pool.y_reserve);
            get_amount_out(
                au_in,
                x_reserve,
                y_reserve,
                pool.fee_bps
            )
        } else if (exists<Pool<CoinOut, CoinIn>>(@aux)) {
            let pool = borrow_global<Pool<CoinOut, CoinIn>>(@aux);
            let x_reserve = coin::value(&pool.x_reserve);
            let y_reserve = coin::value(&pool.y_reserve);
            get_amount_out(au_in, y_reserve, x_reserve, pool.fee_bps)
        } else {
            abort(EPOOL_NOT_FOUND)
        }
    }

    /// Returns au of input token required to receive au of output token
    public fun au_in<CoinIn, CoinOut>(au_out: u64): u64 acquires Pool {
        if (exists<Pool<CoinIn, CoinOut>>(@aux)) {
            let pool = borrow_global<Pool<CoinIn, CoinOut>>(@aux);
            let x_reserve = coin::value(&pool.x_reserve);
            let y_reserve = coin::value(&pool.y_reserve);
            get_amount_in(au_out, x_reserve, y_reserve, pool.fee_bps)
        } else if (exists<Pool<CoinOut, CoinIn>>(@aux)) {
            let pool = borrow_global<Pool<CoinOut, CoinIn>>(@aux);
            let x_reserve = coin::value(&pool.x_reserve);
            let y_reserve = coin::value(&pool.y_reserve);
            get_amount_in(au_out, y_reserve, x_reserve, pool.fee_bps)
        } else {
            abort(EPOOL_NOT_FOUND)
        }
    }

    fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64,
        fee_bps: u64
    ): u64 {
        // Swapping x -> y
        //
        // dx_f = dx(1-fee)
        //
        // (x + dx_f)*(y - dy) = x*y
        //
        // dy = y * dx_f / (x + dx_f)
        assert!(amount_in > 0, EINSUFFICIENT_INPUT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, EINSUFFICIENT_LIQUIDITY);
        let amount_in_with_fee = (amount_in as u128) * ((10000 - fee_bps) as u128);
        let numerator = to128(mul256(amount_in_with_fee, (reserve_out as u128)));
        let denominator = ((reserve_in as u128) * 10000) + amount_in_with_fee;
        ((numerator / denominator) as u64)
    }

    fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64,
        fee_bps: u64
    ): u64 {
        // Swapping x -> y
        //
        // dx_f = dx(1-fee)
        //
        // (x + dx_f)*(y - dy) = x*y
        // dx_f = x * dy / (y + dy)
        //
        // dx = x * dy / ((y + dy)*(1-f))
        assert!(amount_out > 0, EINSUFFICIENT_OUTPUT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, EINSUFFICIENT_LIQUIDITY);
        let numerator = (reserve_in as u128) * (amount_out as u128) * 10000;
        let denominator = ((reserve_out - amount_out) as u128) * ((10000 - fee_bps) as u128);
        ((numerator + denominator - 1) / denominator as u64)
    }
}
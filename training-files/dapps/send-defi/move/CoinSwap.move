address admin {

module CoinSwap {
    use std::signer;
    use std::event;
    // use std::bcs;
    use std::string;
    use std::debug;
    use std::option;

    use aptos_std::type_info::{TypeInfo, type_of};
    use aptos_std::comparator::{compare, is_smaller_than, is_equal};

    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::coin::register;
    use aptos_framework::account;

    /*use admin::Compare;
    use admin::U256::{Self, U256}; */
    use admin::SafeMath;
    use admin::Math;
    use admin::FixedPoint64;
    use admin::CoinSwapConfig;

    struct LiquidityToken<phantom X, phantom Y> has key, store, copy, drop {}

    struct LiquidityTokenCapability<phantom X, phantom Y> has key, store {
        mint: coin::MintCapability<LiquidityToken<X, Y>>,
        burn: coin::BurnCapability<LiquidityToken<X, Y>>,
        freeze: coin::FreezeCapability<LiquidityToken<X, Y>>,
    }

    struct RegisterEvent has drop, store {
        x_token_type: TypeInfo,
        y_token_type: TypeInfo,
        signer: address
    }

    /// Event emitted when add token liquidity.
    struct AddLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u64,
        /// token code of X type
        x_token_type: TypeInfo,
        /// token code of X type
        y_token_type: TypeInfo,
        /// signer of add liquidity
        signer: address,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    }

    /// Event emitted when remove token liquidity.
    struct RemoveLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u64,
        /// token code of X type
        x_token_type: TypeInfo,
        /// token code of X type
        y_token_type: TypeInfo,
        /// signer of remove liquidity
        signer: address,
        amount_x_min: u64,
        amount_y_min: u64,
    }

    /// Event emitted when token swap.
    struct SwapEvent has drop, store {
        /// token code of X type
        x_token_type: TypeInfo,
        /// token code of X type
        y_token_type: TypeInfo,
        x_in: u64,
        y_out: u64,
        signer: address,
    }

    /// Struct for swap pair
    struct Pair<phantom X, phantom Y> has key, store {
        token_x_reserve: coin::Coin<X>,
        token_y_reserve: coin::Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        last_k: u128,
    }

    /// Token swap event handle
    struct CoinSwapEventHandle has key, store {
        register_event: event::EventHandle<RegisterEvent>,
        add_liquidity_event: event::EventHandle<AddLiquidityEvent>,
        remove_liquidity_event: event::EventHandle<RemoveLiquidityEvent>,
        swap_event: event::EventHandle<SwapEvent>,
    }

    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;
    const ERROR_SWAP_INVALID_PARAMETER: u64 = 2001;
    const ERROR_SWAP_TOKEN_INSUFFICIENT: u64 = 2002;
    const ERROR_SWAP_DUPLICATE_TOKEN: u64 = 2003;
    const ERROR_SWAP_BURN_CALC_INVALID: u64 = 2004;
    const ERROR_SWAP_SWAPOUT_CALC_INVALID: u64 = 2005;
    const ERROR_SWAP_PRIVILEGE_INSUFFICIENT: u64 = 2006;
    const ERROR_SWAP_ADDLIQUIDITY_INVALID: u64 = 2007;
    const ERROR_SWAP_TOKEN_NOT_EXISTS: u64 = 2008;
    const ERROR_SWAP_TOKEN_FEE_INVALID: u64 = 2009;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const LIQUIDITY_TOKEN_SCALE: u8 = 9;
    const LIQUIDITY_TOKEN_NAME: vector<u8> = b"Sendswap Liquidity Token";
    const LIQUIDITY_TOKEN_SYMBOL: vector<u8> = b"SLT";

    public fun init_event_handle(signer: &signer) {
        assert_admin(signer);
        if (!exists<CoinSwapEventHandle>(signer::address_of(signer))) {
            move_to(signer, CoinSwapEventHandle{
                add_liquidity_event: account::new_event_handle<AddLiquidityEvent>(signer),
                remove_liquidity_event: account::new_event_handle<RemoveLiquidityEvent>(signer),
                swap_event: account::new_event_handle<SwapEvent>(signer),
                register_event: account::new_event_handle<RegisterEvent>(signer),
            });
        };
    }

    /// Check if swap pair exists
    public fun swap_pair_exists<X: copy + drop + store, Y: copy + drop + store>(): bool {
        let order = compare_coin<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        coin::is_coin_initialized<LiquidityToken<X, Y>>()
    }

    fun assert_admin(signer: &signer) {
        assert!(signer::address_of(signer) == CoinSwapConfig::admin_address(), ERROR_SWAP_PRIVILEGE_INSUFFICIENT);
    }

    public fun assert_is_coin<TypeInfo: store>(): bool {
        assert!(coin::is_coin_initialized<TypeInfo>(), ERROR_SWAP_TOKEN_NOT_EXISTS);
        true
    }

    public fun compare_coin<X: copy + drop + store, Y: copy + drop + store>(): u8 {
        let x_type = type_of<X>();
        let y_type = type_of<Y>();
        debug::print(&x_type);
        debug::print(&y_type);
        let result = compare<TypeInfo>(&x_type, &y_type);
        if (is_equal(&result)) {
            EQUAL
        } else if (is_smaller_than(&result)) {
            LESS_THAN
        } else {
            GREATER_THAN
        }
    }

    public fun create_pair<X: copy + drop + store, Y: copy + drop + store>(): Pair<X, Y> {
        Pair<X, Y> {
            token_x_reserve: coin::zero<X>(),
            token_y_reserve: coin::zero<Y>(),
            last_block_timestamp: 0u64,
            last_price_x_cumulative: 0u128,
            last_price_y_cumulative: 0u128,
            last_k: 0u128
        }
    }

    fun register_liquidity_token<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) {
        let (burn_capability, freeze_capability, mint_capability) = coin::initialize<LiquidityToken<X, Y>>(
            signer,
            string::utf8(LIQUIDITY_TOKEN_NAME),
            string::utf8(LIQUIDITY_TOKEN_SYMBOL),
            LIQUIDITY_TOKEN_SCALE,
            true
            );
        move_to(signer, LiquidityTokenCapability<X, Y>{ mint: mint_capability, burn: burn_capability, freeze: freeze_capability });
    }

    public fun register_swap_pair<X: copy + drop + store, Y: copy + drop + store>(signer: &signer)
    acquires CoinSwapEventHandle {
        // check X,Y is token.
        assert_is_coin<X>();
        assert_is_coin<Y>();

        // Event handle
        init_event_handle(signer);

        let order = compare_coin<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);

        register<LiquidityToken<X, Y>>(signer);

        register_liquidity_token<X, Y>(signer);
        let pair = create_pair<X, Y>();
        move_to(signer, pair);

        let event_handle = borrow_global_mut<CoinSwapEventHandle>(CoinSwapConfig::admin_address());
        event::emit_event(&mut event_handle.register_event, RegisterEvent {
            x_token_type: type_of<X>(),
            y_token_type: type_of<Y>(),
            signer: signer::address_of(signer)
        });
    }

    /// Get reserves of a token pair.
    /// The order of type args should be sorted.
    public fun get_reserves<X: copy + drop + store, Y: copy + drop + store>(): (u64, u64) acquires Pair {
        let token_pair = borrow_global<Pair<X, Y>>(CoinSwapConfig::admin_address());
        let x_reserve = coin::value(&token_pair.token_x_reserve);
        let y_reserve = coin::value(&token_pair.token_y_reserve);
        (x_reserve, y_reserve)
    }

    fun update_oracle<X: copy + drop + store, Y: copy + drop + store>(x_reserve: u64, y_reserve: u64) acquires Pair {
        let token_pair = borrow_global_mut<Pair<X, Y>>(CoinSwapConfig::admin_address());
        
        let last_block_timestamp = token_pair.last_block_timestamp;
        let block_timestamp = timestamp::now_seconds() % (1u64 << 32);
        let time_elapsed: u64 = block_timestamp - last_block_timestamp;
        if (time_elapsed > 0 && x_reserve > 0 && y_reserve > 0) {
            let last_price_x_cumulative = FixedPoint64::to_u128(FixedPoint64::div(FixedPoint64::encode(x_reserve), y_reserve)) * (time_elapsed as u128);
            let last_price_y_cumulative = FixedPoint64::to_u128(FixedPoint64::div(FixedPoint64::encode(y_reserve), x_reserve)) * (time_elapsed as u128);
            token_pair.last_price_x_cumulative = *&token_pair.last_price_x_cumulative + last_price_x_cumulative;
            token_pair.last_price_y_cumulative = *&token_pair.last_price_y_cumulative + last_price_y_cumulative;
        };

        token_pair.last_block_timestamp = block_timestamp;
    }

    /// Liquidity Provider's methods
    /// type args, X, Y should be sorted.
    public fun mint<X: copy + drop + store, Y: copy + drop + store>(
        x: coin::Coin<X>,
        y: coin::Coin<Y>,
    ): coin::Coin<LiquidityToken<X, Y>> acquires Pair, LiquidityTokenCapability {
        CoinSwapConfig::assert_global_freeze();
        let total_supply_option = coin::supply<LiquidityToken<X, Y>>();
        let total_supply = option::get_with_default(&total_supply_option, 0u128);
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let x_value = coin::value<X>(&x);
        let y_value = coin::value<Y>(&y);
        let liquidity = if (total_supply == 0u128) {
            // 1000 is the MINIMUM_LIQUIDITY
            // sqrt(x*y) - 1000
            let init_liquidity = Math::sqrt((x_value as u128) * (y_value as u128));
            assert!(init_liquidity > 1000u64, ERROR_SWAP_ADDLIQUIDITY_INVALID);
            init_liquidity - 1000u64
        } else {
            let x_liquidity = ((x_value as u128) * total_supply) / (x_reserve as u128);
            let y_liquidity = ((y_value as u128) * total_supply) / (y_reserve as u128);
            // use smaller one.
            if (x_liquidity < y_liquidity) {
                (x_liquidity as u64)
            } else {
                (y_liquidity as u64)
            }
        };
        assert!(liquidity > 0u64, ERROR_SWAP_ADDLIQUIDITY_INVALID);
        let admin_address = CoinSwapConfig::admin_address();
        let token_pair = borrow_global_mut<Pair<X, Y>>(admin_address);
        debug::print(token_pair);
        coin::deposit<X>(admin_address, x);
        coin::deposit<Y>(admin_address, y);
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(admin_address);
        let mint_token = coin::mint(liquidity, &liquidity_cap.mint);
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_mint_event<X, Y>(x_value, y_value, liquidity);

        mint_token
    }

    fun burn_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        to_burn: coin::Coin<LiquidityToken<X, Y>>
    ) acquires LiquidityTokenCapability {
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(CoinSwapConfig::admin_address());
        coin::burn(to_burn, &liquidity_cap.burn);
    }

    public fun burn<X: copy + drop + store, Y: copy + drop + store>(
        to_burn: coin::Coin<LiquidityToken<X, Y>>,
    ): (coin::Coin<X>, coin::Coin<Y>) acquires Pair, LiquidityTokenCapability {
        CoinSwapConfig::assert_global_freeze();

        let to_burn_value = coin::value(&to_burn);
        let token_pair = borrow_global_mut<Pair<X, Y>>(CoinSwapConfig::admin_address());
        let x_reserve = coin::value(&token_pair.token_x_reserve);
        let y_reserve = coin::value(&token_pair.token_y_reserve);
        let total_supply_option = coin::supply<LiquidityToken<X, Y>>();
        let total_supply = option::get_with_default(&total_supply_option, 0u128);
        let x = ((to_burn_value as u128) * (x_reserve as u128)) / (total_supply);
        let y = ((to_burn_value as u128) * (y_reserve as u128)) / (total_supply);
        assert!(x > 0 && y > 0, ERROR_SWAP_BURN_CALC_INVALID);
        burn_liquidity(to_burn);

        let x_token = coin::extract<X>(&mut token_pair.token_x_reserve, (x as u64));
        let y_token = coin::extract<Y>(&mut token_pair.token_y_reserve, (y as u64));
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_burn_event<X, Y>(x, y, to_burn_value);
        (x_token, y_token)
    }

    /// Get cumulative info of a token pair.
    /// The order of type args should be sorted.
    public fun get_cumulative_info<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128, u64) acquires Pair {
        let token_pair = borrow_global<Pair<X, Y>>(CoinSwapConfig::admin_address());
        let last_price_x_cumulative = *&token_pair.last_price_x_cumulative;
        let last_price_y_cumulative = *&token_pair.last_price_y_cumulative;
        let last_block_timestamp = token_pair.last_block_timestamp;
        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    public fun swap<X: copy + drop + store, Y: copy + drop + store>(
        x_in: coin::Coin<X>,
        y_out: u64,
        y_in: coin::Coin<Y>,
        x_out: u64,
    ): (coin::Coin<X>, coin::Coin<Y>, coin::Coin<X>, coin::Coin<Y>) acquires Pair {
        CoinSwapConfig::assert_global_freeze();

        let x_in_value = coin::value(&x_in);
        let y_in_value = coin::value(&y_in);
        assert!(x_in_value > 0 || y_in_value > 0, ERROR_SWAP_TOKEN_INSUFFICIENT);
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let token_pair = borrow_global_mut<Pair<X, Y>>(CoinSwapConfig::admin_address());
        let admin_address = CoinSwapConfig::admin_address();
        coin::deposit(admin_address, x_in);
        coin::deposit(admin_address, y_in);
        let x_swapped = coin::extract<X>(&mut token_pair.token_x_reserve, x_out);
        let y_swapped = coin::extract<Y>(&mut token_pair.token_y_reserve, y_out);
            {
                let x_reserve_new = coin::value(&token_pair.token_x_reserve);
                let y_reserve_new = coin::value(&token_pair.token_y_reserve);
                let (x_adjusted, y_adjusted);
                let (fee_numerator, fee_denominator) = CoinSwapConfig::get_poundage_rate<X, Y>();
                //                x_adjusted = x_reserve_new * 1000 - x_in_value * 3;
                //                y_adjusted = y_reserve_new * 1000 - y_in_value * 3;
                x_adjusted = x_reserve_new * fee_denominator - x_in_value * fee_numerator;
                y_adjusted = y_reserve_new * fee_denominator - y_in_value * fee_numerator;
                // x_adjusted, y_adjusted >= x_reserve, y_reserve * 1000000
                let cmp_order = SafeMath::safe_compare_mul_u64(x_adjusted, y_adjusted, x_reserve, y_reserve * 1000000);
                assert!((EQUAL == cmp_order || GREATER_THAN == cmp_order), ERROR_SWAP_SWAPOUT_CALC_INVALID);
            };

        let (x_swap_fee, y_swap_fee);
        // calculate and handle swap fee, default fee rate is 3/1000
        if (CoinSwapConfig::get_swap_fee_switch()) {
            let (actual_fee_operation_numerator, actual_fee_operation_denominator) = calc_actual_swap_fee_operation_rate<X, Y>();
            x_swap_fee = coin::extract<X>(&mut token_pair.token_x_reserve, SafeMath::safe_mul_div_u64(x_in_value, actual_fee_operation_numerator, actual_fee_operation_denominator));
            y_swap_fee = coin::extract<Y>(&mut token_pair.token_y_reserve, SafeMath::safe_mul_div_u64(y_in_value, actual_fee_operation_numerator, actual_fee_operation_denominator));
        } else {
            x_swap_fee = coin::zero();
            y_swap_fee = coin::zero();
        };

        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_swap_event<X, Y>(x_in_value, y_out, y_in_value, x_out);
        
        (x_swapped, y_swapped, x_swap_fee, y_swap_fee)
    }

    public fun calc_actual_swap_fee_operation_rate<X: copy + drop + store, Y: copy + drop + store>(): (u64, u64) {
        let (fee_numerator, fee_denominator) = CoinSwapConfig::get_poundage_rate<X, Y>();
        let (operation_numerator, operation_denominator) = CoinSwapConfig::get_swap_fee_operation_rate_v2<X, Y>();
        (fee_numerator * operation_numerator, fee_denominator * operation_denominator)
    }

    /// Emit token pair register event
    fun emit_token_pair_register_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
    ) acquires CoinSwapEventHandle {
        let event_handle = borrow_global_mut<CoinSwapEventHandle>(CoinSwapConfig::admin_address());
        event::emit_event(&mut event_handle.register_event, RegisterEvent{
            x_token_type: type_of<X>(),
            y_token_type: type_of<Y>(),
            signer: signer::address_of(signer),
        });
    }

    /// if swap fee deposit to fee address fail, return back to lp pool
    public fun return_back_to_lp_pool<X: copy + drop + store, Y: copy + drop + store>(
        x_in: coin::Coin<X>,
        y_in: coin::Coin<Y>,
    ) {
        let admin_address = CoinSwapConfig::admin_address();
        // let token_pair = borrow_global_mut<Pair<X, Y>>(admin_address);
        coin::deposit(admin_address, x_in);
        coin::deposit(admin_address, y_in);
    }

    /// Do mint and emit `AddLiquidityEvent` event
    public fun mint_and_emit_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        x_token: coin::Coin<X>,
        y_token: coin::Coin<Y>,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64): coin::Coin<LiquidityToken<X, Y>>
    acquires Pair, LiquidityTokenCapability, CoinSwapEventHandle {
        let liquidity_token = mint<X, Y>(x_token, y_token);

        let event_handle = borrow_global_mut<CoinSwapEventHandle>(CoinSwapConfig::admin_address());
        event::emit_event(&mut event_handle.add_liquidity_event, AddLiquidityEvent{
            x_token_type: type_of<X>(),
            y_token_type: type_of<Y>(),
            signer: signer::address_of(signer),
            liquidity: coin::value<LiquidityToken<X, Y>>(&liquidity_token),
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
        });
        liquidity_token
    }

    /// Do burn and emit `RemoveLiquidityEvent` event
    public fun burn_and_emit_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        to_burn: coin::Coin<LiquidityToken<X, Y>>,
        amount_x_min: u64,
        amount_y_min: u64)
    : (coin::Coin<X>, coin::Coin<Y>) acquires Pair, LiquidityTokenCapability, CoinSwapEventHandle {
        let liquidity = coin::value<LiquidityToken<X, Y>>(&to_burn);
        let (x_token, y_token) = burn<X, Y>(to_burn);

        let event_handle = borrow_global_mut<CoinSwapEventHandle>(CoinSwapConfig::admin_address());
        event::emit_event(&mut event_handle.remove_liquidity_event, RemoveLiquidityEvent{
            x_token_type: type_of<X>(),
            y_token_type: type_of<Y>(),
            signer: signer::address_of(signer),
            liquidity,
            amount_x_min,
            amount_y_min,
        });
        (x_token, y_token)
    }

    /// Do swap and emit `SwapEvent` event
    public fun swap_and_emit_event<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        x_in: coin::Coin<X>,
        y_out: u64,
        y_in: coin::Coin<Y>,
        x_out: u64): (coin::Coin<X>, coin::Coin<Y>, coin::Coin<X>, coin::Coin<Y>) acquires Pair, CoinSwapEventHandle {
        let (token_x_out, token_y_out, token_x_fee, token_y_fee) = swap<X, Y>(x_in, y_out, y_in, x_out);
        let event_handle = borrow_global_mut<CoinSwapEventHandle>(CoinSwapConfig::admin_address());
        event::emit_event(&mut event_handle.swap_event, SwapEvent{
            x_token_type: type_of<X>(),
            y_token_type: type_of<Y>(),
            signer: signer::address_of(signer),
            x_in: coin::value<X>(&token_x_out),
            y_out: coin::value<Y>(&token_y_out),
        });
        (token_x_out, token_y_out, token_x_fee, token_y_fee)
    }

} 
}
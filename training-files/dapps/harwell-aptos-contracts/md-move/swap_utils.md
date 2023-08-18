```rust
/// Uniswap v2 like token swap program
module hwswap::swap_utils {
    use std::string;
    use aptos_std::type_info;
    use aptos_std::comparator;
    use hwswap::math;


    const EQUAL: u8 = 0;
    const SMALLER: u8 = 1;
    const GREATER: u8 = 2;

    const MINIMUM_LIQUIDITY: u128 = 1000;
    
    const ERROR_INSUFFICIENT_INPUT_AMOUNT: u64 = 0;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 1;
    const ERROR_INSUFFICIENT_AMOUNT: u64 = 2;
    const ERROR_INSUFFICIENT_OUTPOT_AMOUNT: u64 = 3;
    const ERROR_SAME_COIN: u64 = 4;
    const ERROR_INVALID_AMOUNT: u64 = 5;
    const ERROR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 6;

    //sort coins before using this function
    public fun get_fee(reserve_x: u64, reserve_y: u64,k_last: u128,lp_supply: u128): u64{
        if (k_last != 0) {
            let root_k = math::sqrt((reserve_x as u128) * (reserve_y as u128));
            let root_k_last = math::sqrt(k_last);
            if (root_k > root_k_last) {
                let numerator = lp_supply * (root_k - root_k_last) * 8u128;
                let denominator = root_k_last * 17u128 + (root_k * 8u128);
                let liquidity = numerator / denominator;
                return  (liquidity as u64)
            };
        };
        0
    }


    //sort coins before using this function
    public fun get_burn_x_y(balance_x:u64, balance_y:u64, total_lp_supply:u128,liquidity: u64): (u64,u64) {
        let amount_x = ((balance_x as u128) * (liquidity as u128) / total_lp_supply as u64);
        let amount_y = ((balance_y as u128) * (liquidity as u128) / total_lp_supply as u64);
        (amount_x,amount_y)
    }

    //sort coins before using this function
    public fun get_liquidity(reserve_x:u128,reserve_y: u128,amount_x:u128,amount_y:u128,total_supply:u128) : u128{
        if(total_supply ==0u128){
            let sqrt = math::sqrt(amount_x * amount_y);
            assert!(sqrt > MINIMUM_LIQUIDITY, ERROR_INSUFFICIENT_LIQUIDITY_MINTED);
            sqrt - MINIMUM_LIQUIDITY
        }else {
            let liquidity = math::min(amount_x * total_supply / reserve_x , amount_y * total_supply / reserve_y);
            assert!(liquidity > 0u128, ERROR_INSUFFICIENT_LIQUIDITY_MINTED);
            liquidity
        }
    }

    //sort coins before using this function
    public fun get_mint_x_y(reserve_x:u64,reserve_y:u64,amount_x: u64,amount_y:u64) :(u64,u64){
        if (reserve_x == 0 && reserve_y == 0) {
            (amount_x, amount_y)
        } else {
            let amount_y_optimal = quote(amount_x, reserve_x, reserve_y);
            if (amount_y_optimal <= amount_y) {
                (amount_x, amount_y_optimal)
            } else {
                let amount_x_optimal = quote(amount_y, reserve_y, reserve_x);
                assert!(amount_x_optimal <= amount_x, ERROR_INVALID_AMOUNT);
                (amount_x_optimal, amount_y)
            }
        }
    }


    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_in > 0, ERROR_INSUFFICIENT_INPUT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        let amount_in_with_fee = (amount_in as u128) * 9975u128;
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = (reserve_in as u128) * 10000u128 + amount_in_with_fee;
        ((numerator / denominator) as u64)
    }

    public fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_out > 0, ERROR_INSUFFICIENT_OUTPOT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        let numerator = (reserve_in as u128) * (amount_out as u128) * 10000u128;
        let denominator = ((reserve_out as u128) - (amount_out as u128)) * 9975u128;
        (((numerator / denominator) as u64) + 1u64)
    }

    public fun quote(amount_x: u64, reserve_x: u64, reserve_y: u64): u64 {
        assert!(amount_x > 0, ERROR_INSUFFICIENT_AMOUNT);
        assert!(reserve_x > 0 && reserve_y > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        (((amount_x as u128) * (reserve_y as u128) / (reserve_x as u128)) as u64)
    }

    public fun get_token_info<T>(): vector<u8> {
        let type_name = type_info::type_name<T>();
        *string::bytes(&type_name)
    }

    // convert Struct to bytes ,then compare
    fun compare_struct<X, Y>(): u8 {
        let struct_x_bytes: vector<u8> = get_token_info<X>();
        let struct_y_bytes: vector<u8> = get_token_info<Y>();
        if (comparator::is_greater_than(&comparator::compare_u8_vector(struct_x_bytes, struct_y_bytes))) {
            GREATER
        } else if (comparator::is_equal(&comparator::compare_u8_vector(struct_x_bytes, struct_y_bytes))) {
            EQUAL
        } else {
            SMALLER
        }
    }

    public fun get_smaller_enum(): u8 {
        SMALLER
    }

    public fun get_greater_enum(): u8 {
        GREATER
    }

    public fun get_equal_enum(): u8 {
        EQUAL
    }

    public fun sort_token_type<X, Y>(): bool {
        let compare_x_y: u8 = compare_struct<X, Y>();
        assert!(compare_x_y != get_equal_enum(), ERROR_SAME_COIN);
        (compare_x_y == get_smaller_enum())
    }
}

```
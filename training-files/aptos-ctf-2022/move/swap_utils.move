/// Uniswap v2 like coin swap program
module ctfmovement::swap_utils {
    use std::string;
    use aptos_std::type_info;
    use aptos_std::comparator;
    use ctfmovement::simple_coin::SimpleCoin;

    const REWARD_NUMERATOR: u128 = 10;
    const REWARD_DENOMINATOR: u128 = 10000;
    const FEE_NUMERATOR: u128 = 25;
    const FEE_DENOMINATOR: u128 = 10000;

    const EQUAL: u8 = 0;
    const SMALLER: u8 = 1;
    const GREATER: u8 = 2;

    const ERROR_INSUFFICIENT_INPUT_AMOUNT: u64 = 0;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 1;
    const ERROR_INSUFFICIENT_AMOUNT: u64 = 2;
    const ERROR_INSUFFICIENT_OUTPOT_AMOUNT: u64 = 3;
    const ERROR_SAME_COIN: u64 = 4;

    public fun fee(): (u128, u128) {
        (FEE_NUMERATOR, FEE_DENOMINATOR)
    }

    public fun reward(): (u128, u128) {
        (REWARD_NUMERATOR, REWARD_DENOMINATOR)
    }
    public fun get_amount_out(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_in > 0, ERROR_INSUFFICIENT_INPUT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        let (fee_num, fee_den) = fee();
        let amount_in_with_fee = (amount_in as u128) * (fee_den - fee_num);
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = (reserve_in as u128) * fee_den + amount_in_with_fee;
        ((numerator / denominator) as u64)
    }

    public fun get_amount_out_no_fee(
        amount_in: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_in > 0, ERROR_INSUFFICIENT_INPUT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        let amount_in = (amount_in as u128);
        let numerator = amount_in * (reserve_out as u128);
        let denominator = (reserve_in as u128) + amount_in;
        ((numerator / denominator) as u64)
    }

    public fun get_amount_in(
        amount_out: u64,
        reserve_in: u64,
        reserve_out: u64
    ): u64 {
        assert!(amount_out > 0, ERROR_INSUFFICIENT_OUTPOT_AMOUNT);
        assert!(reserve_in > 0 && reserve_out > 0, ERROR_INSUFFICIENT_LIQUIDITY);

        let (fee_num, fee_den) = fee();
        let numerator = (reserve_in as u128) * (amount_out as u128) * fee_den;
        let denominator = ((reserve_out as u128) - (amount_out as u128)) * (fee_den - fee_num);
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

    public fun is_simple_coin<X>(): bool {
        compare_struct<X, SimpleCoin>() == EQUAL
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

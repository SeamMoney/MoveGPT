module collectibleswap::exponential {
    use collectibleswap::u256:: {Self, U256};
    const FEE_DIVISOR: u64 = 10000;
    const MIN_PRICE: u64 = 1;
    public fun validate_delta(delta: u64): bool {
        delta >= FEE_DIVISOR        
    }

    public fun validate_spot_price(_new_spot_price: u64): bool {
        _new_spot_price > MIN_PRICE
    }

    // ret = base_unit * (x/base_unit) ^ n
    fun fpow(x: U256, n: u64, base_unit: U256): U256 {
        let z = u256::from_u64((0 as u64));
        if (u256::compare(&x, &z) == 0) {
            if (n == 0) {
                z = base_unit
            }
        } else {
            z = base_unit;
            let i = 0;
            while (i < n) {
                z = u256::mul(z, x);
                z = u256::div(z, base_unit);
                i = i + 1;
            };
        };

        z
    }

    public fun get_buy_info(
                    spot_price: u64,
                    delta: u64,
                    num_items: u64,
                    fee_multiplier: u64,
                    protocol_fee_multiplier: u64): (u8, u64, u64, u64, u64, u64) {
        if (num_items == 0) {
            return (1, 0, 0, 0, 0, 0)
        };

        let delta_pow_n = fpow(u256::from_u64(delta), num_items, u256::from_u64(FEE_DIVISOR));

        let new_spot_price_u256 = u256::div(u256::mul(u256::from_u64(spot_price), delta_pow_n), u256::from_u64(FEE_DIVISOR));
        let new_spot_price = u256::as_u64(new_spot_price_u256);
        let buy_spot_price_u256 = u256::div(u256::mul(u256::from_u64(spot_price), u256::from_u64(delta)), u256::from_u64(FEE_DIVISOR));
        let buy_spot_price = u256::as_u64(buy_spot_price_u256);
        let input_value = buy_spot_price * ((u256::as_u64(delta_pow_n) - FEE_DIVISOR) * FEE_DIVISOR / (delta - FEE_DIVISOR)) / FEE_DIVISOR;

        let total_fee = input_value * (protocol_fee_multiplier + fee_multiplier) / FEE_DIVISOR;
        let trade_fee = input_value * fee_multiplier / FEE_DIVISOR;
        let protocol_fee = total_fee - trade_fee;
        input_value = input_value + trade_fee;
        input_value = input_value + protocol_fee;
        let new_delta = delta;

        return (0, new_spot_price, new_delta, input_value, protocol_fee, trade_fee)
    }

     public fun get_sell_info(
                    spot_price: u64,
                    delta: u64,
                    num_items_sell: u64,
                    fee_multiplier: u64,
                    protocol_fee_multiplier: u64): (u8, u64, u64, u64, u64, u64) {
        if (num_items_sell == 0) {
            return (1, 0, 0, 0, 0, 0)
        };

        let inv_delta = u256::div(u256::mul(u256::from_u64(FEE_DIVISOR), u256::from_u64(FEE_DIVISOR)), u256::from_u64(delta));
        let inv_delta_pow_n = fpow(inv_delta, num_items_sell, u256::from_u64(FEE_DIVISOR));
        let new_spot_price_u256 = u256::div((u256::mul(u256::from_u64(spot_price), inv_delta_pow_n)), u256::from_u64(FEE_DIVISOR));
        let new_spot_price = u256::as_u64(new_spot_price_u256);

        if (new_spot_price < MIN_PRICE) {
            new_spot_price = MIN_PRICE;
        };

        let output_value = spot_price * ((FEE_DIVISOR - u256::as_u64(inv_delta_pow_n)) * FEE_DIVISOR / (FEE_DIVISOR - u256::as_u64(inv_delta))) / FEE_DIVISOR;
        
        let total_fee = output_value * (protocol_fee_multiplier + fee_multiplier) / FEE_DIVISOR;
        let trade_fee = output_value * fee_multiplier / FEE_DIVISOR;
        let protocol_fee = total_fee - trade_fee;
        output_value = output_value - trade_fee;
        output_value = output_value - protocol_fee;

        return (0, new_spot_price, delta, output_value, protocol_fee, trade_fee)
    }

    #[test]
    fun test_fpow() {
        let ret = fpow(u256::from_u64(2), 4, u256::from_u64(2));
        assert!(u256::as_u64(ret) == 2, 5);
        assert!(u256::as_u64(fpow(u256::from_u64(4), 4, u256::from_u64(2))) == 32, 5);

        assert!(u256::as_u64(fpow(u256::from_u64(11000), 1, u256::from_u64(FEE_DIVISOR))) >= FEE_DIVISOR, 5);
    }

    #[test]
    fun test_get_buy_info() {
        let (_, new_spot_price, _, _, _, _) = get_buy_info(
                                                900,
                                                11000,
                                                1,
                                                125,
                                                25);
        assert!(new_spot_price > 0, 5);
    }
}
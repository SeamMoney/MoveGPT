module collectibleswap::linear {
    const FEE_DIVISOR: u64 = 10000;
    public fun validate_delta(_delta: u64): bool {
        //all valids for linear curve
        true
    }

    public fun validate_spot_price(_new_spot_price: u64): bool {
        //all valids for linear curve
        true
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

        let new_spot_price = spot_price + delta * num_items;
        let buy_spot_price = spot_price + delta;
        let input_value = num_items * buy_spot_price + num_items * (num_items - 1) * delta / 2;

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

        let total_price_decrease = delta * num_items_sell;
        let new_spot_price: u64 = 0;
        let num_items = num_items_sell;

        if (spot_price < total_price_decrease) {
            num_items = spot_price / delta + 1;
        } else {
            new_spot_price = spot_price - total_price_decrease;
        };

        let output_value = spot_price * num_items - num_items * (num_items - 1) * delta / 2;

        let total_fee = output_value * (protocol_fee_multiplier + fee_multiplier) / FEE_DIVISOR;
        let trade_fee = output_value * fee_multiplier / FEE_DIVISOR;
        let protocol_fee = total_fee - trade_fee;
        output_value = output_value - trade_fee;
        output_value = output_value - protocol_fee;

        return (0, new_spot_price, delta, output_value, protocol_fee, trade_fee)
    }
}
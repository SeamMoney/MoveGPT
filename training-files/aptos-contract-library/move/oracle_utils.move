module argo_oracle::oracle_utils {

    const BPS_DECIMALS: u64 = 4;
    const PRICE_DECIMALS: u64 = 6;

    /// Converts to a price with 6 decimals.
    public fun to_price_precision(val: u128, decimals: u64): u64 {
        if (decimals > PRICE_DECIMALS) {
            return (val / (pow(10, decimals - PRICE_DECIMALS) as u128) as u64)
        } else if (decimals < PRICE_DECIMALS) {
            return (val as u64) * pow(10, PRICE_DECIMALS - decimals)
        };
        return (val as u64)
    }

    /// Converts to bps
    public fun to_bps(val: u128, decimals: u64): u64 {
        if (decimals > BPS_DECIMALS) {
            return (val / (pow(10, decimals - BPS_DECIMALS) as u128) as u64)
        } else if (decimals < BPS_DECIMALS) {
            return (val as u64) * pow(10, BPS_DECIMALS - decimals)
        };
        return (val as u64)
    }

    /// Exponentiation.
    fun pow(base: u64, exponent: u64): u64 {
        let result = 1;
        let i = 0;
        while (i < exponent) {
            result = result * base;
            i = i + 1;
        };
        return result
    }
}
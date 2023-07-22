/// oracle_pyth writes pyth prices
module argo_oracle::oracle_pyth {
    use argo_oracle::oracle_utils::{to_price_precision};
    use argo_safe::safe::{Self, SafeWriteCapability};
    use pyth::i64;
    use pyth::price;
    use pyth::price_identifier::{Self, PriceIdentifier};
    use pyth::pyth;

    const BPS_PRECISION: u64 = 10000;

    struct OraclePyth has key {
        safe_write_cap: SafeWriteCapability,
        pyth_price_id: PriceIdentifier,
        max_conf_bps: u64,
    }

    #[cmd]
    /// Create a new Safe.
    public entry fun new_safe(
        creator: &signer,
        pyth_price_id_bytes: vector<u8>,
        max_conf_bps: u64,
    ) {
        let safe_write_cap = safe::new_safe(creator);
        move_to(creator, OraclePyth {
            safe_write_cap,
            pyth_price_id: price_identifier::from_byte_vec(pyth_price_id_bytes),
            max_conf_bps,
        });
    }

    #[cmd]
    /// Write a new price. Best effort and will return early if price is invalid.
    public entry fun write_price(oracle_addr: address) acquires OraclePyth {
        let oracle = borrow_global<OraclePyth>(oracle_addr);

        // Fetch and unwrap the Pyth price
        let pyth_price = pyth::get_price_unsafe(oracle.pyth_price_id);
        let price_i64 = price::get_price(&pyth_price);
        let expo_i64 = price::get_expo(&pyth_price);

        // If an unexpected price is encountered, return early. In general, price is positive and
        // expo is negative
        if (i64::get_is_negative(&price_i64) || !i64::get_is_negative(&expo_i64)) {
            return
        };

        // If the confidence exceeds the max confidence bounds, return early.
        let magnitude = i64::get_magnitude_if_positive(&price_i64);
        let conf = price::get_conf(&pyth_price);
        let confidence_bps = scale_ceil(conf, BPS_PRECISION, magnitude);
        if (confidence_bps > oracle.max_conf_bps) {
            return
        };

        // Write the price
        let exp = i64::get_magnitude_if_negative(&expo_i64);
        let price = to_price_precision((magnitude as u128), (exp as u64));
        let timestamp = price::get_timestamp(&pyth_price);
        safe::write_price(price, timestamp, &oracle.safe_write_cap);
    }

    /// Scales a number by a numerator/denominator. Applies ceiling division.
    fun scale_ceil(n: u64, numerator: u64, denominator: u64): u64 {
        let top = (n as u128) * (numerator as u128);
        let bottom = (denominator as u128);
        let quotient = top / bottom;
        let remainer = top % bottom;
        if (remainer > 0) {
            return (quotient + 1 as u64)
        } else {
            return (quotient as u64)
        }
    }
}
/// oracle_sb writes switchboard prices
module argo_oracle::oracle_sb {
    use argo_oracle::oracle_utils::{to_price_precision, to_bps};
    use argo_safe::safe::{Self, SafeWriteCapability};
    use switchboard::aggregator;
    use switchboard::math::{unpack};

    const BPS_PRECISION: u64 = 10000;

    struct OracleSB has key {
        safe_write_cap: SafeWriteCapability,
        sb_aggregator_addr: address,
        max_std_deviation_bps: u64,
    }

    #[cmd]
    /// Create a new Safe.
    public entry fun new_safe(
        creator: &signer,
        sb_aggregator_addr: address,
        max_std_deviation_bps: u64,
    ) {
        let safe_write_cap = safe::new_safe(creator);
        move_to(creator, OracleSB {
            safe_write_cap,
            sb_aggregator_addr,
            max_std_deviation_bps,
        });
    }

    #[cmd]
    /// Write a new price. Best effort and will return early if price is invalid.
    public entry fun write_price(oracle_addr: address) acquires OracleSB {
        let oracle = borrow_global<OracleSB>(oracle_addr);

        let (result, timestamp, std_deviation , _ , _) =
            aggregator::latest_round(oracle.sb_aggregator_addr);

        // Parse result
        let (result_value, result_decimals, result_neg) = unpack(result);
        let price = to_price_precision(result_value, (result_decimals as u64));

        // Parse std_deviation
        let (
            std_deviation_value,
            std_deviation_decimals,
            std_deviation_neg
        ) = unpack(std_deviation);
        let std_deviation_bps =
            to_bps(std_deviation_value, (std_deviation_decimals as u64));

        // Return early if price/standard deviation is invalid or if standard deviation exceeds the
        // max standard deviation
        if (result_neg || std_deviation_neg || std_deviation_bps > oracle.max_std_deviation_bps) {
            return
        };

        safe::write_price(price, timestamp, &oracle.safe_write_cap);
    }
}
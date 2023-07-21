/// oracle_stable maintains a stable price and just updates the latest timestamp.
module argo_oracle::oracle_stable {
    use aptos_framework::timestamp;
    use argo_safe::safe::{Self, SafeWriteCapability};

    struct OracleStable has key {
        safe_write_cap: SafeWriteCapability,
        price: u64,
    }

    #[cmd]
    /// Create a new Safe.
    public entry fun new_safe(creator: &signer, price: u64) {
        let safe_write_cap = safe::new_safe(creator);
        move_to(creator, OracleStable {
            safe_write_cap,
            price,
        });
    }

    #[cmd]
    /// Writes the stable price and uses the latest timestamp.
    public entry fun write_price(oracle_addr: address) acquires OracleStable {
        let oracle = borrow_global<OracleStable>(oracle_addr);
        safe::write_price(oracle.price, timestamp::now_seconds(), &oracle.safe_write_cap);
    }
}
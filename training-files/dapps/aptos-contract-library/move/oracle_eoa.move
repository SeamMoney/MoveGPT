/// oracle_eoa is a script for EOA management of a safe.
module argo_oracle::oracle_eoa {
    use argo_safe::safe::{Self, SafeWriteCapability};
    use std::signer;

    struct OracleEOA has key {
        safe_write_cap: SafeWriteCapability,
    }

    #[cmd]
    /// Create a new Safe.
    public entry fun new_safe(writer: &signer) {
        let safe_write_cap = safe::new_safe(writer);
        move_to(writer, OracleEOA { safe_write_cap });
    }

    #[cmd]
    /// Write a new price
    public entry fun write_price(
        writer: &signer,
        price: u64,
        fresh_time: u64,
    ) acquires OracleEOA {
        let oracle = borrow_global<OracleEOA>(signer::address_of(writer));
        safe::write_price(price, fresh_time, &oracle.safe_write_cap);
    }
}
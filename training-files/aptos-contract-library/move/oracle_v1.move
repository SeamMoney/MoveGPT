/// oracle_v1 medianizes multiple Safe prices
module argo_oracle::oracle_v1 {
    use argo_safe::safe::{Self, SafeWriteCapability};
    use std::error;
    use std::vector;

    const EEMPTY_SAFE_ADDRS: u64 = 0;

    const MAX_U64: u64 = 18446744073709551615;
    const PRICE_DECIMALS: u64 = 6;

    struct OracleV1 has key {
        safe_write_cap: SafeWriteCapability,
        safe_addrs: vector<address>,
    }

    /// Create a new Safe.
    public entry fun new_safe(creator: &signer, safe_addrs: vector<address>) {
        let safe_write_cap = safe::new_safe(creator);
        assert!(vector::length(&safe_addrs) > 0, error::invalid_argument(EEMPTY_SAFE_ADDRS));
        move_to(creator, OracleV1 {
            safe_write_cap,
            safe_addrs,
        });
    }

    #[cmd]
    /// Write a new price by medianizing over every Safe price. Fresh time is the min timestamp of
    /// all the Safe prices.
    public entry fun write_price(oracle_addr: address) acquires OracleV1 {
        let oracle = borrow_global<OracleV1>(oracle_addr);

        let length = vector::length(&oracle.safe_addrs);
        let prices = vector::empty<u64>();
        let min_timestamp = MAX_U64;
        let i = 0;
        while (i < length) {
            let safe_addr = *vector::borrow(&oracle.safe_addrs, i);
            vector::push_back(&mut prices, safe::price(safe_addr));
            let safe_fresh_time = safe::fresh_time(safe_addr);
            if (safe_fresh_time < min_timestamp) {
                min_timestamp = safe_fresh_time;
            };
            i = i + 1;
        };
        let median = u64_median(&mut prices);
        safe::write_price(median, min_timestamp, &oracle.safe_write_cap);
    }

    /// O(n^2) median finding. Sorts the list in-place and returns the median.
    /// TODO: Can be improved to O(n) with quickselect.
    fun u64_median(lis: &mut vector<u64>): u64 {
        let i = 0;
        let length = vector::length(lis);
        while (i < length) {
            let min_idx = i;
            let min = *vector::borrow(lis, min_idx);
            let j = i + 1;
            while (j < length) {
                if (*vector::borrow(lis, j) < min) {
                    min_idx = j;
                    min = *vector::borrow(lis, min_idx);
                };
                j = j + 1;
            };
            if (i != min_idx) {
                vector::swap(lis, i, min_idx);
            };
            // INVARIANT: lis[0..i] is sorted
            i = i + 1;
        };
        let mid = length / 2;
        if (length % 2 == 0) {
            return (*vector::borrow(lis, mid - 1) + *vector::borrow(lis, mid)) / 2
        } else {
            return *vector::borrow(lis, mid)
        }
    }

    #[test]
    fun test_u64_median() {
        assert!(u64_median(&mut vector<u64>[1]) == 1, 1);
        assert!(u64_median(&mut vector<u64>[1, 1]) == 1, 1);
        assert!(u64_median(&mut vector<u64>[1, 3]) == 2, 1);
        assert!(u64_median(&mut vector<u64>[1, 2, 3, 4, 5]) == 3, 1);
        assert!(u64_median(&mut vector<u64>[3, 5, 1, 4, 3]) == 3, 1);
        assert!(u64_median(&mut vector<u64>[5, 4, 3, 2, 1]) == 3, 1);
    }
}
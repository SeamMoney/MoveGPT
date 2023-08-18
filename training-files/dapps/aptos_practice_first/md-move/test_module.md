```rust
module use_oracle::test_module {
    #[test_only]
    use std::signer;
    #[test_only]
    use std::vector;
    #[test_only]
    use std::unit_test;
    #[test_only]
    use switchboard::aggregator;
    #[test_only]
    fun debug_latest_value(account: &signer, value: u128, dec: u8, sign: bool) {
        aggregator::new_test(account, value, dec, sign);
        std::debug::print(&aggregator::latest_value(signer::address_of(account)));
    }
    #[test]
    #[expected_failure]
    fun test_aggregator_with_decimals() {
        let signers = unit_test::create_signers_for_testing(11);
        debug_latest_value(vector::borrow(&signers, 0), 100, 0, false); // { 100000000000, 9, false }
        debug_latest_value(vector::borrow(&signers, 1), 1, 1, false); // { 100000000, 9, false }
        debug_latest_value(vector::borrow(&signers, 2), 2, 2, false); // { 20000000, 9, false }
        debug_latest_value(vector::borrow(&signers, 3), 3, 3, false); // { 3000000, 9, false }
        debug_latest_value(vector::borrow(&signers, 4), 4, 4, false); // { 400000, 9, false }
        debug_latest_value(vector::borrow(&signers, 5), 5, 5, false); // { 50000, 9, false }
        debug_latest_value(vector::borrow(&signers, 6), 6, 6, false); // { 6000, 9, false }
        debug_latest_value(vector::borrow(&signers, 7), 7, 7, false); // { 700, 9, false }
        debug_latest_value(vector::borrow(&signers, 8), 8, 8, false); // { 80, 9, false }
        debug_latest_value(vector::borrow(&signers, 9), 9, 9, false); // { 9, 9, false }
        debug_latest_value(vector::borrow(&signers, 10), 10, 10, false); // fail here - assert!(dec <= MAX_DECIMALS, EMORE_THAN_9_DECIMALS);
    }
}

```
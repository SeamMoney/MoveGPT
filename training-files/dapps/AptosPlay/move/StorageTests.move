#[test_only]
module Sender::StorageTests {
    use Sender::Storage;

    #[test(account = @Sender)]
    /// Test storage with `u128` number.
    fun store_u128(account: signer) {
        let value: u128 = 100;

        Storage::store(&account, value);
        assert!(value == Storage::get<u128>(&account), 101);
    }

    #[test(account = @Sender)]
    #[expected_failure(abort_code = 101)]
    /// Test store value twice.
    fun store_existing_resource(account: signer) {
        let value: u128 = 100;

        Storage::store(&account, value);
        Storage::store(&account, value);
    }

    #[test(account = @Sender)]
    #[expected_failure(abort_code = 102)]
    /// Test get missed value.
    fun get_missed_value(account: signer) {
        Storage::get<u128>(&account);
    }
}

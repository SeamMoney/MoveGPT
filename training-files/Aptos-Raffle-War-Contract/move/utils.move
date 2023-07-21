module GameDeployer::utils {
    use std::signer;
    use std::error;
    // Not owner & admin
    const EINVALID_OWNER: u64 = 1;

    public fun assert_owner(sender: &signer) {
        assert!(signer::address_of(sender) == @GameDeployer, error::permission_denied(EINVALID_OWNER));
    }

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    public fun setup_timestamp(aptos: &signer) {
        timestamp::set_time_has_started_for_testing(aptos);
        // Set the time to a nonzero value to avoid subtraction overflow.
        timestamp::update_global_time_for_test_secs(100);
    }
}
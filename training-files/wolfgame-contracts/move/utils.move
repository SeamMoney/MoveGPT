module woolf_deployer::utils {

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    public fun setup_timestamp(aptos: &signer) {
        timestamp::set_time_has_started_for_testing(aptos);
        // Set the time to a nonzero value to avoid subtraction overflow.
        timestamp::update_global_time_for_test_secs(100);
    }
}
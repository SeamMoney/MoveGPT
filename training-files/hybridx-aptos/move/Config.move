module HybridX::Config {
    use std::signer;
    use std::error;

    const ERROR_NOT_HAS_PRIVILEGE: u64 = 101;
    const ERROR_GLOBAL_FREEZE: u64 = 102;

    public fun admin_address(): address {
        @HybridX
    }

    public fun assert_admin(signer: &signer) {
        assert!(signer::address_of(signer) == admin_address(), error::invalid_state(ERROR_NOT_HAS_PRIVILEGE));
    }
}

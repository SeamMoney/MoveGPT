address Quantum {

module AdminSignerCapability {
    use std::error;
    use std::signer;
    use aptos_framework::account;

    friend Quantum::Oracle;
    
    const ENOT_ADMIN_ACCOUNT: u64 = 11;

    struct AdminSignerCapability has key {
        cap: account::SignerCapability,
    }

    public fun admin_address(): address {
        @Quantum
    }

    public fun assert_admin(signer: &signer) {
        assert!(signer::address_of(signer) == admin_address(), error::invalid_state(ENOT_ADMIN_ACCOUNT));
    }

    public(friend) fun initialize(signer: &signer, cap: account::SignerCapability) {
        assert_admin(signer);
        assert!(
            account::get_signer_capability_address(&cap) == admin_address(), 
            error::invalid_argument(ENOT_ADMIN_ACCOUNT)
        );
        move_to(signer, AdminSignerCapability{cap});
    }

    public(friend) fun get_admin_signer(): signer acquires AdminSignerCapability {
        let cap = borrow_global<AdminSignerCapability>(admin_address());
        account::create_signer_with_capability(&cap.cap)
    }
}
}
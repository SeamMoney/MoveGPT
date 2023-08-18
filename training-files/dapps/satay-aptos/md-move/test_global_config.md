```rust
#[test_only]
module satay::test_global_config {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;

    use satay::satay;
    use satay::global_config;
    use satay::setup_tests;

    fun initialize(aptos_framework: &signer, satay: &signer) {
        setup_tests::setup_tests(aptos_framework, satay);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay)]
    fun test_initialize(aptos_framework: &signer, satay: &signer) {
        initialize(aptos_framework, satay);
    }

    #[test(aptos_framework=@aptos_framework, non_satay=@0x1)]
    #[expected_failure]
    fun test_initialize_reject(aptos_framework: &signer, non_satay: &signer) {
        initialize(aptos_framework, non_satay);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, new_dao_admin=@0x1)]
    fun test_set_dao_admin(aptos_framework: &signer, satay: &signer, new_dao_admin: &signer) {
        initialize(aptos_framework, satay);
        let new_dao_admin_address = signer::address_of(new_dao_admin);
        global_config::set_dao_admin(satay, new_dao_admin_address);
        global_config::assert_dao_admin(satay);
        global_config::accept_dao_admin(new_dao_admin);
        global_config::assert_dao_admin(new_dao_admin);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_dao_admin=@0x1)]
    #[expected_failure]
    fun test_set_dao_admin_reject(aptos_framework: &signer, satay: &signer, non_dao_admin: &signer) {
        initialize(aptos_framework, satay);
        let new_dao_admin_address = signer::address_of(non_dao_admin);
        global_config::set_dao_admin(non_dao_admin, new_dao_admin_address);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_dao_admin=@0x1)]
    #[expected_failure]
    fun test_accept_dao_admin_reject(aptos_framework: &signer, satay: &signer, non_dao_admin: &signer) {
        initialize(aptos_framework, satay);
        global_config::accept_dao_admin(non_dao_admin);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, new_governance=@0x1)]
    fun test_set_governance(aptos_framework: &signer, satay: &signer, new_governance: &signer) {
        initialize(aptos_framework, satay);
        let new_governance_address = signer::address_of(new_governance);
        global_config::set_governance(satay, new_governance_address);
        global_config::assert_governance(satay);
        global_config::accept_governance(new_governance);
        global_config::assert_governance(new_governance);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_governance=@0x1)]
    #[expected_failure]
    fun test_set_governance_reject(aptos_framework: &signer, satay: &signer, non_governance: &signer) {
        initialize(aptos_framework, satay);
        let new_governance_address = signer::address_of(non_governance);
        global_config::set_governance(non_governance, new_governance_address);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_governance=@0x1)]
    #[expected_failure]
    fun test_accept_governance_reject(aptos_framework: &signer, satay: &signer, non_governance: &signer) {
        initialize(aptos_framework, satay);
        global_config::accept_governance(non_governance);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, new_governance=@0x1)]
    fun test_new_vault_after_governance_change(aptos_framework: &signer, satay: &signer, new_governance: &signer) {
        initialize(aptos_framework, satay);
        let new_governance_address = signer::address_of(new_governance);
        global_config::set_governance(satay, new_governance_address);
        global_config::accept_governance(new_governance);
        satay::new_vault<AptosCoin>(new_governance, 0, 0);
    }
}

```
```rust
#[test_only]
module satay::test_vault_config {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;

    use satay::satay;
    use satay::vault_config;
    use satay::setup_tests::setup_tests;

    fun initialize(aptos_framework: &signer, satay: &signer) {
        setup_tests(aptos_framework, satay)
    }

    fun create_vault(governance: &signer) {
        satay::new_vault<AptosCoin>(governance, 0, 0);
    }

    fun initialize_with_vault(aptos_framework: &signer, satay: &signer) {
        initialize(aptos_framework, satay);
        create_vault(satay)
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay)]
    fun test_create_vault(aptos_framework: &signer, satay: &signer, ) {
        initialize_with_vault(aptos_framework, satay);
        vault_config::assert_vault_manager(satay, satay::get_vault_address<AptosCoin>());
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_governance=@0x10)]
    #[expected_failure]
    fun test_create_vault_reject(aptos_framework: &signer, satay: &signer, non_governance: &signer) {
        initialize(aptos_framework, satay);
        create_vault(non_governance);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, new_vault_manager=@0x10)]
    fun test_set_vault_manager(aptos_framework: &signer, satay: &signer, new_vault_manager: &signer, ) {
        initialize_with_vault(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        vault_config::set_vault_manager(satay, vault_addr,signer::address_of(new_vault_manager));
        vault_config::assert_vault_manager(satay, vault_addr);
        vault_config::accept_vault_manager(new_vault_manager, vault_addr);
        vault_config::assert_vault_manager(new_vault_manager, vault_addr);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_vault_manager=@0x10)]
    #[expected_failure]
    fun test_set_vault_manager_reject(aptos_framework: &signer, satay: &signer, non_vault_manager: &signer) {
        initialize_with_vault(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        vault_config::set_vault_manager(non_vault_manager, vault_addr, signer::address_of(non_vault_manager));
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_vault_manager=@0x1)]
    #[expected_failure]
    fun test_accept_vault_manager_reject(aptos_framework: &signer, satay: &signer, non_vault_manager: &signer) {
        initialize_with_vault(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        vault_config::accept_vault_manager(non_vault_manager, vault_addr);
    }
}

```
#[test_only]
module satay::test_keeper_config {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;

    use satay::satay;
    use satay::mock_strategy::{MockStrategy};
    use satay::mock_vault_strategy;
    use satay::keeper_config;
    use satay::setup_tests;

    fun initialize(aptos_framework: &signer, satay: &signer) {
        setup_tests::setup_tests(aptos_framework, satay);
    }

    fun create_vault(governance: &signer) {
        satay::new_vault<AptosCoin>(governance, 0, 0, );
    }

    fun initialize_with_vault(aptos_framework: &signer, satay: &signer, ) {
        initialize(aptos_framework, satay);
        create_vault(satay);
    }

    fun initialize_strategy(governance: &signer) {
        mock_vault_strategy::approve(governance, 0);
    }

    fun initialize_with_vault_and_strategy(aptos_framework: &signer, satay: &signer) {
        initialize_with_vault(aptos_framework, satay);
        mock_vault_strategy::approve(satay, 0);
    }


    #[test(aptos_framework=@aptos_framework, satay=@satay)]
    fun test_initialize_strategy(aptos_framework: &signer, satay: &signer) {
        initialize_with_vault_and_strategy(aptos_framework, satay);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_governance=@0x1)]
    #[expected_failure]
    fun test_initialize_strategy_reject(aptos_framework: &signer, satay: &signer, non_governance: &signer) {
        initialize_with_vault(aptos_framework, satay);
        initialize_strategy(non_governance);
    }


    #[test(aptos_framework=@aptos_framework, satay=@satay, new_keeper=@0x1)]
    fun test_set_keeper(aptos_framework: &signer, satay: &signer, new_keeper: &signer) {
        initialize_with_vault_and_strategy(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        let new_keeper_address = signer::address_of(new_keeper);
        keeper_config::set_keeper<AptosCoin, MockStrategy>(satay, vault_addr, new_keeper_address);
        keeper_config::assert_keeper<AptosCoin, MockStrategy>(satay, vault_addr);
        keeper_config::accept_keeper<AptosCoin, MockStrategy>(new_keeper, vault_addr);
        keeper_config::assert_keeper<AptosCoin, MockStrategy>(new_keeper, vault_addr);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_keeper=@0x1)]
    #[expected_failure]
    fun test_set_keeper_reject(aptos_framework: &signer, satay: &signer, non_keeper: &signer) {
        initialize_with_vault_and_strategy(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        let new_keeper_address = signer::address_of(non_keeper);
        keeper_config::set_keeper<AptosCoin, MockStrategy>(non_keeper, new_keeper_address, vault_addr);
    }

    #[test(aptos_framework=@aptos_framework, satay=@satay, non_keeper=@0x1)]
    #[expected_failure]
    fun test_accept_keeper_reject(aptos_framework: &signer, satay: &signer, non_keeper: &signer) {
        initialize_with_vault_and_strategy(aptos_framework, satay);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        keeper_config::accept_keeper<AptosCoin, MockStrategy>(non_keeper, vault_addr);
    }
}

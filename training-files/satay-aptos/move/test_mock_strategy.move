#[test_only]
module satay::test_mock_strategy {

    use aptos_framework::aptos_coin::{AptosCoin};

    use satay_coins::strategy_coin::StrategyCoin;

    use satay::vault;
    use satay::satay;
    use satay::mock_vault_strategy;
    use satay::mock_strategy::{Self, MockStrategy};
    use satay::setup_tests;

    const INITIAL_DEBT_RATIO: u64 = 10000;
    const MAX_DEBT_RATIO: u64 = 10000;
    const DEPOSIT_AMOUNT: u64 = 1000;
    const MANAGEMENT_FEE: u64 = 2000;
    const PERFORMANCE_FEE: u64 = 200;

    const ERR_INITIALIZE: u64 = 1;
    const ERR_HARVEST: u64 = 2;
    const ERR_REVOKE: u64 = 3;

    fun initialize_vault_with_deposit(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer,
    ) {
        setup_tests::setup_tests_with_user(aptos_framework, satay, user, DEPOSIT_AMOUNT);
        satay::new_vault<AptosCoin>(satay, MANAGEMENT_FEE, PERFORMANCE_FEE);
        satay::deposit<AptosCoin>(user, DEPOSIT_AMOUNT);
    }

    fun initialize_with_strategy(aptos_framework: &signer, satay: &signer, user: &signer) {
        initialize_vault_with_deposit(aptos_framework, satay, user);
        mock_strategy::initialize(satay);
        mock_vault_strategy::approve(satay, INITIAL_DEBT_RATIO);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_initialize_strategy(aptos_framework: &signer, satay: &signer, user: &signer) {
        initialize_vault_with_deposit(aptos_framework, satay, user);
        mock_strategy::initialize(satay);
        mock_vault_strategy::approve(satay, INITIAL_DEBT_RATIO);

        let vault_cap = satay::test_lock_vault<AptosCoin>();
        assert!(vault::has_strategy<AptosCoin, MockStrategy>(&vault_cap), ERR_INITIALIZE);
        assert!(vault::has_coin<AptosCoin, StrategyCoin<AptosCoin, MockStrategy>>(&vault_cap), ERR_INITIALIZE);
        assert!(vault::credit_available<AptosCoin, MockStrategy>(&vault_cap) == DEPOSIT_AMOUNT, ERR_INITIALIZE);
        satay::test_unlock_vault(vault_cap);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_harvest(aptos_framework: &signer, satay: &signer, user: &signer) {
        initialize_with_strategy(aptos_framework, satay, user);
        mock_vault_strategy::harvest(satay);

        let vault_cap = satay::test_lock_vault<AptosCoin>();
        assert!(vault::credit_available<AptosCoin, MockStrategy>(&vault_cap) == 0, ERR_HARVEST);
        assert!(vault::balance<AptosCoin, AptosCoin>(&vault_cap) == 0, ERR_HARVEST);
        assert!(vault::balance<AptosCoin, StrategyCoin<AptosCoin, MockStrategy>>(&vault_cap) == DEPOSIT_AMOUNT, ERR_HARVEST);
        satay::test_unlock_vault(vault_cap);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_revoke(aptos_framework: &signer, satay: &signer, user: &signer) {
        initialize_with_strategy(aptos_framework, satay, user);
        mock_vault_strategy::harvest(satay);
        mock_vault_strategy::revoke(satay);

        let vault_cap = satay::test_lock_vault<AptosCoin>();
        assert!(vault::credit_available<AptosCoin, MockStrategy>(&vault_cap) == 0, ERR_REVOKE);
        assert!(vault::balance<AptosCoin, AptosCoin>(&vault_cap) == DEPOSIT_AMOUNT, ERR_HARVEST);
        assert!(vault::balance<AptosCoin, StrategyCoin<AptosCoin, MockStrategy>>(&vault_cap) == 0, ERR_HARVEST);
        satay::test_unlock_vault(vault_cap);
    }
}

#[test_only]
module satay::test_satay {

    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::timestamp;

    use satay_coins::vault_coin::VaultCoin;

    use satay::satay;
    use satay::vault;
    use satay::setup_tests;
    use satay::test_coin;
    use satay::test_coin::USDC;

    const MANAGEMENT_FEE: u64 = 200;
    const PERFORMANCE_FEE: u64 = 2000;
    const DEBT_RATIO: u64 = 1000;
    const DEPOSIT_AMOUNT: u64 = 1000;

    const ERR_INITIALIZED: u64 = 1;
    const ERR_NEW_VAULT: u64 = 2;
    const ERR_UPDATE_FEES: u64 = 3;
    const ERR_DEPOSIT: u64 = 4;
    const ERR_WITHDRAW: u64 = 5;
    const ERR_APPROVE_STRATEGY: u64 = 6;
    const ERR_LOCK_UNLOCK: u64 = 7;
    const ERR_FREEZE: u64 = 8;

    struct TestStrategy has drop {}
    struct TestStrategy2 has drop {}

    struct TestCoin {}

    fun setup_tests(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests::setup_tests_with_user(aptos_framework, satay, user, DEPOSIT_AMOUNT);
    }

    fun create_vault(satay: &signer) {
        satay::new_vault<AptosCoin>(satay, MANAGEMENT_FEE, PERFORMANCE_FEE);
    }

    fun setup_tests_and_create_vault(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests(aptos_framework, satay, user);
        create_vault(satay);
    }

    fun user_deposit(user: &signer) {
        satay::deposit<AptosCoin>(user, DEPOSIT_AMOUNT);
    }

    fun approve_strategy(aptos_framework: &signer, satay: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        satay::test_approve_strategy<AptosCoin, TestStrategy>(satay, DEBT_RATIO, TestStrategy {});
    }

    fun setup_test_and_create_vault_with_strategy(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        approve_strategy(aptos_framework, satay);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_initialize(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests(aptos_framework, satay, user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @0x1,
        user = @0x47
    )]
    #[expected_failure]
    fun test_initialize_unauthorized(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer
    ) {
        setup_tests(aptos_framework, satay, user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_new_vault(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests(aptos_framework, satay, user);
        create_vault(satay);
        assert!(satay::get_total_assets<AptosCoin>() == 0, ERR_NEW_VAULT);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_new_vault_unathorized(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests(aptos_framework, satay, user);
        create_vault(user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_two_new_vaults(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests(aptos_framework, satay, user);
        create_vault(satay);
        test_coin::register_coin<USDC>(satay);
        satay::new_vault<USDC>(satay, MANAGEMENT_FEE, PERFORMANCE_FEE);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_update_vault_fee(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);

        satay::update_vault_fee<AptosCoin>(satay, MANAGEMENT_FEE, PERFORMANCE_FEE);

        let (management_fee_val, performance_fee_val) = satay::get_vault_fees<AptosCoin>();
        assert!(management_fee_val == MANAGEMENT_FEE, ERR_UPDATE_FEES);
        assert!(performance_fee_val == PERFORMANCE_FEE, ERR_UPDATE_FEES);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_update_vault_fee_unauthorized(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);

        satay::update_vault_fee<AptosCoin>(user, MANAGEMENT_FEE, PERFORMANCE_FEE);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_deposit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        user_deposit(user);
        assert!(coin::balance<VaultCoin<AptosCoin>>(signer::address_of(user)) == DEPOSIT_AMOUNT, ERR_DEPOSIT);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_withdraw(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        user_deposit(user);
        satay::withdraw<AptosCoin>(user, DEPOSIT_AMOUNT);

        let user_address = signer::address_of(user);
        assert!(coin::balance<VaultCoin<AptosCoin>>(user_address) == 0, ERR_WITHDRAW);
        assert!(coin::balance<AptosCoin>(user_address) == DEPOSIT_AMOUNT, ERR_WITHDRAW);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_withdraw_no_liquidity(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(aptos_framework, satay, user);
        user_deposit(user);

        let credit = satay::get_credit_available<AptosCoin, TestStrategy>();

        let vault_cap = satay::test_lock_vault<AptosCoin>();
        let aptos = vault::test_withdraw_base_coin<AptosCoin, TestStrategy>(
            &vault_cap,
            credit,
            &TestStrategy {}
        );
        coin::deposit(signer::address_of(user), aptos);
        satay::test_unlock_vault<AptosCoin>(vault_cap);

        satay::withdraw<AptosCoin>(user, DEPOSIT_AMOUNT);
    }
    
    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_freeze(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(satay);
        assert!(satay::is_vault_frozen<AptosCoin>(), ERR_FREEZE);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_freeze_unauthorized(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_unfreeze(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(satay);
        satay::unfreeze_vault<AptosCoin>(satay);
        assert!(!satay::is_vault_frozen<AptosCoin>(), ERR_FREEZE);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_unfreeze_unauthorized(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer
    ) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(satay);
        satay::unfreeze_vault<AptosCoin>(user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    #[expected_failure]
    fun test_deposit_after_freeze(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer
    ) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(satay);
        user_deposit(user);
    }

    #[test(
        aptos_framework = @aptos_framework,
        satay = @satay,
        user = @0x47
    )]
    fun test_withdraw_after_freeze(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        user_deposit(user);
        satay::freeze_vault<AptosCoin>(satay);
        satay::withdraw<AptosCoin>(user, DEPOSIT_AMOUNT);
        assert!(coin::balance<AptosCoin>(signer::address_of(user)) == DEPOSIT_AMOUNT, ERR_FREEZE);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_deposit_after_freeze_and_unfreeze(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer
    ) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        satay::freeze_vault<AptosCoin>(satay);
        satay::unfreeze_vault<AptosCoin>(satay);
        user_deposit(user);
        assert!(coin::balance<AptosCoin>(signer::address_of(user)) == 0, ERR_FREEZE);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_approve_strategy(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(
            aptos_framework,
            satay,
                        user
        );

        approve_strategy(aptos_framework, satay);

        assert!(satay::has_strategy<AptosCoin, TestStrategy>(), ERR_APPROVE_STRATEGY);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_approve_multiple_strategies(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        satay::test_approve_strategy<AptosCoin, TestStrategy2>(
            satay,
            DEBT_RATIO,
            TestStrategy2 {}
        );
        assert!(satay::has_strategy<AptosCoin, TestStrategy2>(), ERR_APPROVE_STRATEGY);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_lock_unlock_vault(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let vault_cap = satay::test_strategy_lock_vault<AptosCoin, TestStrategy>(
            &TestStrategy {}
        );
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy>(vault_cap);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_lock_unlock_vault_multiple_strategies(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        satay::test_approve_strategy<AptosCoin, TestStrategy2>(
            satay,
            DEBT_RATIO,
            TestStrategy2 {}
        );

        let vault_cap = satay::test_strategy_lock_vault<AptosCoin, TestStrategy>(&TestStrategy {});
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy>(vault_cap, );
        let vault_cap = satay::test_strategy_lock_vault<AptosCoin, TestStrategy2>(&TestStrategy2 {});
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy2>(vault_cap, );
    }


    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_reject_unapproved_strategy(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let vault_cap = satay::test_strategy_lock_vault<AptosCoin, TestStrategy2>(&TestStrategy2 {});
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy2>(vault_cap)
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_lock_locked_vault(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        satay::test_approve_strategy<AptosCoin, TestStrategy2>(
            satay,
            DEBT_RATIO,
            TestStrategy2 {}
        );

        let vault_cap = satay::test_strategy_lock_vault<AptosCoin, TestStrategy>(&TestStrategy {});
        let vault_cap_2 = satay::test_strategy_lock_vault<AptosCoin, TestStrategy2>(&TestStrategy2 {});
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy2>(vault_cap_2);
        satay::test_strategy_unlock_vault<AptosCoin, TestStrategy>(vault_cap);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_keeper_lock_unlock_vault(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let keeper_cap = satay::test_keeper_lock_vault<AptosCoin, TestStrategy>(
            satay,
            TestStrategy {}
        );
        satay::test_keeper_unlock_vault<AptosCoin, TestStrategy>(keeper_cap);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_keeper_lock_unlock_vault_unauthorized(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let keeper_cap = satay::test_keeper_lock_vault<AptosCoin, TestStrategy>(
            user,
            TestStrategy {}
        );
        satay::test_keeper_unlock_vault<AptosCoin, TestStrategy>(keeper_cap);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_user_lock_unlock_vault(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let user_cap = satay::test_user_lock_vault<AptosCoin>(satay, );
        satay::test_user_unlock_vault<AptosCoin>(user_cap);
    }

    // test admin functions
    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_admin_functions(
        aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_test_and_create_vault_with_strategy(
            aptos_framework,
            satay,
                        user
        );

        let debt_ratio = 100;
        satay::test_update_strategy_debt_ratio<AptosCoin, TestStrategy>(
            satay,
            debt_ratio,
            TestStrategy {}
        );
    }
}
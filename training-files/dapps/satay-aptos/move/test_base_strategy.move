#[test_only]
module satay::test_base_strategy {

    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::timestamp;

    use satay_coins::vault_coin::VaultCoin;
    use satay_coins::strategy_coin::StrategyCoin;
    
    use satay::satay;
    use satay::base_strategy;
    use satay::vault;
    use satay::dao_storage;
    use satay::setup_tests;

    const MAX_DEBT_RATIO_BPS: u64 = 10000;
    const SECS_PER_YEAR: u64 = 31556952; // 365.2425 days

    const MANAGEMENT_FEE: u64 = 200;
    const PERFORMANCE_FEE: u64 = 2000;
    const DEBT_RATIO: u64 = 1000;
    const VAULT_ID: u64 = 0;
    const PROFIT_AMOUNT: u64 = 50;

    const DEPOSIT_AMOUNT: u64 = 1000;
    const TEND_AMOUNT: u64 = 200;

    const ERR_INITIALIZE: u64 = 1;
    const ERR_DEPOSIT: u64 = 2;
    const ERR_WITHDRAW: u64 = 3;
    const ERR_PREPARE_RETURN: u64 = 4;
    const ERR_ADMIN_FUNCTIONS: u64 = 5;
    const ERR_TEND: u64 = 6;
    const ERR_HARVEST: u64 = 7;
    const ERR_USER_WITHDRAW: u64 = 8;
    const ERR_PROCESS_HARVEST: u64 = 9;

    struct TestStrategy has drop {}

    fun setup_tests_and_create_vault(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests::setup_tests_with_user(aptos_framework, satay, user, DEPOSIT_AMOUNT);
        
        satay::new_vault<AptosCoin>(satay, MANAGEMENT_FEE, PERFORMANCE_FEE);
        satay::new_strategy<AptosCoin, TestStrategy>(satay, TestStrategy {});
    }

    fun user_deposit(user: &signer, amount: u64) {
        satay::deposit<AptosCoin>(user, amount);
    }

    fun initialize_strategy(satay: &signer) {
        base_strategy::approve_strategy<AptosCoin, TestStrategy>(satay, DEBT_RATIO, TestStrategy {});
    }

    fun setup_tests_and_create_vault_and_strategy(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault(aptos_framework, satay, user);
        initialize_strategy(satay);
    }

    fun setup_and_user_deposit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault_and_strategy(aptos_framework, satay, user);
        user_deposit(user, DEPOSIT_AMOUNT);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_initialize(aptos_framework: &signer, satay: &signer, user: &signer){
        setup_tests_and_create_vault(aptos_framework, satay, user);

        initialize_strategy(satay);

        let vault_cap = satay::test_lock_vault<AptosCoin>();
        assert!(vault::has_strategy<AptosCoin, TestStrategy>(&vault_cap), ERR_INITIALIZE);
        assert!(vault::has_coin<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>(&vault_cap), ERR_INITIALIZE);
        satay::test_unlock_vault(vault_cap);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_initialize_unauthorized(aptos_framework: &signer, satay: &signer, user: &signer){
        setup_tests_and_create_vault(aptos_framework, satay, user);

        base_strategy::approve_strategy<AptosCoin, TestStrategy>(
            user,
            DEBT_RATIO,
            TestStrategy {}
        );
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_deposit_strategy_coin(aptos_framework: &signer, satay: &signer, user: &signer){
        setup_tests_and_create_vault_and_strategy(aptos_framework, satay, user);

        let amount = 1000;
        let strategy_coins = satay::strategy_mint<AptosCoin, TestStrategy>(amount, TestStrategy {});

        let keeper_cap = satay::test_keeper_lock_vault<AptosCoin, TestStrategy>(satay, TestStrategy {});
        base_strategy::deposit_strategy_coin<AptosCoin, TestStrategy>(
            &keeper_cap,
            strategy_coins,
        );
        satay::test_keeper_unlock_vault<AptosCoin, TestStrategy>(keeper_cap);

        assert!(satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>() == amount, ERR_DEPOSIT);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_withdraw_strategy_coin(aptos_framework: &signer, satay: &signer, user: &signer){
        setup_tests_and_create_vault_and_strategy(aptos_framework, satay, user);

        let amount = 1000;
        let strategy_coins = satay::strategy_mint<AptosCoin, TestStrategy>(amount, TestStrategy {});

        let keeper_cap = satay::test_keeper_lock_vault<AptosCoin, TestStrategy>(
            satay,
            TestStrategy {}
        );

        base_strategy::deposit_strategy_coin<AptosCoin, TestStrategy>(
            &keeper_cap,
            strategy_coins,
        );
        let strategy_coins = vault::test_withdraw_strategy_coin<AptosCoin, TestStrategy>(
            &keeper_cap,
            amount,
        );

        assert!(coin::value(&strategy_coins) == amount, ERR_WITHDRAW);
        satay::strategy_burn(strategy_coins, TestStrategy {});

        satay::test_keeper_unlock_vault<AptosCoin, TestStrategy>(keeper_cap);

        assert!(satay::get_vault_balance<AptosCoin, AptosCoin>() == 0, ERR_WITHDRAW);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_admin_functions(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_tests_and_create_vault_and_strategy(aptos_framework, satay, user);

        let debt_ratio = 100;
        base_strategy::update_debt_ratio<AptosCoin, TestStrategy>(
            satay,
            debt_ratio,
            TestStrategy {}
        );

        let vault_cap = satay::test_lock_vault<AptosCoin>();

        assert!(vault::debt_ratio<AptosCoin, TestStrategy>(&vault_cap) == debt_ratio, ERR_ADMIN_FUNCTIONS);

        satay::test_unlock_vault(vault_cap);
    }

    fun apply_position(
        strategy: &signer,
        aptos_coins: Coin<AptosCoin>
    ): Coin<StrategyCoin<AptosCoin, TestStrategy>> {
        let amount = coin::value(&aptos_coins);
        let strategy_address = signer::address_of(strategy);
        coin::deposit<AptosCoin>(strategy_address, aptos_coins);
        satay::strategy_mint<AptosCoin, TestStrategy>(amount, TestStrategy {})
    }

    fun liquidate_position(
        strategy: &signer,
        strategy_coins: Coin<StrategyCoin<AptosCoin, TestStrategy>>
    ): Coin<AptosCoin> {
        let amount = coin::value(&strategy_coins);
        if (amount > 0) {
            satay::strategy_burn(strategy_coins, TestStrategy {});
            coin::withdraw<AptosCoin>(strategy, amount)
        } else {
            coin::destroy_zero(strategy_coins);
            coin::zero<AptosCoin>()
        }
    }

    fun harvest(
        satay: &signer,
        user: &signer,
    ){

        let strategy_balance = satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>();

        let (to_apply, harvest_lock) = base_strategy::open_vault_for_harvest<AptosCoin, TestStrategy>(
            satay,
            strategy_balance,
            TestStrategy {}
        );

        let debt_payment = base_strategy::get_harvest_debt_payment(&harvest_lock);
        let profit = base_strategy::get_harvest_profit(&harvest_lock);

        let strategy_coins_to_liquidate = base_strategy::withdraw_strategy_coin<AptosCoin, TestStrategy>(
            &harvest_lock,
            debt_payment + profit,
        );
        let liquidated_coins = liquidate_position(user, strategy_coins_to_liquidate);
        let debt_payment = coin::extract<AptosCoin>(&mut liquidated_coins, debt_payment);
        let profit = coin::extract<AptosCoin>(&mut liquidated_coins, profit);
        coin::destroy_zero(liquidated_coins);

        let usdt = apply_position(user, to_apply);

        base_strategy::close_vault_for_harvest<AptosCoin, TestStrategy>(
            harvest_lock,
            debt_payment,
            profit,
            usdt
        );
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_harvest_credit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        let credit_available = satay::get_credit_available<AptosCoin, TestStrategy>();

        assert!(credit_available == DEPOSIT_AMOUNT * DEBT_RATIO / MAX_DEBT_RATIO_BPS, ERR_HARVEST);

        harvest(satay, user);

        let strategy_coins = satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>();
        assert!(strategy_coins == credit_available, ERR_HARVEST);
    }

    fun harvest_profit(
        aptos_framework: &signer,
        satay: &signer,
        user: &signer
    ) {
        let keeper_cap = satay::test_keeper_lock_vault<AptosCoin, TestStrategy>(
            satay,
            TestStrategy {},
        );
        aptos_coin::mint(aptos_framework, signer::address_of(user), PROFIT_AMOUNT);
        let strategy_coins = satay::strategy_mint<AptosCoin, TestStrategy>(PROFIT_AMOUNT, TestStrategy {});
        base_strategy::deposit_strategy_coin(
            &keeper_cap,
            strategy_coins,
        );
        satay::test_keeper_unlock_vault<AptosCoin, TestStrategy>(keeper_cap);
    }


    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_harvest_profit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        let seconds = 1000;
        timestamp::fast_forward_seconds(seconds);

        let balance_before = satay::get_vault_balance<AptosCoin, AptosCoin>();

        harvest_profit(aptos_framework, satay, user);

        let performance_fee = PROFIT_AMOUNT * PERFORMANCE_FEE / MAX_DEBT_RATIO_BPS;
        let management_fee = (
            satay::get_strategy_total_debt<AptosCoin, TestStrategy>() *
                seconds * MANAGEMENT_FEE / MAX_DEBT_RATIO_BPS /
                SECS_PER_YEAR
        );
        let vault_cap = satay::test_lock_vault<AptosCoin>();
        let expected_fee = vault::calculate_vault_coin_amount_from_base_coin_amount<AptosCoin>(
            &vault_cap,
            performance_fee + management_fee
        );
        satay::test_unlock_vault(vault_cap);

        harvest(satay, user);

        assert!(satay::get_vault_balance<AptosCoin, AptosCoin>() == balance_before + PROFIT_AMOUNT, ERR_HARVEST);
        assert!(satay::get_total_gain<AptosCoin, TestStrategy>() == PROFIT_AMOUNT, ERR_HARVEST);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        assert!(dao_storage::balance<VaultCoin<AptosCoin>>(vault_addr) == expected_fee, ERR_HARVEST);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_harvest_profit_and_credit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        let seconds = 1000;
        timestamp::fast_forward_seconds(seconds);

        let credit_available = satay::get_credit_available<AptosCoin, TestStrategy>();

        harvest_profit(aptos_framework, satay, user);

        let performance_fee = PROFIT_AMOUNT * PERFORMANCE_FEE / MAX_DEBT_RATIO_BPS;
        let management_fee = (
            satay::get_strategy_total_debt<AptosCoin, TestStrategy>() *
                seconds * MANAGEMENT_FEE / MAX_DEBT_RATIO_BPS /
                SECS_PER_YEAR
        );
        let vault_cap = satay::test_lock_vault<AptosCoin>();
        let expected_fee = vault::calculate_vault_coin_amount_from_base_coin_amount<AptosCoin>(
            &vault_cap,
            performance_fee + management_fee
        );
        satay::test_unlock_vault(vault_cap);

        harvest(satay, user);

        assert!(satay::get_vault_balance<AptosCoin, AptosCoin>() == DEPOSIT_AMOUNT - credit_available + PROFIT_AMOUNT, ERR_HARVEST);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        assert!(dao_storage::balance<VaultCoin<AptosCoin>>(vault_addr) == expected_fee, ERR_HARVEST);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_harvest_debt_payment(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        base_strategy::update_debt_ratio<AptosCoin, TestStrategy>(
            satay,
            0,
            TestStrategy {}
        );

        harvest(satay, user);

        assert!(satay::get_vault_balance<AptosCoin, AptosCoin>() == DEPOSIT_AMOUNT, ERR_HARVEST);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_harvest_debt_payment_and_profit(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        let seconds = 1000;
        timestamp::fast_forward_seconds(seconds);

        harvest_profit(aptos_framework, satay, user);

        let performance_fee = PROFIT_AMOUNT * PERFORMANCE_FEE / MAX_DEBT_RATIO_BPS;
        let management_fee = (
            satay::get_strategy_total_debt<AptosCoin, TestStrategy>() *
                seconds * MANAGEMENT_FEE / MAX_DEBT_RATIO_BPS /
                SECS_PER_YEAR
        );
        let vault_cap = satay::test_lock_vault<AptosCoin>();
        let expected_fee = vault::calculate_vault_coin_amount_from_base_coin_amount<AptosCoin>(
            &vault_cap,
            performance_fee + management_fee
        );
        satay::test_unlock_vault(vault_cap);

        base_strategy::update_debt_ratio<AptosCoin, TestStrategy>(
            satay,
            0,
            TestStrategy {}
        );

        harvest(satay, user);

        assert!(satay::get_vault_balance<AptosCoin, AptosCoin>() == DEPOSIT_AMOUNT + PROFIT_AMOUNT, ERR_HARVEST);
        let vault_addr = satay::get_vault_address<AptosCoin>();
        assert!(dao_storage::balance<VaultCoin<AptosCoin>>(vault_addr) == expected_fee, ERR_HARVEST);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_harvest_profit_wrong_amount(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);
        harvest_profit(aptos_framework, satay, user);
        let strategy_balance = satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>();

        let (to_apply, harvest_lock) = base_strategy::open_vault_for_harvest<AptosCoin, TestStrategy>(
            satay,
            strategy_balance,
            TestStrategy {},
        );

        assert!(base_strategy::get_harvest_debt_payment<AptosCoin, TestStrategy>(&harvest_lock) == 0, ERR_HARVEST);
        assert!(base_strategy::get_harvest_profit<AptosCoin, TestStrategy>(&harvest_lock) == PROFIT_AMOUNT, ERR_HARVEST);

        let strategy_coins = apply_position(user, to_apply);

        base_strategy::close_vault_for_harvest<AptosCoin, TestStrategy>(
            harvest_lock,
            coin::zero(),
            coin::zero(),
            strategy_coins,
        );
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_harvest_debt_payment_wrong_amount(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        base_strategy::update_debt_ratio<AptosCoin, TestStrategy>(
            satay,
            0,
            TestStrategy {}
        );

        let strategy_balance = satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>();
        let debt_out_standing = satay::get_debt_out_standing<AptosCoin, TestStrategy>();

        let (to_apply, harvest_lock) = base_strategy::open_vault_for_harvest<AptosCoin, TestStrategy>(
            satay,
            strategy_balance,
            TestStrategy {},
        );

        assert!(base_strategy::get_harvest_debt_payment<AptosCoin, TestStrategy>(&harvest_lock) == debt_out_standing, ERR_HARVEST);
        assert!(base_strategy::get_harvest_profit<AptosCoin, TestStrategy>(&harvest_lock) == 0, ERR_HARVEST);

        let strategy_coins = apply_position(user, to_apply);

        base_strategy::close_vault_for_harvest<AptosCoin, TestStrategy>(
            harvest_lock,
            coin::zero(),
            coin::zero(),
            strategy_coins,
        );
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    fun test_user_withdraw(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);
        harvest(satay, user);

        let user_vault_coin_balance = coin::balance<VaultCoin<AptosCoin>>(signer::address_of(user));
        let vault_coins = coin::withdraw<VaultCoin<AptosCoin>>(user, user_vault_coin_balance);

        let base_coin_expected = satay::get_base_coin_amount<AptosCoin>(user_vault_coin_balance);

        let user_withdraw_lock = base_strategy::open_vault_for_user_withdraw<AptosCoin, TestStrategy>(
            user,
            vault_coins,
            TestStrategy {}
        );
        let strategy_coins = base_strategy::withdraw_strategy_coin_for_liquidation<AptosCoin, TestStrategy>(
            &user_withdraw_lock,
            base_strategy::get_user_withdraw_amount_needed(&user_withdraw_lock)
        );

        let aptos_coins = liquidate_position(user, strategy_coins);

        base_strategy::close_vault_for_user_withdraw(
            user_withdraw_lock,
            aptos_coins
        );

        assert!(satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, TestStrategy>>() == 0, ERR_USER_WITHDRAW);
        assert!(coin::balance<AptosCoin>(signer::address_of(user)) == base_coin_expected, ERR_USER_WITHDRAW);
        assert!(satay::get_total_loss<AptosCoin, TestStrategy>() == 0, ERR_USER_WITHDRAW);
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_user_withdraw_loss(aptos_framework: &signer, satay: &signer, user: &signer) {
        let loss = 10;

        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        let user_vault_coin_balance = coin::balance<VaultCoin<AptosCoin>>(signer::address_of(user));
        let user_vault_coins = coin::withdraw<VaultCoin<AptosCoin>>(user, user_vault_coin_balance);

        let user_withdraw_lock = base_strategy::open_vault_for_user_withdraw<AptosCoin, TestStrategy>(
            user,
            user_vault_coins,
            TestStrategy {}
        );

        let strategy_coins = base_strategy::withdraw_strategy_coin_for_liquidation<AptosCoin, TestStrategy>(
            &user_withdraw_lock,
            base_strategy::get_user_withdraw_amount_needed(&user_withdraw_lock) - loss
        );
        let aptos_coins = liquidate_position(user, strategy_coins);

        base_strategy::close_vault_for_user_withdraw(
            user_withdraw_lock,
            aptos_coins
        );
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_user_withdraw_not_enough_share_coins(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        harvest(satay, user);

        let user_withdraw_amount= coin::balance<VaultCoin<AptosCoin>>(signer::address_of(user)) + 1;
        let user_vault_coins = coin::withdraw<VaultCoin<AptosCoin>>(user, user_withdraw_amount);

        let user_withdraw_lock = base_strategy::open_vault_for_user_withdraw<AptosCoin, TestStrategy>(
            user,
            user_vault_coins,
            TestStrategy {}
        );
        base_strategy::close_vault_for_user_withdraw(
            user_withdraw_lock,
            coin::zero<AptosCoin>()
        )
    }

    #[test(aptos_framework = @aptos_framework, satay = @satay, user = @0x47)]
    #[expected_failure]
    fun test_user_withdraw_enough_liquidity(aptos_framework: &signer, satay: &signer, user: &signer) {
        setup_and_user_deposit(aptos_framework, satay, user);

        let user_vault_coin_balance = coin::balance<VaultCoin<AptosCoin>>(signer::address_of(user));
        let user_vault_coins = coin::withdraw<VaultCoin<AptosCoin>>(user, user_vault_coin_balance);

        let user_withdraw_lock = base_strategy::open_vault_for_user_withdraw<AptosCoin, TestStrategy>(
            user,
            user_vault_coins,
            TestStrategy {}
        );

        base_strategy::close_vault_for_user_withdraw(
            user_withdraw_lock,
            coin::zero<AptosCoin>()
        )
    }
}

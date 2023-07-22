#[test_only]
module Aptoswap::pool_test {

    use std::signer;
    use std::vector;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_framework::account;

    use Aptoswap::pool::{ 
        swap_y_to_x_impl, 
        initialize_impl, 
        add_liquidity_impl, 
        create_pool_impl, 
        swap_x_to_y_impl, 
        freeze_pool, 
        unfreeze_pool, 
        is_pool_freeze, 
        validate_lsp_from_address,
        get_pool_x, 
        get_pool_y, 
        get_pool_lsp_supply, 
        is_swap_cap_exists, 
        get_pool_admin_fee, 
        get_pool_lp_fee, 
        get_pool_connect_fee, 
        get_pool_incentive_fee,
        get_bank_balance,
        remove_liquidity_impl_v2
    };
    use Aptoswap::pool::{ LSP, Token };

    // ============================================= Test Case =============================================
    #[test(admin = @Aptoswap)]
    fun test_create_pool(admin: signer) {
        test_create_pool_impl(&admin); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134007)] // EPermissionDenied
    fun test_create_pool_with_non_admin(admin: signer, guy: signer) {
        test_create_pool_with_non_admin_impl(&admin, &guy);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_swap_x_to_y(admin: signer, guy: signer) {
        // test_swap_x_to_y_impl(&admin, &guy, false);
        test_swap_x_to_y_default_impl(&admin, &guy);
    }

    #[test(admin = @Aptoswap)]
    fun test_freeze_pool(admin: signer) {
        test_freeze_pool_impl(&admin);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134007)] // EPermissionDenied
    fun test_freeze_pool_with_non_admin_impl(admin: signer, guy: signer) {
        test_freeze_or_unfreeze_pool_with_non_admin_impl(&admin, &guy, true);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134007)] // EPermissionDenied
    fun test_unfreeze_pool_with_non_admin_impl(admin: signer, guy: signer) {
        test_freeze_or_unfreeze_pool_with_non_admin_impl(&admin, &guy, false);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_swap_x_to_y_check_balance_empty(admin: signer, guy: signer) {
        test_swap_x_to_y_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: true,
                check_balance_not_enough: false,
                check_pool_freeze: false
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_swap_x_to_y_check_balance_not_enough(admin: signer, guy: signer) {
        test_swap_x_to_y_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: true,
                check_pool_freeze: false
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134010)] // EPoolFreeze
    fun test_swap_x_to_y_check_pool_freeze(admin: signer, guy: signer) {
        test_swap_x_to_y_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: false,
                check_pool_freeze: true
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_swap_y_to_x(admin: signer, guy: signer) {
        // test_swap_x_to_y_impl(&admin, &guy, false);
        test_swap_y_to_x_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: false,
                check_pool_freeze: false
            }
        );
    }


    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_swap_y_to_x_check_balance_empty(admin: signer, guy: signer) {
        test_swap_y_to_x_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: true,
                check_balance_not_enough: false,
                check_pool_freeze: false
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_swap_y_to_x_check_balance_not_enough(admin: signer, guy: signer) {
        test_swap_y_to_x_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: true,
                check_pool_freeze: false
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    #[expected_failure(abort_code = 134010)] // EPoolFreeze
    fun test_swap_y_to_x_check_pool_freeze(admin: signer, guy: signer) {
        test_swap_y_to_x_impl(
            &admin, 
            &guy, 
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: false,
                check_pool_freeze: true
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134009)] // ECoinNotRegister
    fun test_add_liquidity_check_x_not_register(admin: signer, guy: signer) {
        test_add_liquidity_impl(
            &admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT,
            TestAddLiqudityConfig {
                check_x_not_register: true,
                check_y_not_register: false,
                check_x_zero: false,
                check_y_zero: false,
                check_pool_freeze: false, 
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134009)] // ECoinNotRegister
    fun test_add_liquidity_check_y_not_register(admin: signer, guy: signer) {
        test_add_liquidity_impl(
            &admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT,
            TestAddLiqudityConfig {
                check_x_not_register: false,
                check_y_not_register: true,
                check_x_zero: false,
                check_y_zero: false,
                check_pool_freeze: false,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_add_liquidity_check_x_zero(admin: signer, guy: signer) {
        test_add_liquidity_impl(
            &admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT,
            TestAddLiqudityConfig {
                check_x_not_register: false,
                check_y_not_register: false,
                check_x_zero: true,
                check_y_zero: false,
                check_pool_freeze: false,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_add_liquidity_check_y_zero(admin: signer, guy: signer) {
        test_add_liquidity_impl(
            &admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT,
            TestAddLiqudityConfig {
                check_x_not_register: false,
                check_y_not_register: false,
                check_x_zero: false,
                check_y_zero: true,
                check_pool_freeze: false,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134010)] // EPoolFreeze
    fun test_add_liquidity_check_pool_freeze(admin: signer, guy: signer) {
        test_add_liquidity_impl(
            &admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT,
            TestAddLiqudityConfig {
                check_x_not_register: false,
                check_y_not_register: false,
                check_x_zero: false,
                check_y_zero: false,
                check_pool_freeze: true,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_1(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT, TEST_Y_AMT, TEST_LSP_AMT);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_2(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT, TEST_Y_AMT + TEST_Y_AMT / 3, TEST_LSP_AMT);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_3(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT, 2 * TEST_Y_AMT, TEST_LSP_AMT);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_4(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT, 1, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_5(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, 1, TEST_Y_AMT, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_6(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT / 2, TEST_Y_AMT / 3, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_7(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT / 3, TEST_Y_AMT / 2, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_8(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT * 2, TEST_Y_AMT * 3, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_add_liquidity_case_9(admin: signer, guy: signer) {
        test_add_liquidity_default_impl(&admin, &guy, TEST_X_AMT * 3, TEST_Y_AMT * 2, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134009)] // ECoinNotRegister
    fun test_withdraw_case_check_lsp_not_register(admin: signer, guy: signer) {
        test_withdraw_liquidity_impl(
            &admin, 
            &guy,
            0,
            TestWithdrawLiqudityConfig {
                check_lsp_not_register: true,
                check_lsp_zero: false,
                check_lsp_amount_larger: false,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_withdraw_case_check_lsp_zero(admin: signer, guy: signer) {
        test_withdraw_liquidity_impl(
            &admin, 
            &guy,
            0,
            TestWithdrawLiqudityConfig {
                check_lsp_not_register: false,
                check_lsp_zero: true,
                check_lsp_amount_larger: false,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)] 
    #[expected_failure(abort_code = 134008)] // ENotEnoughBalance
    fun test_withdraw_case_check_lsp_amount_larger(admin: signer, guy: signer) {
        test_withdraw_liquidity_impl(
            &admin, 
            &guy,
            0,
            TestWithdrawLiqudityConfig {
                check_lsp_not_register: false,
                check_lsp_zero: false,
                check_lsp_amount_larger: true,
            }
        );
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_1(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 0);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_2(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 1); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_3(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 10); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_4(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 100); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_5(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 1000); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_6(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, 10000); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_7(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, TEST_LSP_AMT / 6); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_8(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, TEST_LSP_AMT / 3); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_9(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, TEST_LSP_AMT / 2); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_10(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, TEST_LSP_AMT * 2 / 3); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_withdraw_case_11(admin: signer, guy: signer) {
        test_withdraw_liquidity_default_impl(&admin, &guy, TEST_LSP_AMT - 1); 
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_amm_simulate_1000(admin: signer, guy: signer) {
        test_amm_simulate_1000_impl(&admin, &guy);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_amm_simulate_3000(admin: signer, guy: signer) {
        test_amm_simulate_3000_impl(&admin, &guy);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_amm_simulate_5000(admin: signer, guy: signer) {
        test_amm_simulate_5000_impl(&admin, &guy);
    }

    #[test(admin = @Aptoswap, guy = @0x10000)]
    fun test_amm_simulate_10000(admin: signer, guy: signer) {
        test_amm_simulate_10000_impl(&admin, &guy);
    }

    // ============================================= Test Case =============================================

    struct TX { }
    struct TY { }
    struct TZ { }
    struct TW { }

    const TEST_Y_AMT: u64 = 1000000000;
    const TEST_X_AMT: u64 = 1000000;
    const TEST_LSP_AMT: u64 = 31622000;

    #[test_only]
    fun test_create_pool_impl(admin: &signer) {
        account::create_account_for_test(signer::address_of(admin));
        let admin_addr = signer::address_of(admin);
        test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 201);

        assert!(coin::balance<LSP<TX, TY>>(admin_addr) == TEST_LSP_AMT, 0);
    }

    #[test_only]
    fun test_create_pool_with_non_admin_impl(admin: &signer, guy: &signer) {
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);
        let _ = create_pool_impl<TZ, TW>(guy, 100, 201, 3, 25, 1, 2, 10, 0);
    }

    #[test_only]
    fun test_freeze_pool_impl(admin: &signer) {
        let admin_addr = signer::address_of(admin);
        account::create_account_for_test(admin_addr);
         test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 201);

        freeze_pool<TX, TY>(admin);
        assert!(is_pool_freeze<TX, TY>() == true, 0);

        unfreeze_pool<TX, TY>(admin);
        assert!(is_pool_freeze<TX, TY>() == false, 0);
    }

    #[test_only]
    fun test_freeze_or_unfreeze_pool_with_non_admin_impl(admin: &signer, guy: &signer, freeze: bool) {
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);

        test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 201);
        if (freeze) {
            freeze_pool<TX, TY>(guy);
        } else {
            unfreeze_pool<TX, TY>(guy);
        };
    }

    struct TestSwapConfig has copy, drop {
        check_balance_empty: bool,
        check_balance_not_enough: bool,
        check_pool_freeze: bool
    }

    #[test_only]
    fun test_swap_x_to_y_default_impl(admin: &signer, guy: &signer): address {
        test_swap_x_to_y_impl(
            admin, guy,
            TestSwapConfig {
                check_balance_empty: false,
                check_balance_not_enough: false,
                check_pool_freeze: false
            }
        )
    }

    // **Test Case**:
    // The other guy tries to exchange 5000 X token for exchange.
    // 
    // Consider now current pool has 1000000000 Y token and 1000000 X token, when
    // transfer 5000 X token:
    //    - We take floor[5000 * 5 / 10000] = 2 X token to the admin.
    //    - We take floor[(5000 - 2) * 26 / 10000] = 12 X token to the lp provider, 
    //    - The rest 5000 - 2 - 12 = 4986 X token is added to the pool.
    //    - Based on the CPMM formula, we got Y_after * (1000000 + 4986)  >= 1000000000 * 1000000,
    // Y_after = 995038737, and we withdraw 1000000000 - 995038737 = 4961263 Y token
    //    - We re-added the 12 X token into the pool, given now the pool value to 1000000 + 4986 + 12 = 
    // 1004998 X token, with 995038737 Y token.
    //    - In conclusion:
    //        - Admin: 2 X token and 0 Y token
    //        - Guy: 0 X token and 4961263 Y token
    //        - Pool: 1004998 X token and 995038737 Y token
    #[test_only]
    fun test_swap_x_to_y_impl(admin: &signer, guy: &signer, config: TestSwapConfig): address {
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);

        // Create pool (x direction)
        let pool_account_addr = test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 200);

        // Doing a extra freeze -> unfreeze to check whether unfreeze is also okay
        freeze_pool<TX, TY>(admin);
        if (!config.check_pool_freeze) {
            unfreeze_pool<TX, TY>(admin);
        };

        managed_coin::register<TX>(guy);
        if (!config.check_balance_empty) {
            if (!config.check_balance_not_enough) {
                managed_coin::mint<TX>(admin, guy_addr, 5000);
            }
            else {
                managed_coin::mint<TX>(admin, guy_addr, 4999);
            };
        };

        // Redeem the profit
        let old_balance_tx = get_bank_balance<TX>();
        let old_balance_ty = get_bank_balance<TY>();

        swap_x_to_y_impl<TX, TY>(guy, 5000, 0, 0);

        // Check pool balance and guy balance
        validate_lsp_from_address<TX, TY>();
        assert!(coin::balance<TY>(guy_addr) == 4961263, 0);
        assert!(get_pool_x<TX, TY>() == 1004998, 1);
        assert!(get_pool_y<TX, TY>() == 995038737, 2);
        
        assert!(get_bank_balance<TX>() == old_balance_tx + 2, 0);
        assert!(get_bank_balance<TY>() == old_balance_ty, 0);
        validate_lsp_from_address<TX, TY>();

        pool_account_addr
    }

    // **Test Case**:
    // The other guy tries to exchange 5000000 Y token for exchange.
    // 
    // Consider now current pool has 1000000000 Y token and 1000000 X token, when
    // transfer 5000000 Y token:
    //    - We take floor[5000000 * 26/10000] = 13000 Y token to the lp provider, 
    //    - The rest 5000000 - 13000 = 4987000 Y token is added to the pool.
    //    - Based on the CPMM formula, we got (1000000000 + 4987000) * X_after >= 1000000000 * 1000000,
    // X_after = 995038, and we withdraw 1000000 - 995038 = 4962 X token
    //    - We take floor[4962 * 5/10000] = 2 X token for the admin fee, now we left 4962 - 2 = 4960 X to the guy
    //    - We re-added the 13000 Y into the pool, given now the pool value to 1000000000 + 4987000 + 13000 = 
    // 1005000000 Y token, with 995038 X token.
    //    - In conclusion:
    //        - Admin: 2 X token and 0 Y token
    //        - Guy: 4960 X token and 0 Y token
    //        - Pool: 995038 X token and 1005000000 Y token
    #[test_only]
    fun test_swap_y_to_x_impl(admin: &signer, guy: &signer, config: TestSwapConfig): address {
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);

        // Create pool
        let pool_account_addr = test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 200);
        
        // Doing a extra freeze -> unfreeze to check whether unfreeze is also okay
        freeze_pool<TX, TY>(admin);
        if (!config.check_pool_freeze) {
            unfreeze_pool<TX, TY>(admin);
        };

        managed_coin::register<TY>(guy);
        if (!config.check_balance_empty) {
            if (!config.check_balance_not_enough) {
                managed_coin::mint<TY>(admin, guy_addr, 5000000);
            }
            else {
                managed_coin::mint<TY>(admin, guy_addr, 5000000 - 1);
            };
        };

        // Redeem the profit
        let old_balance_tx = get_bank_balance<TX>();
        let old_balance_ty = get_bank_balance<TY>();

        swap_y_to_x_impl<TX, TY>(guy, 5000000, 0, 0);

        validate_lsp_from_address<TX, TY>();
        assert!(coin::balance<TX>(guy_addr) == 4960, 0);
        assert!(get_pool_x<TX, TY>() == 995038, 1);
        assert!(get_pool_y<TX, TY>() == 1005000000, 2);
        
        assert!(get_bank_balance<TX>() == old_balance_tx + 2, 0);
        assert!(get_bank_balance<TY>() == old_balance_ty, 0);
        validate_lsp_from_address<TX, TY>();

        pool_account_addr
    }

    struct TestAddLiqudityConfig has copy, drop {
        check_x_not_register: bool,
        check_y_not_register: bool,
        check_x_zero: bool,
        check_y_zero: bool,
        check_pool_freeze: bool
    }

    #[test_only]
    fun test_add_liquidity_default_impl(admin: &signer, guy: &signer, x_added: u64, y_added: u64, checked: u64) {
        test_add_liquidity_impl(admin, guy, x_added, y_added, checked, TestAddLiqudityConfig {
            check_x_not_register: false,
            check_y_not_register: false,
            check_x_zero: false,
            check_y_zero: false,
            check_pool_freeze: false
        });
    }

    #[test_only]
    fun test_add_liquidity_impl(admin: &signer, guy: &signer, x_added: u64, y_added: u64, checked: u64, config: TestAddLiqudityConfig) {
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);

        test_utils_create_pool(admin, TEST_X_AMT, TEST_Y_AMT, 201);

        // Doing a extra freeze -> unfreeze to check whether unfreeze is also okay
        freeze_pool<TX, TY>(admin);
        if (!config.check_pool_freeze) {
            unfreeze_pool<TX, TY>(admin);
        };

        let x_pool = get_pool_x<TX, TY>();
        let y_pool = get_pool_y<TX, TY>();
        let lsp_pool = get_pool_lsp_supply<TX, TY>();

        if (!config.check_x_not_register) {
            managed_coin::register<TX>(guy);
            if (!config.check_x_zero) {
                managed_coin::mint<TX>(admin, guy_addr, x_added);
            };
        };
        if (!config.check_y_not_register) {
            managed_coin::register<TY>(guy);
            if (!config.check_y_zero) {
                managed_coin::mint<TY>(admin, guy_addr, y_added);
            };
        };

        add_liquidity_impl<TX, TY>(guy, x_added, y_added);
        validate_lsp_from_address<TX, TY>();

        let lsp_checked_x = (x_added as u128) * (lsp_pool as u128) / (x_pool as u128);
        let lsp_checked_y = (y_added as u128) * (lsp_pool as u128) / (y_pool as u128);
        let lsp_checked = if (lsp_checked_x < lsp_checked_y) { lsp_checked_x } else { lsp_checked_y };
        let checked = (if (checked > 0) { checked } else { (lsp_checked as u64) });

        assert!(coin::is_account_registered<LSP<TX, TY>>(guy_addr), 0);
        assert!(coin::balance<LSP<TX, TY>>(guy_addr) == checked, 0);
    }

    struct TestWithdrawLiqudityConfig has copy, drop {
        check_lsp_not_register: bool,
        check_lsp_zero: bool,
        check_lsp_amount_larger: bool
    }

    #[test_only]
    fun test_withdraw_liquidity_default_impl(admin: &signer, guy: &signer, lsp_left: u64) {
        test_withdraw_liquidity_impl(admin, guy, lsp_left, TestWithdrawLiqudityConfig {
            check_lsp_not_register: false,
            check_lsp_zero: false,
            check_lsp_amount_larger: false
        })
    }

    #[test_only]
    fun test_withdraw_liquidity_impl(admin: &signer, guy: &signer, lsp_left: u64, config: TestWithdrawLiqudityConfig) {
        test_swap_x_to_y_default_impl(admin, guy);
        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);

        // Transfer the lsp token to the guy
        if (!config.check_lsp_not_register) {
            if (!coin::is_account_registered<LSP<TX, TY>>(guy_addr)) {
                managed_coin::register<LSP<TX, TY>>(guy);
            };
            if (!config.check_lsp_zero) {
                coin::transfer<LSP<TX, TY>>(admin, guy_addr, coin::balance<LSP<TX, TY>>(admin_addr));
            };
        };

        let lsp_take = TEST_LSP_AMT - lsp_left;
        let (x_pool_ori_amt, y_pool_ori_amt) = (get_pool_x<TX, TY>(), get_pool_y<TX, TY>());
        let old_balance_tx = coin::balance<TX>(guy_addr);
        let old_balance_ty = coin::balance<TY>(guy_addr);
        let old_balance_admin_tx = get_bank_balance<TX>();
        let old_balance_admin_ty = get_bank_balance<TY>();

        
        if (!config.check_lsp_amount_larger) {
            remove_liquidity_impl_v2<TX, TY>(guy, lsp_take, 0);
        } else {
            remove_liquidity_impl_v2<TX, TY>(guy, lsp_take + 1, 0);
        };

        validate_lsp_from_address<TX, TY>();

        let (x_pool_amt, y_pool_amt, lsp_supply) = (
            get_pool_x<TX, TY>(), 
            get_pool_y<TX, TY>(), 
            get_pool_lsp_supply<TX, TY>()
        );

        let x_guy_amt_checked = (1004998 as u128) * (lsp_take as u128) / (TEST_LSP_AMT as u128);
        let y_guy_amt_checked = (995038737 as u128) * (lsp_take as u128) / (TEST_LSP_AMT as u128);
        let x_guy_amt_checked = (x_guy_amt_checked as u64);
        let y_guy_amt_checked = (y_guy_amt_checked as u64);

        let x_admin_amt_checked = x_guy_amt_checked * 10 / 10000;
        let y_admin_amt_checked = y_guy_amt_checked * 10 / 10000;
        let x_guy_amt_checked = x_guy_amt_checked - x_admin_amt_checked;
        let y_guy_amt_checked = y_guy_amt_checked - y_admin_amt_checked;
        

        let new_balance_tx = coin::balance<TX>(guy_addr);
        let new_balance_ty = coin::balance<TY>(guy_addr);
        let new_balance_admin_tx = get_bank_balance<TX>();
        let new_balance_admin_ty = get_bank_balance<TY>();

        assert!(new_balance_tx - old_balance_tx == x_guy_amt_checked , 0);
        assert!(new_balance_ty - old_balance_ty == y_guy_amt_checked, 1);
        assert!(lsp_supply == lsp_left, 2);
        assert!(new_balance_admin_tx - old_balance_admin_tx == x_admin_amt_checked, 5);
        assert!(new_balance_admin_ty - old_balance_admin_ty == y_admin_amt_checked, 6);
        assert!(x_pool_amt + x_guy_amt_checked + x_admin_amt_checked == x_pool_ori_amt, 3);
        assert!(y_pool_amt + y_guy_amt_checked + y_admin_amt_checked == y_pool_ori_amt, 4);
    }

    #[test_only]
    fun test_utils_create_pool(admin: &signer, init_x_amt: u64, init_y_amt: u64, fee_direction: u8): address {
        let admin_addr = signer::address_of(admin);

        initialize_impl(admin, 8);

        // Check registe token and borrow capability
        assert!(coin::is_coin_initialized<Token>(), 0);
        assert!(is_swap_cap_exists(admin_addr), 0);

        managed_coin::initialize<TX>(admin, b"TX", b"TX", 10, true);
        managed_coin::initialize<TY>(admin, b"TY", b"TY", 10, true);
        assert!(coin::is_coin_initialized<TX>(), 1);
        assert!(coin::is_coin_initialized<TY>(), 2);

        // Creat the pool
        let pool_account_addr = create_pool_impl<TX, TY>(admin, 100, fee_direction, 3, 25, 1, 2, 10, 0);
        assert!(coin::is_coin_initialized<LSP<TX, TY>>(), 6);
        assert!(coin::is_account_registered<LSP<TX, TY>>(pool_account_addr), 7);
        assert!(get_pool_x<TX, TY>() == 0, 0);
        assert!(get_pool_y<TX, TY>() == 0, 0);
        assert!(get_pool_lsp_supply<TX, TY>() == 0, 0);

        assert!(get_pool_admin_fee<TX, TY>() == 3, 0);
        assert!(get_pool_connect_fee<TX, TY>() == 2, 0);
        assert!(get_pool_lp_fee<TX, TY>() == 25, 0);
        assert!(get_pool_incentive_fee<TX, TY>() == 1, 0);

        validate_lsp_from_address<TX, TY>();

        // Register & mint some coin
        assert!(coin::is_account_registered<TX>(admin_addr), 3);
        assert!(coin::is_account_registered<TY>(admin_addr), 4);
        managed_coin::mint<TX>(admin, admin_addr, init_x_amt);
        managed_coin::mint<TY>(admin, admin_addr, init_y_amt);
        assert!(coin::balance<TX>(admin_addr) == init_x_amt, 5);
        assert!(coin::balance<TY>(admin_addr) == init_y_amt, 5);
        add_liquidity_impl<TX, TY>(admin, init_x_amt, init_y_amt);
        validate_lsp_from_address<TX, TY>();
        
        // let _ = borrow_global<LSPCapabilities<TX, TY>>(pool_account_addr);
        assert!(coin::balance<LSP<TX, TY>>(admin_addr) > 0, 8);
        assert!(coin::balance<LSP<TX, TY>>(admin_addr) == get_pool_lsp_supply<TX, TY>(), 8);

        // Use == for testing
        assert!(get_pool_x<TX, TY>() == init_x_amt, 9);
        assert!(get_pool_y<TX, TY>() == init_y_amt, 10);

        pool_account_addr
    }

    struct AmmSimulationStepData has copy, drop {
        /// The number of X token added in current step
        x_added: u64,
        /// The number of Y token added in current step
        y_added: u64,
        /// The number of X token that should currently in the pool
        x_checked: u64,
        /// The number of Y token that should currently in the pool
        y_checked: u64,
        /// The number of X token that should currently for the admin
        x_admin_checked: u64,
        /// The number of Y token that should currently for the admin
        y_admin_checked: u64,
    }

    struct AmmSimulationData has copy, drop {
        /// The initial X token for the pool
        x_init: u64,
        /// The initial Y token for the pool
        y_init: u64,
        /// Thee fee direction
        fee_direction: u8,
        /// The simulation step data
        data: vector<AmmSimulationStepData>
    }

    #[test_only]
    /// Getting a series of simulation data and check whether the simulation in the pool is right
    fun test_utils_amm_simulate(admin: &signer, guy: &signer, s: &AmmSimulationData) {

        let admin_addr = signer::address_of(admin);
        let guy_addr = signer::address_of(guy);
        account::create_account_for_test(admin_addr);
        account::create_account_for_test(guy_addr);
        managed_coin::register<TX>(guy);
        managed_coin::register<TY>(guy);

        // TODO
        test_utils_create_pool(admin, s.x_init, s.y_init, s.fee_direction);
        let ori_admin_x = get_bank_balance<TX>();
        let ori_admin_y = get_bank_balance<TY>();

        let i: u64 = 0;
        let data_legnth: u64 = vector::length(&s.data);

        while (i < data_legnth) 
        {
            let info = vector::borrow(&s.data, i);
            // Do the simulatio

            // let (x_amt_ori, y_amt_ori, _) = pool::get_amounts(pool_mut);
            if (info.x_added > 0) 
            {
                managed_coin::mint<TX>(admin, guy_addr, info.x_added);
                swap_x_to_y_impl<TX, TY>(guy, info.x_added, 0, 0);
            }
            else if (info.y_added > 0) 
            {
                managed_coin::mint<TY>(admin, guy_addr, info.y_added);
                swap_y_to_x_impl<TX, TY>(guy, info.y_added, 0, 0);
            };

            // Check the data matches the simulate data
            let (x_amt, y_amt) = (get_pool_x<TX, TY>(), get_pool_y<TX, TY>());
            assert!(x_amt == info.x_checked, i);
            assert!(y_amt == info.y_checked, i);
            assert!(get_bank_balance<TX>() - ori_admin_x == info.x_admin_checked, i);
            assert!(get_bank_balance<TY>() - ori_admin_y == info.y_admin_checked, i);
            
            i = i + 1;
        }
    }

    #[test_only]
    fun test_amm_simulate_1000_impl(admin: &signer, guy: &signer) {
        let s = AmmSimulationData {
            x_init: 100000,
            y_init: 2245300000,
            fee_direction: 200,
            data: vector [
                AmmSimulationStepData { x_added: 826, y_added: 0, x_checked: 100826, y_checked: 2226949933, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24777258, x_checked: 99720, y_checked: 2251727191, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 839, y_added: 0, x_checked: 100559, y_checked: 2232984631, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30701239, x_checked: 99199, y_checked: 2263685870, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2438, y_added: 0, x_checked: 101636, y_checked: 2209538273, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29673026, x_checked: 100293, y_checked: 2239211299, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35921653, x_checked: 98714, y_checked: 2275132952, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1735, y_added: 0, x_checked: 100449, y_checked: 2235924877, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 774, y_added: 0, x_checked: 101223, y_checked: 2218871756, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1352, y_added: 0, x_checked: 102575, y_checked: 2189689738, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36848550, x_checked: 100882, y_checked: 2226538288, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 911, y_added: 0, x_checked: 101793, y_checked: 2206655162, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20091888, x_checked: 100877, y_checked: 2226747050, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1886, y_added: 0, x_checked: 102763, y_checked: 2185964852, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32319572, x_checked: 101270, y_checked: 2218284424, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 39161466, x_checked: 99518, y_checked: 2257445890, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1512, y_added: 0, x_checked: 101030, y_checked: 2223727322, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34514246, x_checked: 99490, y_checked: 2258241568, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24755917, x_checked: 98414, y_checked: 2282997485, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1026, y_added: 0, x_checked: 99440, y_checked: 2259487465, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2059, y_added: 0, x_checked: 101498, y_checked: 2213782562, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 794, y_added: 0, x_checked: 102292, y_checked: 2196641925, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28243534, x_checked: 100997, y_checked: 2224885459, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2693, y_added: 0, x_checked: 103689, y_checked: 2167247830, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1309, y_added: 0, x_checked: 104998, y_checked: 2140290112, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 83500813, x_checked: 101066, y_checked: 2223790925, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2204, y_added: 0, x_checked: 103269, y_checked: 2176456981, x_admin_checked: 5, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26051256, x_checked: 102051, y_checked: 2202508237, x_admin_checked: 5, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 838, y_added: 0, x_checked: 102889, y_checked: 2184611935, x_admin_checked: 5, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 113504641, x_checked: 97820, y_checked: 2298116576, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 868, y_added: 0, x_checked: 98688, y_checked: 2277949897, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 862, y_added: 0, x_checked: 99550, y_checked: 2258270578, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1047, y_added: 0, x_checked: 100597, y_checked: 2234811234, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27150280, x_checked: 99393, y_checked: 2261961514, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 64718130, x_checked: 96636, y_checked: 2326679644, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 744, y_added: 0, x_checked: 97380, y_checked: 2308927121, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1231, y_added: 0, x_checked: 98611, y_checked: 2280173242, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30101425, x_checked: 97330, y_checked: 2310274667, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34116285, x_checked: 95918, y_checked: 2344390952, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37283750, x_checked: 94421, y_checked: 2381674702, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31370453, x_checked: 93197, y_checked: 2413045155, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 822, y_added: 0, x_checked: 94019, y_checked: 2391998993, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 44002424, x_checked: 92326, y_checked: 2436001417, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1289, y_added: 0, x_checked: 93615, y_checked: 2402536714, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24623810, x_checked: 92668, y_checked: 2427160524, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 48620707, x_checked: 90853, y_checked: 2475781231, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 876, y_added: 0, x_checked: 91729, y_checked: 2452191309, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27910916, x_checked: 90700, y_checked: 2480102225, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25728750, x_checked: 89772, y_checked: 2505830975, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3463, y_added: 0, x_checked: 93234, y_checked: 2413016448, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 896, y_added: 0, x_checked: 94130, y_checked: 2390098330, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 43503054, x_checked: 92452, y_checked: 2433601384, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37172369, x_checked: 91065, y_checked: 2470773753, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 900, y_added: 0, x_checked: 91965, y_checked: 2446647150, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1632, y_added: 0, x_checked: 93597, y_checked: 2404089037, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1932, y_added: 0, x_checked: 95529, y_checked: 2355591492, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 798, y_added: 0, x_checked: 96327, y_checked: 2336125613, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22804138, x_checked: 95399, y_checked: 2358929751, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 951, y_added: 0, x_checked: 96350, y_checked: 2335694974, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29490512, x_checked: 95152, y_checked: 2365185486, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26219644, x_checked: 94112, y_checked: 2391405130, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2186, y_added: 0, x_checked: 96297, y_checked: 2337264982, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 796, y_added: 0, x_checked: 97093, y_checked: 2318151075, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24121273, x_checked: 96096, y_checked: 2342272348, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18081765, x_checked: 95362, y_checked: 2360354113, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1488, y_added: 0, x_checked: 96850, y_checked: 2324161708, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2045, y_added: 0, x_checked: 98894, y_checked: 2276239637, x_admin_checked: 11, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 49997941, x_checked: 96774, y_checked: 2326237578, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18244587, x_checked: 96023, y_checked: 2344482165, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29453359, x_checked: 94835, y_checked: 2373935524, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18900399, x_checked: 94088, y_checked: 2392835923, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 41110791, x_checked: 92503, y_checked: 2433946714, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 846, y_added: 0, x_checked: 93349, y_checked: 2411940104, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 65810627, x_checked: 90876, y_checked: 2477750731, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27067134, x_checked: 89897, y_checked: 2504817865, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 783, y_added: 0, x_checked: 90680, y_checked: 2483244135, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1114, y_added: 0, x_checked: 91794, y_checked: 2453161258, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22358415, x_checked: 90968, y_checked: 2475519673, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 936, y_added: 0, x_checked: 91904, y_checked: 2450360968, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 792, y_added: 0, x_checked: 92696, y_checked: 2429477360, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2090, y_added: 0, x_checked: 94785, y_checked: 2376058593, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35546010, x_checked: 93392, y_checked: 2411604603, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1212, y_added: 0, x_checked: 94604, y_checked: 2380784317, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21938987, x_checked: 93743, y_checked: 2402723304, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2757, y_added: 0, x_checked: 96499, y_checked: 2334271139, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32253574, x_checked: 95188, y_checked: 2366524713, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 878, y_added: 0, x_checked: 96066, y_checked: 2344944562, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 857, y_added: 0, x_checked: 96923, y_checked: 2324258358, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 773, y_added: 0, x_checked: 97696, y_checked: 2305915336, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 831, y_added: 0, x_checked: 98527, y_checked: 2286513116, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31248778, x_checked: 97203, y_checked: 2317761894, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46644800, x_checked: 95291, y_checked: 2364406694, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36570855, x_checked: 93844, y_checked: 2400977549, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 954, y_added: 0, x_checked: 94798, y_checked: 2376865450, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22201753, x_checked: 93923, y_checked: 2399067203, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 869, y_added: 0, x_checked: 94792, y_checked: 2377124053, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1160, y_added: 0, x_checked: 95952, y_checked: 2348459528, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23625805, x_checked: 94999, y_checked: 2372085333, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1398, y_added: 0, x_checked: 96397, y_checked: 2337756858, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 42011172, x_checked: 94700, y_checked: 2379768030, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1052, y_added: 0, x_checked: 95752, y_checked: 2353671358, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22565722, x_checked: 94846, y_checked: 2376237080, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23869602, x_checked: 93906, y_checked: 2400106682, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 755, y_added: 0, x_checked: 94661, y_checked: 2380988994, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19698345, x_checked: 93887, y_checked: 2400687339, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1280, y_added: 0, x_checked: 95167, y_checked: 2368472660, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2550, y_added: 0, x_checked: 97716, y_checked: 2306830802, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45236223, x_checked: 95842, y_checked: 2352067025, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1110, y_added: 0, x_checked: 96952, y_checked: 2325186259, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31221698, x_checked: 95671, y_checked: 2356407957, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27643755, x_checked: 94565, y_checked: 2384051712, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36604042, x_checked: 93139, y_checked: 2420655754, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37786770, x_checked: 91712, y_checked: 2458442524, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29811389, x_checked: 90617, y_checked: 2488253913, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24056647, x_checked: 89752, y_checked: 2512310560, x_admin_checked: 16, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2851, y_added: 0, x_checked: 92602, y_checked: 2435173578, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1397, y_added: 0, x_checked: 93999, y_checked: 2399058936, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46238506, x_checked: 92227, y_checked: 2445297442, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 934, y_added: 0, x_checked: 93161, y_checked: 2420833706, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1381, y_added: 0, x_checked: 94542, y_checked: 2385547646, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1470, y_added: 0, x_checked: 96012, y_checked: 2349096914, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1785, y_added: 0, x_checked: 97797, y_checked: 2306315308, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45597985, x_checked: 95906, y_checked: 2351913293, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19830222, x_checked: 95107, y_checked: 2371743515, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30317372, x_checked: 93910, y_checked: 2402060887, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 52175430, x_checked: 91919, y_checked: 2454236317, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34002099, x_checked: 90667, y_checked: 2488238416, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 6801, y_added: 0, x_checked: 97465, y_checked: 2315092280, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2071, y_added: 0, x_checked: 99535, y_checked: 2267059873, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20916190, x_checked: 98628, y_checked: 2287976063, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 41809079, x_checked: 96863, y_checked: 2329785142, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22509978, x_checked: 95939, y_checked: 2352295120, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1287, y_added: 0, x_checked: 97226, y_checked: 2321228943, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 899, y_added: 0, x_checked: 98125, y_checked: 2300009226, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36822150, x_checked: 96583, y_checked: 2336831376, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1317, y_added: 0, x_checked: 97900, y_checked: 2305465794, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1741, y_added: 0, x_checked: 99641, y_checked: 2265273957, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46174652, x_checked: 97656, y_checked: 2311448609, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3478, y_added: 0, x_checked: 101133, y_checked: 2232178567, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2234, y_added: 0, x_checked: 103366, y_checked: 2184062800, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20978812, x_checked: 102386, y_checked: 2205041612, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25579795, x_checked: 101215, y_checked: 2230621407, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25498636, x_checked: 100075, y_checked: 2256120043, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3366, y_added: 0, x_checked: 103440, y_checked: 2182895171, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1850, y_added: 0, x_checked: 105290, y_checked: 2144622044, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 16779006, x_checked: 104475, y_checked: 2161401050, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20439864, x_checked: 103499, y_checked: 2181840914, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3789, y_added: 0, x_checked: 107287, y_checked: 2104982875, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 42169898, x_checked: 105186, y_checked: 2147152773, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1444, y_added: 0, x_checked: 106630, y_checked: 2118135291, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 51893241, x_checked: 104087, y_checked: 2170028532, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 55570504, x_checked: 101495, y_checked: 2225599036, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23111363, x_checked: 100455, y_checked: 2248710399, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1002, y_added: 0, x_checked: 101457, y_checked: 2226545791, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36193235, x_checked: 99839, y_checked: 2262739026, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 826, y_added: 0, x_checked: 100665, y_checked: 2244216859, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 774, y_added: 0, x_checked: 101439, y_checked: 2227136944, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 43973893, x_checked: 99480, y_checked: 2271110837, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 103913082, x_checked: 95139, y_checked: 2375023919, x_admin_checked: 30, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 43020901, x_checked: 93451, y_checked: 2418044820, x_admin_checked: 30, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27145354, x_checked: 92417, y_checked: 2445190174, x_admin_checked: 30, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 820, y_added: 0, x_checked: 93237, y_checked: 2423737227, x_admin_checked: 30, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25830063, x_checked: 92257, y_checked: 2449567290, x_admin_checked: 30, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 56819489, x_checked: 90171, y_checked: 2506386779, x_admin_checked: 31, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 143507324, x_checked: 85300, y_checked: 2649894103, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1138, y_added: 0, x_checked: 86438, y_checked: 2615067414, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 33611981, x_checked: 85344, y_checked: 2648679395, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30450518, x_checked: 84377, y_checked: 2679129913, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 767, y_added: 0, x_checked: 85144, y_checked: 2655026775, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 731, y_added: 0, x_checked: 85875, y_checked: 2632456853, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22434376, x_checked: 85152, y_checked: 2654891229, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2477, y_added: 0, x_checked: 87628, y_checked: 2580051790, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28776850, x_checked: 86664, y_checked: 2608828640, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 42350045, x_checked: 85284, y_checked: 2651178685, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 86582356, x_checked: 82594, y_checked: 2737761041, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22507020, x_checked: 81923, y_checked: 2760268061, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29910040, x_checked: 81048, y_checked: 2790178101, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 44021768, x_checked: 79793, y_checked: 2834199869, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 997, y_added: 0, x_checked: 80790, y_checked: 2799293338, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 51378633, x_checked: 79338, y_checked: 2850671971, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4403, y_added: 0, x_checked: 83739, y_checked: 2701206441, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1101, y_added: 0, x_checked: 84840, y_checked: 2666214741, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45236841, x_checked: 83429, y_checked: 2711451582, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22763720, x_checked: 82737, y_checked: 2734215302, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 827, y_added: 0, x_checked: 83564, y_checked: 2707220644, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 845, y_added: 0, x_checked: 84409, y_checked: 2680182757, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1096, y_added: 0, x_checked: 85505, y_checked: 2645890160, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28387793, x_checked: 84600, y_checked: 2674277953, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 93633606, x_checked: 81746, y_checked: 2767911559, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34124755, x_checked: 80754, y_checked: 2802036314, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1136, y_added: 0, x_checked: 81890, y_checked: 2763233203, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 626, y_added: 0, x_checked: 82516, y_checked: 2742303424, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3165, y_added: 0, x_checked: 85680, y_checked: 2641281975, x_admin_checked: 39, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 39642232, x_checked: 84417, y_checked: 2680924207, x_admin_checked: 39, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27816169, x_checked: 83553, y_checked: 2708740376, x_admin_checked: 39, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 132585112, x_checked: 79664, y_checked: 2841325488, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1095, y_added: 0, x_checked: 80759, y_checked: 2802869766, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45228342, x_checked: 79480, y_checked: 2848098108, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23860900, x_checked: 78822, y_checked: 2871959008, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35383400, x_checked: 77866, y_checked: 2907342408, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23439533, x_checked: 77245, y_checked: 2930781941, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28064766, x_checked: 76515, y_checked: 2958846707, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 711, y_added: 0, x_checked: 77226, y_checked: 2931643326, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 758, y_added: 0, x_checked: 77984, y_checked: 2903185150, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 53167312, x_checked: 76586, y_checked: 2956352462, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1738, y_added: 0, x_checked: 78324, y_checked: 2890899000, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 55001756, x_checked: 76866, y_checked: 2945900756, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 63654109, x_checked: 75245, y_checked: 3009554865, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1167, y_added: 0, x_checked: 76412, y_checked: 2963707886, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 608, y_added: 0, x_checked: 77020, y_checked: 2940350394, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2397, y_added: 0, x_checked: 79416, y_checked: 2851854771, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1129, y_added: 0, x_checked: 80545, y_checked: 2811950120, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 952, y_added: 0, x_checked: 81497, y_checked: 2779170777, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26762957, x_checked: 80722, y_checked: 2805933734, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24968414, x_checked: 80012, y_checked: 2830902148, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 33295791, x_checked: 79085, y_checked: 2864197939, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 637, y_added: 0, x_checked: 79722, y_checked: 2841347876, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23064978, x_checked: 79082, y_checked: 2864412854, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1212, y_added: 0, x_checked: 80294, y_checked: 2821281306, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 779, y_added: 0, x_checked: 81073, y_checked: 2794241606, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26003637, x_checked: 80328, y_checked: 2820245243, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 876, y_added: 0, x_checked: 81204, y_checked: 2789890150, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1036, y_added: 0, x_checked: 82240, y_checked: 2754812128, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27615956, x_checked: 81426, y_checked: 2782428084, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21145638, x_checked: 80814, y_checked: 2803573722, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37449736, x_checked: 79752, y_checked: 2841023458, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1648, y_added: 0, x_checked: 81400, y_checked: 2783641737, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 51679987, x_checked: 79921, y_checked: 2835321724, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 794, y_added: 0, x_checked: 80715, y_checked: 2807500001, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1751, y_added: 0, x_checked: 82466, y_checked: 2748021666, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 47531539, x_checked: 81068, y_checked: 2795553205, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1161, y_added: 0, x_checked: 82229, y_checked: 2756183048, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2996, y_added: 0, x_checked: 85224, y_checked: 2659541827, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20709897, x_checked: 84568, y_checked: 2680251724, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27803781, x_checked: 83702, y_checked: 2708055505, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27120049, x_checked: 82875, y_checked: 2735175554, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1853, y_added: 0, x_checked: 84728, y_checked: 2675483618, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22604974, x_checked: 84020, y_checked: 2698088592, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1665, y_added: 0, x_checked: 85685, y_checked: 2645783821, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45099836, x_checked: 84253, y_checked: 2690883657, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34731739, x_checked: 83183, y_checked: 2725615396, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1137, y_added: 0, x_checked: 84320, y_checked: 2688926036, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22933473, x_checked: 83609, y_checked: 2711859509, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22603427, x_checked: 82920, y_checked: 2734462936, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 952, y_added: 0, x_checked: 83872, y_checked: 2703489528, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32888364, x_checked: 82867, y_checked: 2736377892, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31182041, x_checked: 81936, y_checked: 2767559933, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1483, y_added: 0, x_checked: 83419, y_checked: 2718456779, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 775, y_added: 0, x_checked: 84194, y_checked: 2693497554, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 43491310, x_checked: 82860, y_checked: 2736988864, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1324, y_added: 0, x_checked: 84184, y_checked: 2694039003, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1306, y_added: 0, x_checked: 85490, y_checked: 2652976236, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 682, y_added: 0, x_checked: 86172, y_checked: 2632010055, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1652, y_added: 0, x_checked: 87824, y_checked: 2582618658, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46214560, x_checked: 86285, y_checked: 2628833218, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1047, y_added: 0, x_checked: 87332, y_checked: 2597376323, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1393, y_added: 0, x_checked: 88725, y_checked: 2556683450, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 738, y_added: 0, x_checked: 89463, y_checked: 2535621148, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35037827, x_checked: 88247, y_checked: 2570658975, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1565, y_added: 0, x_checked: 89812, y_checked: 2525977002, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1368, y_added: 0, x_checked: 91180, y_checked: 2488160902, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 54463327, x_checked: 89232, y_checked: 2542624229, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1175, y_added: 0, x_checked: 90407, y_checked: 2509661577, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1080, y_added: 0, x_checked: 91487, y_checked: 2480089351, x_admin_checked: 42, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 91627700, x_checked: 88236, y_checked: 2571717051, x_admin_checked: 43, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1259, y_added: 0, x_checked: 89495, y_checked: 2535623584, x_admin_checked: 43, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1356, y_added: 0, x_checked: 90851, y_checked: 2497860522, x_admin_checked: 43, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29200276, x_checked: 89804, y_checked: 2527060798, x_admin_checked: 43, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 183829386, x_checked: 83730, y_checked: 2710890184, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26715214, x_checked: 82916, y_checked: 2737605398, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 877, y_added: 0, x_checked: 83793, y_checked: 2709017546, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 734, y_added: 0, x_checked: 84527, y_checked: 2685525250, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1257, y_added: 0, x_checked: 85784, y_checked: 2646266572, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 993, y_added: 0, x_checked: 86777, y_checked: 2616045309, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32101739, x_checked: 85728, y_checked: 2648147048, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1103, y_added: 0, x_checked: 86831, y_checked: 2614568291, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 695, y_added: 0, x_checked: 87526, y_checked: 2593836953, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1041, y_added: 0, x_checked: 88567, y_checked: 2563407364, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25447587, x_checked: 87699, y_checked: 2588854951, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 743, y_added: 0, x_checked: 88442, y_checked: 2567135044, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 707, y_added: 0, x_checked: 89149, y_checked: 2546804837, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 38791755, x_checked: 87815, y_checked: 2585596592, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21905722, x_checked: 87080, y_checked: 2607502314, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30559510, x_checked: 86074, y_checked: 2638061824, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 837, y_added: 0, x_checked: 86911, y_checked: 2612715984, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1216, y_added: 0, x_checked: 88127, y_checked: 2576752745, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 47121109, x_checked: 86549, y_checked: 2623873854, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1971, y_added: 0, x_checked: 88520, y_checked: 2565595190, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 821, y_added: 0, x_checked: 89341, y_checked: 2542075535, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34122118, x_checked: 88161, y_checked: 2576197653, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25166912, x_checked: 87311, y_checked: 2601364565, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1288, y_added: 0, x_checked: 88599, y_checked: 2563634268, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31322299, x_checked: 87533, y_checked: 2594956567, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46700491, x_checked: 85990, y_checked: 2641657058, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37646886, x_checked: 84785, y_checked: 2679303944, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36006033, x_checked: 83664, y_checked: 2715309977, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 55817713, x_checked: 81984, y_checked: 2771127690, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1564, y_added: 0, x_checked: 83548, y_checked: 2719382991, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 773, y_added: 0, x_checked: 84321, y_checked: 2694517371, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 741, y_added: 0, x_checked: 85062, y_checked: 2671076043, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 843, y_added: 0, x_checked: 85905, y_checked: 2644925910, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1213, y_added: 0, x_checked: 87118, y_checked: 2608188720, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 895, y_added: 0, x_checked: 88013, y_checked: 2581724841, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1205, y_added: 0, x_checked: 89218, y_checked: 2546941080, x_admin_checked: 46, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2378, y_added: 0, x_checked: 91595, y_checked: 2481007428, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1705, y_added: 0, x_checked: 93300, y_checked: 2435772974, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1309, y_added: 0, x_checked: 94609, y_checked: 2402148051, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 39222731, x_checked: 93093, y_checked: 2441370782, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1448, y_added: 0, x_checked: 94541, y_checked: 2404054774, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 79312924, x_checked: 91530, y_checked: 2483367698, x_admin_checked: 48, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1364, y_added: 0, x_checked: 92894, y_checked: 2446982436, x_admin_checked: 48, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1345, y_added: 0, x_checked: 94239, y_checked: 2412135346, x_admin_checked: 48, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2575, y_added: 0, x_checked: 96813, y_checked: 2348148614, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25868508, x_checked: 95761, y_checked: 2374017122, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 985, y_added: 0, x_checked: 96746, y_checked: 2349895122, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25526558, x_checked: 95710, y_checked: 2375421680, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2053, y_added: 0, x_checked: 97762, y_checked: 2325681118, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 87021010, x_checked: 94245, y_checked: 2412702128, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26959965, x_checked: 93207, y_checked: 2439662093, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28502950, x_checked: 92134, y_checked: 2468165043, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 743, y_added: 0, x_checked: 92877, y_checked: 2448446511, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21637256, x_checked: 92066, y_checked: 2470083767, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 967, y_added: 0, x_checked: 93033, y_checked: 2444461869, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32707407, x_checked: 91808, y_checked: 2477169276, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 45732527, x_checked: 90149, y_checked: 2522901803, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 39523773, x_checked: 88763, y_checked: 2562425576, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 937, y_added: 0, x_checked: 89700, y_checked: 2535715194, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 717, y_added: 0, x_checked: 90417, y_checked: 2515634987, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22535489, x_checked: 89617, y_checked: 2538170476, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1429, y_added: 0, x_checked: 91046, y_checked: 2498415294, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22354642, x_checked: 90241, y_checked: 2520769936, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 55993270, x_checked: 88286, y_checked: 2576763206, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 776, y_added: 0, x_checked: 89062, y_checked: 2554369149, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 40657907, x_checked: 87671, y_checked: 2595027056, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27835980, x_checked: 86743, y_checked: 2622863036, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29465238, x_checked: 85782, y_checked: 2652328274, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25882174, x_checked: 84956, y_checked: 2678210448, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20750073, x_checked: 84305, y_checked: 2698960521, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 657, y_added: 0, x_checked: 84962, y_checked: 2678121335, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1129, y_added: 0, x_checked: 86091, y_checked: 2643061772, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1239, y_added: 0, x_checked: 87330, y_checked: 2605652674, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1350, y_added: 0, x_checked: 88680, y_checked: 2566072917, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 978, y_added: 0, x_checked: 89658, y_checked: 2538138511, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1120, y_added: 0, x_checked: 90778, y_checked: 2506878720, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1740, y_added: 0, x_checked: 92518, y_checked: 2459837824, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21052379, x_checked: 91735, y_checked: 2480890203, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19489306, x_checked: 91022, y_checked: 2500379509, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1623, y_added: 0, x_checked: 92645, y_checked: 2456682718, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 752, y_added: 0, x_checked: 93397, y_checked: 2436928460, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37698403, x_checked: 91978, y_checked: 2474626863, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23837371, x_checked: 91103, y_checked: 2498464234, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 11924, y_added: 0, x_checked: 103022, y_checked: 2210051141, x_admin_checked: 56, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2764, y_added: 0, x_checked: 105785, y_checked: 2152469216, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25818014, x_checked: 104535, y_checked: 2178287230, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23797438, x_checked: 103409, y_checked: 2202084668, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1655, y_added: 0, x_checked: 105064, y_checked: 2167479283, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21543619, x_checked: 104033, y_checked: 2189022902, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20166008, x_checked: 103086, y_checked: 2209188910, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 859, y_added: 0, x_checked: 103945, y_checked: 2190974361, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1660, y_added: 0, x_checked: 105605, y_checked: 2156616225, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22443376, x_checked: 104521, y_checked: 2179059601, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23475881, x_checked: 103410, y_checked: 2202535482, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18001178, x_checked: 102574, y_checked: 2220536660, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1453, y_added: 0, x_checked: 104027, y_checked: 2189584398, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 75713788, x_checked: 100559, y_checked: 2265298186, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 835, y_added: 0, x_checked: 101394, y_checked: 2246687316, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1417, y_added: 0, x_checked: 102811, y_checked: 2215786843, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32816581, x_checked: 101315, y_checked: 2248603424, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20791250, x_checked: 100390, y_checked: 2269394674, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19421915, x_checked: 99541, y_checked: 2288816589, x_admin_checked: 58, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2039, y_added: 0, x_checked: 101579, y_checked: 2243006007, x_admin_checked: 59, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 48778939, x_checked: 99423, y_checked: 2291784946, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18391507, x_checked: 98634, y_checked: 2310176453, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1118, y_added: 0, x_checked: 99752, y_checked: 2284330269, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 765, y_added: 0, x_checked: 100517, y_checked: 2266967578, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 65307371, x_checked: 97710, y_checked: 2332274949, x_admin_checked: 61, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 847, y_added: 0, x_checked: 98557, y_checked: 2312278274, x_admin_checked: 61, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 78583489, x_checked: 95326, y_checked: 2390861763, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1080, y_added: 0, x_checked: 96406, y_checked: 2364126888, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25733957, x_checked: 95371, y_checked: 2389860845, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 969, y_added: 0, x_checked: 96340, y_checked: 2365872436, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20906316, x_checked: 95499, y_checked: 2386778752, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1049, y_added: 0, x_checked: 96548, y_checked: 2360895160, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2030, y_added: 0, x_checked: 98577, y_checked: 2312418394, x_admin_checked: 63, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 33575891, x_checked: 97170, y_checked: 2345994285, x_admin_checked: 63, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24186949, x_checked: 96181, y_checked: 2370181234, x_admin_checked: 63, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3657, y_added: 0, x_checked: 99837, y_checked: 2283591791, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23921770, x_checked: 98805, y_checked: 2307513561, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 877, y_added: 0, x_checked: 99682, y_checked: 2287258000, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28064278, x_checked: 98477, y_checked: 2315322278, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1159, y_added: 0, x_checked: 99636, y_checked: 2288458563, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 49527151, x_checked: 97531, y_checked: 2337985714, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18192541, x_checked: 96780, y_checked: 2356178255, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1551, y_added: 0, x_checked: 98331, y_checked: 2319107992, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17911266, x_checked: 97580, y_checked: 2337019258, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 779, y_added: 0, x_checked: 98359, y_checked: 2318557289, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1733, y_added: 0, x_checked: 100092, y_checked: 2278504680, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1305, y_added: 0, x_checked: 101397, y_checked: 2249246410, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22193170, x_checked: 100409, y_checked: 2271439580, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19970432, x_checked: 99537, y_checked: 2291410012, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2087, y_added: 0, x_checked: 101623, y_checked: 2244485017, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23398229, x_checked: 100578, y_checked: 2267883246, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35019388, x_checked: 99053, y_checked: 2302902634, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21371588, x_checked: 98145, y_checked: 2324274222, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1019, y_added: 0, x_checked: 99164, y_checked: 2300436594, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2703, y_added: 0, x_checked: 101866, y_checked: 2239571314, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1461, y_added: 0, x_checked: 103327, y_checked: 2207968831, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19239714, x_checked: 102437, y_checked: 2227208545, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1246, y_added: 0, x_checked: 103683, y_checked: 2200506962, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 901, y_added: 0, x_checked: 104584, y_checked: 2181591128, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 829, y_added: 0, x_checked: 105413, y_checked: 2164475497, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21123799, x_checked: 104397, y_checked: 2185599296, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1321, y_added: 0, x_checked: 105718, y_checked: 2158350374, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1556, y_added: 0, x_checked: 107274, y_checked: 2127123006, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2737, y_added: 0, x_checked: 110010, y_checked: 2074352458, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2772, y_added: 0, x_checked: 112781, y_checked: 2023511749, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 15372355, x_checked: 111933, y_checked: 2038884104, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1546, y_added: 0, x_checked: 113479, y_checked: 2011177920, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1185, y_added: 0, x_checked: 114664, y_checked: 1990445393, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1132, y_added: 0, x_checked: 115796, y_checked: 1971021215, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 6291, y_added: 0, x_checked: 122084, y_checked: 1869747785, x_admin_checked: 72, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3833, y_added: 0, x_checked: 125916, y_checked: 1812975360, x_admin_checked: 73, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2200, y_added: 0, x_checked: 128115, y_checked: 1781926512, x_admin_checked: 74, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 41808401, x_checked: 125186, y_checked: 1823734913, x_admin_checked: 75, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1849, y_added: 0, x_checked: 127035, y_checked: 1797246962, x_admin_checked: 75, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 8807, y_added: 0, x_checked: 135838, y_checked: 1681048388, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 40768301, x_checked: 132630, y_checked: 1721816689, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19459331, x_checked: 131152, y_checked: 1741276020, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2212, y_added: 0, x_checked: 133363, y_checked: 1712471938, x_admin_checked: 81, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 87970861, x_checked: 126863, y_checked: 1800442799, x_admin_checked: 84, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 69552181, x_checked: 122157, y_checked: 1869994980, x_admin_checked: 86, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32212784, x_checked: 120094, y_checked: 1902207764, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 930, y_added: 0, x_checked: 121024, y_checked: 1887621583, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 43348244, x_checked: 118315, y_checked: 1930969827, x_admin_checked: 88, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25541633, x_checked: 116775, y_checked: 1956511460, x_admin_checked: 88, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26766462, x_checked: 115204, y_checked: 1983277922, x_admin_checked: 88, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3705, y_added: 0, x_checked: 118908, y_checked: 1921643999, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1525, y_added: 0, x_checked: 120433, y_checked: 1897358172, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3944, y_added: 0, x_checked: 124376, y_checked: 1837355361, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1989, y_added: 0, x_checked: 126365, y_checked: 1808506730, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20432697, x_checked: 124957, y_checked: 1828939427, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2204, y_added: 0, x_checked: 127160, y_checked: 1797324400, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2130, y_added: 0, x_checked: 129289, y_checked: 1767796253, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3051, y_added: 0, x_checked: 132339, y_checked: 1727145436, x_admin_checked: 93, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 14327779, x_checked: 131254, y_checked: 1741473215, x_admin_checked: 93, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1910, y_added: 0, x_checked: 133164, y_checked: 1716546451, x_admin_checked: 93, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1349, y_added: 0, x_checked: 134513, y_checked: 1699369502, x_admin_checked: 93, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 132933130, x_checked: 124778, y_checked: 1832302632, x_admin_checked: 97, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1076, y_added: 0, x_checked: 125854, y_checked: 1816666067, x_admin_checked: 97, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2484, y_added: 0, x_checked: 128337, y_checked: 1781601416, x_admin_checked: 98, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 7410, y_added: 0, x_checked: 135744, y_checked: 1684622442, x_admin_checked: 101, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2073, y_added: 0, x_checked: 137816, y_checked: 1659355123, x_admin_checked: 102, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2359, y_added: 0, x_checked: 140174, y_checked: 1631511370, x_admin_checked: 103, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30840836, x_checked: 137581, y_checked: 1662352206, x_admin_checked: 104, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 97084453, x_checked: 130009, y_checked: 1759436659, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1476, y_added: 0, x_checked: 131485, y_checked: 1739725595, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 14166635, x_checked: 130426, y_checked: 1753892230, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1772, y_added: 0, x_checked: 132198, y_checked: 1730435179, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1017, y_added: 0, x_checked: 133215, y_checked: 1717250342, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1521, y_added: 0, x_checked: 134736, y_checked: 1697902551, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1471, y_added: 0, x_checked: 136207, y_checked: 1679602641, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1995, y_added: 0, x_checked: 138202, y_checked: 1655416811, x_admin_checked: 107, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26791626, x_checked: 136007, y_checked: 1682208437, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1556, y_added: 0, x_checked: 137563, y_checked: 1663229036, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1152, y_added: 0, x_checked: 138715, y_checked: 1649440038, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 12854657, x_checked: 137646, y_checked: 1662294695, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1352, y_added: 0, x_checked: 138998, y_checked: 1646161485, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21388731, x_checked: 137220, y_checked: 1667550216, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22494875, x_checked: 135399, y_checked: 1690045091, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1993, y_added: 0, x_checked: 137392, y_checked: 1665590015, x_admin_checked: 108, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 6756, y_added: 0, x_checked: 144145, y_checked: 1587746610, x_admin_checked: 111, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4197, y_added: 0, x_checked: 148340, y_checked: 1542949742, x_admin_checked: 113, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3099, y_added: 0, x_checked: 151438, y_checked: 1511465131, x_admin_checked: 114, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 49991373, x_checked: 146602, y_checked: 1561456504, x_admin_checked: 116, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2325, y_added: 0, x_checked: 148926, y_checked: 1537151803, x_admin_checked: 117, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24236025, x_checked: 146621, y_checked: 1561387828, x_admin_checked: 118, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24453233, x_checked: 144366, y_checked: 1585841061, x_admin_checked: 119, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1211, y_added: 0, x_checked: 145577, y_checked: 1572681459, x_admin_checked: 119, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 76010147, x_checked: 138883, y_checked: 1648691606, x_admin_checked: 122, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 84876013, x_checked: 132101, y_checked: 1733567619, x_admin_checked: 125, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1144, y_added: 0, x_checked: 133245, y_checked: 1718709546, x_admin_checked: 125, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 47715116, x_checked: 129655, y_checked: 1766424662, x_admin_checked: 126, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 97618342, x_checked: 122882, y_checked: 1864043004, x_admin_checked: 129, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2726, y_added: 0, x_checked: 125607, y_checked: 1823704876, x_admin_checked: 130, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 13845257, x_checked: 124664, y_checked: 1837550133, x_admin_checked: 130, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20385618, x_checked: 123300, y_checked: 1857935751, x_admin_checked: 130, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37181934, x_checked: 120888, y_checked: 1895117685, x_admin_checked: 131, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1269, y_added: 0, x_checked: 122157, y_checked: 1875476749, x_admin_checked: 131, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 5348, y_added: 0, x_checked: 127503, y_checked: 1797024185, x_admin_checked: 133, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 58374462, x_checked: 123502, y_checked: 1855398647, x_admin_checked: 135, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46064724, x_checked: 120518, y_checked: 1901463371, x_admin_checked: 136, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4168, y_added: 0, x_checked: 124684, y_checked: 1838078209, x_admin_checked: 138, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1268, y_added: 0, x_checked: 125952, y_checked: 1819617015, x_admin_checked: 138, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2531, y_added: 0, x_checked: 128482, y_checked: 1783869379, x_admin_checked: 139, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2247, y_added: 0, x_checked: 130728, y_checked: 1753288294, x_admin_checked: 140, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 10164, y_added: 0, x_checked: 140887, y_checked: 1627163460, x_admin_checked: 145, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 14292123, x_checked: 139664, y_checked: 1641455583, x_admin_checked: 145, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2644, y_added: 0, x_checked: 142307, y_checked: 1611037537, x_admin_checked: 146, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2036, y_added: 0, x_checked: 144342, y_checked: 1588379410, x_admin_checked: 147, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19780124, x_checked: 142572, y_checked: 1608159534, x_admin_checked: 147, y_admin_checked: 0 },
            ]
        };

        test_utils_amm_simulate(admin, guy, &s);
    }

    #[test_only]
    fun test_amm_simulate_3000_impl(admin: &signer, guy: &signer) {
        let s = AmmSimulationData {
            x_init: 100000,
            y_init: 1481000000,
            fee_direction: 201,
            data: vector [
                AmmSimulationStepData { x_added: 0, y_added: 13737939, x_checked: 99084, y_checked: 1494731071, x_admin_checked: 0, y_admin_checked: 6868 },
                AmmSimulationStepData { x_added: 0, y_added: 14795134, x_checked: 98116, y_checked: 1509518808, x_admin_checked: 0, y_admin_checked: 14265 },
                AmmSimulationStepData { x_added: 882, y_added: 0, x_checked: 98998, y_checked: 1496100321, x_admin_checked: 0, y_admin_checked: 20974 },
                AmmSimulationStepData { x_added: 0, y_added: 13317206, x_checked: 98128, y_checked: 1509410869, x_admin_checked: 0, y_admin_checked: 27632 },
                AmmSimulationStepData { x_added: 1296, y_added: 0, x_checked: 99424, y_checked: 1489780527, x_admin_checked: 0, y_admin_checked: 37447 },
                AmmSimulationStepData { x_added: 2952, y_added: 0, x_checked: 102376, y_checked: 1446921814, x_admin_checked: 0, y_admin_checked: 58876 },
                AmmSimulationStepData { x_added: 0, y_added: 16703773, x_checked: 101212, y_checked: 1463617236, x_admin_checked: 0, y_admin_checked: 67227 },
                AmmSimulationStepData { x_added: 779, y_added: 0, x_checked: 101991, y_checked: 1452466714, x_admin_checked: 0, y_admin_checked: 72802 },
                AmmSimulationStepData { x_added: 0, y_added: 18229332, x_checked: 100731, y_checked: 1470686932, x_admin_checked: 0, y_admin_checked: 81916 },
                AmmSimulationStepData { x_added: 1373, y_added: 0, x_checked: 102104, y_checked: 1450953129, x_admin_checked: 0, y_admin_checked: 91782 },
                AmmSimulationStepData { x_added: 823, y_added: 0, x_checked: 102927, y_checked: 1439379338, x_admin_checked: 0, y_admin_checked: 97568 },
                AmmSimulationStepData { x_added: 0, y_added: 28881100, x_checked: 100909, y_checked: 1468245998, x_admin_checked: 0, y_admin_checked: 112008 },
                AmmSimulationStepData { x_added: 859, y_added: 0, x_checked: 101768, y_checked: 1455881488, x_admin_checked: 0, y_admin_checked: 118190 },
                AmmSimulationStepData { x_added: 0, y_added: 15744324, x_checked: 100683, y_checked: 1471617940, x_admin_checked: 0, y_admin_checked: 126062 },
                AmmSimulationStepData { x_added: 903, y_added: 0, x_checked: 101586, y_checked: 1458565415, x_admin_checked: 0, y_admin_checked: 132588 },
                AmmSimulationStepData { x_added: 0, y_added: 14613496, x_checked: 100582, y_checked: 1473171605, x_admin_checked: 0, y_admin_checked: 139894 },
                AmmSimulationStepData { x_added: 2889, y_added: 0, x_checked: 103471, y_checked: 1432136264, x_admin_checked: 0, y_admin_checked: 160411 },
                AmmSimulationStepData { x_added: 0, y_added: 15747488, x_checked: 102350, y_checked: 1447875879, x_admin_checked: 0, y_admin_checked: 168284 },
                AmmSimulationStepData { x_added: 1097, y_added: 0, x_checked: 103447, y_checked: 1432549628, x_admin_checked: 0, y_admin_checked: 175947 },
                AmmSimulationStepData { x_added: 1046, y_added: 0, x_checked: 104493, y_checked: 1418236608, x_admin_checked: 0, y_admin_checked: 183103 },
                AmmSimulationStepData { x_added: 0, y_added: 10872077, x_checked: 103701, y_checked: 1429103249, x_admin_checked: 0, y_admin_checked: 188539 },
                AmmSimulationStepData { x_added: 864, y_added: 0, x_checked: 104565, y_checked: 1417321960, x_admin_checked: 0, y_admin_checked: 194429 },
                AmmSimulationStepData { x_added: 1008, y_added: 0, x_checked: 105573, y_checked: 1403816112, x_admin_checked: 0, y_admin_checked: 201181 },
                AmmSimulationStepData { x_added: 977, y_added: 0, x_checked: 106550, y_checked: 1390970065, x_admin_checked: 0, y_admin_checked: 207604 },
                AmmSimulationStepData { x_added: 1337, y_added: 0, x_checked: 107887, y_checked: 1373770536, x_admin_checked: 0, y_admin_checked: 216203 },
                AmmSimulationStepData { x_added: 1967, y_added: 0, x_checked: 109854, y_checked: 1349233783, x_admin_checked: 0, y_admin_checked: 228471 },
                AmmSimulationStepData { x_added: 0, y_added: 11740265, x_checked: 108910, y_checked: 1360968178, x_admin_checked: 0, y_admin_checked: 234341 },
                AmmSimulationStepData { x_added: 11750, y_added: 0, x_checked: 120660, y_checked: 1228741145, x_admin_checked: 0, y_admin_checked: 300454 },
                AmmSimulationStepData { x_added: 0, y_added: 41168273, x_checked: 116761, y_checked: 1269888834, x_admin_checked: 0, y_admin_checked: 321038 },
                AmmSimulationStepData { x_added: 1043, y_added: 0, x_checked: 117804, y_checked: 1258667002, x_admin_checked: 0, y_admin_checked: 326648 },
                AmmSimulationStepData { x_added: 0, y_added: 12949046, x_checked: 116609, y_checked: 1271609574, x_admin_checked: 0, y_admin_checked: 333122 },
                AmmSimulationStepData { x_added: 1364, y_added: 0, x_checked: 117973, y_checked: 1256939229, x_admin_checked: 0, y_admin_checked: 340457 },
                AmmSimulationStepData { x_added: 942, y_added: 0, x_checked: 118915, y_checked: 1247003202, x_admin_checked: 0, y_admin_checked: 345425 },
                AmmSimulationStepData { x_added: 1916, y_added: 0, x_checked: 120831, y_checked: 1227270278, x_admin_checked: 0, y_admin_checked: 355291 },
                AmmSimulationStepData { x_added: 0, y_added: 11687143, x_checked: 119695, y_checked: 1238951578, x_admin_checked: 0, y_admin_checked: 361134 },
                AmmSimulationStepData { x_added: 1386, y_added: 0, x_checked: 121081, y_checked: 1224799792, x_admin_checked: 0, y_admin_checked: 368209 },
                AmmSimulationStepData { x_added: 0, y_added: 21642755, x_checked: 118985, y_checked: 1246431726, x_admin_checked: 0, y_admin_checked: 379030 },
                AmmSimulationStepData { x_added: 1801, y_added: 0, x_checked: 120786, y_checked: 1227887260, x_admin_checked: 0, y_admin_checked: 388302 },
                AmmSimulationStepData { x_added: 0, y_added: 14021280, x_checked: 119427, y_checked: 1241901530, x_admin_checked: 0, y_admin_checked: 395312 },
                AmmSimulationStepData { x_added: 0, y_added: 53767543, x_checked: 114486, y_checked: 1295642190, x_admin_checked: 0, y_admin_checked: 422195 },
                AmmSimulationStepData { x_added: 0, y_added: 11266700, x_checked: 113503, y_checked: 1306903257, x_admin_checked: 0, y_admin_checked: 427828 },
                AmmSimulationStepData { x_added: 0, y_added: 16516087, x_checked: 112091, y_checked: 1323411086, x_admin_checked: 0, y_admin_checked: 436086 },
                AmmSimulationStepData { x_added: 0, y_added: 15388113, x_checked: 110807, y_checked: 1338791505, x_admin_checked: 0, y_admin_checked: 443780 },
                AmmSimulationStepData { x_added: 1034, y_added: 0, x_checked: 111841, y_checked: 1326437740, x_admin_checked: 0, y_admin_checked: 449956 },
                AmmSimulationStepData { x_added: 0, y_added: 28975290, x_checked: 109458, y_checked: 1355398543, x_admin_checked: 0, y_admin_checked: 464443 },
                AmmSimulationStepData { x_added: 993, y_added: 0, x_checked: 110451, y_checked: 1343237275, x_admin_checked: 0, y_admin_checked: 470523 },
                AmmSimulationStepData { x_added: 0, y_added: 13304021, x_checked: 109372, y_checked: 1356534644, x_admin_checked: 0, y_admin_checked: 477175 },
                AmmSimulationStepData { x_added: 1254, y_added: 0, x_checked: 110626, y_checked: 1341194030, x_admin_checked: 0, y_admin_checked: 484845 },
                AmmSimulationStepData { x_added: 0, y_added: 12263574, x_checked: 109627, y_checked: 1353451473, x_admin_checked: 0, y_admin_checked: 490976 },
                AmmSimulationStepData { x_added: 858, y_added: 0, x_checked: 110485, y_checked: 1342965204, x_admin_checked: 0, y_admin_checked: 496219 },
                AmmSimulationStepData { x_added: 0, y_added: 16214528, x_checked: 109171, y_checked: 1359171625, x_admin_checked: 0, y_admin_checked: 504326 },
                AmmSimulationStepData { x_added: 0, y_added: 10990322, x_checked: 108299, y_checked: 1370156452, x_admin_checked: 0, y_admin_checked: 509821 },
                AmmSimulationStepData { x_added: 889, y_added: 0, x_checked: 109188, y_checked: 1359025641, x_admin_checked: 0, y_admin_checked: 515386 },
                AmmSimulationStepData { x_added: 0, y_added: 13981823, x_checked: 108080, y_checked: 1373000474, x_admin_checked: 0, y_admin_checked: 522376 },
                AmmSimulationStepData { x_added: 0, y_added: 28086594, x_checked: 105920, y_checked: 1401073025, x_admin_checked: 0, y_admin_checked: 536419 },
                AmmSimulationStepData { x_added: 0, y_added: 12656644, x_checked: 104975, y_checked: 1413723341, x_admin_checked: 0, y_admin_checked: 542747 },
                AmmSimulationStepData { x_added: 1069, y_added: 0, x_checked: 106044, y_checked: 1399498385, x_admin_checked: 0, y_admin_checked: 549859 },
                AmmSimulationStepData { x_added: 940, y_added: 0, x_checked: 106984, y_checked: 1387227821, x_admin_checked: 0, y_admin_checked: 555994 },
                AmmSimulationStepData { x_added: 0, y_added: 55610636, x_checked: 102873, y_checked: 1442810652, x_admin_checked: 0, y_admin_checked: 583799 },
                AmmSimulationStepData { x_added: 916, y_added: 0, x_checked: 103789, y_checked: 1430104543, x_admin_checked: 0, y_admin_checked: 590152 },
                AmmSimulationStepData { x_added: 1243, y_added: 0, x_checked: 105032, y_checked: 1413220353, x_admin_checked: 0, y_admin_checked: 598594 },
                AmmSimulationStepData { x_added: 1255, y_added: 0, x_checked: 106287, y_checked: 1396572957, x_admin_checked: 0, y_admin_checked: 606917 },
                AmmSimulationStepData { x_added: 923, y_added: 0, x_checked: 107210, y_checked: 1384575311, x_admin_checked: 0, y_admin_checked: 612915 },
                AmmSimulationStepData { x_added: 0, y_added: 13785658, x_checked: 106157, y_checked: 1398354077, x_admin_checked: 0, y_admin_checked: 619807 },
                AmmSimulationStepData { x_added: 0, y_added: 12528401, x_checked: 105218, y_checked: 1410876214, x_admin_checked: 0, y_admin_checked: 626071 },
                AmmSimulationStepData { x_added: 1224, y_added: 0, x_checked: 106442, y_checked: 1394691547, x_admin_checked: 0, y_admin_checked: 634163 },
                AmmSimulationStepData { x_added: 0, y_added: 13064427, x_checked: 105458, y_checked: 1407749442, x_admin_checked: 0, y_admin_checked: 640695 },
                AmmSimulationStepData { x_added: 1823, y_added: 0, x_checked: 107281, y_checked: 1383879496, x_admin_checked: 0, y_admin_checked: 652629 },
                AmmSimulationStepData { x_added: 908, y_added: 0, x_checked: 108189, y_checked: 1372290352, x_admin_checked: 0, y_admin_checked: 658423 },
                AmmSimulationStepData { x_added: 0, y_added: 35163608, x_checked: 105495, y_checked: 1407436379, x_admin_checked: 0, y_admin_checked: 676004 },
                AmmSimulationStepData { x_added: 1120, y_added: 0, x_checked: 106615, y_checked: 1392677261, x_admin_checked: 0, y_admin_checked: 683383 },
                AmmSimulationStepData { x_added: 1333, y_added: 0, x_checked: 107948, y_checked: 1375517960, x_admin_checked: 0, y_admin_checked: 691962 },
                AmmSimulationStepData { x_added: 1026, y_added: 0, x_checked: 108974, y_checked: 1362592343, x_admin_checked: 0, y_admin_checked: 698424 },
                AmmSimulationStepData { x_added: 0, y_added: 11900910, x_checked: 108034, y_checked: 1374487303, x_admin_checked: 0, y_admin_checked: 704374 },
                AmmSimulationStepData { x_added: 0, y_added: 36564654, x_checked: 105243, y_checked: 1411033675, x_admin_checked: 0, y_admin_checked: 722656 },
                AmmSimulationStepData { x_added: 0, y_added: 36965968, x_checked: 102565, y_checked: 1447981161, x_admin_checked: 0, y_admin_checked: 741138 },
                AmmSimulationStepData { x_added: 843, y_added: 0, x_checked: 103408, y_checked: 1436204745, x_admin_checked: 0, y_admin_checked: 747026 },
                AmmSimulationStepData { x_added: 0, y_added: 15908168, x_checked: 102279, y_checked: 1452104959, x_admin_checked: 0, y_admin_checked: 754980 },
                AmmSimulationStepData { x_added: 1435, y_added: 0, x_checked: 103714, y_checked: 1432054875, x_admin_checked: 0, y_admin_checked: 765005 },
                AmmSimulationStepData { x_added: 0, y_added: 11013771, x_checked: 102925, y_checked: 1443063140, x_admin_checked: 0, y_admin_checked: 770511 },
                AmmSimulationStepData { x_added: 0, y_added: 13056059, x_checked: 102005, y_checked: 1456112671, x_admin_checked: 0, y_admin_checked: 777039 },
                AmmSimulationStepData { x_added: 1646, y_added: 0, x_checked: 103651, y_checked: 1433044594, x_admin_checked: 0, y_admin_checked: 788573 },
                AmmSimulationStepData { x_added: 856, y_added: 0, x_checked: 104507, y_checked: 1421333958, x_admin_checked: 0, y_admin_checked: 794428 },
                AmmSimulationStepData { x_added: 1974, y_added: 0, x_checked: 106481, y_checked: 1395050039, x_admin_checked: 0, y_admin_checked: 807569 },
                AmmSimulationStepData { x_added: 2004, y_added: 0, x_checked: 108485, y_checked: 1369342950, x_admin_checked: 0, y_admin_checked: 820422 },
                AmmSimulationStepData { x_added: 1084, y_added: 0, x_checked: 109569, y_checked: 1355820365, x_admin_checked: 0, y_admin_checked: 827183 },
                AmmSimulationStepData { x_added: 0, y_added: 15893178, x_checked: 108304, y_checked: 1371705597, x_admin_checked: 0, y_admin_checked: 835129 },
                AmmSimulationStepData { x_added: 0, y_added: 11605087, x_checked: 107399, y_checked: 1383304882, x_admin_checked: 0, y_admin_checked: 840931 },
                AmmSimulationStepData { x_added: 1095, y_added: 0, x_checked: 108494, y_checked: 1369368811, x_admin_checked: 0, y_admin_checked: 847899 },
                AmmSimulationStepData { x_added: 1218, y_added: 0, x_checked: 109712, y_checked: 1354203391, x_admin_checked: 0, y_admin_checked: 855481 },
                AmmSimulationStepData { x_added: 883, y_added: 0, x_checked: 110595, y_checked: 1343415609, x_admin_checked: 0, y_admin_checked: 860874 },
                AmmSimulationStepData { x_added: 1667, y_added: 0, x_checked: 112262, y_checked: 1323514131, x_admin_checked: 0, y_admin_checked: 870824 },
                AmmSimulationStepData { x_added: 1867, y_added: 0, x_checked: 114129, y_checked: 1301908814, x_admin_checked: 0, y_admin_checked: 881626 },
                AmmSimulationStepData { x_added: 929, y_added: 0, x_checked: 115058, y_checked: 1291419405, x_admin_checked: 0, y_admin_checked: 886870 },
                AmmSimulationStepData { x_added: 0, y_added: 14214573, x_checked: 113810, y_checked: 1305626871, x_admin_checked: 0, y_admin_checked: 893977 },
                AmmSimulationStepData { x_added: 0, y_added: 11447559, x_checked: 112824, y_checked: 1317068707, x_admin_checked: 0, y_admin_checked: 899700 },
                AmmSimulationStepData { x_added: 1277, y_added: 0, x_checked: 114101, y_checked: 1302362529, x_admin_checked: 0, y_admin_checked: 907053 },
                AmmSimulationStepData { x_added: 0, y_added: 18287196, x_checked: 112526, y_checked: 1320640582, x_admin_checked: 0, y_admin_checked: 916196 },
                AmmSimulationStepData { x_added: 2685, y_added: 0, x_checked: 115211, y_checked: 1289930144, x_admin_checked: 0, y_admin_checked: 931551 },
                AmmSimulationStepData { x_added: 2604, y_added: 0, x_checked: 117815, y_checked: 1261483774, x_admin_checked: 0, y_admin_checked: 945774 },
                AmmSimulationStepData { x_added: 1013, y_added: 0, x_checked: 118828, y_checked: 1250750769, x_admin_checked: 0, y_admin_checked: 951140 },
                AmmSimulationStepData { x_added: 0, y_added: 18362486, x_checked: 117114, y_checked: 1269104074, x_admin_checked: 0, y_admin_checked: 960321 },
                AmmSimulationStepData { x_added: 0, y_added: 12308838, x_checked: 115993, y_checked: 1281406758, x_admin_checked: 0, y_admin_checked: 966475 },
                AmmSimulationStepData { x_added: 1115, y_added: 0, x_checked: 117108, y_checked: 1269228000, x_admin_checked: 0, y_admin_checked: 972564 },
                AmmSimulationStepData { x_added: 0, y_added: 10764155, x_checked: 116127, y_checked: 1279986773, x_admin_checked: 0, y_admin_checked: 977946 },
                AmmSimulationStepData { x_added: 1200, y_added: 0, x_checked: 117327, y_checked: 1266927688, x_admin_checked: 0, y_admin_checked: 984475 },
                AmmSimulationStepData { x_added: 2288, y_added: 0, x_checked: 119615, y_checked: 1242745798, x_admin_checked: 0, y_admin_checked: 996565 },
                AmmSimulationStepData { x_added: 0, y_added: 28278971, x_checked: 116962, y_checked: 1271010630, x_admin_checked: 0, y_admin_checked: 1010704 },
                AmmSimulationStepData { x_added: 0, y_added: 14820479, x_checked: 115619, y_checked: 1285823699, x_admin_checked: 0, y_admin_checked: 1018114 },
                AmmSimulationStepData { x_added: 1527, y_added: 0, x_checked: 117146, y_checked: 1269095467, x_admin_checked: 0, y_admin_checked: 1026478 },
                AmmSimulationStepData { x_added: 0, y_added: 24553093, x_checked: 114930, y_checked: 1293636284, x_admin_checked: 0, y_admin_checked: 1038754 },
                AmmSimulationStepData { x_added: 1016, y_added: 0, x_checked: 115946, y_checked: 1282322657, x_admin_checked: 0, y_admin_checked: 1044410 },
                AmmSimulationStepData { x_added: 0, y_added: 14327385, x_checked: 114669, y_checked: 1296642879, x_admin_checked: 0, y_admin_checked: 1051573 },
                AmmSimulationStepData { x_added: 0, y_added: 10847763, x_checked: 113721, y_checked: 1307485219, x_admin_checked: 0, y_admin_checked: 1056996 },
                AmmSimulationStepData { x_added: 1212, y_added: 0, x_checked: 114933, y_checked: 1293731199, x_admin_checked: 0, y_admin_checked: 1063873 },
                AmmSimulationStepData { x_added: 0, y_added: 15605206, x_checked: 113568, y_checked: 1309328603, x_admin_checked: 0, y_admin_checked: 1071675 },
                AmmSimulationStepData { x_added: 1019, y_added: 0, x_checked: 114587, y_checked: 1297707648, x_admin_checked: 0, y_admin_checked: 1077485 },
                AmmSimulationStepData { x_added: 988, y_added: 0, x_checked: 115575, y_checked: 1286636380, x_admin_checked: 0, y_admin_checked: 1083020 },
                AmmSimulationStepData { x_added: 0, y_added: 65031155, x_checked: 110031, y_checked: 1351635020, x_admin_checked: 0, y_admin_checked: 1115535 },
                AmmSimulationStepData { x_added: 1269, y_added: 0, x_checked: 111300, y_checked: 1336260213, x_admin_checked: 0, y_admin_checked: 1123222 },
                AmmSimulationStepData { x_added: 0, y_added: 33320275, x_checked: 108601, y_checked: 1369563828, x_admin_checked: 0, y_admin_checked: 1139882 },
                AmmSimulationStepData { x_added: 0, y_added: 12887660, x_checked: 107592, y_checked: 1382445045, x_admin_checked: 0, y_admin_checked: 1146325 },
                AmmSimulationStepData { x_added: 856, y_added: 0, x_checked: 108448, y_checked: 1371558447, x_admin_checked: 0, y_admin_checked: 1151768 },
                AmmSimulationStepData { x_added: 1002, y_added: 0, x_checked: 109450, y_checked: 1359026849, x_admin_checked: 0, y_admin_checked: 1158033 },
                AmmSimulationStepData { x_added: 0, y_added: 11614727, x_checked: 108526, y_checked: 1370635769, x_admin_checked: 0, y_admin_checked: 1163840 },
                AmmSimulationStepData { x_added: 0, y_added: 15748981, x_checked: 107297, y_checked: 1386376876, x_admin_checked: 0, y_admin_checked: 1171714 },
                AmmSimulationStepData { x_added: 1412, y_added: 0, x_checked: 108709, y_checked: 1368407261, x_admin_checked: 0, y_admin_checked: 1180698 },
                AmmSimulationStepData { x_added: 1528, y_added: 0, x_checked: 110237, y_checked: 1349476432, x_admin_checked: 0, y_admin_checked: 1190163 },
                AmmSimulationStepData { x_added: 1074, y_added: 0, x_checked: 111311, y_checked: 1336479831, x_admin_checked: 0, y_admin_checked: 1196661 },
                AmmSimulationStepData { x_added: 0, y_added: 13425703, x_checked: 110208, y_checked: 1349898822, x_admin_checked: 0, y_admin_checked: 1203373 },
                AmmSimulationStepData { x_added: 1184, y_added: 0, x_checked: 111392, y_checked: 1335586543, x_admin_checked: 0, y_admin_checked: 1210529 },
                AmmSimulationStepData { x_added: 0, y_added: 14246524, x_checked: 110220, y_checked: 1349825944, x_admin_checked: 0, y_admin_checked: 1217652 },
                AmmSimulationStepData { x_added: 0, y_added: 26306818, x_checked: 108120, y_checked: 1376119609, x_admin_checked: 0, y_admin_checked: 1230805 },
                AmmSimulationStepData { x_added: 1056, y_added: 0, x_checked: 109176, y_checked: 1362834120, x_admin_checked: 0, y_admin_checked: 1237447 },
                AmmSimulationStepData { x_added: 0, y_added: 14997228, x_checked: 107992, y_checked: 1377823850, x_admin_checked: 0, y_admin_checked: 1244945 },
                AmmSimulationStepData { x_added: 1057, y_added: 0, x_checked: 109049, y_checked: 1364493780, x_admin_checked: 0, y_admin_checked: 1251610 },
                AmmSimulationStepData { x_added: 988, y_added: 0, x_checked: 110037, y_checked: 1352266845, x_admin_checked: 0, y_admin_checked: 1257723 },
                AmmSimulationStepData { x_added: 920, y_added: 0, x_checked: 110957, y_checked: 1341078697, x_admin_checked: 0, y_admin_checked: 1263317 },
                AmmSimulationStepData { x_added: 910, y_added: 0, x_checked: 111867, y_checked: 1330193260, x_admin_checked: 0, y_admin_checked: 1268759 },
                AmmSimulationStepData { x_added: 0, y_added: 20705760, x_checked: 110158, y_checked: 1350888668, x_admin_checked: 0, y_admin_checked: 1279111 },
                AmmSimulationStepData { x_added: 0, y_added: 29502826, x_checked: 107811, y_checked: 1380376743, x_admin_checked: 0, y_admin_checked: 1293862 },
                AmmSimulationStepData { x_added: 0, y_added: 18481968, x_checked: 106391, y_checked: 1398849471, x_admin_checked: 0, y_admin_checked: 1303102 },
                AmmSimulationStepData { x_added: 1144, y_added: 0, x_checked: 107535, y_checked: 1383993696, x_admin_checked: 0, y_admin_checked: 1310529 },
                AmmSimulationStepData { x_added: 1008, y_added: 0, x_checked: 108543, y_checked: 1371166307, x_admin_checked: 0, y_admin_checked: 1316942 },
                AmmSimulationStepData { x_added: 0, y_added: 14414645, x_checked: 107418, y_checked: 1385573745, x_admin_checked: 0, y_admin_checked: 1324149 },
                AmmSimulationStepData { x_added: 0, y_added: 26658395, x_checked: 105397, y_checked: 1412218811, x_admin_checked: 0, y_admin_checked: 1337478 },
                AmmSimulationStepData { x_added: 1313, y_added: 0, x_checked: 106710, y_checked: 1394881555, x_admin_checked: 0, y_admin_checked: 1346146 },
                AmmSimulationStepData { x_added: 876, y_added: 0, x_checked: 107586, y_checked: 1383549699, x_admin_checked: 0, y_admin_checked: 1351811 },
                AmmSimulationStepData { x_added: 0, y_added: 22199811, x_checked: 105893, y_checked: 1405738411, x_admin_checked: 0, y_admin_checked: 1362910 },
                AmmSimulationStepData { x_added: 811, y_added: 0, x_checked: 106704, y_checked: 1395080295, x_admin_checked: 0, y_admin_checked: 1368239 },
                AmmSimulationStepData { x_added: 0, y_added: 18975850, x_checked: 105277, y_checked: 1414046658, x_admin_checked: 0, y_admin_checked: 1377726 },
                AmmSimulationStepData { x_added: 0, y_added: 13175514, x_checked: 104309, y_checked: 1427215585, x_admin_checked: 0, y_admin_checked: 1384313 },
                AmmSimulationStepData { x_added: 0, y_added: 21384452, x_checked: 102774, y_checked: 1448589345, x_admin_checked: 0, y_admin_checked: 1395005 },
                AmmSimulationStepData { x_added: 0, y_added: 11701574, x_checked: 101953, y_checked: 1460285069, x_admin_checked: 0, y_admin_checked: 1400855 },
                AmmSimulationStepData { x_added: 0, y_added: 11318469, x_checked: 101172, y_checked: 1471597879, x_admin_checked: 0, y_admin_checked: 1406514 },
                AmmSimulationStepData { x_added: 0, y_added: 11236479, x_checked: 100408, y_checked: 1482828740, x_admin_checked: 0, y_admin_checked: 1412132 },
                AmmSimulationStepData { x_added: 2174, y_added: 0, x_checked: 102582, y_checked: 1451474192, x_admin_checked: 0, y_admin_checked: 1427809 },
                AmmSimulationStepData { x_added: 0, y_added: 12524820, x_checked: 101708, y_checked: 1463992750, x_admin_checked: 0, y_admin_checked: 1434071 },
                AmmSimulationStepData { x_added: 0, y_added: 31997193, x_checked: 99540, y_checked: 1495973945, x_admin_checked: 0, y_admin_checked: 1450069 },
                AmmSimulationStepData { x_added: 1008, y_added: 0, x_checked: 100548, y_checked: 1481006172, x_admin_checked: 0, y_admin_checked: 1457552 },
                AmmSimulationStepData { x_added: 843, y_added: 0, x_checked: 101391, y_checked: 1468721544, x_admin_checked: 0, y_admin_checked: 1463694 },
                AmmSimulationStepData { x_added: 0, y_added: 40387118, x_checked: 98686, y_checked: 1509088469, x_admin_checked: 0, y_admin_checked: 1483887 },
                AmmSimulationStepData { x_added: 812, y_added: 0, x_checked: 99498, y_checked: 1496802934, x_admin_checked: 0, y_admin_checked: 1490029 },
                AmmSimulationStepData { x_added: 0, y_added: 12828769, x_checked: 98656, y_checked: 1509625289, x_admin_checked: 0, y_admin_checked: 1496443 },
                AmmSimulationStepData { x_added: 0, y_added: 12289570, x_checked: 97862, y_checked: 1521908715, x_admin_checked: 0, y_admin_checked: 1502587 },
                AmmSimulationStepData { x_added: 844, y_added: 0, x_checked: 98706, y_checked: 1508925988, x_admin_checked: 0, y_admin_checked: 1509078 },
                AmmSimulationStepData { x_added: 0, y_added: 12530946, x_checked: 97896, y_checked: 1521450669, x_admin_checked: 0, y_admin_checked: 1515343 },
                AmmSimulationStepData { x_added: 983, y_added: 0, x_checked: 98879, y_checked: 1506355722, x_admin_checked: 0, y_admin_checked: 1522890 },
                AmmSimulationStepData { x_added: 0, y_added: 15179935, x_checked: 97896, y_checked: 1521528068, x_admin_checked: 0, y_admin_checked: 1530479 },
                AmmSimulationStepData { x_added: 0, y_added: 15015439, x_checked: 96943, y_checked: 1536536000, x_admin_checked: 0, y_admin_checked: 1537986 },
                AmmSimulationStepData { x_added: 1064, y_added: 0, x_checked: 98007, y_checked: 1519885817, x_admin_checked: 0, y_admin_checked: 1546311 },
                AmmSimulationStepData { x_added: 946, y_added: 0, x_checked: 98953, y_checked: 1505385992, x_admin_checked: 0, y_admin_checked: 1553560 },
                AmmSimulationStepData { x_added: 0, y_added: 14610562, x_checked: 98005, y_checked: 1519989249, x_admin_checked: 0, y_admin_checked: 1560865 },
                AmmSimulationStepData { x_added: 1462, y_added: 0, x_checked: 99467, y_checked: 1497693099, x_admin_checked: 0, y_admin_checked: 1572013 },
                AmmSimulationStepData { x_added: 0, y_added: 13189217, x_checked: 98602, y_checked: 1510875722, x_admin_checked: 0, y_admin_checked: 1578607 },
                AmmSimulationStepData { x_added: 1905, y_added: 0, x_checked: 100507, y_checked: 1482297722, x_admin_checked: 0, y_admin_checked: 1592896 },
                AmmSimulationStepData { x_added: 0, y_added: 15283661, x_checked: 99485, y_checked: 1497573742, x_admin_checked: 0, y_admin_checked: 1600537 },
                AmmSimulationStepData { x_added: 0, y_added: 16339817, x_checked: 98415, y_checked: 1513905390, x_admin_checked: 0, y_admin_checked: 1608706 },
                AmmSimulationStepData { x_added: 0, y_added: 25102016, x_checked: 96815, y_checked: 1538994855, x_admin_checked: 0, y_admin_checked: 1621257 },
                AmmSimulationStepData { x_added: 912, y_added: 0, x_checked: 97727, y_checked: 1524663975, x_admin_checked: 0, y_admin_checked: 1628422 },
                AmmSimulationStepData { x_added: 1594, y_added: 0, x_checked: 99321, y_checked: 1500255106, x_admin_checked: 0, y_admin_checked: 1640626 },
                AmmSimulationStepData { x_added: 0, y_added: 20005627, x_checked: 98018, y_checked: 1520250731, x_admin_checked: 0, y_admin_checked: 1650628 },
                AmmSimulationStepData { x_added: 0, y_added: 12523466, x_checked: 97220, y_checked: 1532767936, x_admin_checked: 0, y_admin_checked: 1656889 },
                AmmSimulationStepData { x_added: 0, y_added: 14276518, x_checked: 96326, y_checked: 1547037316, x_admin_checked: 0, y_admin_checked: 1664027 },
                AmmSimulationStepData { x_added: 776, y_added: 0, x_checked: 97102, y_checked: 1534705629, x_admin_checked: 0, y_admin_checked: 1670192 },
                AmmSimulationStepData { x_added: 0, y_added: 17669358, x_checked: 96001, y_checked: 1552366153, x_admin_checked: 0, y_admin_checked: 1679026 },
                AmmSimulationStepData { x_added: 760, y_added: 0, x_checked: 96761, y_checked: 1540189160, x_admin_checked: 0, y_admin_checked: 1685114 },
                AmmSimulationStepData { x_added: 0, y_added: 13674322, x_checked: 95913, y_checked: 1553856645, x_admin_checked: 0, y_admin_checked: 1691951 },
                AmmSimulationStepData { x_added: 0, y_added: 15283304, x_checked: 94982, y_checked: 1569132308, x_admin_checked: 0, y_admin_checked: 1699592 },
                AmmSimulationStepData { x_added: 0, y_added: 14103411, x_checked: 94139, y_checked: 1583228668, x_admin_checked: 0, y_admin_checked: 1706643 },
                AmmSimulationStepData { x_added: 736, y_added: 0, x_checked: 94875, y_checked: 1570963210, x_admin_checked: 0, y_admin_checked: 1712775 },
                AmmSimulationStepData { x_added: 811, y_added: 0, x_checked: 95686, y_checked: 1557680852, x_admin_checked: 0, y_admin_checked: 1719416 },
                AmmSimulationStepData { x_added: 927, y_added: 0, x_checked: 96613, y_checked: 1542766870, x_admin_checked: 0, y_admin_checked: 1726872 },
                AmmSimulationStepData { x_added: 752, y_added: 0, x_checked: 97365, y_checked: 1530867011, x_admin_checked: 0, y_admin_checked: 1732821 },
                AmmSimulationStepData { x_added: 0, y_added: 12121495, x_checked: 96603, y_checked: 1542982446, x_admin_checked: 0, y_admin_checked: 1738881 },
                AmmSimulationStepData { x_added: 819, y_added: 0, x_checked: 97422, y_checked: 1530042427, x_admin_checked: 0, y_admin_checked: 1745351 },
                AmmSimulationStepData { x_added: 782, y_added: 0, x_checked: 98204, y_checked: 1517889589, x_admin_checked: 0, y_admin_checked: 1751427 },
                AmmSimulationStepData { x_added: 0, y_added: 24253519, x_checked: 96665, y_checked: 1542130982, x_admin_checked: 0, y_admin_checked: 1763553 },
                AmmSimulationStepData { x_added: 780, y_added: 0, x_checked: 97445, y_checked: 1529818370, x_admin_checked: 0, y_admin_checked: 1769709 },
                AmmSimulationStepData { x_added: 820, y_added: 0, x_checked: 98265, y_checked: 1517083247, x_admin_checked: 0, y_admin_checked: 1776076 },
                AmmSimulationStepData { x_added: 0, y_added: 13288985, x_checked: 97415, y_checked: 1530365588, x_admin_checked: 0, y_admin_checked: 1782720 },
                AmmSimulationStepData { x_added: 0, y_added: 45457651, x_checked: 94614, y_checked: 1575800511, x_admin_checked: 0, y_admin_checked: 1805448 },
                AmmSimulationStepData { x_added: 0, y_added: 13090069, x_checked: 93837, y_checked: 1588884035, x_admin_checked: 0, y_admin_checked: 1811993 },
                AmmSimulationStepData { x_added: 0, y_added: 15227022, x_checked: 92949, y_checked: 1604103444, x_admin_checked: 0, y_admin_checked: 1819606 },
                AmmSimulationStepData { x_added: 889, y_added: 0, x_checked: 93838, y_checked: 1588940397, x_admin_checked: 0, y_admin_checked: 1827187 },
                AmmSimulationStepData { x_added: 1069, y_added: 0, x_checked: 94907, y_checked: 1571076224, x_admin_checked: 0, y_admin_checked: 1836119 },
                AmmSimulationStepData { x_added: 0, y_added: 15480744, x_checked: 93984, y_checked: 1586549228, x_admin_checked: 0, y_admin_checked: 1843859 },
                AmmSimulationStepData { x_added: 0, y_added: 12092756, x_checked: 93276, y_checked: 1598635938, x_admin_checked: 0, y_admin_checked: 1849905 },
                AmmSimulationStepData { x_added: 0, y_added: 13659884, x_checked: 92489, y_checked: 1612288993, x_admin_checked: 0, y_admin_checked: 1856734 },
                AmmSimulationStepData { x_added: 777, y_added: 0, x_checked: 93266, y_checked: 1598891284, x_admin_checked: 0, y_admin_checked: 1863432 },
                AmmSimulationStepData { x_added: 0, y_added: 18848703, x_checked: 92183, y_checked: 1617730563, x_admin_checked: 0, y_admin_checked: 1872856 },
                AmmSimulationStepData { x_added: 0, y_added: 25819347, x_checked: 90740, y_checked: 1643537001, x_admin_checked: 0, y_admin_checked: 1885765 },
                AmmSimulationStepData { x_added: 1765, y_added: 0, x_checked: 92505, y_checked: 1612247949, x_admin_checked: 0, y_admin_checked: 1901409 },
                AmmSimulationStepData { x_added: 0, y_added: 17607179, x_checked: 91509, y_checked: 1629846325, x_admin_checked: 0, y_admin_checked: 1910212 },
                AmmSimulationStepData { x_added: 0, y_added: 15552992, x_checked: 90647, y_checked: 1645391541, x_admin_checked: 0, y_admin_checked: 1917988 },
                AmmSimulationStepData { x_added: 0, y_added: 27257935, x_checked: 89175, y_checked: 1672635848, x_admin_checked: 0, y_admin_checked: 1931616 },
                AmmSimulationStepData { x_added: 774, y_added: 0, x_checked: 89949, y_checked: 1658279896, x_admin_checked: 0, y_admin_checked: 1938793 },
                AmmSimulationStepData { x_added: 781, y_added: 0, x_checked: 90730, y_checked: 1644041734, x_admin_checked: 0, y_admin_checked: 1945912 },
                AmmSimulationStepData { x_added: 0, y_added: 16197762, x_checked: 89848, y_checked: 1660231398, x_admin_checked: 0, y_admin_checked: 1954010 },
                AmmSimulationStepData { x_added: 0, y_added: 19938576, x_checked: 88786, y_checked: 1680160005, x_admin_checked: 0, y_admin_checked: 1963979 },
                AmmSimulationStepData { x_added: 813, y_added: 0, x_checked: 89599, y_checked: 1664951798, x_admin_checked: 0, y_admin_checked: 1971583 },
                AmmSimulationStepData { x_added: 1300, y_added: 0, x_checked: 90899, y_checked: 1641194510, x_admin_checked: 0, y_admin_checked: 1983461 },
                AmmSimulationStepData { x_added: 0, y_added: 13474549, x_checked: 90162, y_checked: 1654662322, x_admin_checked: 0, y_admin_checked: 1990198 },
                AmmSimulationStepData { x_added: 0, y_added: 17415611, x_checked: 89226, y_checked: 1672069226, x_admin_checked: 0, y_admin_checked: 1998905 },
                AmmSimulationStepData { x_added: 1328, y_added: 0, x_checked: 90554, y_checked: 1647602443, x_admin_checked: 0, y_admin_checked: 2011138 },
                AmmSimulationStepData { x_added: 1654, y_added: 0, x_checked: 92208, y_checked: 1618118429, x_admin_checked: 0, y_admin_checked: 2025880 },
                AmmSimulationStepData { x_added: 0, y_added: 22580879, x_checked: 90943, y_checked: 1640688018, x_admin_checked: 0, y_admin_checked: 2037170 },
                AmmSimulationStepData { x_added: 0, y_added: 14440245, x_checked: 90153, y_checked: 1655121043, x_admin_checked: 0, y_admin_checked: 2044390 },
                AmmSimulationStepData { x_added: 0, y_added: 54912150, x_checked: 87267, y_checked: 1710005737, x_admin_checked: 0, y_admin_checked: 2071846 },
                AmmSimulationStepData { x_added: 0, y_added: 22538903, x_checked: 86136, y_checked: 1732533371, x_admin_checked: 0, y_admin_checked: 2083115 },
                AmmSimulationStepData { x_added: 921, y_added: 0, x_checked: 87057, y_checked: 1714243806, x_admin_checked: 0, y_admin_checked: 2092259 },
                AmmSimulationStepData { x_added: 897, y_added: 0, x_checked: 87954, y_checked: 1696799653, x_admin_checked: 0, y_admin_checked: 2100981 },
                AmmSimulationStepData { x_added: 0, y_added: 15127770, x_checked: 87180, y_checked: 1711919860, x_admin_checked: 0, y_admin_checked: 2108544 },
                AmmSimulationStepData { x_added: 803, y_added: 0, x_checked: 87983, y_checked: 1696334134, x_admin_checked: 0, y_admin_checked: 2116336 },
                AmmSimulationStepData { x_added: 0, y_added: 13022197, x_checked: 87315, y_checked: 1709349820, x_admin_checked: 0, y_admin_checked: 2122847 },
                AmmSimulationStepData { x_added: 0, y_added: 15437620, x_checked: 86536, y_checked: 1724779722, x_admin_checked: 0, y_admin_checked: 2130565 },
                AmmSimulationStepData { x_added: 1038, y_added: 0, x_checked: 87574, y_checked: 1704375121, x_admin_checked: 0, y_admin_checked: 2140767 },
                AmmSimulationStepData { x_added: 709, y_added: 0, x_checked: 88283, y_checked: 1690706451, x_admin_checked: 0, y_admin_checked: 2147601 },
                AmmSimulationStepData { x_added: 0, y_added: 14904635, x_checked: 87514, y_checked: 1705603634, x_admin_checked: 0, y_admin_checked: 2155053 },
                AmmSimulationStepData { x_added: 906, y_added: 0, x_checked: 88420, y_checked: 1688165266, x_admin_checked: 0, y_admin_checked: 2163772 },
                AmmSimulationStepData { x_added: 2923, y_added: 0, x_checked: 91343, y_checked: 1634268775, x_admin_checked: 0, y_admin_checked: 2190720 },
                AmmSimulationStepData { x_added: 0, y_added: 15406822, x_checked: 90493, y_checked: 1649667894, x_admin_checked: 0, y_admin_checked: 2198423 },
                AmmSimulationStepData { x_added: 1318, y_added: 0, x_checked: 91811, y_checked: 1626039090, x_admin_checked: 0, y_admin_checked: 2210237 },
                AmmSimulationStepData { x_added: 0, y_added: 15187574, x_checked: 90965, y_checked: 1641219071, x_admin_checked: 0, y_admin_checked: 2217830 },
                AmmSimulationStepData { x_added: 0, y_added: 16810281, x_checked: 90046, y_checked: 1658020947, x_admin_checked: 0, y_admin_checked: 2226235 },
                AmmSimulationStepData { x_added: 0, y_added: 15930894, x_checked: 89192, y_checked: 1673943876, x_admin_checked: 0, y_admin_checked: 2234200 },
                AmmSimulationStepData { x_added: 0, y_added: 13832586, x_checked: 88464, y_checked: 1687769546, x_admin_checked: 0, y_admin_checked: 2241116 },
                AmmSimulationStepData { x_added: 0, y_added: 13014872, x_checked: 87790, y_checked: 1700777911, x_admin_checked: 0, y_admin_checked: 2247623 },
                AmmSimulationStepData { x_added: 0, y_added: 14830760, x_checked: 87034, y_checked: 1715601256, x_admin_checked: 0, y_admin_checked: 2255038 },
                AmmSimulationStepData { x_added: 0, y_added: 13154994, x_checked: 86374, y_checked: 1728749673, x_admin_checked: 0, y_admin_checked: 2261615 },
                AmmSimulationStepData { x_added: 708, y_added: 0, x_checked: 87082, y_checked: 1714714166, x_admin_checked: 0, y_admin_checked: 2268632 },
                AmmSimulationStepData { x_added: 0, y_added: 17046941, x_checked: 86228, y_checked: 1731752584, x_admin_checked: 0, y_admin_checked: 2277155 },
                AmmSimulationStepData { x_added: 3371, y_added: 0, x_checked: 89599, y_checked: 1666747350, x_admin_checked: 0, y_admin_checked: 2309657 },
                AmmSimulationStepData { x_added: 0, y_added: 13149731, x_checked: 88900, y_checked: 1679890507, x_admin_checked: 0, y_admin_checked: 2316231 },
                AmmSimulationStepData { x_added: 0, y_added: 20727492, x_checked: 87820, y_checked: 1700607636, x_admin_checked: 0, y_admin_checked: 2326594 },
                AmmSimulationStepData { x_added: 683, y_added: 0, x_checked: 88503, y_checked: 1687502685, x_admin_checked: 0, y_admin_checked: 2333146 },
                AmmSimulationStepData { x_added: 0, y_added: 14398794, x_checked: 87757, y_checked: 1701894280, x_admin_checked: 0, y_admin_checked: 2340345 },
                AmmSimulationStepData { x_added: 0, y_added: 16522416, x_checked: 86916, y_checked: 1718408435, x_admin_checked: 0, y_admin_checked: 2348606 },
                AmmSimulationStepData { x_added: 1081, y_added: 0, x_checked: 87997, y_checked: 1697337208, x_admin_checked: 0, y_admin_checked: 2359141 },
                AmmSimulationStepData { x_added: 0, y_added: 14974287, x_checked: 87230, y_checked: 1712304008, x_admin_checked: 0, y_admin_checked: 2366628 },
                AmmSimulationStepData { x_added: 0, y_added: 13007755, x_checked: 86575, y_checked: 1725305260, x_admin_checked: 0, y_admin_checked: 2373131 },
                AmmSimulationStepData { x_added: 0, y_added: 16041871, x_checked: 85780, y_checked: 1741339111, x_admin_checked: 0, y_admin_checked: 2381151 },
                AmmSimulationStepData { x_added: 1281, y_added: 0, x_checked: 87061, y_checked: 1715776482, x_admin_checked: 0, y_admin_checked: 2393932 },
                AmmSimulationStepData { x_added: 0, y_added: 13206232, x_checked: 86399, y_checked: 1728976111, x_admin_checked: 0, y_admin_checked: 2400535 },
                AmmSimulationStepData { x_added: 0, y_added: 114701151, x_checked: 81040, y_checked: 1843619912, x_admin_checked: 0, y_admin_checked: 2457885 },
                AmmSimulationStepData { x_added: 629, y_added: 0, x_checked: 81669, y_checked: 1829443083, x_admin_checked: 0, y_admin_checked: 2464973 },
                AmmSimulationStepData { x_added: 930, y_added: 0, x_checked: 82599, y_checked: 1808888788, x_admin_checked: 0, y_admin_checked: 2475250 },
                AmmSimulationStepData { x_added: 748, y_added: 0, x_checked: 83347, y_checked: 1792676374, x_admin_checked: 0, y_admin_checked: 2483356 },
                AmmSimulationStepData { x_added: 0, y_added: 14918760, x_checked: 82662, y_checked: 1807587675, x_admin_checked: 0, y_admin_checked: 2490815 },
                AmmSimulationStepData { x_added: 662, y_added: 0, x_checked: 83324, y_checked: 1793248112, x_admin_checked: 0, y_admin_checked: 2497984 },
                AmmSimulationStepData { x_added: 0, y_added: 18845002, x_checked: 82461, y_checked: 1812083692, x_admin_checked: 0, y_admin_checked: 2507406 },
                AmmSimulationStepData { x_added: 0, y_added: 16091249, x_checked: 81738, y_checked: 1828166896, x_admin_checked: 0, y_admin_checked: 2515451 },
                AmmSimulationStepData { x_added: 0, y_added: 16991429, x_checked: 80988, y_checked: 1845149830, x_admin_checked: 0, y_admin_checked: 2523946 },
                AmmSimulationStepData { x_added: 1512, y_added: 0, x_checked: 82500, y_checked: 1811399135, x_admin_checked: 0, y_admin_checked: 2540821 },
                AmmSimulationStepData { x_added: 865, y_added: 0, x_checked: 83365, y_checked: 1792646962, x_admin_checked: 0, y_admin_checked: 2550197 },
                AmmSimulationStepData { x_added: 0, y_added: 14962744, x_checked: 82678, y_checked: 1807602225, x_admin_checked: 0, y_admin_checked: 2557678 },
                AmmSimulationStepData { x_added: 649, y_added: 0, x_checked: 83327, y_checked: 1793545074, x_admin_checked: 0, y_admin_checked: 2564706 },
                AmmSimulationStepData { x_added: 0, y_added: 17411037, x_checked: 82529, y_checked: 1810947406, x_admin_checked: 0, y_admin_checked: 2573411 },
                AmmSimulationStepData { x_added: 0, y_added: 14377941, x_checked: 81881, y_checked: 1825318159, x_admin_checked: 0, y_admin_checked: 2580599 },
                AmmSimulationStepData { x_added: 720, y_added: 0, x_checked: 82601, y_checked: 1809429494, x_admin_checked: 0, y_admin_checked: 2588543 },
                AmmSimulationStepData { x_added: 0, y_added: 13793087, x_checked: 81979, y_checked: 1823215685, x_admin_checked: 0, y_admin_checked: 2595439 },
                AmmSimulationStepData { x_added: 684, y_added: 0, x_checked: 82663, y_checked: 1808151251, x_admin_checked: 0, y_admin_checked: 2602971 },
                AmmSimulationStepData { x_added: 0, y_added: 18670838, x_checked: 81821, y_checked: 1826812754, x_admin_checked: 0, y_admin_checked: 2612306 },
                AmmSimulationStepData { x_added: 649, y_added: 0, x_checked: 82470, y_checked: 1812458577, x_admin_checked: 0, y_admin_checked: 2619483 },
                AmmSimulationStepData { x_added: 0, y_added: 17231208, x_checked: 81696, y_checked: 1829681170, x_admin_checked: 0, y_admin_checked: 2628098 },
                AmmSimulationStepData { x_added: 0, y_added: 14391976, x_checked: 81061, y_checked: 1844065951, x_admin_checked: 0, y_admin_checked: 2635293 },
                AmmSimulationStepData { x_added: 0, y_added: 17408945, x_checked: 80306, y_checked: 1861466192, x_admin_checked: 0, y_admin_checked: 2643997 },
                AmmSimulationStepData { x_added: 0, y_added: 29910483, x_checked: 79040, y_checked: 1891361720, x_admin_checked: 0, y_admin_checked: 2658952 },
                AmmSimulationStepData { x_added: 0, y_added: 23720015, x_checked: 78065, y_checked: 1915069875, x_admin_checked: 0, y_admin_checked: 2670812 },
                AmmSimulationStepData { x_added: 615, y_added: 0, x_checked: 78680, y_checked: 1900124936, x_admin_checked: 0, y_admin_checked: 2678284 },
                AmmSimulationStepData { x_added: 0, y_added: 15654519, x_checked: 78040, y_checked: 1915771628, x_admin_checked: 0, y_admin_checked: 2686111 },
                AmmSimulationStepData { x_added: 0, y_added: 20178380, x_checked: 77230, y_checked: 1935939919, x_admin_checked: 0, y_admin_checked: 2696200 },
                AmmSimulationStepData { x_added: 0, y_added: 14707685, x_checked: 76650, y_checked: 1950640251, x_admin_checked: 0, y_admin_checked: 2703553 },
                AmmSimulationStepData { x_added: 0, y_added: 18980442, x_checked: 75914, y_checked: 1969611203, x_admin_checked: 0, y_admin_checked: 2713043 },
                AmmSimulationStepData { x_added: 0, y_added: 15315754, x_checked: 75331, y_checked: 1984919300, x_admin_checked: 0, y_admin_checked: 2720700 },
                AmmSimulationStepData { x_added: 638, y_added: 0, x_checked: 75969, y_checked: 1968275535, x_admin_checked: 0, y_admin_checked: 2729021 },
                AmmSimulationStepData { x_added: 674, y_added: 0, x_checked: 76643, y_checked: 1950991939, x_admin_checked: 0, y_admin_checked: 2737662 },
                AmmSimulationStepData { x_added: 601, y_added: 0, x_checked: 77244, y_checked: 1935837231, x_admin_checked: 0, y_admin_checked: 2745239 },
                AmmSimulationStepData { x_added: 612, y_added: 0, x_checked: 77856, y_checked: 1920644931, x_admin_checked: 0, y_admin_checked: 2752835 },
                AmmSimulationStepData { x_added: 0, y_added: 28497565, x_checked: 76722, y_checked: 1949128248, x_admin_checked: 0, y_admin_checked: 2767083 },
                AmmSimulationStepData { x_added: 0, y_added: 16432062, x_checked: 76083, y_checked: 1965552094, x_admin_checked: 0, y_admin_checked: 2775299 },
                AmmSimulationStepData { x_added: 0, y_added: 14924894, x_checked: 75512, y_checked: 1980469526, x_admin_checked: 0, y_admin_checked: 2782761 },
                AmmSimulationStepData { x_added: 977, y_added: 0, x_checked: 76489, y_checked: 1955223958, x_admin_checked: 0, y_admin_checked: 2795383 },
                AmmSimulationStepData { x_added: 0, y_added: 37817173, x_checked: 75043, y_checked: 1993022223, x_admin_checked: 0, y_admin_checked: 2814291 },
                AmmSimulationStepData { x_added: 0, y_added: 15780954, x_checked: 74456, y_checked: 2008795287, x_admin_checked: 0, y_admin_checked: 2822181 },
                AmmSimulationStepData { x_added: 0, y_added: 15830463, x_checked: 73876, y_checked: 2024617835, x_admin_checked: 0, y_admin_checked: 2830096 },
                AmmSimulationStepData { x_added: 0, y_added: 15777695, x_checked: 73307, y_checked: 2040387642, x_admin_checked: 0, y_admin_checked: 2837984 },
                AmmSimulationStepData { x_added: 0, y_added: 22993584, x_checked: 72493, y_checked: 2063369730, x_admin_checked: 0, y_admin_checked: 2849480 },
                AmmSimulationStepData { x_added: 0, y_added: 17168231, x_checked: 71897, y_checked: 2080529377, x_admin_checked: 0, y_admin_checked: 2858064 },
                AmmSimulationStepData { x_added: 0, y_added: 54536684, x_checked: 70067, y_checked: 2135038793, x_admin_checked: 0, y_admin_checked: 2885332 },
                AmmSimulationStepData { x_added: 651, y_added: 0, x_checked: 70718, y_checked: 2115414443, x_admin_checked: 0, y_admin_checked: 2895144 },
                AmmSimulationStepData { x_added: 0, y_added: 17967443, x_checked: 70125, y_checked: 2133372903, x_admin_checked: 0, y_admin_checked: 2904127 },
                AmmSimulationStepData { x_added: 656, y_added: 0, x_checked: 70781, y_checked: 2113630614, x_admin_checked: 0, y_admin_checked: 2913998 },
                AmmSimulationStepData { x_added: 542, y_added: 0, x_checked: 71323, y_checked: 2097598056, x_admin_checked: 0, y_admin_checked: 2922014 },
                AmmSimulationStepData { x_added: 0, y_added: 16616167, x_checked: 70765, y_checked: 2114205915, x_admin_checked: 0, y_admin_checked: 2930322 },
                AmmSimulationStepData { x_added: 0, y_added: 19482727, x_checked: 70121, y_checked: 2133678901, x_admin_checked: 0, y_admin_checked: 2940063 },
                AmmSimulationStepData { x_added: 0, y_added: 16771287, x_checked: 69576, y_checked: 2150441803, x_admin_checked: 0, y_admin_checked: 2948448 },
                AmmSimulationStepData { x_added: 0, y_added: 19978292, x_checked: 68938, y_checked: 2170410106, x_admin_checked: 0, y_admin_checked: 2958437 },
                AmmSimulationStepData { x_added: 0, y_added: 17216683, x_checked: 68398, y_checked: 2187618181, x_admin_checked: 0, y_admin_checked: 2967045 },
                AmmSimulationStepData { x_added: 0, y_added: 27236074, x_checked: 67560, y_checked: 2214840637, x_admin_checked: 0, y_admin_checked: 2980663 },
                AmmSimulationStepData { x_added: 0, y_added: 21928864, x_checked: 66900, y_checked: 2236758537, x_admin_checked: 0, y_admin_checked: 2991627 },
                AmmSimulationStepData { x_added: 683, y_added: 0, x_checked: 67583, y_checked: 2214186413, x_admin_checked: 0, y_admin_checked: 3002913 },
                AmmSimulationStepData { x_added: 0, y_added: 18714933, x_checked: 67019, y_checked: 2232891989, x_admin_checked: 0, y_admin_checked: 3012270 },
                AmmSimulationStepData { x_added: 518, y_added: 0, x_checked: 67537, y_checked: 2215798807, x_admin_checked: 0, y_admin_checked: 3020816 },
                AmmSimulationStepData { x_added: 0, y_added: 17158360, x_checked: 67020, y_checked: 2232948588, x_admin_checked: 0, y_admin_checked: 3029395 },
                AmmSimulationStepData { x_added: 547, y_added: 0, x_checked: 67567, y_checked: 2214904159, x_admin_checked: 0, y_admin_checked: 3038417 },
                AmmSimulationStepData { x_added: 0, y_added: 25923386, x_checked: 66788, y_checked: 2240814584, x_admin_checked: 0, y_admin_checked: 3051378 },
                AmmSimulationStepData { x_added: 684, y_added: 0, x_checked: 67472, y_checked: 2218131115, x_admin_checked: 0, y_admin_checked: 3062719 },
                AmmSimulationStepData { x_added: 0, y_added: 17642901, x_checked: 66942, y_checked: 2235765195, x_admin_checked: 0, y_admin_checked: 3071540 },
                AmmSimulationStepData { x_added: 0, y_added: 19344313, x_checked: 66370, y_checked: 2255099836, x_admin_checked: 0, y_admin_checked: 3081212 },
                AmmSimulationStepData { x_added: 0, y_added: 17799903, x_checked: 65852, y_checked: 2272890840, x_admin_checked: 0, y_admin_checked: 3090111 },
                AmmSimulationStepData { x_added: 0, y_added: 19448071, x_checked: 65296, y_checked: 2292329187, x_admin_checked: 0, y_admin_checked: 3099835 },
                AmmSimulationStepData { x_added: 0, y_added: 18172739, x_checked: 64785, y_checked: 2310492840, x_admin_checked: 0, y_admin_checked: 3108921 },
                AmmSimulationStepData { x_added: 0, y_added: 19795214, x_checked: 64237, y_checked: 2330278157, x_admin_checked: 0, y_admin_checked: 3118818 },
                AmmSimulationStepData { x_added: 0, y_added: 17686555, x_checked: 63755, y_checked: 2347955869, x_admin_checked: 0, y_admin_checked: 3127661 },
                AmmSimulationStepData { x_added: 0, y_added: 25061448, x_checked: 63084, y_checked: 2373004787, x_admin_checked: 0, y_admin_checked: 3140191 },
                AmmSimulationStepData { x_added: 0, y_added: 18576097, x_checked: 62596, y_checked: 2391571596, x_admin_checked: 0, y_admin_checked: 3149479 },
                AmmSimulationStepData { x_added: 0, y_added: 19966136, x_checked: 62080, y_checked: 2411527749, x_admin_checked: 0, y_admin_checked: 3159462 },
                AmmSimulationStepData { x_added: 0, y_added: 23196722, x_checked: 61491, y_checked: 2434712873, x_admin_checked: 0, y_admin_checked: 3171060 },
                AmmSimulationStepData { x_added: 480, y_added: 0, x_checked: 61971, y_checked: 2415893647, x_admin_checked: 0, y_admin_checked: 3180469 },
                AmmSimulationStepData { x_added: 0, y_added: 19732434, x_checked: 61471, y_checked: 2435616215, x_admin_checked: 0, y_admin_checked: 3190335 },
                AmmSimulationStepData { x_added: 627, y_added: 0, x_checked: 62098, y_checked: 2411062763, x_admin_checked: 0, y_admin_checked: 3202611 },
                AmmSimulationStepData { x_added: 475, y_added: 0, x_checked: 62573, y_checked: 2392798304, x_admin_checked: 0, y_admin_checked: 3211743 },
                AmmSimulationStepData { x_added: 0, y_added: 19909927, x_checked: 62059, y_checked: 2412698277, x_admin_checked: 0, y_admin_checked: 3221697 },
                AmmSimulationStepData { x_added: 475, y_added: 0, x_checked: 62534, y_checked: 2394410030, x_admin_checked: 0, y_admin_checked: 3230841 },
                AmmSimulationStepData { x_added: 0, y_added: 18485738, x_checked: 62057, y_checked: 2412886526, x_admin_checked: 0, y_admin_checked: 3240083 },
                AmmSimulationStepData { x_added: 0, y_added: 18905976, x_checked: 61577, y_checked: 2431783050, x_admin_checked: 0, y_admin_checked: 3249535 },
                AmmSimulationStepData { x_added: 500, y_added: 0, x_checked: 62077, y_checked: 2412235081, x_admin_checked: 0, y_admin_checked: 3259308 },
                AmmSimulationStepData { x_added: 673, y_added: 0, x_checked: 62750, y_checked: 2386401650, x_admin_checked: 0, y_admin_checked: 3272224 },
                AmmSimulationStepData { x_added: 0, y_added: 20194891, x_checked: 62226, y_checked: 2406586444, x_admin_checked: 0, y_admin_checked: 3282321 },
                AmmSimulationStepData { x_added: 477, y_added: 0, x_checked: 62703, y_checked: 2388316929, x_admin_checked: 0, y_admin_checked: 3291455 },
                AmmSimulationStepData { x_added: 0, y_added: 18720552, x_checked: 62217, y_checked: 2407028121, x_admin_checked: 0, y_admin_checked: 3300815 },
                AmmSimulationStepData { x_added: 0, y_added: 22955587, x_checked: 61632, y_checked: 2429972231, x_admin_checked: 0, y_admin_checked: 3312292 },
                AmmSimulationStepData { x_added: 559, y_added: 0, x_checked: 62191, y_checked: 2408169297, x_admin_checked: 0, y_admin_checked: 3323193 },
                AmmSimulationStepData { x_added: 613, y_added: 0, x_checked: 62804, y_checked: 2384702272, x_admin_checked: 0, y_admin_checked: 3334926 },
                AmmSimulationStepData { x_added: 0, y_added: 21134637, x_checked: 62254, y_checked: 2405826342, x_admin_checked: 0, y_admin_checked: 3345493 },
                AmmSimulationStepData { x_added: 690, y_added: 0, x_checked: 62944, y_checked: 2379491177, x_admin_checked: 0, y_admin_checked: 3358660 },
                AmmSimulationStepData { x_added: 0, y_added: 18431371, x_checked: 62462, y_checked: 2397913333, x_admin_checked: 0, y_admin_checked: 3367875 },
                AmmSimulationStepData { x_added: 0, y_added: 18960039, x_checked: 61974, y_checked: 2416863892, x_admin_checked: 0, y_admin_checked: 3377355 },
                AmmSimulationStepData { x_added: 665, y_added: 0, x_checked: 62639, y_checked: 2391243700, x_admin_checked: 0, y_admin_checked: 3390165 },
                AmmSimulationStepData { x_added: 0, y_added: 26041054, x_checked: 61967, y_checked: 2417271734, x_admin_checked: 0, y_admin_checked: 3403185 },
                AmmSimulationStepData { x_added: 0, y_added: 19771052, x_checked: 61466, y_checked: 2437032901, x_admin_checked: 0, y_admin_checked: 3413070 },
                AmmSimulationStepData { x_added: 487, y_added: 0, x_checked: 61953, y_checked: 2417914907, x_admin_checked: 0, y_admin_checked: 3422628 },
                AmmSimulationStepData { x_added: 0, y_added: 20898369, x_checked: 61424, y_checked: 2438802827, x_admin_checked: 0, y_admin_checked: 3433077 },
                AmmSimulationStepData { x_added: 758, y_added: 0, x_checked: 62182, y_checked: 2409112508, x_admin_checked: 0, y_admin_checked: 3447922 },
                AmmSimulationStepData { x_added: 0, y_added: 18837777, x_checked: 61702, y_checked: 2427940867, x_admin_checked: 0, y_admin_checked: 3457340 },
                AmmSimulationStepData { x_added: 713, y_added: 0, x_checked: 62415, y_checked: 2400243654, x_admin_checked: 0, y_admin_checked: 3471188 },
                AmmSimulationStepData { x_added: 0, y_added: 21263711, x_checked: 61869, y_checked: 2421496734, x_admin_checked: 0, y_admin_checked: 3481819 },
                AmmSimulationStepData { x_added: 886, y_added: 0, x_checked: 62755, y_checked: 2387385168, x_admin_checked: 0, y_admin_checked: 3498874 },
                AmmSimulationStepData { x_added: 560, y_added: 0, x_checked: 63315, y_checked: 2366306919, x_admin_checked: 0, y_admin_checked: 3509413 },
                AmmSimulationStepData { x_added: 664, y_added: 0, x_checked: 63979, y_checked: 2341785029, x_admin_checked: 0, y_admin_checked: 3521673 },
                AmmSimulationStepData { x_added: 554, y_added: 0, x_checked: 64533, y_checked: 2321717356, x_admin_checked: 0, y_admin_checked: 3531706 },
                AmmSimulationStepData { x_added: 0, y_added: 18005176, x_checked: 64038, y_checked: 2339713530, x_admin_checked: 0, y_admin_checked: 3540708 },
                AmmSimulationStepData { x_added: 0, y_added: 60476635, x_checked: 62430, y_checked: 2400159927, x_admin_checked: 0, y_admin_checked: 3570946 },
                AmmSimulationStepData { x_added: 0, y_added: 21688272, x_checked: 61873, y_checked: 2421837355, x_admin_checked: 0, y_admin_checked: 3581790 },
                AmmSimulationStepData { x_added: 606, y_added: 0, x_checked: 62479, y_checked: 2398385715, x_admin_checked: 0, y_admin_checked: 3593515 },
                AmmSimulationStepData { x_added: 0, y_added: 18806465, x_checked: 61995, y_checked: 2417182777, x_admin_checked: 0, y_admin_checked: 3602918 },
                AmmSimulationStepData { x_added: 0, y_added: 19103865, x_checked: 61511, y_checked: 2436277091, x_admin_checked: 0, y_admin_checked: 3612469 },
                AmmSimulationStepData { x_added: 525, y_added: 0, x_checked: 62036, y_checked: 2415698238, x_admin_checked: 0, y_admin_checked: 3622758 },
                AmmSimulationStepData { x_added: 505, y_added: 0, x_checked: 62541, y_checked: 2396230507, x_admin_checked: 0, y_admin_checked: 3632491 },
                AmmSimulationStepData { x_added: 0, y_added: 18929352, x_checked: 62053, y_checked: 2415150395, x_admin_checked: 0, y_admin_checked: 3641955 },
                AmmSimulationStepData { x_added: 0, y_added: 18630598, x_checked: 61580, y_checked: 2433771678, x_admin_checked: 0, y_admin_checked: 3651270 },
                AmmSimulationStepData { x_added: 493, y_added: 0, x_checked: 62073, y_checked: 2414480925, x_admin_checked: 0, y_admin_checked: 3660915 },
                AmmSimulationStepData { x_added: 0, y_added: 19414913, x_checked: 61580, y_checked: 2433886131, x_admin_checked: 0, y_admin_checked: 3670622 },
                AmmSimulationStepData { x_added: 476, y_added: 0, x_checked: 62056, y_checked: 2415255950, x_admin_checked: 0, y_admin_checked: 3679937 },
                AmmSimulationStepData { x_added: 503, y_added: 0, x_checked: 62559, y_checked: 2395874601, x_admin_checked: 0, y_admin_checked: 3689627 },
                AmmSimulationStepData { x_added: 890, y_added: 0, x_checked: 63449, y_checked: 2362342100, x_admin_checked: 0, y_admin_checked: 3706393 },
                AmmSimulationStepData { x_added: 0, y_added: 39355129, x_checked: 62413, y_checked: 2401677552, x_admin_checked: 0, y_admin_checked: 3726070 },
                AmmSimulationStepData { x_added: 476, y_added: 0, x_checked: 62889, y_checked: 2383537417, x_admin_checked: 0, y_admin_checked: 3735140 },
                AmmSimulationStepData { x_added: 503, y_added: 0, x_checked: 63392, y_checked: 2364661934, x_admin_checked: 0, y_admin_checked: 3744577 },
                AmmSimulationStepData { x_added: 0, y_added: 27038882, x_checked: 62678, y_checked: 2391687297, x_admin_checked: 0, y_admin_checked: 3758096 },
                AmmSimulationStepData { x_added: 578, y_added: 0, x_checked: 63256, y_checked: 2369870784, x_admin_checked: 0, y_admin_checked: 3769004 },
                AmmSimulationStepData { x_added: 535, y_added: 0, x_checked: 63791, y_checked: 2350032079, x_admin_checked: 0, y_admin_checked: 3778923 },
                AmmSimulationStepData { x_added: 528, y_added: 0, x_checked: 64319, y_checked: 2330776709, x_admin_checked: 0, y_admin_checked: 3788550 },
                AmmSimulationStepData { x_added: 497, y_added: 0, x_checked: 64816, y_checked: 2312940325, x_admin_checked: 0, y_admin_checked: 3797468 },
                AmmSimulationStepData { x_added: 553, y_added: 0, x_checked: 65369, y_checked: 2293408704, x_admin_checked: 0, y_admin_checked: 3807233 },
                AmmSimulationStepData { x_added: 517, y_added: 0, x_checked: 65886, y_checked: 2275447122, x_admin_checked: 0, y_admin_checked: 3816213 },
                AmmSimulationStepData { x_added: 4034, y_added: 0, x_checked: 69920, y_checked: 2144473024, x_admin_checked: 0, y_admin_checked: 3881700 },
                AmmSimulationStepData { x_added: 663, y_added: 0, x_checked: 70583, y_checked: 2124359665, x_admin_checked: 0, y_admin_checked: 3891756 },
                AmmSimulationStepData { x_added: 711, y_added: 0, x_checked: 71294, y_checked: 2103203376, x_admin_checked: 0, y_admin_checked: 3902334 },
                AmmSimulationStepData { x_added: 1017, y_added: 0, x_checked: 72311, y_checked: 2073680752, x_admin_checked: 0, y_admin_checked: 3917095 },
                AmmSimulationStepData { x_added: 557, y_added: 0, x_checked: 72868, y_checked: 2057857863, x_admin_checked: 0, y_admin_checked: 3925006 },
                AmmSimulationStepData { x_added: 0, y_added: 16593574, x_checked: 72287, y_checked: 2074443141, x_admin_checked: 0, y_admin_checked: 3933302 },
                AmmSimulationStepData { x_added: 621, y_added: 0, x_checked: 72908, y_checked: 2056802109, x_admin_checked: 0, y_admin_checked: 3942122 },
                AmmSimulationStepData { x_added: 0, y_added: 25116021, x_checked: 72032, y_checked: 2081905572, x_admin_checked: 0, y_admin_checked: 3954680 },
                AmmSimulationStepData { x_added: 0, y_added: 17932710, x_checked: 71419, y_checked: 2099829316, x_admin_checked: 0, y_admin_checked: 3963646 },
                AmmSimulationStepData { x_added: 550, y_added: 0, x_checked: 71969, y_checked: 2083810999, x_admin_checked: 0, y_admin_checked: 3971655 },
                AmmSimulationStepData { x_added: 0, y_added: 17358108, x_checked: 71377, y_checked: 2101160428, x_admin_checked: 0, y_admin_checked: 3980334 },
                AmmSimulationStepData { x_added: 0, y_added: 16996968, x_checked: 70807, y_checked: 2118148898, x_admin_checked: 0, y_admin_checked: 3988832 },
                AmmSimulationStepData { x_added: 677, y_added: 0, x_checked: 71484, y_checked: 2098118001, x_admin_checked: 0, y_admin_checked: 3998847 },
                AmmSimulationStepData { x_added: 546, y_added: 0, x_checked: 72030, y_checked: 2082242808, x_admin_checked: 0, y_admin_checked: 4006784 },
                AmmSimulationStepData { x_added: 668, y_added: 0, x_checked: 72698, y_checked: 2063138087, x_admin_checked: 0, y_admin_checked: 4016336 },
                AmmSimulationStepData { x_added: 4075, y_added: 0, x_checked: 76773, y_checked: 1953884198, x_admin_checked: 0, y_admin_checked: 4070962 },
                AmmSimulationStepData { x_added: 694, y_added: 0, x_checked: 77467, y_checked: 1936405024, x_admin_checked: 0, y_admin_checked: 4079701 },
                AmmSimulationStepData { x_added: 928, y_added: 0, x_checked: 78395, y_checked: 1913531668, x_admin_checked: 0, y_admin_checked: 4091137 },
                AmmSimulationStepData { x_added: 840, y_added: 0, x_checked: 79235, y_checked: 1893293390, x_admin_checked: 0, y_admin_checked: 4101256 },
                AmmSimulationStepData { x_added: 802, y_added: 0, x_checked: 80037, y_checked: 1874368736, x_admin_checked: 0, y_admin_checked: 4110718 },
                AmmSimulationStepData { x_added: 0, y_added: 23515058, x_checked: 79049, y_checked: 1897872037, x_admin_checked: 0, y_admin_checked: 4122475 },
                AmmSimulationStepData { x_added: 1709, y_added: 0, x_checked: 80758, y_checked: 1857801306, x_admin_checked: 0, y_admin_checked: 4142510 },
                AmmSimulationStepData { x_added: 0, y_added: 16308417, x_checked: 80058, y_checked: 1874101569, x_admin_checked: 0, y_admin_checked: 4150664 },
                AmmSimulationStepData { x_added: 739, y_added: 0, x_checked: 80797, y_checked: 1856983309, x_admin_checked: 0, y_admin_checked: 4159223 },
                AmmSimulationStepData { x_added: 1139, y_added: 0, x_checked: 81936, y_checked: 1831213909, x_admin_checked: 0, y_admin_checked: 4172107 },
                AmmSimulationStepData { x_added: 636, y_added: 0, x_checked: 82572, y_checked: 1817131231, x_admin_checked: 0, y_admin_checked: 4179148 },
                AmmSimulationStepData { x_added: 651, y_added: 0, x_checked: 83223, y_checked: 1802938647, x_admin_checked: 0, y_admin_checked: 4186244 },
                AmmSimulationStepData { x_added: 0, y_added: 14359091, x_checked: 82568, y_checked: 1817290559, x_admin_checked: 0, y_admin_checked: 4193423 },
                AmmSimulationStepData { x_added: 0, y_added: 13880241, x_checked: 81945, y_checked: 1831163860, x_admin_checked: 0, y_admin_checked: 4200363 },
                AmmSimulationStepData { x_added: 0, y_added: 14348526, x_checked: 81310, y_checked: 1845505212, x_admin_checked: 0, y_admin_checked: 4207537 },
                AmmSimulationStepData { x_added: 0, y_added: 18342236, x_checked: 80513, y_checked: 1863838277, x_admin_checked: 0, y_admin_checked: 4216708 },
                AmmSimulationStepData { x_added: 0, y_added: 17947516, x_checked: 79748, y_checked: 1881776820, x_admin_checked: 0, y_admin_checked: 4225681 },
                AmmSimulationStepData { x_added: 0, y_added: 17143703, x_checked: 79031, y_checked: 1898911952, x_admin_checked: 0, y_admin_checked: 4234252 },
                AmmSimulationStepData { x_added: 0, y_added: 16364631, x_checked: 78358, y_checked: 1915268401, x_admin_checked: 0, y_admin_checked: 4242434 },
                AmmSimulationStepData { x_added: 0, y_added: 27914280, x_checked: 77236, y_checked: 1943168724, x_admin_checked: 0, y_admin_checked: 4256391 },
                AmmSimulationStepData { x_added: 869, y_added: 0, x_checked: 78105, y_checked: 1921598141, x_admin_checked: 0, y_admin_checked: 4267176 },
                AmmSimulationStepData { x_added: 0, y_added: 14891590, x_checked: 77507, y_checked: 1936482286, x_admin_checked: 0, y_admin_checked: 4274621 },
            ]
        };

        test_utils_amm_simulate(admin, guy, &s);
    }

    #[test_only]
    fun test_amm_simulate_5000_impl(admin: &signer, guy: &signer) {
        let s = AmmSimulationData {
            x_init: 100000,
            y_init: 3948200000,
            fee_direction: 200,
            data: vector [
                AmmSimulationStepData { x_added: 946, y_added: 0, x_checked: 100946, y_checked: 3911277541, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 833, y_added: 0, x_checked: 101779, y_checked: 3879342314, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29531685, x_checked: 101013, y_checked: 3908873999, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 802, y_added: 0, x_checked: 101815, y_checked: 3878159855, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 829, y_added: 0, x_checked: 102644, y_checked: 3846913015, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 44613277, x_checked: 101471, y_checked: 3891526292, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1128, y_added: 0, x_checked: 102599, y_checked: 3848816870, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34086643, x_checked: 101701, y_checked: 3882903513, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 855, y_added: 0, x_checked: 102556, y_checked: 3850607195, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1087, y_added: 0, x_checked: 103643, y_checked: 3810295844, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 908, y_added: 0, x_checked: 104551, y_checked: 3777276609, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 858, y_added: 0, x_checked: 105409, y_checked: 3746601713, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 850, y_added: 0, x_checked: 106259, y_checked: 3716701394, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30400599, x_checked: 105400, y_checked: 3747101993, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46104878, x_checked: 104123, y_checked: 3793206871, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 837, y_added: 0, x_checked: 104960, y_checked: 3763029775, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 886, y_added: 0, x_checked: 105846, y_checked: 3731601274, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 53797935, x_checked: 104346, y_checked: 3785399209, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30121751, x_checked: 103525, y_checked: 3815520960, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 854, y_added: 0, x_checked: 104379, y_checked: 3784375939, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 856, y_added: 0, x_checked: 105235, y_checked: 3753664499, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 979, y_added: 0, x_checked: 106214, y_checked: 3719136101, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28403423, x_checked: 105412, y_checked: 3747539524, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 831, y_added: 0, x_checked: 106243, y_checked: 3718297421, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 877, y_added: 0, x_checked: 107120, y_checked: 3687924279, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 832, y_added: 0, x_checked: 107952, y_checked: 3659568771, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1225, y_added: 0, x_checked: 109177, y_checked: 3618606701, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 915, y_added: 0, x_checked: 110092, y_checked: 3588596819, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 879, y_added: 0, x_checked: 110971, y_checked: 3560235751, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 892, y_added: 0, x_checked: 111863, y_checked: 3531909437, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28834353, x_checked: 110960, y_checked: 3560743790, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 971, y_added: 0, x_checked: 111931, y_checked: 3529917457, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31121437, x_checked: 110956, y_checked: 3561038894, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 887, y_added: 0, x_checked: 111843, y_checked: 3532860325, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 904, y_added: 0, x_checked: 112747, y_checked: 3504596190, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 908, y_added: 0, x_checked: 113655, y_checked: 3476658836, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28835057, x_checked: 112723, y_checked: 3505493893, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 965, y_added: 0, x_checked: 113688, y_checked: 3475799906, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29316878, x_checked: 112740, y_checked: 3505116784, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1146, y_added: 0, x_checked: 113886, y_checked: 3469906802, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 991, y_added: 0, x_checked: 114877, y_checked: 3440033133, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 988, y_added: 0, x_checked: 115865, y_checked: 3410758277, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 912, y_added: 0, x_checked: 116777, y_checked: 3384179044, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1406, y_added: 0, x_checked: 118183, y_checked: 3344003015, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1049, y_added: 0, x_checked: 119232, y_checked: 3314638165, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1058, y_added: 0, x_checked: 120290, y_checked: 3285539187, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1002, y_added: 0, x_checked: 121292, y_checked: 3258450893, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1676, y_added: 0, x_checked: 122968, y_checked: 3214144187, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1158, y_added: 0, x_checked: 124126, y_checked: 3184235657, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26053128, x_checked: 123122, y_checked: 3210288785, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 971, y_added: 0, x_checked: 124093, y_checked: 3185220329, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1029, y_added: 0, x_checked: 125122, y_checked: 3159075658, x_admin_checked: 0, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2666, y_added: 0, x_checked: 127787, y_checked: 3093338325, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1087, y_added: 0, x_checked: 128874, y_checked: 3067294871, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27273874, x_checked: 127742, y_checked: 3094568745, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1387, y_added: 0, x_checked: 129129, y_checked: 3061400498, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1025, y_added: 0, x_checked: 130154, y_checked: 3037337766, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25043077, x_checked: 129093, y_checked: 3062380843, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1236, y_added: 0, x_checked: 130329, y_checked: 3033407994, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1071, y_added: 0, x_checked: 131400, y_checked: 3008729437, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27826379, x_checked: 130199, y_checked: 3036555816, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26539035, x_checked: 129074, y_checked: 3063094851, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 996, y_added: 0, x_checked: 130070, y_checked: 3039686202, x_admin_checked: 1, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2253, y_added: 0, x_checked: 132322, y_checked: 2988066419, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1254, y_added: 0, x_checked: 133576, y_checked: 2960081190, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1194, y_added: 0, x_checked: 134770, y_checked: 2933921547, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1070, y_added: 0, x_checked: 135840, y_checked: 2910854157, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24103706, x_checked: 134728, y_checked: 2934957863, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22770193, x_checked: 133694, y_checked: 2957728056, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1029, y_added: 0, x_checked: 134723, y_checked: 2935180817, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1082, y_added: 0, x_checked: 135805, y_checked: 2911838216, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23845544, x_checked: 134705, y_checked: 2935683760, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1226, y_added: 0, x_checked: 135931, y_checked: 2909270209, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1241, y_added: 0, x_checked: 137172, y_checked: 2883012990, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1086, y_added: 0, x_checked: 138258, y_checked: 2860408647, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34387509, x_checked: 136620, y_checked: 2894796156, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1587, y_added: 0, x_checked: 138207, y_checked: 2861638683, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1843, y_added: 0, x_checked: 140050, y_checked: 2824061362, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1225, y_added: 0, x_checked: 141275, y_checked: 2799633288, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1129, y_added: 0, x_checked: 142404, y_checked: 2777476390, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1319, y_added: 0, x_checked: 143723, y_checked: 2752043890, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1608, y_added: 0, x_checked: 145331, y_checked: 2721669092, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22351746, x_checked: 144151, y_checked: 2744020838, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1108, y_added: 0, x_checked: 145259, y_checked: 2723127614, x_admin_checked: 2, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2380, y_added: 0, x_checked: 147638, y_checked: 2679356739, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1251, y_added: 0, x_checked: 148889, y_checked: 2656897696, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1237, y_added: 0, x_checked: 150126, y_checked: 2635058193, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1211, y_added: 0, x_checked: 151337, y_checked: 2614024253, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1174, y_added: 0, x_checked: 152511, y_checked: 2593953028, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23482465, x_checked: 151147, y_checked: 2617435493, x_admin_checked: 3, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2318, y_added: 0, x_checked: 153464, y_checked: 2578018237, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1261, y_added: 0, x_checked: 154725, y_checked: 2557057114, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21813426, x_checked: 153420, y_checked: 2578870540, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1257, y_added: 0, x_checked: 154677, y_checked: 2557962672, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1690, y_added: 0, x_checked: 156367, y_checked: 2530381179, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20524926, x_checked: 155113, y_checked: 2550906105, x_admin_checked: 4, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 5968, y_added: 0, x_checked: 161079, y_checked: 2456655111, x_admin_checked: 6, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1262, y_added: 0, x_checked: 162341, y_checked: 2437602710, x_admin_checked: 6, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20220120, x_checked: 161009, y_checked: 2457822830, x_admin_checked: 6, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2050, y_added: 0, x_checked: 163058, y_checked: 2427012052, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28034018, x_checked: 161201, y_checked: 2455046070, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1537, y_added: 0, x_checked: 162738, y_checked: 2431903903, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1494, y_added: 0, x_checked: 164232, y_checked: 2409825168, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1738, y_added: 0, x_checked: 165970, y_checked: 2384647501, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21986252, x_checked: 164458, y_checked: 2406633753, x_admin_checked: 7, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2944, y_added: 0, x_checked: 167401, y_checked: 2364422702, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1548, y_added: 0, x_checked: 168949, y_checked: 2342814080, x_admin_checked: 8, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2721, y_added: 0, x_checked: 171669, y_checked: 2305787513, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19279873, x_checked: 170250, y_checked: 2325067386, x_admin_checked: 9, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2146, y_added: 0, x_checked: 172395, y_checked: 2296204667, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22257848, x_checked: 170745, y_checked: 2318462515, x_admin_checked: 10, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4315, y_added: 0, x_checked: 175058, y_checked: 2261483386, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21741745, x_checked: 173396, y_checked: 2283225131, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20017519, x_checked: 171893, y_checked: 2303242650, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1503, y_added: 0, x_checked: 173396, y_checked: 2283317602, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1674, y_added: 0, x_checked: 175070, y_checked: 2261536443, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17715176, x_checked: 173713, y_checked: 2279251619, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19175851, x_checked: 172268, y_checked: 2298427470, x_admin_checked: 12, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27126694, x_checked: 170264, y_checked: 2325554164, x_admin_checked: 13, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32388336, x_checked: 167932, y_checked: 2357942500, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1310, y_added: 0, x_checked: 169242, y_checked: 2339732568, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17803754, x_checked: 167968, y_checked: 2357536322, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1466, y_added: 0, x_checked: 169434, y_checked: 2337179507, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20484915, x_checked: 167966, y_checked: 2357664422, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1405, y_added: 0, x_checked: 169371, y_checked: 2338148070, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1905, y_added: 0, x_checked: 171276, y_checked: 2312196254, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21011010, x_checked: 169738, y_checked: 2333207264, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1499, y_added: 0, x_checked: 171237, y_checked: 2312823006, x_admin_checked: 14, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36168101, x_checked: 168608, y_checked: 2348991107, x_admin_checked: 15, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 5946, y_added: 0, x_checked: 174552, y_checked: 2269196174, x_admin_checked: 17, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2056, y_added: 0, x_checked: 176607, y_checked: 2242855294, x_admin_checked: 18, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19773610, x_checked: 175068, y_checked: 2262628904, x_admin_checked: 18, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3297, y_added: 0, x_checked: 178364, y_checked: 2220917250, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17189447, x_checked: 176998, y_checked: 2238106697, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24878770, x_checked: 175058, y_checked: 2262985467, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1510, y_added: 0, x_checked: 176568, y_checked: 2243670659, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1412, y_added: 0, x_checked: 177980, y_checked: 2225908072, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1374, y_added: 0, x_checked: 179354, y_checked: 2208892723, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1815, y_added: 0, x_checked: 181169, y_checked: 2186811722, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23043746, x_checked: 179285, y_checked: 2209855468, x_admin_checked: 19, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2128, y_added: 0, x_checked: 181412, y_checked: 2184005786, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1636, y_added: 0, x_checked: 183048, y_checked: 2164533433, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21477366, x_checked: 181255, y_checked: 2186010799, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1712, y_added: 0, x_checked: 182967, y_checked: 2165603906, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20193772, x_checked: 181281, y_checked: 2185797678, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21534710, x_checked: 179517, y_checked: 2207332388, x_admin_checked: 20, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28521508, x_checked: 177233, y_checked: 2235853896, x_admin_checked: 21, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31773218, x_checked: 174757, y_checked: 2267627114, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17695305, x_checked: 173408, y_checked: 2285322419, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1509, y_added: 0, x_checked: 174917, y_checked: 2265645918, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1614, y_added: 0, x_checked: 176531, y_checked: 2244982281, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25752387, x_checked: 174535, y_checked: 2270734668, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26381638, x_checked: 172536, y_checked: 2297116306, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17708221, x_checked: 171220, y_checked: 2314824527, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24926954, x_checked: 169401, y_checked: 2339751481, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1766, y_added: 0, x_checked: 171167, y_checked: 2315665423, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17789368, x_checked: 169866, y_checked: 2333454791, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1370, y_added: 0, x_checked: 171236, y_checked: 2314826182, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20881233, x_checked: 169710, y_checked: 2335707415, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1403, y_added: 0, x_checked: 171113, y_checked: 2316596958, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23237300, x_checked: 169419, y_checked: 2339834258, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1359, y_added: 0, x_checked: 170778, y_checked: 2321255337, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1538, y_added: 0, x_checked: 172316, y_checked: 2300577113, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18283866, x_checked: 170961, y_checked: 2318860979, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17605270, x_checked: 169677, y_checked: 2336466249, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1623, y_added: 0, x_checked: 171300, y_checked: 2314383195, x_admin_checked: 22, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3260, y_added: 0, x_checked: 174559, y_checked: 2271277973, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24199675, x_checked: 172724, y_checked: 2295477648, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1725, y_added: 0, x_checked: 174449, y_checked: 2272831445, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1369, y_added: 0, x_checked: 175818, y_checked: 2255172612, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1714, y_added: 0, x_checked: 177532, y_checked: 2233450151, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18283068, x_checked: 176095, y_checked: 2251733219, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19354002, x_checked: 174599, y_checked: 2271087221, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1391, y_added: 0, x_checked: 175990, y_checked: 2253175279, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21105099, x_checked: 174362, y_checked: 2274280378, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1481, y_added: 0, x_checked: 175843, y_checked: 2255164214, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19347691, x_checked: 174352, y_checked: 2274511905, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24609024, x_checked: 172491, y_checked: 2299120929, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19665883, x_checked: 171032, y_checked: 2318786812, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20670246, x_checked: 169525, y_checked: 2339457058, x_admin_checked: 23, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2699, y_added: 0, x_checked: 172223, y_checked: 2302901344, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1354, y_added: 0, x_checked: 173577, y_checked: 2284976887, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19834577, x_checked: 172088, y_checked: 2304811464, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17730077, x_checked: 170778, y_checked: 2322541541, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1355, y_added: 0, x_checked: 172133, y_checked: 2304299073, x_admin_checked: 24, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32757424, x_checked: 169727, y_checked: 2337056497, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1652, y_added: 0, x_checked: 171379, y_checked: 2314582571, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21380433, x_checked: 169815, y_checked: 2335963004, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18765304, x_checked: 168466, y_checked: 2354728308, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1291, y_added: 0, x_checked: 169757, y_checked: 2336861925, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26998387, x_checked: 167824, y_checked: 2363860312, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1605, y_added: 0, x_checked: 169429, y_checked: 2341522757, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1628, y_added: 0, x_checked: 171057, y_checked: 2319292028, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22285913, x_checked: 169434, y_checked: 2341577941, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19905111, x_checked: 168010, y_checked: 2361483052, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1428, y_added: 0, x_checked: 169438, y_checked: 2341622260, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1728, y_added: 0, x_checked: 171166, y_checked: 2318036670, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19410647, x_checked: 169749, y_checked: 2337447317, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1560, y_added: 0, x_checked: 171309, y_checked: 2316215783, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1430, y_added: 0, x_checked: 172739, y_checked: 2297081151, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20197421, x_checked: 171238, y_checked: 2317278572, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1350, y_added: 0, x_checked: 172588, y_checked: 2299192561, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23699986, x_checked: 170832, y_checked: 2322892547, x_admin_checked: 25, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 38373184, x_checked: 168063, y_checked: 2361265731, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1676, y_added: 0, x_checked: 169739, y_checked: 2338005730, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22109225, x_checked: 168154, y_checked: 2360114955, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1503, y_added: 0, x_checked: 169657, y_checked: 2339247941, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17813271, x_checked: 168379, y_checked: 2357061212, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1467, y_added: 0, x_checked: 169846, y_checked: 2336743992, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1575, y_added: 0, x_checked: 171421, y_checked: 2315328236, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1640, y_added: 0, x_checked: 173061, y_checked: 2293440205, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1836, y_added: 0, x_checked: 174897, y_checked: 2269416474, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19371003, x_checked: 173421, y_checked: 2288787477, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23189142, x_checked: 171687, y_checked: 2311976619, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1932, y_added: 0, x_checked: 173619, y_checked: 2286315216, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1376, y_added: 0, x_checked: 174995, y_checked: 2268376620, x_admin_checked: 26, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 37715862, x_checked: 172141, y_checked: 2306092482, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1330, y_added: 0, x_checked: 173471, y_checked: 2288451276, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1678, y_added: 0, x_checked: 175149, y_checked: 2266578728, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19988883, x_checked: 173622, y_checked: 2286567611, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1357, y_added: 0, x_checked: 174979, y_checked: 2268873685, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1640, y_added: 0, x_checked: 176619, y_checked: 2247856913, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22539794, x_checked: 174871, y_checked: 2270396707, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1614, y_added: 0, x_checked: 176485, y_checked: 2249684344, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19640055, x_checked: 174962, y_checked: 2269324399, x_admin_checked: 27, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 42106490, x_checked: 171783, y_checked: 2311430889, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1996, y_added: 0, x_checked: 173779, y_checked: 2284947878, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1764, y_added: 0, x_checked: 175543, y_checked: 2262038392, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1811, y_added: 0, x_checked: 177354, y_checked: 2238990728, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21097688, x_checked: 175703, y_checked: 2260088416, x_admin_checked: 28, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2622, y_added: 0, x_checked: 178324, y_checked: 2226944644, x_admin_checked: 29, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1624, y_added: 0, x_checked: 179948, y_checked: 2206895905, x_admin_checked: 29, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1552, y_added: 0, x_checked: 181500, y_checked: 2188073040, x_admin_checked: 29, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21920856, x_checked: 179705, y_checked: 2209993896, x_admin_checked: 29, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 54923341, x_checked: 175359, y_checked: 2264917237, x_admin_checked: 31, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1402, y_added: 0, x_checked: 176761, y_checked: 2246990925, x_admin_checked: 31, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19063110, x_checked: 175278, y_checked: 2266054035, x_admin_checked: 31, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1854, y_added: 0, x_checked: 177132, y_checked: 2242386406, x_admin_checked: 31, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3826, y_added: 0, x_checked: 180957, y_checked: 2195096873, x_admin_checked: 32, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19361140, x_checked: 179379, y_checked: 2214458013, x_admin_checked: 32, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2450, y_added: 0, x_checked: 181828, y_checked: 2184704073, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1784, y_added: 0, x_checked: 183612, y_checked: 2163524314, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1554, y_added: 0, x_checked: 185166, y_checked: 2145413348, x_admin_checked: 33, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29227819, x_checked: 182684, y_checked: 2174641167, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17839329, x_checked: 181202, y_checked: 2192480496, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1801, y_added: 0, x_checked: 183003, y_checked: 2170950939, x_admin_checked: 34, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3433, y_added: 0, x_checked: 186435, y_checked: 2131078303, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18403249, x_checked: 184843, y_checked: 2149481552, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17917890, x_checked: 183319, y_checked: 2167399442, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1713, y_added: 0, x_checked: 185032, y_checked: 2147380388, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21345029, x_checked: 183216, y_checked: 2168725417, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1701, y_added: 0, x_checked: 184917, y_checked: 2148822398, x_admin_checked: 35, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3143, y_added: 0, x_checked: 188059, y_checked: 2113010787, x_admin_checked: 36, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1864, y_added: 0, x_checked: 189923, y_checked: 2092316702, x_admin_checked: 36, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1517, y_added: 0, x_checked: 191440, y_checked: 2075769392, x_admin_checked: 36, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28311774, x_checked: 188871, y_checked: 2104081166, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1708, y_added: 0, x_checked: 190579, y_checked: 2085267816, x_admin_checked: 37, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24740569, x_checked: 188351, y_checked: 2110008385, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18839579, x_checked: 186689, y_checked: 2128847964, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1610, y_added: 0, x_checked: 188299, y_checked: 2110690659, x_admin_checked: 38, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3443, y_added: 0, x_checked: 191741, y_checked: 2072887508, x_admin_checked: 39, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2443, y_added: 0, x_checked: 194183, y_checked: 2046882606, x_admin_checked: 40, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34954045, x_checked: 190932, y_checked: 2081836651, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18845359, x_checked: 189224, y_checked: 2100682010, x_admin_checked: 41, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4154, y_added: 0, x_checked: 193376, y_checked: 2055684312, x_admin_checked: 43, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 108677305, x_checked: 183691, y_checked: 2164361617, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 16749179, x_checked: 182285, y_checked: 2181110796, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1492, y_added: 0, x_checked: 183777, y_checked: 2163438689, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19264239, x_checked: 182160, y_checked: 2182702928, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1505, y_added: 0, x_checked: 183665, y_checked: 2164852639, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1640, y_added: 0, x_checked: 185305, y_checked: 2145739419, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1571, y_added: 0, x_checked: 186876, y_checked: 2127746496, x_admin_checked: 47, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2464, y_added: 0, x_checked: 189339, y_checked: 2100134442, x_admin_checked: 48, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2057, y_added: 0, x_checked: 191395, y_checked: 2077628691, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19484344, x_checked: 189622, y_checked: 2097113035, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1859, y_added: 0, x_checked: 191481, y_checked: 2076796524, x_admin_checked: 49, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24816918, x_checked: 189226, y_checked: 2101613442, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1455, y_added: 0, x_checked: 190681, y_checked: 2085609799, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20136729, x_checked: 188863, y_checked: 2105746528, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1857, y_added: 0, x_checked: 190720, y_checked: 2085287058, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19944415, x_checked: 188918, y_checked: 2105231473, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1459, y_added: 0, x_checked: 190377, y_checked: 2089130446, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1588, y_added: 0, x_checked: 191965, y_checked: 2071891619, x_admin_checked: 50, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2978, y_added: 0, x_checked: 194942, y_checked: 2040324594, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1674, y_added: 0, x_checked: 196616, y_checked: 2022994309, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19518020, x_checked: 194742, y_checked: 2042512329, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17807340, x_checked: 193064, y_checked: 2060319669, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 16792756, x_checked: 191508, y_checked: 2077112425, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 16750746, x_checked: 189980, y_checked: 2093863171, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1771, y_added: 0, x_checked: 191751, y_checked: 2074567661, x_admin_checked: 51, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22751029, x_checked: 189677, y_checked: 2097318690, x_admin_checked: 52, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3506, y_added: 0, x_checked: 193182, y_checked: 2059361905, x_admin_checked: 53, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1798, y_added: 0, x_checked: 194980, y_checked: 2040413444, x_admin_checked: 53, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2214, y_added: 0, x_checked: 197193, y_checked: 2017566046, x_admin_checked: 54, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20601112, x_checked: 195205, y_checked: 2038167158, x_admin_checked: 54, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 3235, y_added: 0, x_checked: 198439, y_checked: 2005031574, x_admin_checked: 55, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 34055426, x_checked: 195134, y_checked: 2039087000, x_admin_checked: 56, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30526356, x_checked: 192264, y_checked: 2069613356, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1694, y_added: 0, x_checked: 193958, y_checked: 2051579975, x_admin_checked: 57, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 46575012, x_checked: 189664, y_checked: 2098154987, x_admin_checked: 59, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35982858, x_checked: 186475, y_checked: 2134137845, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20262099, x_checked: 184726, y_checked: 2154399944, x_admin_checked: 60, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2037, y_added: 0, x_checked: 186762, y_checked: 2130970642, x_admin_checked: 61, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1760, y_added: 0, x_checked: 188522, y_checked: 2111121162, x_admin_checked: 61, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 33218879, x_checked: 185610, y_checked: 2144340041, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1671, y_added: 0, x_checked: 187281, y_checked: 2125252728, x_admin_checked: 62, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31772548, x_checked: 184530, y_checked: 2157025276, x_admin_checked: 63, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17386583, x_checked: 183059, y_checked: 2174411859, x_admin_checked: 63, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35019379, x_checked: 180165, y_checked: 2209431238, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21365174, x_checked: 178444, y_checked: 2230796412, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21825293, x_checked: 176720, y_checked: 2252621705, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1641, y_added: 0, x_checked: 178361, y_checked: 2231946645, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19408182, x_checked: 176828, y_checked: 2251354827, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1623, y_added: 0, x_checked: 178451, y_checked: 2230928911, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18709188, x_checked: 176971, y_checked: 2249638099, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17692554, x_checked: 175594, y_checked: 2267330653, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23817942, x_checked: 173774, y_checked: 2291148595, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18862185, x_checked: 172359, y_checked: 2310010780, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20400123, x_checked: 170855, y_checked: 2330410903, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1782, y_added: 0, x_checked: 172637, y_checked: 2306409290, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19264968, x_checked: 171211, y_checked: 2325674258, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20607304, x_checked: 169712, y_checked: 2346281562, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1586, y_added: 0, x_checked: 171298, y_checked: 2324612284, x_admin_checked: 64, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2374, y_added: 0, x_checked: 173671, y_checked: 2292928541, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1629, y_added: 0, x_checked: 175300, y_checked: 2271673014, x_admin_checked: 65, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2083, y_added: 0, x_checked: 177382, y_checked: 2245072808, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1428, y_added: 0, x_checked: 178810, y_checked: 2227180731, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23968128, x_checked: 176912, y_checked: 2251148859, x_admin_checked: 66, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25943325, x_checked: 174902, y_checked: 2277092184, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21761780, x_checked: 173251, y_checked: 2298853964, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1333, y_added: 0, x_checked: 174584, y_checked: 2281340743, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1479, y_added: 0, x_checked: 176063, y_checked: 2262215111, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19374506, x_checked: 174572, y_checked: 2281589617, x_admin_checked: 67, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2016, y_added: 0, x_checked: 176587, y_checked: 2255618708, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21472520, x_checked: 174927, y_checked: 2277091228, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1680, y_added: 0, x_checked: 176607, y_checked: 2255481149, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17992820, x_checked: 175213, y_checked: 2273473969, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1386, y_added: 0, x_checked: 176599, y_checked: 2255669407, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1807, y_added: 0, x_checked: 178406, y_checked: 2232872735, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21885166, x_checked: 176679, y_checked: 2254757901, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1923, y_added: 0, x_checked: 178602, y_checked: 2230530976, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1594, y_added: 0, x_checked: 180196, y_checked: 2210848947, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1397, y_added: 0, x_checked: 181593, y_checked: 2193877069, x_admin_checked: 68, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29225803, x_checked: 179212, y_checked: 2223102872, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17148675, x_checked: 177844, y_checked: 2240251547, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1516, y_added: 0, x_checked: 179360, y_checked: 2221353481, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19292836, x_checked: 177820, y_checked: 2240646317, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1949, y_added: 0, x_checked: 179769, y_checked: 2216415568, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17957464, x_checked: 178328, y_checked: 2234373032, x_admin_checked: 69, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2420, y_added: 0, x_checked: 180747, y_checked: 2204542822, x_admin_checked: 70, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1678, y_added: 0, x_checked: 182425, y_checked: 2184312670, x_admin_checked: 70, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 7363, y_added: 0, x_checked: 189785, y_checked: 2099813660, x_admin_checked: 73, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21150620, x_checked: 187898, y_checked: 2120964280, x_admin_checked: 73, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2723, y_added: 0, x_checked: 190620, y_checked: 2090754284, x_admin_checked: 74, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20468059, x_checked: 188777, y_checked: 2111222343, x_admin_checked: 74, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31642318, x_checked: 185997, y_checked: 2142864661, x_admin_checked: 75, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1530, y_added: 0, x_checked: 187527, y_checked: 2125415405, x_admin_checked: 75, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26170575, x_checked: 185252, y_checked: 2151585980, x_admin_checked: 76, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17064775, x_checked: 183799, y_checked: 2168650755, x_admin_checked: 76, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21825568, x_checked: 181973, y_checked: 2190476323, x_admin_checked: 76, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 61891343, x_checked: 176986, y_checked: 2252367666, x_admin_checked: 78, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30886128, x_checked: 174599, y_checked: 2283253794, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1477, y_added: 0, x_checked: 176076, y_checked: 2264139472, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17545716, x_checked: 174726, y_checked: 2281685188, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21366454, x_checked: 173110, y_checked: 2303051642, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1481, y_added: 0, x_checked: 174591, y_checked: 2283554825, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17388915, x_checked: 173275, y_checked: 2300943740, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19298271, x_checked: 171838, y_checked: 2320242011, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1670, y_added: 0, x_checked: 173508, y_checked: 2297962853, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17683627, x_checked: 172187, y_checked: 2315646480, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20890250, x_checked: 170652, y_checked: 2336536730, x_admin_checked: 79, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 40927575, x_checked: 167722, y_checked: 2377464305, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1315, y_added: 0, x_checked: 169037, y_checked: 2359011017, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19414607, x_checked: 167661, y_checked: 2378425624, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18521958, x_checked: 166369, y_checked: 2396947582, x_admin_checked: 80, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2544, y_added: 0, x_checked: 168912, y_checked: 2360944977, x_admin_checked: 81, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 2570, y_added: 0, x_checked: 171481, y_checked: 2325656440, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1380, y_added: 0, x_checked: 172861, y_checked: 2307130084, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1342, y_added: 0, x_checked: 174203, y_checked: 2289396174, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20069210, x_checked: 172694, y_checked: 2309465384, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1321, y_added: 0, x_checked: 174015, y_checked: 2291973054, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18413052, x_checked: 172632, y_checked: 2310386106, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17862480, x_checked: 171311, y_checked: 2328248586, x_admin_checked: 82, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 4078, y_added: 0, x_checked: 175387, y_checked: 2274269680, x_admin_checked: 84, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27546005, x_checked: 173294, y_checked: 2301815685, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19337514, x_checked: 171855, y_checked: 2321153199, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1617, y_added: 0, x_checked: 173472, y_checked: 2299569852, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23955934, x_checked: 171689, y_checked: 2323525786, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1996, y_added: 0, x_checked: 173685, y_checked: 2296889790, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17670016, x_checked: 172363, y_checked: 2314559806, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20313083, x_checked: 170868, y_checked: 2334872889, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20741632, x_checked: 169368, y_checked: 2355614521, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1757, y_added: 0, x_checked: 171125, y_checked: 2331483104, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1584, y_added: 0, x_checked: 172709, y_checked: 2310153419, x_admin_checked: 85, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 57742573, x_checked: 168509, y_checked: 2367895992, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1381, y_added: 0, x_checked: 169890, y_checked: 2348689339, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21326617, x_checked: 168366, y_checked: 2370015956, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1478, y_added: 0, x_checked: 169844, y_checked: 2349433332, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1410, y_added: 0, x_checked: 171254, y_checked: 2330130364, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1343, y_added: 0, x_checked: 172597, y_checked: 2312039500, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 18949007, x_checked: 171198, y_checked: 2330988507, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1659, y_added: 0, x_checked: 172857, y_checked: 2308670202, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22793764, x_checked: 171172, y_checked: 2331463966, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17730165, x_checked: 169884, y_checked: 2349194131, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1319, y_added: 0, x_checked: 171203, y_checked: 2331136074, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1386, y_added: 0, x_checked: 172589, y_checked: 2312455757, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 17576014, x_checked: 171291, y_checked: 2330031771, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1321, y_added: 0, x_checked: 172612, y_checked: 2312240220, x_admin_checked: 87, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 39320680, x_checked: 169734, y_checked: 2351560900, x_admin_checked: 88, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30242169, x_checked: 167585, y_checked: 2381803069, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19716397, x_checked: 166213, y_checked: 2401519466, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1426, y_added: 0, x_checked: 167639, y_checked: 2381133856, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19519206, x_checked: 166280, y_checked: 2400653062, x_admin_checked: 89, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 32933339, x_checked: 164036, y_checked: 2433586401, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24758447, x_checked: 162389, y_checked: 2458344848, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 25292237, x_checked: 160740, y_checked: 2483637085, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20658205, x_checked: 159418, y_checked: 2504295290, x_admin_checked: 90, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 48544186, x_checked: 156395, y_checked: 2552839476, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 20730390, x_checked: 155139, y_checked: 2573569866, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22779134, x_checked: 153782, y_checked: 2596349000, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21522498, x_checked: 152521, y_checked: 2617871498, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26704306, x_checked: 150985, y_checked: 2644575804, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1287, y_added: 0, x_checked: 152272, y_checked: 2622275564, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21994007, x_checked: 151009, y_checked: 2644269571, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1183, y_added: 0, x_checked: 152192, y_checked: 2623767182, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 19958354, x_checked: 151047, y_checked: 2643725536, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1232, y_added: 0, x_checked: 152279, y_checked: 2622388368, x_admin_checked: 91, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35254396, x_checked: 150265, y_checked: 2657642764, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22794243, x_checked: 148991, y_checked: 2680437007, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 29494364, x_checked: 147374, y_checked: 2709931371, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 21534775, x_checked: 146216, y_checked: 2731466146, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24825070, x_checked: 144903, y_checked: 2756291216, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22170066, x_checked: 143750, y_checked: 2778461282, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 24835028, x_checked: 142480, y_checked: 2803296310, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27097733, x_checked: 141120, y_checked: 2830394043, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 38084383, x_checked: 139252, y_checked: 2868478426, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22538153, x_checked: 138170, y_checked: 2891016579, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 31894847, x_checked: 136667, y_checked: 2922911426, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 26848632, x_checked: 135427, y_checked: 2949760058, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22695606, x_checked: 134396, y_checked: 2972455664, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23107071, x_checked: 133362, y_checked: 2995562735, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1055, y_added: 0, x_checked: 134417, y_checked: 2972095655, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1041, y_added: 0, x_checked: 135458, y_checked: 2949298530, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28701594, x_checked: 134156, y_checked: 2978000124, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1159, y_added: 0, x_checked: 135315, y_checked: 2952558418, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 22567718, x_checked: 134292, y_checked: 2975126136, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 35195361, x_checked: 132726, y_checked: 3010321497, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 30097992, x_checked: 131416, y_checked: 3040419489, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1196, y_added: 0, x_checked: 132612, y_checked: 3013066742, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1104, y_added: 0, x_checked: 133716, y_checked: 2988234642, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36429667, x_checked: 132110, y_checked: 3024664309, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 28201517, x_checked: 130893, y_checked: 3052865826, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 27073167, x_checked: 129746, y_checked: 3079938993, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1048, y_added: 0, x_checked: 130794, y_checked: 3055307394, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 33124256, x_checked: 129395, y_checked: 3088431650, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 999, y_added: 0, x_checked: 130394, y_checked: 3064816963, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1236, y_added: 0, x_checked: 131630, y_checked: 3036107661, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 36236073, x_checked: 130082, y_checked: 3072343734, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23905592, x_checked: 129081, y_checked: 3096249326, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 1126, y_added: 0, x_checked: 130207, y_checked: 3069520827, x_admin_checked: 92, y_admin_checked: 0 },
                AmmSimulationStepData { x_added: 0, y_added: 23299210, x_checked: 129229, y_checked: 3092820037, x_admin_checked: 92, y_admin_checked: 0 },
            ]
        };

        test_utils_amm_simulate(admin, guy, &s);
    }

    #[test_only]
    fun test_amm_simulate_10000_impl(admin: &signer, guy: &signer) {
        let s = AmmSimulationData {
            x_init: 100000,
            y_init: 1048100000,
            fee_direction: 201,
            data: vector [
                AmmSimulationStepData { x_added: 0, y_added: 8215928, x_checked: 99225, y_checked: 1056311821, x_admin_checked: 0, y_admin_checked: 4107 },
                AmmSimulationStepData { x_added: 0, y_added: 8828148, x_checked: 98406, y_checked: 1065135555, x_admin_checked: 0, y_admin_checked: 8521 },
                AmmSimulationStepData { x_added: 0, y_added: 8809903, x_checked: 97602, y_checked: 1073941054, x_admin_checked: 0, y_admin_checked: 12925 },
                AmmSimulationStepData { x_added: 951, y_added: 0, x_checked: 98553, y_checked: 1063599505, x_admin_checked: 0, y_admin_checked: 18095 },
                AmmSimulationStepData { x_added: 0, y_added: 9050876, x_checked: 97724, y_checked: 1072645856, x_admin_checked: 0, y_admin_checked: 22620 },
                AmmSimulationStepData { x_added: 850, y_added: 0, x_checked: 98574, y_checked: 1063418047, x_admin_checked: 0, y_admin_checked: 27233 },
                AmmSimulationStepData { x_added: 790, y_added: 0, x_checked: 99364, y_checked: 1054984507, x_admin_checked: 0, y_admin_checked: 31449 },
                AmmSimulationStepData { x_added: 0, y_added: 15088515, x_checked: 97968, y_checked: 1070065478, x_admin_checked: 0, y_admin_checked: 38993 },
                AmmSimulationStepData { x_added: 811, y_added: 0, x_checked: 98779, y_checked: 1061301465, x_admin_checked: 0, y_admin_checked: 43375 },
                AmmSimulationStepData { x_added: 0, y_added: 12291564, x_checked: 97652, y_checked: 1073586884, x_admin_checked: 0, y_admin_checked: 49520 },
                AmmSimulationStepData { x_added: 819, y_added: 0, x_checked: 98471, y_checked: 1064679305, x_admin_checked: 0, y_admin_checked: 53973 },
                AmmSimulationStepData { x_added: 928, y_added: 0, x_checked: 99399, y_checked: 1054760565, x_admin_checked: 0, y_admin_checked: 58932 },
                AmmSimulationStepData { x_added: 0, y_added: 11657426, x_checked: 98316, y_checked: 1066412163, x_admin_checked: 0, y_admin_checked: 64760 },
                AmmSimulationStepData { x_added: 0, y_added: 10173729, x_checked: 97390, y_checked: 1076580806, x_admin_checked: 0, y_admin_checked: 69846 },
                AmmSimulationStepData { x_added: 0, y_added: 15271263, x_checked: 96033, y_checked: 1091844434, x_admin_checked: 0, y_admin_checked: 77481 },
                AmmSimulationStepData { x_added: 0, y_added: 8292325, x_checked: 95312, y_checked: 1100132613, x_admin_checked: 0, y_admin_checked: 81627 },
                AmmSimulationStepData { x_added: 759, y_added: 0, x_checked: 96071, y_checked: 1091452479, x_admin_checked: 0, y_admin_checked: 85967 },
                AmmSimulationStepData { x_added: 976, y_added: 0, x_checked: 97047, y_checked: 1080498028, x_admin_checked: 0, y_admin_checked: 91444 },
                AmmSimulationStepData { x_added: 0, y_added: 10025495, x_checked: 96158, y_checked: 1090518511, x_admin_checked: 0, y_admin_checked: 96456 },
                AmmSimulationStepData { x_added: 0, y_added: 9662492, x_checked: 95317, y_checked: 1100176172, x_admin_checked: 0, y_admin_checked: 101287 },
                AmmSimulationStepData { x_added: 0, y_added: 9202461, x_checked: 94529, y_checked: 1109374032, x_admin_checked: 0, y_admin_checked: 105888 },
                AmmSimulationStepData { x_added: 0, y_added: 8840373, x_checked: 93784, y_checked: 1118209985, x_admin_checked: 0, y_admin_checked: 110308 },
                AmmSimulationStepData { x_added: 725, y_added: 0, x_checked: 94509, y_checked: 1109643684, x_admin_checked: 0, y_admin_checked: 114591 },
                AmmSimulationStepData { x_added: 918, y_added: 0, x_checked: 95427, y_checked: 1098992035, x_admin_checked: 0, y_admin_checked: 119916 },
                AmmSimulationStepData { x_added: 0, y_added: 9244219, x_checked: 94634, y_checked: 1108231632, x_admin_checked: 0, y_admin_checked: 124538 },
                AmmSimulationStepData { x_added: 762, y_added: 0, x_checked: 95396, y_checked: 1099390873, x_admin_checked: 0, y_admin_checked: 128958 },
                AmmSimulationStepData { x_added: 0, y_added: 8535937, x_checked: 94664, y_checked: 1107922543, x_admin_checked: 0, y_admin_checked: 133225 },
                AmmSimulationStepData { x_added: 0, y_added: 12415968, x_checked: 93619, y_checked: 1120332304, x_admin_checked: 0, y_admin_checked: 139432 },
                AmmSimulationStepData { x_added: 0, y_added: 8958313, x_checked: 92879, y_checked: 1129286138, x_admin_checked: 0, y_admin_checked: 143911 },
                AmmSimulationStepData { x_added: 0, y_added: 9194600, x_checked: 92132, y_checked: 1138476141, x_admin_checked: 0, y_admin_checked: 148508 },
                AmmSimulationStepData { x_added: 834, y_added: 0, x_checked: 92966, y_checked: 1128287120, x_admin_checked: 0, y_admin_checked: 153602 },
                AmmSimulationStepData { x_added: 0, y_added: 11693745, x_checked: 92016, y_checked: 1139975019, x_admin_checked: 0, y_admin_checked: 159448 },
                AmmSimulationStepData { x_added: 0, y_added: 9168512, x_checked: 91285, y_checked: 1149138947, x_admin_checked: 0, y_admin_checked: 164032 },
                AmmSimulationStepData { x_added: 0, y_added: 9631440, x_checked: 90529, y_checked: 1158765572, x_admin_checked: 0, y_admin_checked: 168847 },
                AmmSimulationStepData { x_added: 0, y_added: 10583549, x_checked: 89713, y_checked: 1169343830, x_admin_checked: 0, y_admin_checked: 174138 },
                AmmSimulationStepData { x_added: 0, y_added: 20544663, x_checked: 88169, y_checked: 1189878221, x_admin_checked: 0, y_admin_checked: 184410 },
                AmmSimulationStepData { x_added: 673, y_added: 0, x_checked: 88842, y_checked: 1180877893, x_admin_checked: 0, y_admin_checked: 188910 },
                AmmSimulationStepData { x_added: 0, y_added: 9378452, x_checked: 88145, y_checked: 1190251656, x_admin_checked: 0, y_admin_checked: 193599 },
                AmmSimulationStepData { x_added: 0, y_added: 9873528, x_checked: 87423, y_checked: 1200120248, x_admin_checked: 0, y_admin_checked: 198535 },
                AmmSimulationStepData { x_added: 788, y_added: 0, x_checked: 88211, y_checked: 1189426391, x_admin_checked: 0, y_admin_checked: 203881 },
                AmmSimulationStepData { x_added: 956, y_added: 0, x_checked: 89167, y_checked: 1176700403, x_admin_checked: 0, y_admin_checked: 210243 },
                AmmSimulationStepData { x_added: 0, y_added: 9549478, x_checked: 88452, y_checked: 1186245107, x_admin_checked: 0, y_admin_checked: 215017 },
                AmmSimulationStepData { x_added: 2647, y_added: 0, x_checked: 91099, y_checked: 1151853076, x_admin_checked: 0, y_admin_checked: 232213 },
                AmmSimulationStepData { x_added: 0, y_added: 9188238, x_checked: 90381, y_checked: 1161036720, x_admin_checked: 0, y_admin_checked: 236807 },
                AmmSimulationStepData { x_added: 830, y_added: 0, x_checked: 91211, y_checked: 1150496769, x_admin_checked: 0, y_admin_checked: 242076 },
                AmmSimulationStepData { x_added: 0, y_added: 14720944, x_checked: 90063, y_checked: 1165210353, x_admin_checked: 0, y_admin_checked: 249436 },
                AmmSimulationStepData { x_added: 0, y_added: 9480424, x_checked: 89339, y_checked: 1174686037, x_admin_checked: 0, y_admin_checked: 254176 },
                AmmSimulationStepData { x_added: 0, y_added: 9206756, x_checked: 88647, y_checked: 1183888190, x_admin_checked: 0, y_admin_checked: 258779 },
                AmmSimulationStepData { x_added: 756, y_added: 0, x_checked: 89403, y_checked: 1173890253, x_admin_checked: 0, y_admin_checked: 263777 },
                AmmSimulationStepData { x_added: 702, y_added: 0, x_checked: 90105, y_checked: 1164757506, x_admin_checked: 0, y_admin_checked: 268343 },
                AmmSimulationStepData { x_added: 0, y_added: 10558311, x_checked: 89299, y_checked: 1175310538, x_admin_checked: 0, y_admin_checked: 273622 },
                AmmSimulationStepData { x_added: 0, y_added: 11775754, x_checked: 88416, y_checked: 1187080405, x_admin_checked: 0, y_admin_checked: 279509 },
                AmmSimulationStepData { x_added: 0, y_added: 9118365, x_checked: 87745, y_checked: 1196194211, x_admin_checked: 0, y_admin_checked: 284068 },
                AmmSimulationStepData { x_added: 0, y_added: 9915630, x_checked: 87026, y_checked: 1206104884, x_admin_checked: 0, y_admin_checked: 289025 },
                AmmSimulationStepData { x_added: 0, y_added: 9574394, x_checked: 86343, y_checked: 1215674491, x_admin_checked: 0, y_admin_checked: 293812 },
                AmmSimulationStepData { x_added: 695, y_added: 0, x_checked: 87038, y_checked: 1205981165, x_admin_checked: 0, y_admin_checked: 298658 },
                AmmSimulationStepData { x_added: 0, y_added: 13813539, x_checked: 86056, y_checked: 1219787798, x_admin_checked: 0, y_admin_checked: 305564 },
                AmmSimulationStepData { x_added: 1453, y_added: 0, x_checked: 87509, y_checked: 1199575558, x_admin_checked: 0, y_admin_checked: 315670 },
                AmmSimulationStepData { x_added: 0, y_added: 9965241, x_checked: 86791, y_checked: 1209535817, x_admin_checked: 0, y_admin_checked: 320652 },
                AmmSimulationStepData { x_added: 0, y_added: 11618133, x_checked: 85968, y_checked: 1221148141, x_admin_checked: 0, y_admin_checked: 326461 },
                AmmSimulationStepData { x_added: 742, y_added: 0, x_checked: 86710, y_checked: 1210712422, x_admin_checked: 0, y_admin_checked: 331678 },
                AmmSimulationStepData { x_added: 0, y_added: 10639426, x_checked: 85957, y_checked: 1221346529, x_admin_checked: 0, y_admin_checked: 336997 },
                AmmSimulationStepData { x_added: 746, y_added: 0, x_checked: 86703, y_checked: 1210851925, x_admin_checked: 0, y_admin_checked: 342244 },
                AmmSimulationStepData { x_added: 0, y_added: 11638128, x_checked: 85881, y_checked: 1222484234, x_admin_checked: 0, y_admin_checked: 348063 },
                AmmSimulationStepData { x_added: 0, y_added: 11973187, x_checked: 85051, y_checked: 1234451435, x_admin_checked: 0, y_admin_checked: 354049 },
                AmmSimulationStepData { x_added: 0, y_added: 9664980, x_checked: 84393, y_checked: 1244111583, x_admin_checked: 0, y_admin_checked: 358881 },
                AmmSimulationStepData { x_added: 0, y_added: 14390496, x_checked: 83431, y_checked: 1258494884, x_admin_checked: 0, y_admin_checked: 366076 },
                AmmSimulationStepData { x_added: 0, y_added: 13458338, x_checked: 82551, y_checked: 1271946493, x_admin_checked: 0, y_admin_checked: 372805 },
                AmmSimulationStepData { x_added: 0, y_added: 10779990, x_checked: 81860, y_checked: 1282721094, x_admin_checked: 0, y_admin_checked: 378194 },
                AmmSimulationStepData { x_added: 0, y_added: 16840142, x_checked: 80803, y_checked: 1299552816, x_admin_checked: 0, y_admin_checked: 386614 },
                AmmSimulationStepData { x_added: 0, y_added: 10250804, x_checked: 80173, y_checked: 1309798495, x_admin_checked: 0, y_admin_checked: 391739 },
                AmmSimulationStepData { x_added: 0, y_added: 10026621, x_checked: 79566, y_checked: 1319820103, x_admin_checked: 0, y_admin_checked: 396752 },
                AmmSimulationStepData { x_added: 0, y_added: 10264651, x_checked: 78954, y_checked: 1330079622, x_admin_checked: 0, y_admin_checked: 401884 },
                AmmSimulationStepData { x_added: 0, y_added: 11675014, x_checked: 78270, y_checked: 1341748799, x_admin_checked: 0, y_admin_checked: 407721 },
                AmmSimulationStepData { x_added: 0, y_added: 11625687, x_checked: 77600, y_checked: 1353368674, x_admin_checked: 0, y_admin_checked: 413533 },
                AmmSimulationStepData { x_added: 0, y_added: 10329023, x_checked: 77015, y_checked: 1363692533, x_admin_checked: 0, y_admin_checked: 418697 },
                AmmSimulationStepData { x_added: 0, y_added: 11437306, x_checked: 76377, y_checked: 1375124121, x_admin_checked: 0, y_admin_checked: 424415 },
                AmmSimulationStepData { x_added: 0, y_added: 10928157, x_checked: 75777, y_checked: 1386046814, x_admin_checked: 0, y_admin_checked: 429879 },
                AmmSimulationStepData { x_added: 0, y_added: 11139929, x_checked: 75175, y_checked: 1397181174, x_admin_checked: 0, y_admin_checked: 435448 },
                AmmSimulationStepData { x_added: 872, y_added: 0, x_checked: 76047, y_checked: 1381196591, x_admin_checked: 0, y_admin_checked: 443440 },
                AmmSimulationStepData { x_added: 0, y_added: 11158597, x_checked: 75440, y_checked: 1392349609, x_admin_checked: 0, y_admin_checked: 449019 },
                AmmSimulationStepData { x_added: 592, y_added: 0, x_checked: 76032, y_checked: 1381526674, x_admin_checked: 0, y_admin_checked: 454430 },
                AmmSimulationStepData { x_added: 0, y_added: 11197599, x_checked: 75423, y_checked: 1392718675, x_admin_checked: 0, y_admin_checked: 460028 },
                AmmSimulationStepData { x_added: 0, y_added: 13109249, x_checked: 74722, y_checked: 1405821370, x_admin_checked: 0, y_admin_checked: 466582 },
                AmmSimulationStepData { x_added: 602, y_added: 0, x_checked: 75324, y_checked: 1394604363, x_admin_checked: 0, y_admin_checked: 472190 },
                AmmSimulationStepData { x_added: 0, y_added: 15135340, x_checked: 74518, y_checked: 1409732136, x_admin_checked: 0, y_admin_checked: 479757 },
                AmmSimulationStepData { x_added: 0, y_added: 11305021, x_checked: 73927, y_checked: 1421031505, x_admin_checked: 0, y_admin_checked: 485409 },
                AmmSimulationStepData { x_added: 0, y_added: 10832950, x_checked: 73370, y_checked: 1431859039, x_admin_checked: 0, y_admin_checked: 490825 },
                AmmSimulationStepData { x_added: 0, y_added: 11702434, x_checked: 72778, y_checked: 1443555622, x_admin_checked: 0, y_admin_checked: 496676 },
                AmmSimulationStepData { x_added: 0, y_added: 12590571, x_checked: 72151, y_checked: 1456139898, x_admin_checked: 0, y_admin_checked: 502971 },
                AmmSimulationStepData { x_added: 0, y_added: 17479994, x_checked: 71298, y_checked: 1473611153, x_admin_checked: 0, y_admin_checked: 511710 },
                AmmSimulationStepData { x_added: 0, y_added: 11398251, x_checked: 70753, y_checked: 1485003705, x_admin_checked: 0, y_admin_checked: 517409 },
                AmmSimulationStepData { x_added: 0, y_added: 11397703, x_checked: 70216, y_checked: 1496395710, x_admin_checked: 0, y_admin_checked: 523107 },
                AmmSimulationStepData { x_added: 0, y_added: 11552853, x_checked: 69680, y_checked: 1507942787, x_admin_checked: 0, y_admin_checked: 528883 },
                AmmSimulationStepData { x_added: 0, y_added: 12538271, x_checked: 69108, y_checked: 1520474789, x_admin_checked: 0, y_admin_checked: 535152 },
                AmmSimulationStepData { x_added: 0, y_added: 13268654, x_checked: 68512, y_checked: 1533736809, x_admin_checked: 0, y_admin_checked: 541786 },
                AmmSimulationStepData { x_added: 949, y_added: 0, x_checked: 69461, y_checked: 1512825930, x_admin_checked: 0, y_admin_checked: 552241 },
                AmmSimulationStepData { x_added: 0, y_added: 11905209, x_checked: 68921, y_checked: 1524725187, x_admin_checked: 0, y_admin_checked: 558193 },
                AmmSimulationStepData { x_added: 667, y_added: 0, x_checked: 69588, y_checked: 1510132419, x_admin_checked: 0, y_admin_checked: 565489 },
                AmmSimulationStepData { x_added: 0, y_added: 11764217, x_checked: 69052, y_checked: 1521890754, x_admin_checked: 0, y_admin_checked: 571371 },
                AmmSimulationStepData { x_added: 0, y_added: 11844855, x_checked: 68521, y_checked: 1533729687, x_admin_checked: 0, y_admin_checked: 577293 },
                AmmSimulationStepData { x_added: 0, y_added: 11759422, x_checked: 68002, y_checked: 1545483230, x_admin_checked: 0, y_admin_checked: 583172 },
                AmmSimulationStepData { x_added: 576, y_added: 0, x_checked: 68578, y_checked: 1532524763, x_admin_checked: 0, y_admin_checked: 589651 },
                AmmSimulationStepData { x_added: 0, y_added: 16020019, x_checked: 67871, y_checked: 1548536772, x_admin_checked: 0, y_admin_checked: 597661 },
                AmmSimulationStepData { x_added: 553, y_added: 0, x_checked: 68424, y_checked: 1536044010, x_admin_checked: 0, y_admin_checked: 603907 },
                AmmSimulationStepData { x_added: 0, y_added: 17388389, x_checked: 67661, y_checked: 1553423705, x_admin_checked: 0, y_admin_checked: 612601 },
                AmmSimulationStepData { x_added: 0, y_added: 15122540, x_checked: 67011, y_checked: 1568538684, x_admin_checked: 0, y_admin_checked: 620162 },
                AmmSimulationStepData { x_added: 0, y_added: 13772818, x_checked: 66430, y_checked: 1582304616, x_admin_checked: 0, y_admin_checked: 627048 },
                AmmSimulationStepData { x_added: 0, y_added: 12037341, x_checked: 65930, y_checked: 1594335939, x_admin_checked: 0, y_admin_checked: 633066 },
                AmmSimulationStepData { x_added: 0, y_added: 13309112, x_checked: 65386, y_checked: 1607638397, x_admin_checked: 0, y_admin_checked: 639720 },
                AmmSimulationStepData { x_added: 0, y_added: 13790597, x_checked: 64832, y_checked: 1621422099, x_admin_checked: 0, y_admin_checked: 646615 },
                AmmSimulationStepData { x_added: 0, y_added: 13423361, x_checked: 64302, y_checked: 1634838749, x_admin_checked: 0, y_admin_checked: 653326 },
                AmmSimulationStepData { x_added: 0, y_added: 12487725, x_checked: 63817, y_checked: 1647320231, x_admin_checked: 0, y_admin_checked: 659569 },
                AmmSimulationStepData { x_added: 0, y_added: 13629243, x_checked: 63295, y_checked: 1660942660, x_admin_checked: 0, y_admin_checked: 666383 },
                AmmSimulationStepData { x_added: 0, y_added: 22715918, x_checked: 62444, y_checked: 1683647221, x_admin_checked: 0, y_admin_checked: 677740 },
                AmmSimulationStepData { x_added: 0, y_added: 13309941, x_checked: 61956, y_checked: 1696950508, x_admin_checked: 0, y_admin_checked: 684394 },
                AmmSimulationStepData { x_added: 0, y_added: 14828995, x_checked: 61421, y_checked: 1711772089, x_admin_checked: 0, y_admin_checked: 691808 },
                AmmSimulationStepData { x_added: 0, y_added: 13395936, x_checked: 60946, y_checked: 1725161328, x_admin_checked: 0, y_admin_checked: 698505 },
                AmmSimulationStepData { x_added: 0, y_added: 25888030, x_checked: 60048, y_checked: 1751036414, x_admin_checked: 0, y_admin_checked: 711449 },
                AmmSimulationStepData { x_added: 0, y_added: 13384394, x_checked: 59594, y_checked: 1764414116, x_admin_checked: 0, y_admin_checked: 718141 },
                AmmSimulationStepData { x_added: 567, y_added: 0, x_checked: 60161, y_checked: 1747814077, x_admin_checked: 0, y_admin_checked: 726441 },
                AmmSimulationStepData { x_added: 0, y_added: 13472288, x_checked: 59703, y_checked: 1761279629, x_admin_checked: 0, y_admin_checked: 733177 },
                AmmSimulationStepData { x_added: 0, y_added: 14452371, x_checked: 59219, y_checked: 1775724774, x_admin_checked: 0, y_admin_checked: 740403 },
                AmmSimulationStepData { x_added: 458, y_added: 0, x_checked: 59677, y_checked: 1762126239, x_admin_checked: 0, y_admin_checked: 747202 },
                AmmSimulationStepData { x_added: 0, y_added: 13884242, x_checked: 59212, y_checked: 1776003539, x_admin_checked: 0, y_admin_checked: 754144 },
                AmmSimulationStepData { x_added: 0, y_added: 13710072, x_checked: 58760, y_checked: 1789706756, x_admin_checked: 0, y_admin_checked: 760999 },
                AmmSimulationStepData { x_added: 0, y_added: 21491959, x_checked: 58065, y_checked: 1811187970, x_admin_checked: 0, y_admin_checked: 771744 },
                AmmSimulationStepData { x_added: 0, y_added: 14197598, x_checked: 57615, y_checked: 1825378470, x_admin_checked: 0, y_admin_checked: 778842 },
                AmmSimulationStepData { x_added: 470, y_added: 0, x_checked: 58085, y_checked: 1810639429, x_admin_checked: 0, y_admin_checked: 786211 },
                AmmSimulationStepData { x_added: 0, y_added: 16769351, x_checked: 57554, y_checked: 1827400396, x_admin_checked: 0, y_admin_checked: 794595 },
                AmmSimulationStepData { x_added: 0, y_added: 15173700, x_checked: 57082, y_checked: 1842566510, x_admin_checked: 0, y_admin_checked: 802181 },
                AmmSimulationStepData { x_added: 498, y_added: 0, x_checked: 57580, y_checked: 1826662178, x_admin_checked: 0, y_admin_checked: 810133 },
                AmmSimulationStepData { x_added: 574, y_added: 0, x_checked: 58154, y_checked: 1808663495, x_admin_checked: 0, y_admin_checked: 819132 },
                AmmSimulationStepData { x_added: 0, y_added: 13814005, x_checked: 57715, y_checked: 1822470593, x_admin_checked: 0, y_admin_checked: 826039 },
                AmmSimulationStepData { x_added: 0, y_added: 16778353, x_checked: 57191, y_checked: 1839240557, x_admin_checked: 0, y_admin_checked: 834428 },
                AmmSimulationStepData { x_added: 0, y_added: 14463190, x_checked: 56747, y_checked: 1853696516, x_admin_checked: 0, y_admin_checked: 841659 },
                AmmSimulationStepData { x_added: 0, y_added: 15750382, x_checked: 56271, y_checked: 1869439023, x_admin_checked: 0, y_admin_checked: 849534 },
                AmmSimulationStepData { x_added: 482, y_added: 0, x_checked: 56753, y_checked: 1853594645, x_admin_checked: 0, y_admin_checked: 857456 },
                AmmSimulationStepData { x_added: 0, y_added: 14858124, x_checked: 56304, y_checked: 1868445340, x_admin_checked: 0, y_admin_checked: 864885 },
                AmmSimulationStepData { x_added: 0, y_added: 20817440, x_checked: 55686, y_checked: 1889252372, x_admin_checked: 0, y_admin_checked: 875293 },
                AmmSimulationStepData { x_added: 0, y_added: 15506446, x_checked: 55235, y_checked: 1904751065, x_admin_checked: 0, y_admin_checked: 883046 },
                AmmSimulationStepData { x_added: 0, y_added: 15561478, x_checked: 54789, y_checked: 1920304763, x_admin_checked: 0, y_admin_checked: 890826 },
                AmmSimulationStepData { x_added: 0, y_added: 18005524, x_checked: 54282, y_checked: 1938301285, x_admin_checked: 0, y_admin_checked: 899828 },
                AmmSimulationStepData { x_added: 0, y_added: 15808445, x_checked: 53845, y_checked: 1954101826, x_admin_checked: 0, y_admin_checked: 907732 },
                AmmSimulationStepData { x_added: 0, y_added: 15948598, x_checked: 53411, y_checked: 1970042450, x_admin_checked: 0, y_admin_checked: 915706 },
                AmmSimulationStepData { x_added: 488, y_added: 0, x_checked: 53899, y_checked: 1952241963, x_admin_checked: 0, y_admin_checked: 924606 },
                AmmSimulationStepData { x_added: 417, y_added: 0, x_checked: 54316, y_checked: 1937289691, x_admin_checked: 0, y_admin_checked: 932082 },
                AmmSimulationStepData { x_added: 0, y_added: 31457191, x_checked: 53451, y_checked: 1968731154, x_admin_checked: 0, y_admin_checked: 947810 },
                AmmSimulationStepData { x_added: 0, y_added: 20332800, x_checked: 52907, y_checked: 1989053788, x_admin_checked: 0, y_admin_checked: 957976 },
                AmmSimulationStepData { x_added: 455, y_added: 0, x_checked: 53362, y_checked: 1972130747, x_admin_checked: 0, y_admin_checked: 966437 },
                AmmSimulationStepData { x_added: 601, y_added: 0, x_checked: 53963, y_checked: 1950202753, x_admin_checked: 0, y_admin_checked: 977400 },
                AmmSimulationStepData { x_added: 0, y_added: 16258751, x_checked: 53519, y_checked: 1966453375, x_admin_checked: 0, y_admin_checked: 985529 },
                AmmSimulationStepData { x_added: 0, y_added: 15855435, x_checked: 53093, y_checked: 1982300883, x_admin_checked: 0, y_admin_checked: 993456 },
                AmmSimulationStepData { x_added: 0, y_added: 15070209, x_checked: 52694, y_checked: 1997363557, x_admin_checked: 0, y_admin_checked: 1000991 },
                AmmSimulationStepData { x_added: 409, y_added: 0, x_checked: 53103, y_checked: 1982017161, x_admin_checked: 0, y_admin_checked: 1008664 },
                AmmSimulationStepData { x_added: 0, y_added: 18215449, x_checked: 52621, y_checked: 2000223503, x_admin_checked: 0, y_admin_checked: 1017771 },
                AmmSimulationStepData { x_added: 0, y_added: 16109913, x_checked: 52202, y_checked: 2016325362, x_admin_checked: 0, y_admin_checked: 1025825 },
                AmmSimulationStepData { x_added: 450, y_added: 0, x_checked: 52652, y_checked: 1999130436, x_admin_checked: 0, y_admin_checked: 1034422 },
                AmmSimulationStepData { x_added: 0, y_added: 17686928, x_checked: 52192, y_checked: 2016808521, x_admin_checked: 0, y_admin_checked: 1043265 },
                AmmSimulationStepData { x_added: 0, y_added: 17845639, x_checked: 51736, y_checked: 2034645238, x_admin_checked: 0, y_admin_checked: 1052187 },
                AmmSimulationStepData { x_added: 0, y_added: 15460875, x_checked: 51348, y_checked: 2050098383, x_admin_checked: 0, y_admin_checked: 1059917 },
                AmmSimulationStepData { x_added: 451, y_added: 0, x_checked: 51799, y_checked: 2032287961, x_admin_checked: 0, y_admin_checked: 1068822 },
                AmmSimulationStepData { x_added: 405, y_added: 0, x_checked: 52204, y_checked: 2016560047, x_admin_checked: 0, y_admin_checked: 1076685 },
                AmmSimulationStepData { x_added: 0, y_added: 15639352, x_checked: 51804, y_checked: 2032191580, x_admin_checked: 0, y_admin_checked: 1084504 },
                AmmSimulationStepData { x_added: 427, y_added: 0, x_checked: 52231, y_checked: 2015616554, x_admin_checked: 0, y_admin_checked: 1092791 },
                AmmSimulationStepData { x_added: 427, y_added: 0, x_checked: 52658, y_checked: 1999310030, x_admin_checked: 0, y_admin_checked: 1100944 },
                AmmSimulationStepData { x_added: 0, y_added: 18521643, x_checked: 52177, y_checked: 2017822413, x_admin_checked: 0, y_admin_checked: 1110204 },
                AmmSimulationStepData { x_added: 637, y_added: 0, x_checked: 52814, y_checked: 1993522808, x_admin_checked: 0, y_admin_checked: 1122353 },
                AmmSimulationStepData { x_added: 426, y_added: 0, x_checked: 53240, y_checked: 1977608776, x_admin_checked: 0, y_admin_checked: 1130310 },
                AmmSimulationStepData { x_added: 432, y_added: 0, x_checked: 53672, y_checked: 1961727772, x_admin_checked: 0, y_admin_checked: 1138250 },
                AmmSimulationStepData { x_added: 522, y_added: 0, x_checked: 54194, y_checked: 1942868138, x_admin_checked: 0, y_admin_checked: 1147679 },
                AmmSimulationStepData { x_added: 512, y_added: 0, x_checked: 54706, y_checked: 1924719786, x_admin_checked: 0, y_admin_checked: 1156753 },
                AmmSimulationStepData { x_added: 457, y_added: 0, x_checked: 55163, y_checked: 1908808974, x_admin_checked: 0, y_admin_checked: 1164708 },
                AmmSimulationStepData { x_added: 423, y_added: 0, x_checked: 55586, y_checked: 1894317342, x_admin_checked: 0, y_admin_checked: 1171953 },
                AmmSimulationStepData { x_added: 0, y_added: 16034678, x_checked: 55121, y_checked: 1910344003, x_admin_checked: 0, y_admin_checked: 1179970 },
                AmmSimulationStepData { x_added: 423, y_added: 0, x_checked: 55544, y_checked: 1895829750, x_admin_checked: 0, y_admin_checked: 1187227 },
                AmmSimulationStepData { x_added: 435, y_added: 0, x_checked: 55979, y_checked: 1881131296, x_admin_checked: 0, y_admin_checked: 1194576 },
                AmmSimulationStepData { x_added: 0, y_added: 16724491, x_checked: 55488, y_checked: 1897847425, x_admin_checked: 0, y_admin_checked: 1202938 },
                AmmSimulationStepData { x_added: 0, y_added: 27402353, x_checked: 54701, y_checked: 1925236077, x_admin_checked: 0, y_admin_checked: 1216639 },
                AmmSimulationStepData { x_added: 463, y_added: 0, x_checked: 55164, y_checked: 1909111881, x_admin_checked: 0, y_admin_checked: 1224701 },
                AmmSimulationStepData { x_added: 451, y_added: 0, x_checked: 55615, y_checked: 1893664326, x_admin_checked: 0, y_admin_checked: 1232424 },
                AmmSimulationStepData { x_added: 448, y_added: 0, x_checked: 56063, y_checked: 1878565544, x_admin_checked: 0, y_admin_checked: 1239973 },
                AmmSimulationStepData { x_added: 479, y_added: 0, x_checked: 56542, y_checked: 1862684072, x_admin_checked: 0, y_admin_checked: 1247913 },
                AmmSimulationStepData { x_added: 500, y_added: 0, x_checked: 57042, y_checked: 1846389138, x_admin_checked: 0, y_admin_checked: 1256060 },
                AmmSimulationStepData { x_added: 438, y_added: 0, x_checked: 57480, y_checked: 1832351454, x_admin_checked: 0, y_admin_checked: 1263078 },
                AmmSimulationStepData { x_added: 0, y_added: 15019166, x_checked: 57015, y_checked: 1847363111, x_admin_checked: 0, y_admin_checked: 1270587 },
                AmmSimulationStepData { x_added: 0, y_added: 15006497, x_checked: 56557, y_checked: 1862362105, x_admin_checked: 0, y_admin_checked: 1278090 },
                AmmSimulationStepData { x_added: 573, y_added: 0, x_checked: 57130, y_checked: 1843715339, x_admin_checked: 0, y_admin_checked: 1287413 },
                AmmSimulationStepData { x_added: 439, y_added: 0, x_checked: 57569, y_checked: 1829687628, x_admin_checked: 0, y_admin_checked: 1294426 },
                AmmSimulationStepData { x_added: 0, y_added: 18845478, x_checked: 56984, y_checked: 1848523684, x_admin_checked: 0, y_admin_checked: 1303848 },
                AmmSimulationStepData { x_added: 476, y_added: 0, x_checked: 57460, y_checked: 1833242375, x_admin_checked: 0, y_admin_checked: 1311488 },
                AmmSimulationStepData { x_added: 468, y_added: 0, x_checked: 57928, y_checked: 1818463012, x_admin_checked: 0, y_admin_checked: 1318877 },
                AmmSimulationStepData { x_added: 463, y_added: 0, x_checked: 58391, y_checked: 1804074763, x_admin_checked: 0, y_admin_checked: 1326071 },
                AmmSimulationStepData { x_added: 0, y_added: 13968233, x_checked: 57944, y_checked: 1818036012, x_admin_checked: 0, y_admin_checked: 1333055 },
                AmmSimulationStepData { x_added: 453, y_added: 0, x_checked: 58397, y_checked: 1803963948, x_admin_checked: 0, y_admin_checked: 1340091 },
                AmmSimulationStepData { x_added: 479, y_added: 0, x_checked: 58876, y_checked: 1789317753, x_admin_checked: 0, y_admin_checked: 1347414 },
                AmmSimulationStepData { x_added: 0, y_added: 13911055, x_checked: 58424, y_checked: 1803221853, x_admin_checked: 0, y_admin_checked: 1354369 },
                AmmSimulationStepData { x_added: 0, y_added: 13801647, x_checked: 57982, y_checked: 1817016600, x_admin_checked: 0, y_admin_checked: 1361269 },
                AmmSimulationStepData { x_added: 0, y_added: 14957762, x_checked: 57511, y_checked: 1831966884, x_admin_checked: 0, y_admin_checked: 1368747 },
                AmmSimulationStepData { x_added: 494, y_added: 0, x_checked: 58005, y_checked: 1816396240, x_admin_checked: 0, y_admin_checked: 1376532 },
                AmmSimulationStepData { x_added: 852, y_added: 0, x_checked: 58857, y_checked: 1790163349, x_admin_checked: 0, y_admin_checked: 1389648 },
                AmmSimulationStepData { x_added: 501, y_added: 0, x_checked: 59358, y_checked: 1775083718, x_admin_checked: 0, y_admin_checked: 1397187 },
                AmmSimulationStepData { x_added: 480, y_added: 0, x_checked: 59838, y_checked: 1760874030, x_admin_checked: 0, y_admin_checked: 1404291 },
                AmmSimulationStepData { x_added: 467, y_added: 0, x_checked: 60305, y_checked: 1747266852, x_admin_checked: 0, y_admin_checked: 1411094 },
                AmmSimulationStepData { x_added: 0, y_added: 15964634, x_checked: 59761, y_checked: 1763223504, x_admin_checked: 0, y_admin_checked: 1419076 },
                AmmSimulationStepData { x_added: 469, y_added: 0, x_checked: 60230, y_checked: 1749522653, x_admin_checked: 0, y_admin_checked: 1425926 },
                AmmSimulationStepData { x_added: 473, y_added: 0, x_checked: 60703, y_checked: 1735918906, x_admin_checked: 0, y_admin_checked: 1432727 },
                AmmSimulationStepData { x_added: 0, y_added: 13604946, x_checked: 60233, y_checked: 1749517050, x_admin_checked: 0, y_admin_checked: 1439529 },
                AmmSimulationStepData { x_added: 504, y_added: 0, x_checked: 60737, y_checked: 1735027998, x_admin_checked: 0, y_admin_checked: 1446773 },
                AmmSimulationStepData { x_added: 528, y_added: 0, x_checked: 61265, y_checked: 1720103087, x_admin_checked: 0, y_admin_checked: 1454235 },
                AmmSimulationStepData { x_added: 0, y_added: 13832947, x_checked: 60778, y_checked: 1733929118, x_admin_checked: 0, y_admin_checked: 1461151 },
                AmmSimulationStepData { x_added: 0, y_added: 15185335, x_checked: 60252, y_checked: 1749106861, x_admin_checked: 0, y_admin_checked: 1468743 },
                AmmSimulationStepData { x_added: 476, y_added: 0, x_checked: 60728, y_checked: 1735425538, x_admin_checked: 0, y_admin_checked: 1475583 },
                AmmSimulationStepData { x_added: 0, y_added: 13606147, x_checked: 60258, y_checked: 1749024882, x_admin_checked: 0, y_admin_checked: 1482386 },
                AmmSimulationStepData { x_added: 0, y_added: 16589170, x_checked: 59694, y_checked: 1765605758, x_admin_checked: 0, y_admin_checked: 1490680 },
                AmmSimulationStepData { x_added: 0, y_added: 14250258, x_checked: 59218, y_checked: 1779848891, x_admin_checked: 0, y_admin_checked: 1497805 },
                AmmSimulationStepData { x_added: 531, y_added: 0, x_checked: 59749, y_checked: 1764060582, x_admin_checked: 0, y_admin_checked: 1505699 },
                AmmSimulationStepData { x_added: 472, y_added: 0, x_checked: 60221, y_checked: 1750263297, x_admin_checked: 0, y_admin_checked: 1512597 },
                AmmSimulationStepData { x_added: 0, y_added: 15555190, x_checked: 59693, y_checked: 1765810710, x_admin_checked: 0, y_admin_checked: 1520374 },
                AmmSimulationStepData { x_added: 509, y_added: 0, x_checked: 60202, y_checked: 1750910097, x_admin_checked: 0, y_admin_checked: 1527824 },
                AmmSimulationStepData { x_added: 0, y_added: 13912353, x_checked: 59729, y_checked: 1764815494, x_admin_checked: 0, y_admin_checked: 1534780 },
                AmmSimulationStepData { x_added: 565, y_added: 0, x_checked: 60294, y_checked: 1748306846, x_admin_checked: 0, y_admin_checked: 1543034 },
                AmmSimulationStepData { x_added: 669, y_added: 0, x_checked: 60963, y_checked: 1729149519, x_admin_checked: 0, y_admin_checked: 1552612 },
                AmmSimulationStepData { x_added: 0, y_added: 13133922, x_checked: 60505, y_checked: 1742276875, x_admin_checked: 0, y_admin_checked: 1559178 },
                AmmSimulationStepData { x_added: 0, y_added: 13223269, x_checked: 60051, y_checked: 1755493533, x_admin_checked: 0, y_admin_checked: 1565789 },
                AmmSimulationStepData { x_added: 468, y_added: 0, x_checked: 60519, y_checked: 1741946895, x_admin_checked: 0, y_admin_checked: 1572562 },
                AmmSimulationStepData { x_added: 536, y_added: 0, x_checked: 61055, y_checked: 1726682677, x_admin_checked: 0, y_admin_checked: 1580194 },
                AmmSimulationStepData { x_added: 596, y_added: 0, x_checked: 61651, y_checked: 1710018019, x_admin_checked: 0, y_admin_checked: 1588526 },
                AmmSimulationStepData { x_added: 479, y_added: 0, x_checked: 62130, y_checked: 1696861706, x_admin_checked: 0, y_admin_checked: 1595104 },
                AmmSimulationStepData { x_added: 561, y_added: 0, x_checked: 62691, y_checked: 1681703905, x_admin_checked: 0, y_admin_checked: 1602682 },
                AmmSimulationStepData { x_added: 484, y_added: 0, x_checked: 63175, y_checked: 1668846354, x_admin_checked: 0, y_admin_checked: 1609110 },
                AmmSimulationStepData { x_added: 513, y_added: 0, x_checked: 63688, y_checked: 1655429969, x_admin_checked: 0, y_admin_checked: 1615818 },
                AmmSimulationStepData { x_added: 0, y_added: 89226600, x_checked: 60441, y_checked: 1744611956, x_admin_checked: 0, y_admin_checked: 1660431 },
                AmmSimulationStepData { x_added: 476, y_added: 0, x_checked: 60917, y_checked: 1731008130, x_admin_checked: 0, y_admin_checked: 1667232 },
                AmmSimulationStepData { x_added: 535, y_added: 0, x_checked: 61452, y_checked: 1715965929, x_admin_checked: 0, y_admin_checked: 1674753 },
                AmmSimulationStepData { x_added: 543, y_added: 0, x_checked: 61995, y_checked: 1700963614, x_admin_checked: 0, y_admin_checked: 1682254 },
                AmmSimulationStepData { x_added: 555, y_added: 0, x_checked: 62550, y_checked: 1685898084, x_admin_checked: 0, y_admin_checked: 1689786 },
                AmmSimulationStepData { x_added: 505, y_added: 0, x_checked: 63055, y_checked: 1672422450, x_admin_checked: 0, y_admin_checked: 1696523 },
                AmmSimulationStepData { x_added: 515, y_added: 0, x_checked: 63570, y_checked: 1658899741, x_admin_checked: 0, y_admin_checked: 1703284 },
                AmmSimulationStepData { x_added: 485, y_added: 0, x_checked: 64055, y_checked: 1646364888, x_admin_checked: 0, y_admin_checked: 1709551 },
                AmmSimulationStepData { x_added: 633, y_added: 0, x_checked: 64688, y_checked: 1630279700, x_admin_checked: 0, y_admin_checked: 1717593 },
                AmmSimulationStepData { x_added: 510, y_added: 0, x_checked: 65198, y_checked: 1617551931, x_admin_checked: 0, y_admin_checked: 1723956 },
                AmmSimulationStepData { x_added: 497, y_added: 0, x_checked: 65695, y_checked: 1605339161, x_admin_checked: 0, y_admin_checked: 1730062 },
                AmmSimulationStepData { x_added: 1208, y_added: 0, x_checked: 66903, y_checked: 1576423860, x_admin_checked: 0, y_admin_checked: 1744519 },
                AmmSimulationStepData { x_added: 640, y_added: 0, x_checked: 67543, y_checked: 1561509661, x_admin_checked: 0, y_admin_checked: 1751976 },
                AmmSimulationStepData { x_added: 0, y_added: 12502663, x_checked: 67009, y_checked: 1574006073, x_admin_checked: 0, y_admin_checked: 1758227 },
                AmmSimulationStepData { x_added: 514, y_added: 0, x_checked: 67523, y_checked: 1562047525, x_admin_checked: 0, y_admin_checked: 1764206 },
                AmmSimulationStepData { x_added: 0, y_added: 12539777, x_checked: 66987, y_checked: 1574581033, x_admin_checked: 0, y_admin_checked: 1770475 },
                AmmSimulationStepData { x_added: 529, y_added: 0, x_checked: 67516, y_checked: 1562267047, x_admin_checked: 0, y_admin_checked: 1776631 },
                AmmSimulationStepData { x_added: 858, y_added: 0, x_checked: 68374, y_checked: 1542707863, x_admin_checked: 0, y_admin_checked: 1786410 },
                AmmSimulationStepData { x_added: 530, y_added: 0, x_checked: 68904, y_checked: 1530863786, x_admin_checked: 0, y_admin_checked: 1792332 },
                AmmSimulationStepData { x_added: 700, y_added: 0, x_checked: 69604, y_checked: 1515489826, x_admin_checked: 0, y_admin_checked: 1800018 },
                AmmSimulationStepData { x_added: 705, y_added: 0, x_checked: 70309, y_checked: 1500315098, x_admin_checked: 0, y_admin_checked: 1807605 },
                AmmSimulationStepData { x_added: 578, y_added: 0, x_checked: 70887, y_checked: 1488102788, x_admin_checked: 0, y_admin_checked: 1813711 },
                AmmSimulationStepData { x_added: 0, y_added: 15317202, x_checked: 70168, y_checked: 1503412332, x_admin_checked: 0, y_admin_checked: 1821369 },
                AmmSimulationStepData { x_added: 550, y_added: 0, x_checked: 70718, y_checked: 1491740834, x_admin_checked: 0, y_admin_checked: 1827204 },
                AmmSimulationStepData { x_added: 0, y_added: 12639796, x_checked: 70126, y_checked: 1504374311, x_admin_checked: 0, y_admin_checked: 1833523 },
                AmmSimulationStepData { x_added: 0, y_added: 13283005, x_checked: 69515, y_checked: 1517650675, x_admin_checked: 0, y_admin_checked: 1840164 },
                AmmSimulationStepData { x_added: 632, y_added: 0, x_checked: 70147, y_checked: 1503998613, x_admin_checked: 0, y_admin_checked: 1846990 },
                AmmSimulationStepData { x_added: 569, y_added: 0, x_checked: 70716, y_checked: 1491918133, x_admin_checked: 0, y_admin_checked: 1853030 },
                AmmSimulationStepData { x_added: 719, y_added: 0, x_checked: 71435, y_checked: 1476922512, x_admin_checked: 0, y_admin_checked: 1860527 },
                AmmSimulationStepData { x_added: 0, y_added: 12741510, x_checked: 70826, y_checked: 1489657652, x_admin_checked: 0, y_admin_checked: 1866897 },
                AmmSimulationStepData { x_added: 0, y_added: 12780062, x_checked: 70226, y_checked: 1502431324, x_admin_checked: 0, y_admin_checked: 1873287 },
                AmmSimulationStepData { x_added: 565, y_added: 0, x_checked: 70791, y_checked: 1490461113, x_admin_checked: 0, y_admin_checked: 1879272 },
                AmmSimulationStepData { x_added: 621, y_added: 0, x_checked: 71412, y_checked: 1477520728, x_admin_checked: 0, y_admin_checked: 1885742 },
                AmmSimulationStepData { x_added: 616, y_added: 0, x_checked: 72028, y_checked: 1464904970, x_admin_checked: 0, y_admin_checked: 1892049 },
                AmmSimulationStepData { x_added: 562, y_added: 0, x_checked: 72590, y_checked: 1453583535, x_admin_checked: 0, y_admin_checked: 1897709 },
                AmmSimulationStepData { x_added: 0, y_added: 11114267, x_checked: 72041, y_checked: 1464692245, x_admin_checked: 0, y_admin_checked: 1903266 },
                AmmSimulationStepData { x_added: 686, y_added: 0, x_checked: 72727, y_checked: 1450896434, x_admin_checked: 0, y_admin_checked: 1910163 },
                AmmSimulationStepData { x_added: 896, y_added: 0, x_checked: 73623, y_checked: 1433277801, x_admin_checked: 0, y_admin_checked: 1918972 },
                AmmSimulationStepData { x_added: 651, y_added: 0, x_checked: 74274, y_checked: 1420734474, x_admin_checked: 0, y_admin_checked: 1925243 },
                AmmSimulationStepData { x_added: 608, y_added: 0, x_checked: 74882, y_checked: 1409217724, x_admin_checked: 0, y_admin_checked: 1931001 },
                AmmSimulationStepData { x_added: 0, y_added: 10825914, x_checked: 74313, y_checked: 1420038226, x_admin_checked: 0, y_admin_checked: 1936413 },
                AmmSimulationStepData { x_added: 597, y_added: 0, x_checked: 74910, y_checked: 1408739947, x_admin_checked: 0, y_admin_checked: 1942062 },
                AmmSimulationStepData { x_added: 606, y_added: 0, x_checked: 75516, y_checked: 1397453611, x_admin_checked: 0, y_admin_checked: 1947705 },
                AmmSimulationStepData { x_added: 849, y_added: 0, x_checked: 76365, y_checked: 1381953393, x_admin_checked: 0, y_admin_checked: 1955455 },
                AmmSimulationStepData { x_added: 591, y_added: 0, x_checked: 76956, y_checked: 1371358208, x_admin_checked: 0, y_admin_checked: 1960752 },
                AmmSimulationStepData { x_added: 0, y_added: 10705565, x_checked: 76362, y_checked: 1382058421, x_admin_checked: 0, y_admin_checked: 1966104 },
                AmmSimulationStepData { x_added: 608, y_added: 0, x_checked: 76970, y_checked: 1371159105, x_admin_checked: 0, y_admin_checked: 1971553 },
                AmmSimulationStepData { x_added: 0, y_added: 12799119, x_checked: 76261, y_checked: 1383951825, x_admin_checked: 0, y_admin_checked: 1977952 },
                AmmSimulationStepData { x_added: 722, y_added: 0, x_checked: 76983, y_checked: 1370989974, x_admin_checked: 0, y_admin_checked: 1984432 },
                AmmSimulationStepData { x_added: 700, y_added: 0, x_checked: 77683, y_checked: 1358653500, x_admin_checked: 0, y_admin_checked: 1990600 },
                AmmSimulationStepData { x_added: 0, y_added: 13255382, x_checked: 76935, y_checked: 1371902255, x_admin_checked: 0, y_admin_checked: 1997227 },
                AmmSimulationStepData { x_added: 628, y_added: 0, x_checked: 77563, y_checked: 1360811996, x_admin_checked: 0, y_admin_checked: 2002772 },
                AmmSimulationStepData { x_added: 0, y_added: 11052888, x_checked: 76941, y_checked: 1371859358, x_admin_checked: 0, y_admin_checked: 2008298 },
                AmmSimulationStepData { x_added: 633, y_added: 0, x_checked: 77574, y_checked: 1360682594, x_admin_checked: 0, y_admin_checked: 2013886 },
                AmmSimulationStepData { x_added: 617, y_added: 0, x_checked: 78191, y_checked: 1349962803, x_admin_checked: 0, y_admin_checked: 2019245 },
                AmmSimulationStepData { x_added: 0, y_added: 11493599, x_checked: 77533, y_checked: 1361450656, x_admin_checked: 0, y_admin_checked: 2024991 },
                AmmSimulationStepData { x_added: 0, y_added: 12816602, x_checked: 76813, y_checked: 1374260850, x_admin_checked: 0, y_admin_checked: 2031399 },
                AmmSimulationStepData { x_added: 711, y_added: 0, x_checked: 77524, y_checked: 1361674583, x_admin_checked: 0, y_admin_checked: 2037692 },
                AmmSimulationStepData { x_added: 0, y_added: 11050802, x_checked: 76902, y_checked: 1372719860, x_admin_checked: 0, y_admin_checked: 2043217 },
                AmmSimulationStepData { x_added: 894, y_added: 0, x_checked: 77796, y_checked: 1356980008, x_admin_checked: 0, y_admin_checked: 2051086 },
                AmmSimulationStepData { x_added: 597, y_added: 0, x_checked: 78393, y_checked: 1346663138, x_admin_checked: 0, y_admin_checked: 2056244 },
                AmmSimulationStepData { x_added: 0, y_added: 16116575, x_checked: 77469, y_checked: 1362771655, x_admin_checked: 0, y_admin_checked: 2064302 },
                AmmSimulationStepData { x_added: 778, y_added: 0, x_checked: 78247, y_checked: 1349256277, x_admin_checked: 0, y_admin_checked: 2071059 },
                AmmSimulationStepData { x_added: 678, y_added: 0, x_checked: 78925, y_checked: 1337682529, x_admin_checked: 0, y_admin_checked: 2076845 },
                AmmSimulationStepData { x_added: 0, y_added: 10798133, x_checked: 78295, y_checked: 1348475263, x_admin_checked: 0, y_admin_checked: 2082244 },
                AmmSimulationStepData { x_added: 820, y_added: 0, x_checked: 79115, y_checked: 1334532514, x_admin_checked: 0, y_admin_checked: 2089215 },
                AmmSimulationStepData { x_added: 0, y_added: 13111565, x_checked: 78348, y_checked: 1347637524, x_admin_checked: 0, y_admin_checked: 2095770 },
                AmmSimulationStepData { x_added: 618, y_added: 0, x_checked: 78966, y_checked: 1337107640, x_admin_checked: 0, y_admin_checked: 2101034 },
                AmmSimulationStepData { x_added: 0, y_added: 21261327, x_checked: 77734, y_checked: 1358358337, x_admin_checked: 0, y_admin_checked: 2111664 },
                AmmSimulationStepData { x_added: 593, y_added: 0, x_checked: 78327, y_checked: 1348091655, x_admin_checked: 0, y_admin_checked: 2116797 },
                AmmSimulationStepData { x_added: 630, y_added: 0, x_checked: 78957, y_checked: 1337352134, x_admin_checked: 0, y_admin_checked: 2122166 },
                AmmSimulationStepData { x_added: 643, y_added: 0, x_checked: 79600, y_checked: 1326565817, x_admin_checked: 0, y_admin_checked: 2127559 },
                AmmSimulationStepData { x_added: 0, y_added: 11631168, x_checked: 78911, y_checked: 1338191170, x_admin_checked: 0, y_admin_checked: 2133374 },
                AmmSimulationStepData { x_added: 0, y_added: 10583586, x_checked: 78294, y_checked: 1348769465, x_admin_checked: 0, y_admin_checked: 2138665 },
                AmmSimulationStepData { x_added: 701, y_added: 0, x_checked: 78995, y_checked: 1336817436, x_admin_checked: 0, y_admin_checked: 2144641 },
                AmmSimulationStepData { x_added: 0, y_added: 17916326, x_checked: 77954, y_checked: 1354724804, x_admin_checked: 0, y_admin_checked: 2153599 },
                AmmSimulationStepData { x_added: 616, y_added: 0, x_checked: 78570, y_checked: 1344120676, x_admin_checked: 0, y_admin_checked: 2158901 },
                AmmSimulationStepData { x_added: 610, y_added: 0, x_checked: 79180, y_checked: 1333782462, x_admin_checked: 0, y_admin_checked: 2164070 },
                AmmSimulationStepData { x_added: 0, y_added: 11877796, x_checked: 78484, y_checked: 1345654320, x_admin_checked: 0, y_admin_checked: 2170008 },
                AmmSimulationStepData { x_added: 834, y_added: 0, x_checked: 79318, y_checked: 1331538828, x_admin_checked: 0, y_admin_checked: 2177065 },
                AmmSimulationStepData { x_added: 0, y_added: 11209215, x_checked: 78658, y_checked: 1342742439, x_admin_checked: 0, y_admin_checked: 2182669 },
                AmmSimulationStepData { x_added: 0, y_added: 10270059, x_checked: 78063, y_checked: 1353007363, x_admin_checked: 0, y_admin_checked: 2187804 },
                AmmSimulationStepData { x_added: 0, y_added: 10306830, x_checked: 77475, y_checked: 1363309040, x_admin_checked: 0, y_admin_checked: 2192957 },
                AmmSimulationStepData { x_added: 730, y_added: 0, x_checked: 78205, y_checked: 1350600582, x_admin_checked: 0, y_admin_checked: 2199311 },
                AmmSimulationStepData { x_added: 862, y_added: 0, x_checked: 79067, y_checked: 1335909929, x_admin_checked: 0, y_admin_checked: 2206656 },
                AmmSimulationStepData { x_added: 641, y_added: 0, x_checked: 79708, y_checked: 1325183364, x_admin_checked: 0, y_admin_checked: 2212019 },
                AmmSimulationStepData { x_added: 0, y_added: 10336202, x_checked: 79093, y_checked: 1335514398, x_admin_checked: 0, y_admin_checked: 2217187 },
                AmmSimulationStepData { x_added: 758, y_added: 0, x_checked: 79851, y_checked: 1322853354, x_admin_checked: 0, y_admin_checked: 2223517 },
                AmmSimulationStepData { x_added: 782, y_added: 0, x_checked: 80633, y_checked: 1310056470, x_admin_checked: 0, y_admin_checked: 2229915 },
                AmmSimulationStepData { x_added: 650, y_added: 0, x_checked: 81283, y_checked: 1299596262, x_admin_checked: 0, y_admin_checked: 2235145 },
                AmmSimulationStepData { x_added: 702, y_added: 0, x_checked: 81985, y_checked: 1288484131, x_admin_checked: 0, y_admin_checked: 2240701 },
                AmmSimulationStepData { x_added: 0, y_added: 17460611, x_checked: 80893, y_checked: 1305936012, x_admin_checked: 0, y_admin_checked: 2249431 },
                AmmSimulationStepData { x_added: 740, y_added: 0, x_checked: 81633, y_checked: 1294113606, x_admin_checked: 0, y_admin_checked: 2255342 },
                AmmSimulationStepData { x_added: 624, y_added: 0, x_checked: 82257, y_checked: 1284312099, x_admin_checked: 0, y_admin_checked: 2260242 },
                AmmSimulationStepData { x_added: 728, y_added: 0, x_checked: 82985, y_checked: 1273060594, x_admin_checked: 0, y_admin_checked: 2265867 },
                AmmSimulationStepData { x_added: 747, y_added: 0, x_checked: 83732, y_checked: 1261718282, x_admin_checked: 0, y_admin_checked: 2271538 },
                AmmSimulationStepData { x_added: 757, y_added: 0, x_checked: 84489, y_checked: 1250428407, x_admin_checked: 0, y_admin_checked: 2277182 },
                AmmSimulationStepData { x_added: 713, y_added: 0, x_checked: 85202, y_checked: 1239978941, x_admin_checked: 0, y_admin_checked: 2282406 },
                AmmSimulationStepData { x_added: 671, y_added: 0, x_checked: 85873, y_checked: 1230304241, x_admin_checked: 0, y_admin_checked: 2287243 },
                AmmSimulationStepData { x_added: 823, y_added: 0, x_checked: 86696, y_checked: 1218653149, x_admin_checked: 0, y_admin_checked: 2293068 },
                AmmSimulationStepData { x_added: 674, y_added: 0, x_checked: 87370, y_checked: 1209265912, x_admin_checked: 0, y_admin_checked: 2297761 },
                AmmSimulationStepData { x_added: 0, y_added: 9800657, x_checked: 86670, y_checked: 1219061669, x_admin_checked: 0, y_admin_checked: 2302661 },
                AmmSimulationStepData { x_added: 663, y_added: 0, x_checked: 87333, y_checked: 1209820855, x_admin_checked: 0, y_admin_checked: 2307281 },
                AmmSimulationStepData { x_added: 714, y_added: 0, x_checked: 88047, y_checked: 1200023678, x_admin_checked: 0, y_admin_checked: 2312179 },
                AmmSimulationStepData { x_added: 0, y_added: 9699083, x_checked: 87344, y_checked: 1209717912, x_admin_checked: 0, y_admin_checked: 2317028 },
                AmmSimulationStepData { x_added: 679, y_added: 0, x_checked: 88023, y_checked: 1200399915, x_admin_checked: 0, y_admin_checked: 2321686 },
                AmmSimulationStepData { x_added: 1025, y_added: 0, x_checked: 89048, y_checked: 1186609188, x_admin_checked: 0, y_admin_checked: 2328581 },
                AmmSimulationStepData { x_added: 841, y_added: 0, x_checked: 89889, y_checked: 1175533448, x_admin_checked: 0, y_admin_checked: 2334118 },
                AmmSimulationStepData { x_added: 868, y_added: 0, x_checked: 90757, y_checked: 1164316304, x_admin_checked: 0, y_admin_checked: 2339726 },
                AmmSimulationStepData { x_added: 0, y_added: 9082949, x_checked: 90057, y_checked: 1173394712, x_admin_checked: 0, y_admin_checked: 2344267 },
                AmmSimulationStepData { x_added: 1199, y_added: 0, x_checked: 91256, y_checked: 1158015710, x_admin_checked: 0, y_admin_checked: 2351956 },
                AmmSimulationStepData { x_added: 733, y_added: 0, x_checked: 91989, y_checked: 1148800731, x_admin_checked: 0, y_admin_checked: 2356563 },
                AmmSimulationStepData { x_added: 880, y_added: 0, x_checked: 92869, y_checked: 1137939532, x_admin_checked: 0, y_admin_checked: 2361993 },
                AmmSimulationStepData { x_added: 844, y_added: 0, x_checked: 93713, y_checked: 1127715065, x_admin_checked: 0, y_admin_checked: 2367105 },
                AmmSimulationStepData { x_added: 0, y_added: 9402670, x_checked: 92941, y_checked: 1137113034, x_admin_checked: 0, y_admin_checked: 2371806 },
                AmmSimulationStepData { x_added: 0, y_added: 10079089, x_checked: 92127, y_checked: 1147187084, x_admin_checked: 0, y_admin_checked: 2376845 },
                AmmSimulationStepData { x_added: 0, y_added: 10128755, x_checked: 91324, y_checked: 1157310775, x_admin_checked: 0, y_admin_checked: 2381909 },
                AmmSimulationStepData { x_added: 770, y_added: 0, x_checked: 92094, y_checked: 1147659398, x_admin_checked: 0, y_admin_checked: 2386734 },
                AmmSimulationStepData { x_added: 854, y_added: 0, x_checked: 92948, y_checked: 1137139249, x_admin_checked: 0, y_admin_checked: 2391994 },
                AmmSimulationStepData { x_added: 0, y_added: 15165072, x_checked: 91729, y_checked: 1152296739, x_admin_checked: 0, y_admin_checked: 2399576 },
                AmmSimulationStepData { x_added: 931, y_added: 0, x_checked: 92660, y_checked: 1140743677, x_admin_checked: 0, y_admin_checked: 2405352 },
                AmmSimulationStepData { x_added: 835, y_added: 0, x_checked: 93495, y_checked: 1130579927, x_admin_checked: 0, y_admin_checked: 2410433 },
                AmmSimulationStepData { x_added: 754, y_added: 0, x_checked: 94249, y_checked: 1121547092, x_admin_checked: 0, y_admin_checked: 2414949 },
                AmmSimulationStepData { x_added: 793, y_added: 0, x_checked: 95042, y_checked: 1112212668, x_admin_checked: 0, y_admin_checked: 2419616 },
                AmmSimulationStepData { x_added: 0, y_added: 31635105, x_checked: 92422, y_checked: 1143831956, x_admin_checked: 0, y_admin_checked: 2435433 },
                AmmSimulationStepData { x_added: 753, y_added: 0, x_checked: 93175, y_checked: 1134600179, x_admin_checked: 0, y_admin_checked: 2440048 },
                AmmSimulationStepData { x_added: 715, y_added: 0, x_checked: 93890, y_checked: 1125971857, x_admin_checked: 0, y_admin_checked: 2444362 },
                AmmSimulationStepData { x_added: 1413, y_added: 0, x_checked: 95303, y_checked: 1109312673, x_admin_checked: 0, y_admin_checked: 2452691 },
                AmmSimulationStepData { x_added: 0, y_added: 8900870, x_checked: 94547, y_checked: 1118209093, x_admin_checked: 0, y_admin_checked: 2457141 },
                AmmSimulationStepData { x_added: 920, y_added: 0, x_checked: 95467, y_checked: 1107456295, x_admin_checked: 0, y_admin_checked: 2462517 },
                AmmSimulationStepData { x_added: 824, y_added: 0, x_checked: 96291, y_checked: 1098002162, x_admin_checked: 0, y_admin_checked: 2467244 },
                AmmSimulationStepData { x_added: 933, y_added: 0, x_checked: 97224, y_checked: 1087487670, x_admin_checked: 0, y_admin_checked: 2472501 },
                AmmSimulationStepData { x_added: 787, y_added: 0, x_checked: 98011, y_checked: 1078777472, x_admin_checked: 0, y_admin_checked: 2476856 },
                AmmSimulationStepData { x_added: 0, y_added: 13265777, x_checked: 96825, y_checked: 1092036617, x_admin_checked: 0, y_admin_checked: 2483488 },
                AmmSimulationStepData { x_added: 871, y_added: 0, x_checked: 97696, y_checked: 1082322819, x_admin_checked: 0, y_admin_checked: 2488344 },
                AmmSimulationStepData { x_added: 897, y_added: 0, x_checked: 98593, y_checked: 1072497593, x_admin_checked: 0, y_admin_checked: 2493256 },
                AmmSimulationStepData { x_added: 1395, y_added: 0, x_checked: 99988, y_checked: 1057566187, x_admin_checked: 0, y_admin_checked: 2500721 },
                AmmSimulationStepData { x_added: 1027, y_added: 0, x_checked: 101015, y_checked: 1046834843, x_admin_checked: 0, y_admin_checked: 2506086 },
                AmmSimulationStepData { x_added: 1008, y_added: 0, x_checked: 102023, y_checked: 1036512304, x_admin_checked: 0, y_admin_checked: 2511247 },
                AmmSimulationStepData { x_added: 844, y_added: 0, x_checked: 102867, y_checked: 1028027948, x_admin_checked: 0, y_admin_checked: 2515489 },
                AmmSimulationStepData { x_added: 0, y_added: 44757514, x_checked: 98589, y_checked: 1072763084, x_admin_checked: 0, y_admin_checked: 2537867 },
                AmmSimulationStepData { x_added: 1353, y_added: 0, x_checked: 99942, y_checked: 1058271943, x_admin_checked: 0, y_admin_checked: 2545112 },
                AmmSimulationStepData { x_added: 0, y_added: 9963639, x_checked: 99013, y_checked: 1068230601, x_admin_checked: 0, y_admin_checked: 2550093 },
                AmmSimulationStepData { x_added: 1041, y_added: 0, x_checked: 100054, y_checked: 1057137454, x_admin_checked: 0, y_admin_checked: 2555639 },
                AmmSimulationStepData { x_added: 0, y_added: 15665813, x_checked: 98598, y_checked: 1072795435, x_admin_checked: 0, y_admin_checked: 2563471 },
            ]
        };

        test_utils_amm_simulate(admin, guy, &s);
    }
}
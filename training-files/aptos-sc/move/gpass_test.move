#[test_only]
module ggwp_core::gpass_test {
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_framework::account::create_account_for_test;
    use aptos_framework::coin;
    use aptos_framework::genesis;

    use ggwp_core::gpass;
    use coin::ggwp::GGWPCoin;

    #[test(core_signer = @ggwp_core, accumulative_fund = @0x11112222)]
    #[expected_failure(abort_code = 0x1002, location = ggwp_core::gpass)]
    public entry fun double_initialize(core_signer: &signer, accumulative_fund: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        create_account_for_test(core_addr);
        create_account_for_test(ac_fund_addr);

        gpass::initialize(core_signer, ac_fund_addr, 5000, 5000, 8, 15, 300);
        assert!(gpass::get_total_amount(core_addr) == 0, 1);
        assert!(gpass::get_burn_period(core_addr) == 5000, 2);

        // Try to initialize twice
        gpass::initialize(core_signer, ac_fund_addr, 6000, 5000, 8, 15, 300);
    }

    #[test(core_signer = @ggwp_core, accumulative_fund = @0x11112222)]
    public entry fun update_params(core_signer: &signer, accumulative_fund: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        create_account_for_test(core_addr);

        gpass::initialize(core_signer, ac_fund_addr, 5000, 7000, 8, 15, 300);
        assert!(gpass::get_total_amount(core_addr) == 0, 1);
        assert!(gpass::get_burn_period(core_addr) == 5000, 2);

        let new_period = 11223344;
        gpass::update_burn_period(core_signer, new_period);
        assert!(gpass::get_burn_period(core_addr) == new_period, 3);

        let new_reward_period = 11223344;
        let new_royalty = 20;
        let new_unfreeze_royalty = 40;
        let new_unfreeze_lock_period = 600;
        gpass::update_freezing_params(core_signer, new_reward_period, new_royalty, new_unfreeze_royalty, new_unfreeze_lock_period);
        assert!(gpass::get_reward_period(core_addr) == new_reward_period, 4);
        assert!(gpass::get_royalty(core_addr) == new_royalty, 5);
        assert!(gpass::get_unfreeze_royalty(core_addr) == new_unfreeze_royalty, 6);
        assert!(gpass::get_unfreeze_lock_period(core_addr) == new_unfreeze_lock_period, 7);

        let burner1 = @0x111222;
        let burner2 = @0x111333;
        let burner3 = @0x111444;

        gpass::add_burner(core_signer, burner1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner1) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner2) == false, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner3) == false, 1);

        gpass::add_burner(core_signer, burner2);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner1) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner2) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner3) == false, 1);

        gpass::add_burner(core_signer, burner3);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner1) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner2) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner3) == true, 1);

        gpass::remove_burner(core_signer, burner1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner1) == false, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner2) == true, 1);
        assert!(vector::contains(&gpass::get_burners_list(core_addr), &burner3) == true, 1);
    }

    #[test(core_signer = @ggwp_core, accumulative_fund = @0x11112222)]
    public entry fun update_accumulative_fund(core_signer: &signer, accumulative_fund: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        create_account_for_test(core_addr);

        gpass::initialize(core_signer, ac_fund_addr, 5000, 7000, 8, 15, 300);
        assert!(gpass::get_accumulative_fund_addr(core_addr) == ac_fund_addr, 1);

        let new_ac_fund_addr = @44332211;
        gpass::update_accumulative_fund(core_signer, new_ac_fund_addr);
        assert!(gpass::get_accumulative_fund_addr(core_addr) == new_ac_fund_addr, 1);
    }

    #[test(core_signer = @ggwp_core, accumulative_fund = @0x11112222, user = @0x11)]
    public entry fun mint_to_with_burns(core_signer: &signer, accumulative_fund: &signer, user: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user_addr = signer::address_of(user);
        create_account_for_test(core_addr);
        create_account_for_test(user_addr);
        create_account_for_test(ac_fund_addr);

        let now = timestamp::now_seconds();
        let burn_period = 300;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, 7000, 8, 15, 300);

        gpass::create_wallet(user);
        assert!(gpass::get_balance(user_addr) == 0, 1);
        assert!(gpass::get_last_burned(user_addr) == now, 2);

        gpass::mint_to(core_addr, user_addr, 5);
        assert!(gpass::get_balance(user_addr) == 5, 3);
        assert!(gpass::get_total_amount(core_addr) == 5, 4);

        gpass::mint_to(core_addr, user_addr, 10);
        assert!(gpass::get_balance(user_addr) == 15, 5);
        assert!(gpass::get_total_amount(core_addr) == 15, 6);

        timestamp::update_global_time_for_test_secs(now + burn_period);

        gpass::mint_to(core_addr, user_addr, 5);
        assert!(gpass::get_balance(user_addr) == 5, 8);
        assert!(gpass::get_total_amount(core_addr) == 5, 9);
    }

    #[test(core_signer = @ggwp_core, accumulative_fund = @0x11112222, burner=@0x1212, user1 = @0x11, user2 = @0x22)]
    public entry fun burn_with_burns(core_signer: &signer, accumulative_fund: &signer, burner: &signer, user1: &signer, user2: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let burner_addr = signer::address_of(burner);
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        create_account_for_test(core_addr);
        create_account_for_test(burner_addr);
        create_account_for_test(user1_addr);
        create_account_for_test(user2_addr);

        let now = timestamp::now_seconds();
        let burn_period = 300;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, 7000, 8, 15, 300);
        gpass::add_burner(core_signer, burner_addr);

        gpass::create_wallet(user1);
        gpass::create_wallet(user2);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);
        assert!(gpass::get_balance(user2_addr) == 0, 3);
        assert!(gpass::get_last_burned(user2_addr) == now, 4);

        gpass::mint_to(core_addr, user1_addr, 10);
        assert!(gpass::get_balance(user1_addr) == 10, 5);
        assert!(gpass::get_total_amount(core_addr) == 10, 6);

        gpass::mint_to(core_addr, user2_addr, 15);
        assert!(gpass::get_balance(user2_addr) == 15, 7);
        assert!(gpass::get_total_amount(core_addr) == 25, 8);

        gpass::burn_from(burner, core_addr, user2_addr, 10);
        assert!(gpass::get_balance(user2_addr) == 5, 9);
        assert!(gpass::get_total_amount(core_addr) == 15, 10);

        gpass::burn(user1, core_addr, 2);
        assert!(gpass::get_balance(user1_addr) == 8, 13);

        timestamp::update_global_time_for_test_secs(now + burn_period);

        gpass::burn_from(burner, core_addr, user1_addr, 3);
        assert!(gpass::get_balance(user1_addr) == 0, 11);
        assert!(gpass::get_total_amount(core_addr) == 5, 12);

        gpass::burn_from(burner, core_addr, user2_addr, 3);
        assert!(gpass::get_balance(user1_addr) == 0, 13);
        assert!(gpass::get_total_amount(core_addr) == 0, 14);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun unfreeze_after_burn(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 20000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 4 * 24 * 60 * 60;
        let reward_period = 24 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 5000 GGWP
        let freeze_amount1 = 5000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 5, 1);
        assert!(gpass::get_last_getting_gpass(user1_addr) == now, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_burn_period_passed(core_addr, user1_addr) == false, 1);

        // burn period + half reward period
        let now = now + burn_period + reward_period / 2;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_burn_period_passed(core_addr, user1_addr) == true, 1);

        // all burned!!
        gpass::burn(user1, core_addr, 5);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_burn_period_passed(core_addr, user1_addr) == false, 1);

        // + 2 reward_periods + some_time
        let now = now + 2 * reward_period + 2 * 60;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_burn_period_passed(core_addr, user1_addr) == false, 1);

        gpass::unfreeze(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 10, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11, user2 = @0x22)]
    public entry fun functional(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer, user2: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        let user2_addr = signer::address_of(user2);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);
        create_account_for_test(user2_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 20000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        coin::ggwp::register(user2);
        let user2_init_balance = 30000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user2_init_balance, user2_addr);
        assert!(coin::balance<GGWPCoin>(user2_addr) == user2_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 4 * 24 * 60 * 60;
        let reward_period = 24 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        gpass::create_wallet(user2);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);
        assert!(gpass::get_balance(user2_addr) == 0, 3);
        assert!(gpass::get_last_burned(user2_addr) == now, 4);

        // User1 freeze 5000 GGWP
        let freeze_amount1 = 5000 * 100000000;
        let royalty_amount1 = gpass::calc_royalty_amount(freeze_amount1, 8);
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(coin::balance<GGWPCoin>(user1_addr) == (user1_init_balance - freeze_amount1 - royalty_amount1), 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == royalty_amount1, 1);
        assert!(gpass::get_balance(user1_addr) == 5, 1);
        assert!(gpass::get_last_getting_gpass(user1_addr) == now, 1);
        assert!(gpass::get_treasury_balance(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 1, 1);
        assert!(gpass::get_daily_gpass_reward(core_addr) == 5, 1);

        // User2 freeze 10000 GGWP
        let freeze_amount2 = 10000 * 100000000;
        let royalty_amount2 = gpass::calc_royalty_amount(freeze_amount2, 8);
        gpass::freeze_tokens(user2, core_addr, freeze_amount2);
        assert!(coin::balance<GGWPCoin>(user2_addr) == (user2_init_balance - freeze_amount2 - royalty_amount2), 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == royalty_amount1 + royalty_amount2, 1);
        assert!(gpass::get_balance(user2_addr) == 10, 1);
        assert!(gpass::get_last_getting_gpass(user2_addr) == now, 1);
        assert!(gpass::get_treasury_balance(core_addr) == freeze_amount1 + freeze_amount2, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1 + freeze_amount2, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 2, 1);

        // Check virtual gpass earned
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now + 2 * reward_period) == 10, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user2_addr, now + 2 * reward_period) == 20, 1);

        // User1 withdraw gpass before burn period
        let now = now + 2 * reward_period;
        timestamp::update_global_time_for_test_secs(now);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_last_getting_gpass(user1_addr) == now, 1);

        // User1 withdraw gpass after burn period
        // old gpass was burned, new gpass was minted for every reward_period
        let now = now + 3 * reward_period; // == burn_period + 1 reward_period
        timestamp::update_global_time_for_test_secs(now);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 5, 1);
        assert!(gpass::get_last_getting_gpass(user1_addr) == now, 1);

        // User2 unfreeze tokens without unfreeze royalty
        gpass::unfreeze(user2, core_addr);
        assert!(coin::balance<GGWPCoin>(user2_addr) == (user2_init_balance - royalty_amount2), 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == royalty_amount1 + royalty_amount2, 1);
        assert!(gpass::get_freezed_amount(user2_addr) == 0, 1);
        assert!(gpass::get_balance(user2_addr) == 10, 1);
        assert!(gpass::get_last_getting_gpass(user2_addr) == now, 1);
        assert!(gpass::get_treasury_balance(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 1, 1);

        // User2 freeze and unfreeze tokens with unfreeze royalty
        let now = now + 20 * 24 * 60 * 60; // long time ago
        timestamp::update_global_time_for_test_secs(now);

        let user2_before_balance = coin::balance<GGWPCoin>(user2_addr);
        let freeze_amount3 = 15000 * 100000000;
        let royalty_amount3 = gpass::calc_royalty_amount(freeze_amount3, 8);
        gpass::freeze_tokens(user2, core_addr, freeze_amount3);

        assert!(coin::balance<GGWPCoin>(user2_addr) == (user2_before_balance - freeze_amount3 - royalty_amount3), 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == royalty_amount1 + royalty_amount2 + royalty_amount3, 1);
        assert!(gpass::get_freezed_amount(user2_addr) == freeze_amount3, 1);
        assert!(gpass::get_balance(user2_addr) == 15, 1);
        assert!(gpass::get_last_getting_gpass(user2_addr) == now, 1);
        assert!(gpass::get_treasury_balance(core_addr) == freeze_amount1 + freeze_amount3, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1 + freeze_amount3, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 2, 1);

        let unfreeze_royalty_amount = gpass::calc_royalty_amount(freeze_amount3, 15);
        gpass::unfreeze(user2, core_addr);

        assert!(coin::balance<GGWPCoin>(user2_addr) == (user2_before_balance - royalty_amount3 - unfreeze_royalty_amount), 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == royalty_amount1 + royalty_amount2 + royalty_amount3 + unfreeze_royalty_amount, 1);
        assert!(gpass::get_balance(user2_addr) == 15, 1);
        assert!(gpass::get_last_getting_gpass(user2_addr) == now, 1);
        assert!(gpass::get_treasury_balance(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 1, 1);

        // User2 freeze tokens, and withdraw only after 2 burn periods
        let freeze_amount4 = 15000 * 100000000;
        gpass::freeze_tokens(user2, core_addr, freeze_amount4);

        let now = now + 2 * burn_period + reward_period;
        timestamp::update_global_time_for_test_secs(now);

        assert!(gpass::get_earned_gpass_in_time(core_addr, user2_addr, now) == 30, 1);
        gpass::withdraw_gpass(user2, core_addr);
        assert!(gpass::get_balance(user2_addr) == 30, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user2_addr, now) == 0, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun freeze_tokens_test(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 20000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 24 * 60 * 60;
        let reward_period = 6 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 15000 GGWP
        let freeze_amount1 = 15000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_last_getting_gpass(user1_addr) == now, 1);
        assert!(gpass::get_total_freezed(core_addr) == freeze_amount1, 1);
        assert!(gpass::get_total_users_freezed(core_addr) == 1, 1);

        // Wait burn_period
        let now = now + burn_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
        // gpass::withdraw_gpass(user1, core_addr); // error zero gpass earned

        // Wait 2*reward_period
        let now = now + 2 * reward_period;
        timestamp::update_global_time_for_test_secs(now);

        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 30, 1);
        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun get_earned_gpass_in_time_without_withdraw_test(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 20000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 24 * 60 * 60;
        let reward_period = 6 * 60 * 60;
        let half_period = 3 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 15000 GGWP
        let freeze_amount1 = 15000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        let now = now + burn_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 30, 1);

        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 30, 1);

        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 45, 1);

        // 1 burn period + 3 reward periods + 2 * burn period + half_period = 45
        let now = now + 2 * burn_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 45, 1);

        // + half period = 3 burn periods = 0
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun get_earned_gpass_in_time_with_withdraw_test(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 20000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 24 * 60 * 60;
        let reward_period = 6 * 60 * 60;
        let half_period = 3 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 15000 GGWP
        let freeze_amount1 = 15000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // after 1 burn_period = 0
        let now = now + (burn_period - reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 rewards
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        // to burn
        let now = now + (burn_period - 2* reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // to burn again
        let now = now + burn_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 reward + half
        let now = now + reward_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // + half = 3 reward
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun get_earned_gpass_in_time_with_unfreeze_test(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 60000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 24 * 60 * 60;
        let reward_period = 6 * 60 * 60;
        let half_period = 3 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 15000 GGWP
        let freeze_amount1 = 15000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // after 1 burn_period = 0
        let now = now + (burn_period - reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward after burn
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 rewards after burn
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        // to new burn
        let now = now + (burn_period - 2 * reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // to burn again
        let now = now + burn_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 reward + half
        let now = now + reward_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // + half + half = 3.5 reward
        let now = now + half_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::unfreeze(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // Freeze after 3.5 rewards
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 45 + 15, 1);

        // + half = burn all (4 rewards = 1 burn)
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
        assert!(gpass::get_virtual_balance(user1_addr, core_addr) == 0, 1);

        // + half = 1 reward since refreeze
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // + reward_period = 2 reward since refreeze
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);

        // + reward_period + half = 3.5 reward since refreeze
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::unfreeze(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 45, 1);

        // Freeze after 3 rewards (3.5 from refreze)
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 45 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
    }

    #[test(core_signer = @ggwp_core, ggwp_coin = @coin, accumulative_fund = @0x11112222, user1 = @0x11)]
    public entry fun get_earned_gpass_in_time_with_unfreeze_test2(core_signer: &signer, ggwp_coin: &signer, accumulative_fund: &signer, user1: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(accumulative_fund);
        let core_addr = signer::address_of(core_signer);
        let user1_addr = signer::address_of(user1);
        create_account_for_test(ac_fund_addr);
        create_account_for_test(core_addr);
        create_account_for_test(user1_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);

        coin::ggwp::register(user1);
        let user1_init_balance = 60000 * 100000000;
        coin::ggwp::mint_to(ggwp_coin, user1_init_balance, user1_addr);
        assert!(coin::balance<GGWPCoin>(user1_addr) == user1_init_balance, 1);

        let now = timestamp::now_seconds();
        let burn_period = 24 * 60 * 60;
        let reward_period = 6 * 60 * 60;
        let half_period = 3 * 60 * 60;
        let unfreeze_lock_period = 2 * 24 * 60 * 60;
        gpass::initialize(core_signer, ac_fund_addr, burn_period, reward_period, 8, 15, unfreeze_lock_period);
        gpass::add_reward_table_row(core_signer, 5000 * 100000000, 5);
        gpass::add_reward_table_row(core_signer, 10000 * 100000000, 10);
        gpass::add_reward_table_row(core_signer, 15000 * 100000000, 15);

        gpass::create_wallet(user1);
        assert!(gpass::get_balance(user1_addr) == 0, 1);
        assert!(gpass::get_last_burned(user1_addr) == now, 2);

        // User1 freeze 15000 GGWP
        let freeze_amount1 = 15000 * 100000000;
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // after 1 burn_period = 0
        let now = now + (burn_period - reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward after burn
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 rewards after burn
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        // to new burn
        let now = now + (burn_period - 2 * reward_period);
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // to burn again
        let now = now + burn_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 1 reward
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // 2 reward + half
        let now = now + reward_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::withdraw_gpass(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // + half + half = 3.5 reward
        let now = now + half_period + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        gpass::unfreeze(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 15 + 15 + 15, 1);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);

        // Freeze after 3.5 rewards
        gpass::freeze_tokens(user1, core_addr, freeze_amount1);
        assert!(gpass::get_balance(user1_addr) == 45 + 15, 1);

        // + half = burn all (4 rewards = 1 burn)
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 0, 1);
        assert!(gpass::get_virtual_balance(user1_addr, core_addr) == 0, 1);

        // + half = 1 reward since refreeze
        let now = now + half_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 15, 1);

        // + reward_period = 2 reward since refreeze
        let now = now + reward_period;
        timestamp::update_global_time_for_test_secs(now);
        assert!(gpass::get_earned_gpass_in_time(core_addr, user1_addr, now) == 30, 1);

        gpass::unfreeze(user1, core_addr);
        assert!(gpass::get_balance(user1_addr) == 30, 1);
    }
}

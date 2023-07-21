#[test_only]
module gateway::gateway_test {
    use std::signer;
    use std::string;
    use aptos_framework::genesis;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::account::create_account_for_test;

    use gateway::gateway;
    use coin::ggwp::GGWPCoin;
    use ggwp_core::gpass;

    // Errors from gateway module
    const ERR_NOT_AUTHORIZED: u64 = 0x1000;
    const ERR_NOT_INITIALIZED: u64 = 0x1001;
    const ERR_ALREADY_INITIALIZED: u64 = 0x1002;
    const ERR_ZERO_DEPOSIT_AMOUNT: u64 = 0x1003;
    const ERR_PROJECT_NOT_EXISTS: u64 = 0x1004;
    const ERR_PROJECT_BLOCKED: u64 = 0x1005;
    const ERR_INVALID_PROJECT_ID: u64 = 0x1006;
    const ERR_INVALID_PROJECT_NAME: u64 = 0x1007;
    const ERR_INVALID_GPASS_COST: u64 = 0x1008;
    const ERR_ALREADY_REMOVED: u64 = 0x1009;
    const ERR_ALREADY_BLOCKED: u64 = 0x1010;
    const ERR_NOT_BLOCKED: u64 = 0x1011;
    const ERR_NOT_ENOUGH_GPASS: u64 = 0x1012;
    const ERR_PLAYER_INFO_NOT_EXISTS: u64 = 0x1013;
    const ERR_PLAYER_BLOCKED: u64 = 0x1014;
    const ERR_INVALID_GAME_SESSION_STATUS: u64 = 0x1015;
    const ERR_MISSING_GAME_SESSION: u64 = 0x1016;
    const ERR_GAME_SESSION_ALREADY_FINALIZED: u64 = 0x1017;
    const ERR_EMPTY_GAMES_REWARD_FUND: u64 = 0x1018;
    const ERR_GAME_SESSION_ALREADY_STARTED: u64 = 0x1019;
    const ERR_TIME_FRAME_NOT_PASSED: u64 = 0x1020;
    const ERR_INVALID_BURN_PERIOD: u64 = 0x1021;
    const ERR_INVALID_ERASE_HISTORY: u64 = 0x1022;
    const ERR_NO_REWARD: u64 = 0x1023;

    // CONST
    const MAX_PROJECT_NAME_LEN: u64 = 128;

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    public entry fun skip_calculate_time_frame_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, _contributor1_addr, _contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 244;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);
        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player2_addr);
        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);

        let now = timestamp::now_seconds();
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 1
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 2
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 3
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 0
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 1
        gateway::calculate_time_frame(gateway);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    public entry fun get_reward_before_first_finalize_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, _contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 244;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);
        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player2_addr);

        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);

        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::get_player_reward(player1, gateway_addr);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    public entry fun long_time_burn_period_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 244;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);
        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        // 244 rows in history vector test (while)
        let now = timestamp::now_seconds();
        let i = 0;
        while (i < 244) {
            coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player1_addr);
            coin::ggwp::mint_to(ggwp_coin, 1080 * 100000000, player2_addr);

            gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
            gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);

            gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
            gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
            gateway::start_game(player2, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
            gateway::start_game(player2, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
            gateway::finalize_game(player1, gateway_addr, contributor1_addr, 1, 1);
            gateway::finalize_game(player1, gateway_addr, contributor2_addr, 2, 1);
            gateway::finalize_game(player2, gateway_addr, contributor1_addr, 1, 1);
            gateway::finalize_game(player2, gateway_addr, contributor2_addr, 2, 1);

            now = now + time_frame;
            timestamp::update_global_time_for_test_secs(now);
            gateway::calculate_time_frame(gateway);

            if (i == 240) {
                let balance = coin::balance<GGWPCoin>(player2_addr);
                gateway::get_player_reward(player2, gateway_addr);
                assert!(balance < coin::balance<GGWPCoin>(player2_addr), 1);
            };

            gpass::unfreeze(player1, ggwp_core_addr);
            gpass::unfreeze(player2, ggwp_core_addr);
            i = i + 1;
        };

        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);

        // finalize game for user1 first it burns history
        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::finalize_game(player1, gateway_addr, contributor1_addr, 1, 1);

        let balance = coin::balance<GGWPCoin>(player1_addr);
        gateway::get_player_reward(player1, gateway_addr);
        assert!(balance == coin::balance<GGWPCoin>(player1_addr), 1);

        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);

        let balance = coin::balance<GGWPCoin>(player1_addr);
        gateway::get_player_reward(player1, gateway_addr);
        assert!(balance < coin::balance<GGWPCoin>(player1_addr), 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    public entry fun burned_rewards_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player1_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player1_addr) == 10000 * 100000000, 1);
        gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player2_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player2_addr) == 10000 * 100000000, 1);

        let now = timestamp::now_seconds();
        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        let ac_balance = coin::balance<GGWPCoin>(ac_fund_addr);
        let grf_balance = gateway::games_reward_fund_balance(gateway_addr);

        // frame = 0
        // User1 plays in both projects in first frame and loose
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
        gateway::finalize_game(player1, gateway_addr, contributor1_addr, 1, 2);
        gateway::finalize_game(player1, gateway_addr, contributor2_addr, 2, 2);

        // User2 plays in 2 project in second frame and win
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 1
        gateway::calculate_time_frame(gateway);

        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == ac_balance, 1);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == grf_balance, 1);

        gateway::start_game(player2, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
        gateway::finalize_game(player2, gateway_addr, contributor2_addr, 2, 2);

        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == ac_balance, 1);

        // Skip to burn period - all clear - funds accumulative fund
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now); // frame = 2
        gateway::calculate_time_frame(gateway);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == ac_balance, 1);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == grf_balance, 1);
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == ac_balance, 1);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == grf_balance, 1);
        // index 0
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);

        assert!(coin::balance<GGWPCoin>(ac_fund_addr) > ac_balance, 1);
        assert!(gateway::games_reward_fund_balance(gateway_addr) < grf_balance, 1);
        let ac_balance = coin::balance<GGWPCoin>(ac_fund_addr);
        let grf_balance = gateway::games_reward_fund_balance(gateway_addr);

        // New cicle
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == ac_balance, 1);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == grf_balance, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    public entry fun get_reward_simple_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player1_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player1_addr) == 10000 * 100000000, 1);
        gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player2_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player2_addr) == 10000 * 100000000, 1);

        let now = timestamp::now_seconds();
        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::start_game(player2, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
        gateway::finalize_game(player1, gateway_addr, contributor1_addr, 1, 1);
        gateway::finalize_game(player2, gateway_addr, contributor1_addr, 1, 2);
        gateway::finalize_game(player1, gateway_addr, contributor2_addr, 2, 2);

        // Get reward in current frame (0) - user gets 0
        gateway::get_player_reward(player1, gateway_addr);

        // frame = 1
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);

        // Users get rewards
        gateway::get_player_reward(player1, gateway_addr);
        assert!(coin::balance<GGWPCoin>(player1_addr) == (10000 + 5520) * 100000000, 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == (640) * 100000000, 1);

        gateway::get_player_reward(player2, gateway_addr);
        assert!(coin::balance<GGWPCoin>(player2_addr) == (10000) * 100000000, 1);
        gateway::get_contributor_reward(contributor1, gateway_addr);
        assert!(coin::balance<GGWPCoin>(contributor1_addr) == (1380) * 100000000, 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == (640 + 120) * 100000000, 1);
        gateway::get_contributor_reward(contributor2, gateway_addr);
        assert!(coin::balance<GGWPCoin>(contributor2_addr) == (1380) * 100000000, 1);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == (640 + 120 + 120) * 100000000, 1);

        // User2 wins in project 1 once
        gateway::start_game(player2, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::finalize_game(player2, gateway_addr, contributor1_addr, 1, 1);

        // No reward for this frame anymore
        gateway::get_player_reward(player1, gateway_addr);
        assert!(coin::balance<GGWPCoin>(player1_addr) == (10000 + 5520) * 100000000, 1);
        gateway::get_player_reward(player2, gateway_addr);
        assert!(coin::balance<GGWPCoin>(player2_addr) == (10000) * 100000000, 1);

        // Skip to burn period
        // frame = 2
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);
        // frame = 3
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);
        // frame = 0
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);

        // User2 rewards burned
        gateway::get_player_reward(player2, gateway_addr);
        assert!(coin::balance<GGWPCoin>(player2_addr) == (10000) * 100000000, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor1 = @0x2222, contributor2 = @0x22221, player1 = @0x1111, player2 = @0x11112)]
    #[expected_failure(abort_code = ERR_TIME_FRAME_NOT_PASSED, location = gateway::gateway)]
    public entry fun double_calculate_in_frame_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, contributor2_addr, player1_addr, player2_addr)
            = fixture_setup2(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor1, contributor2, player1, player2);

        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player1_addr);
        coin::ggwp::mint_to(ggwp_coin, 11080 * 100000000, player2_addr);

        coin::ggwp::mint_to(ggwp_coin, 300000000 * 100000000, ac_fund_addr);

        gpass::add_reward_table_row(ggwp_core, 500 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 1000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 1500 * 100000000, 15);

        gpass::freeze_tokens(player1, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player1_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player1_addr) == 10000 * 100000000, 1);
        gpass::freeze_tokens(player2, ggwp_core_addr, 1000 * 100000000);
        assert!(gpass::get_balance(player2_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player2_addr) == 10000 * 100000000, 1);

        let now = timestamp::now_seconds();
        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        gateway::games_reward_fund_deposit(accumulative_fund, gateway_addr, 300000000 * 100000000);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game 1");
        gateway::sign_up(contributor1, gateway_addr, project_name, gpass_cost);
        let gpass_cost = 2;
        let project_name = string::utf8(b"test project game 2");
        gateway::sign_up(contributor2, gateway_addr, project_name, gpass_cost);

        // User1 plays in both projects in first frame and loose
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor1_addr, 1);
        gateway::start_game(player1, gateway_addr, ggwp_core_addr, contributor2_addr, 2);
        gateway::finalize_game(player1, gateway_addr, contributor1_addr, 1, 2);
        gateway::finalize_game(player1, gateway_addr, contributor2_addr, 2, 2);

        // User2 plays in 2 project in second frame and win
        now = now + time_frame;
        timestamp::update_global_time_for_test_secs(now);
        gateway::calculate_time_frame(gateway);
        // expected error
        gateway::calculate_time_frame(gateway);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun start_game_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        coin::ggwp::mint_to(ggwp_coin, 1100000000000, player_addr);

        gpass::add_reward_table_row(ggwp_core, 5000 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 10000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 15000 * 100000000, 15);

        gpass::freeze_tokens(player, ggwp_core_addr, 1000000000000);
        assert!(gpass::get_balance(player_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player_addr) == 20000000000, 1);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 1;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
        let project_name = string::utf8(b"test project game 2");
        // player is second contributor
        gateway::sign_up(player, gateway_addr, project_name, gpass_cost);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
        assert!(gateway::get_is_open_session(player_addr, 1) == true, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 3, 1);
        assert!(gateway::get_is_open_session(player_addr, 2) == false, 1);
        assert!(gateway::get_session_status(player_addr, 2) == 4, 1);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, player_addr, 2);
        assert!(gateway::get_is_open_session(player_addr, 1) == true, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 3, 1);
        assert!(gateway::get_is_open_session(player_addr, 2) == true, 1);
        assert!(gateway::get_session_status(player_addr, 2) == 3, 1);

        gateway::finalize_game(player, gateway_addr, contributor_addr, 1, 2);
        assert!(gateway::get_is_open_session(player_addr, 1) == false, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 4, 1);
        assert!(gateway::get_is_open_session(player_addr, 2) == true, 1);
        assert!(gateway::get_session_status(player_addr, 2) == 3, 1);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
        assert!(gateway::get_is_open_session(player_addr, 1) == true, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 3, 1);
        assert!(gateway::get_is_open_session(player_addr, 2) == true, 1);
        assert!(gateway::get_session_status(player_addr, 2) == 3, 1);

        gateway::finalize_game(player, gateway_addr, player_addr, 2, 0);
        assert!(gateway::get_is_open_session(player_addr, 1) == true, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 3, 1);
        assert!(gateway::get_is_open_session(player_addr, 2) == false, 1);
        assert!(gateway::get_session_status(player_addr, 2) == 4, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_GAME_SESSION_ALREADY_STARTED, location = gateway::gateway)]
    public entry fun start_two_games_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        coin::ggwp::mint_to(ggwp_coin, 1100000000000, player_addr);

        gpass::add_reward_table_row(ggwp_core, 5000 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 10000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 15000 * 100000000, 15);

        gpass::freeze_tokens(player, ggwp_core_addr, 1000000000000);
        assert!(gpass::get_balance(player_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player_addr) == 20000000000, 1);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);

        assert!(gateway::get_is_open_session(player_addr, 1) == false, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 4, 1);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
        assert!(gateway::get_is_open_session(player_addr, 1) == true, 1);
        assert!(gateway::get_session_status(player_addr, 1) == 3, 1);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun block_unblock_player_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        coin::ggwp::mint_to(ggwp_coin, 1100000000000, player_addr);

        gpass::add_reward_table_row(ggwp_core, 5000 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 10000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 15000 * 100000000, 15);

        gpass::freeze_tokens(player, ggwp_core_addr, 1000000000000);
        assert!(gpass::get_balance(player_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player_addr) == 20000000000, 1);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
        assert!(gateway::get_player_is_blocked(player_addr) == false, 1);

        let reason = string::utf8(b"Test reason");
        gateway::block_player(gateway, player_addr, reason);
        assert!(gateway::get_player_is_blocked(player_addr) == true, 1);

        gateway::unblock_player(gateway, player_addr);
        assert!(gateway::get_player_is_blocked(player_addr) == false, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_PLAYER_BLOCKED, location = gateway::gateway)]
    public entry fun blocked_player_start_game_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        coin::ggwp::mint_to(ggwp_coin, 1100000000000, player_addr);

        gpass::add_reward_table_row(ggwp_core, 5000 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 10000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 15000 * 100000000, 15);

        gpass::freeze_tokens(player, ggwp_core_addr, 1000000000000);
        assert!(gpass::get_balance(player_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player_addr) == 20000000000, 1);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);

        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
        assert!(gateway::get_player_is_blocked(player_addr) == false, 1);

        let reason = string::utf8(b"Test reason");
        gateway::block_player(gateway, player_addr, reason);
        assert!(gateway::get_player_is_blocked(player_addr) == true, 1);

        // Blocked player start the game
        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun block_unblock_project_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);

        // Block project
        let reason = string::utf8(b"Test reason");
        gateway::block_project(gateway, contributor_addr, 1, reason);
        assert!(gateway::get_project_is_blocked(contributor_addr) == true, 1);

        // Unblock project
        gateway::unblock_project(gateway, contributor_addr, 1);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_PROJECT_BLOCKED, location = gateway::gateway)]
    public entry fun start_game_in_blocked_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test project game");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);

        // Block project
        let reason = string::utf8(b"Test reason");
        gateway::block_project(gateway, contributor_addr, 1, reason);
        assert!(gateway::get_project_is_blocked(contributor_addr) == true, 1);

        // player try to start game in blocked project
        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_INVALID_PROJECT_NAME, location = gateway::gateway)]
    public entry fun invalid_project_name_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, _contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"");
        while (string::length(&project_name) != MAX_PROJECT_NAME_LEN + 1) {
            string::append(&mut project_name, string::utf8(b"a"));
        };
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_INVALID_PROJECT_NAME, location = gateway::gateway)]
    public entry fun invalid_project_name_test2(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, _contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 5;
        let project_name = string::utf8(b"");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun sign_up_remove_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);
        assert!(gateway::get_project_counter(gateway_addr) == 1, 1);

        let gpass_cost = 5;
        let project_name = string::utf8(b"test game project");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
        assert!(gateway::get_project_counter(gateway_addr) == 2, 1);
        assert!(gateway::get_project_id(contributor_addr) == 1, 1);
        assert!(gateway::get_project_gpass_cost(contributor_addr) == gpass_cost, 1);
        assert!(gateway::get_project_name(contributor_addr) == project_name, 1);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);
        assert!(gateway::get_project_is_removed(contributor_addr) == false, 1);

        gateway::remove(contributor, gateway_addr);
        assert!(gateway::get_project_id(contributor_addr) == 0, 1);
        assert!(gateway::get_project_gpass_cost(contributor_addr) == 0, 1);
        assert!(gateway::get_project_name(contributor_addr) == string::utf8(b""), 1);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);
        assert!(gateway::get_project_is_removed(contributor_addr) == true, 1);

        let gpass_cost = 10;
        let project_name = string::utf8(b"another test game project");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);
        assert!(gateway::get_project_counter(gateway_addr) == 3, 1);
        assert!(gateway::get_project_id(contributor_addr) == 2, 1);
        assert!(gateway::get_project_gpass_cost(contributor_addr) == gpass_cost, 1);
        assert!(gateway::get_project_name(contributor_addr) == project_name, 1);
        assert!(gateway::get_project_is_blocked(contributor_addr) == false, 1);
        assert!(gateway::get_project_is_removed(contributor_addr) == false, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun games_reward_fund_deposit_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == 0, 1);

        coin::ggwp::register(contributor);
        coin::ggwp::mint_to(ggwp_coin, 500000000000, contributor_addr);
        assert!(coin::balance<GGWPCoin>(contributor_addr) == 500000000000, 1);

        let fund_amount = 250000000000;
        gateway::games_reward_fund_deposit(contributor, gateway_addr, fund_amount);
        assert!(gateway::games_reward_fund_balance(gateway_addr) == fund_amount, 1);
        assert!(coin::balance<GGWPCoin>(contributor_addr) == 250000000000, 1);

        let fund_amount = 250000000000;
        gateway::games_reward_fund_deposit(contributor, gateway_addr, fund_amount );
        assert!(gateway::games_reward_fund_balance(gateway_addr) == fund_amount * 2, 1);
        assert!(coin::balance<GGWPCoin>(contributor_addr) == 0, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    public entry fun accumulative_fund_update_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, _ggwp_core_addr, ac_fund_addr, _contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);
        assert!(gateway::get_accumulative_fund_addr(gateway_addr) == ac_fund_addr, 1);

        let new_ac_fund_addr = @44332211;
        gateway::update_accumulative_fund(gateway, new_ac_fund_addr);
        assert!(gateway::get_accumulative_fund_addr(gateway_addr) == new_ac_fund_addr, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_PROJECT_NOT_EXISTS, location = gateway::gateway)]
    public entry fun unexists_project_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, _player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        // player start game in unexists project
        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
    }

    #[test(gateway = @gateway, ggwp_coin = @coin, ggwp_core = @ggwp_core, accumulative_fund = @0x11223344, contributor = @0x2222, player = @0x1111)]
    #[expected_failure(abort_code = ERR_NOT_ENOUGH_GPASS, location = gateway::gateway)]
    public entry fun not_enough_gpass_test(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer) {
        let (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
            = fixture_setup(gateway, ggwp_coin, ggwp_core, accumulative_fund, contributor, player);

        coin::ggwp::mint_to(ggwp_coin, 1100000000000, player_addr);

        gpass::add_reward_table_row(ggwp_core, 5000 * 100000000, 5);
        gpass::add_reward_table_row(ggwp_core, 10000 * 100000000, 10);
        gpass::add_reward_table_row(ggwp_core, 15000 * 100000000, 15);

        gpass::freeze_tokens(player, ggwp_core_addr, 1000000000000);
        assert!(gpass::get_balance(player_addr) == 10, 1);
        assert!(coin::balance<GGWPCoin>(player_addr) == 20000000000, 1);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(gateway, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let gpass_cost = 20;
        let project_name = string::utf8(b"test game project");
        gateway::sign_up(contributor, gateway_addr, project_name, gpass_cost);

        // Player start game without GPASS
        gateway::start_game(player, gateway_addr, ggwp_core_addr, contributor_addr, 1);
    }

    fun fixture_setup(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor: &signer, player: &signer)
    : (address, address, address, address, address) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669882762);

        let gateway_addr = signer::address_of(gateway);
        create_account_for_test(gateway_addr);
        let ggwp_core_addr = signer::address_of(ggwp_core);
        create_account_for_test(ggwp_core_addr);
        let ac_fund_addr = signer::address_of(accumulative_fund);
        create_account_for_test(ac_fund_addr);
        let contributor_addr = signer::address_of(contributor);
        create_account_for_test(contributor_addr);
        let player_addr = signer::address_of(player);
        create_account_for_test(player_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);
        coin::ggwp::register(gateway);
        assert!(coin::balance<GGWPCoin>(gateway_addr) == 0, 1);
        coin::ggwp::register(player);
        assert!(coin::balance<GGWPCoin>(player_addr) == 0, 1);

        gpass::initialize(ggwp_core, ac_fund_addr, 5000, 5000, 8, 15, 300);
        gpass::create_wallet(player);

        (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor_addr, player_addr)
    }

    fun fixture_setup2(gateway: &signer, ggwp_coin: &signer, ggwp_core: &signer, accumulative_fund: &signer, contributor1: &signer, contributor2: &signer, player1: &signer, player2: &signer)
    : (address, address, address, address, address, address, address) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669882762);

        let gateway_addr = signer::address_of(gateway);
        create_account_for_test(gateway_addr);
        let ggwp_core_addr = signer::address_of(ggwp_core);
        create_account_for_test(ggwp_core_addr);
        let ac_fund_addr = signer::address_of(accumulative_fund);
        create_account_for_test(ac_fund_addr);
        let contributor1_addr = signer::address_of(contributor1);
        create_account_for_test(contributor1_addr);
        let contributor2_addr = signer::address_of(contributor2);
        create_account_for_test(contributor2_addr);
        let player1_addr = signer::address_of(player1);
        create_account_for_test(player1_addr);
        let player2_addr = signer::address_of(player2);
        create_account_for_test(player2_addr);

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(accumulative_fund);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);
        coin::ggwp::register(gateway);
        assert!(coin::balance<GGWPCoin>(gateway_addr) == 0, 1);
        coin::ggwp::register(contributor1);
        assert!(coin::balance<GGWPCoin>(contributor1_addr) == 0, 1);
        coin::ggwp::register(contributor2);
        assert!(coin::balance<GGWPCoin>(contributor2_addr) == 0, 1);
        coin::ggwp::register(player1);
        assert!(coin::balance<GGWPCoin>(player1_addr) == 0, 1);
        coin::ggwp::register(player2);
        assert!(coin::balance<GGWPCoin>(player2_addr) == 0, 1);

        gpass::initialize(ggwp_core, ac_fund_addr, 5000, 5000, 8, 15, 300);
        gpass::create_wallet(player1);
        gpass::create_wallet(player2);

        (gateway_addr, ggwp_core_addr, ac_fund_addr, contributor1_addr, contributor2_addr, player1_addr, player2_addr)
    }
}

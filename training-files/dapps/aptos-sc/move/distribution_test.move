module accumulative_fund::distribution_test {
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::genesis;
    use aptos_framework::account::create_account_for_test;

    use accumulative_fund::distribution;
    use coin::ggwp::GGWPCoin;
    use gateway::gateway;

    #[test(ac_fund_signer = @accumulative_fund)]
    public fun update_shares_test(ac_fund_signer: &signer) {
        genesis::setup();

        let ac_fund_addr = signer::address_of(ac_fund_signer);
        create_account_for_test(ac_fund_addr);

        let games_reward_fund = @0x1111;
        let games_reward_fund_share = 80;
        let company_fund = @0x1133;
        let company_fund_share = 10;
        let team_fund = @0x1144;
        let team_fund_share = 10;
        distribution::initialize(ac_fund_signer,
            games_reward_fund,
            games_reward_fund_share,
            company_fund,
            company_fund_share,
            team_fund,
            team_fund_share,
        );

        assert!(distribution::get_games_reward_fund(ac_fund_addr) == games_reward_fund, 1);
        assert!(distribution::get_games_reward_fund_share(ac_fund_addr) == games_reward_fund_share, 1);
        assert!(distribution::get_company_fund(ac_fund_addr) == company_fund, 1);
        assert!(distribution::get_company_fund_share(ac_fund_addr) == company_fund_share, 1);
        assert!(distribution::get_team_fund(ac_fund_addr) == team_fund, 1);
        assert!(distribution::get_team_fund_share(ac_fund_addr) == team_fund_share, 1);

        distribution::update_shares(ac_fund_signer, 30, 50, 20);
        assert!(distribution::get_games_reward_fund_share(ac_fund_addr) == 30, 1);
        assert!(distribution::get_company_fund_share(ac_fund_addr) == 50, 1);
        assert!(distribution::get_team_fund_share(ac_fund_addr) == 20, 1);
    }

    #[test(ac_fund_signer = @accumulative_fund, ggwp_coin = @coin, games_reward_fund = @gateway, company_fund = @0x1133, team_fund = @0x1144)]
    #[expected_failure(abort_code = 0x1004, location = accumulative_fund::distribution)]
    public fun zero_accumulative_fund_amount(ac_fund_signer: &signer, ggwp_coin: &signer, games_reward_fund: &signer, company_fund: &signer, team_fund: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(ac_fund_signer);
        create_account_for_test(ac_fund_addr);
        let games_reward_fund_addr = signer::address_of(games_reward_fund);
        create_account_for_test(games_reward_fund_addr);
        let company_fund_addr = signer::address_of(company_fund);
        create_account_for_test(company_fund_addr);
        let team_fund_addr = signer::address_of(team_fund);
        create_account_for_test(team_fund_addr);

        let games_reward_fund_share = 80;
        let company_fund_share = 10;
        let team_fund_share = 10;
        distribution::initialize(ac_fund_signer,
            games_reward_fund_addr,
            games_reward_fund_share,
            company_fund_addr,
            company_fund_share,
            team_fund_addr,
            team_fund_share,
        );

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(ac_fund_signer);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);
        coin::ggwp::register(company_fund);
        assert!(coin::balance<GGWPCoin>(company_fund_addr) == 0, 1);
        coin::ggwp::register(team_fund);
        assert!(coin::balance<GGWPCoin>(team_fund_addr) == 0, 1);

        distribution::distribute(ac_fund_signer);
    }

    #[test(ac_fund_signer = @accumulative_fund, ggwp_coin = @coin, games_reward_fund = @gateway, company_fund = @0x1133, team_fund = @0x1144)]
    public fun functional(ac_fund_signer: &signer, ggwp_coin: &signer, games_reward_fund: &signer, company_fund: &signer, team_fund: &signer) {
        genesis::setup();
        timestamp::update_global_time_for_test_secs(1669292558);

        let ac_fund_addr = signer::address_of(ac_fund_signer);
        create_account_for_test(ac_fund_addr);
        let games_reward_fund_addr = signer::address_of(games_reward_fund);
        create_account_for_test(games_reward_fund_addr);
        let company_fund_addr = signer::address_of(company_fund);
        create_account_for_test(company_fund_addr);
        let team_fund_addr = signer::address_of(team_fund);
        create_account_for_test(team_fund_addr);

        let reward_coefficient = 20000;
        let royalty = 8;
        let time_frame = 30 * 60;
        let burn_period = time_frame * 4;
        gateway::initialize(games_reward_fund, ac_fund_addr, reward_coefficient, royalty, time_frame, burn_period);

        let games_reward_fund_share = 80;
        let company_fund_share = 9;
        let team_fund_share = 11;
        distribution::initialize(ac_fund_signer,
            games_reward_fund_addr,
            games_reward_fund_share,
            company_fund_addr,
            company_fund_share,
            team_fund_addr,
            team_fund_share,
        );

        coin::ggwp::set_up_test(ggwp_coin);

        coin::ggwp::register(ac_fund_signer);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);
        coin::ggwp::register(games_reward_fund);
        assert!(gateway::games_reward_fund_balance(games_reward_fund_addr) == 0, 1);
        coin::ggwp::register(company_fund);
        assert!(coin::balance<GGWPCoin>(company_fund_addr) == 0, 1);
        coin::ggwp::register(team_fund);
        assert!(coin::balance<GGWPCoin>(team_fund_addr) == 0, 1);

        coin::ggwp::mint_to(ggwp_coin, 10000000000, ac_fund_addr);
        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 10000000000, 1);

        distribution::distribute(ac_fund_signer);

        assert!(coin::balance<GGWPCoin>(ac_fund_addr) == 0, 1);
        assert!(gateway::games_reward_fund_balance(games_reward_fund_addr) == 8000000000, 1);
        assert!(coin::balance<GGWPCoin>(company_fund_addr) == 900000000, 1);
        assert!(coin::balance<GGWPCoin>(team_fund_addr) == 1100000000, 1);
    }
}

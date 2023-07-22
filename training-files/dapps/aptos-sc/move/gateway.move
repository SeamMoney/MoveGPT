module gateway::gateway {
    use std::signer;
    use std::error;
    use std::string::{Self, String};
    use std::table::{Self, Table};
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event::{Self, EventHandle};

    use coin::ggwp::GGWPCoin;
    use ggwp_core::gpass;

    // Errors
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

    const GAME_STATUS_DRAW: u8 = 0;
    const GAME_STATUS_WIN:  u8 = 1;
    const GAME_STATUS_LOSS: u8 = 2;
    const GAME_STATUS_NONE: u8 = 3;
    const GAME_STATUS_NULL: u8 = 4;

    struct GatewayInfo has key, store {
        accumulative_fund: address,
        games_reward_fund: Coin<GGWPCoin>,
        royalty: u8,
        reward_coefficient: u64,
        project_counter: u64,

        time_frame: u64,
        last_calculate: u64,
        // <projectd_id, GamesInFrame>
        games_in_frame: Table<u64, GamesInFrame>,
        total_gpass_spent_in_frame: u64,

        burn_period: u64,
        last_burn: u64,
        history_length: u64,
        // <project_id, RewardsHistory>
        time_frames_history: vector<FrameHistory>,

        // <project_id, reward>
        contributor_rewards: Table<u64, u64>,
    }

    struct GamesInFrame has drop, store {
        gpass_spent: u64,
        wins: u64,
    }

    struct FrameHistory has store {
        games_reward_fund_share: u64,
        // <project_id, win_cost>
        projects_win_cost: Table<u64, u64>,
    }

    struct ProjectInfo has key, store {
        id: u64,
        contributor: address,
        name: String,
        is_blocked: bool,
        is_removed: bool,
        gpass_cost: u64,

        get_contributor_reward_events: EventHandle<GetContributorRewardEvent>,
    }

    struct PlayerInfo has key, store {
        is_blocked: bool,
        last_get_reward: u64,
        // <project_id, (id, tatus)>
        game_sessions: Table<u64, GameSessionInfo>,
        time_frames_history: vector<PlayerFrameHistory>,

        start_game_events: EventHandle<StartGameEvent>,
        finalize_game_events: EventHandle<FinalizeGameEvent>,
        get_reward_events: EventHandle<GetRewardEvent>,
    }

    struct GameSessionInfo has store {
        id: u64,
        status: u8,
    }

    struct PlayerFrameHistory has store {
        // <project_id, wins>
        projects_wins: Table<u64, u64>,
    }

    struct Events has key {
        deposit_events: EventHandle<DepositEvent>,

        block_project_events: EventHandle<BlockProjectEvent>,
        block_player_events: EventHandle<BlockPlayerEvent>,
        unblock_project_events: EventHandle<UnblockProjectEvent>,
        unblock_player_events: EventHandle<UnblockPlayerEvent>,

        sign_up_events: EventHandle<SignUpEvent>,
        remove_events: EventHandle<RemoveEvent>,

        new_player_events: EventHandle<NewPlayerEvent>,

        calculate_rewards_events: EventHandle<CalculateRewardsEvent>,
        burn_rewards_events: EventHandle<BurnRewardsEvent>,
    }

    struct DepositEvent has drop, store {
        funder: address,
        amount: u64,
        date: u64,
    }

    struct BlockProjectEvent has drop, store {
        project_id: u64,
        contributor: address,
        reason: String,
        date: u64,
    }

    struct BlockPlayerEvent has drop, store {
        player: address,
        reason: String,
        date: u64,
    }

    struct UnblockProjectEvent has drop, store {
        project_id: u64,
        contributor: address,
        date: u64,
    }

    struct UnblockPlayerEvent has drop, store {
        player: address,
        date: u64,
    }

    struct SignUpEvent has drop, store {
        name: String,
        contributor: address,
        project_id: u64,
        date: u64,
    }

    struct RemoveEvent has drop, store {
        project_id: u64,
        contributor: address,
        date: u64,
    }

    struct CalculateRewardsEvent has drop, store {
        players_share: u64,
        contributors_share: u64,
        total_wins: u64,
        total_gpass_spent: u64,
        last_calculate: u64,
        date: u64,
    }

    struct BurnRewardsEvent has drop, store {
        unspent_reward: u64,
        last_burn: u64,
        date: u64,
    }

    struct NewPlayerEvent has drop, store {
        player: address,
        date: u64,
    }

    struct StartGameEvent has drop, store {
        project_id: u64,
        session_id: u64,
        date: u64,
    }

    struct FinalizeGameEvent has drop, store {
        project_id: u64,
        session_id: u64,
        status: u8,
        time_frame: u64,
        date: u64,
    }

    struct GetRewardEvent has drop, store {
        reward: u64,
        frames: u64,
        wins: u64,
        last_get_reward: u64,
        date: u64,
    }

    struct GetContributorRewardEvent has drop, store {
        reward: u64,
        date: u64,
    }

    public entry fun initialize(gateway: &signer,
        accumulative_fund_addr: address,
        reward_coefficient: u64,
        royalty: u8,
        time_frame: u64,
        burn_period: u64,
    ) {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));

        if (exists<GatewayInfo>(gateway_addr) && exists<Events>(gateway_addr)) {
            assert!(false, ERR_ALREADY_INITIALIZED);
        };

        if (!exists<GatewayInfo>(gateway_addr)) {
            assert!(burn_period % time_frame == 0, ERR_INVALID_BURN_PERIOD);
            let history_length = burn_period / time_frame;
            let time_frames_history = vector::empty<FrameHistory>();
            let i = 0;
            while (i < history_length) {
                vector::push_back(&mut time_frames_history, FrameHistory {
                    games_reward_fund_share: 0,
                    projects_win_cost: table::new<u64, u64>(),
                });
                i = i + 1;
            };
            assert!(vector::length(&time_frames_history) == history_length, ERR_NOT_INITIALIZED);

            let now = timestamp::now_seconds();
            let gateway_info = GatewayInfo {
                accumulative_fund: accumulative_fund_addr,
                games_reward_fund: coin::zero<GGWPCoin>(),
                royalty: royalty,
                reward_coefficient: reward_coefficient,
                project_counter: 1,

                time_frame: time_frame,
                last_calculate: now,
                games_in_frame: table::new<u64, GamesInFrame>(),
                total_gpass_spent_in_frame: 0,

                burn_period: burn_period,
                last_burn: now,
                history_length: history_length,
                time_frames_history: time_frames_history,

                contributor_rewards: table::new<u64, u64>(),
            };
            move_to(gateway, gateway_info);
        };

        if (!exists<Events>(gateway_addr)) {
            move_to(gateway, Events {
                deposit_events: account::new_event_handle<DepositEvent>(gateway),

                block_project_events: account::new_event_handle<BlockProjectEvent>(gateway),
                block_player_events: account::new_event_handle<BlockPlayerEvent>(gateway),
                unblock_project_events: account::new_event_handle<UnblockProjectEvent>(gateway),
                unblock_player_events: account::new_event_handle<UnblockPlayerEvent>(gateway),

                sign_up_events: account::new_event_handle<SignUpEvent>(gateway),
                remove_events: account::new_event_handle<RemoveEvent>(gateway),

                new_player_events: account::new_event_handle<NewPlayerEvent>(gateway),

                calculate_rewards_events: account::new_event_handle<CalculateRewardsEvent>(gateway),
                burn_rewards_events: account::new_event_handle<BurnRewardsEvent>(gateway),
            });
        };
    }

    // Private API

    public entry fun update_params(gateway: &signer,
        reward_coefficient: u64,
        royalty: u8,
        time_frame: u64,
        burn_period: u64,
    ) acquires GatewayInfo {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);
        gateway_info.reward_coefficient = reward_coefficient;
        gateway_info.royalty = royalty;
        gateway_info.time_frame = time_frame;
        gateway_info.burn_period = burn_period;
    }

    public entry fun update_accumulative_fund(gateway: &signer,
        accumulative_fund: address,
    ) acquires GatewayInfo {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);
        gateway_info.accumulative_fund = accumulative_fund;
    }

    public entry fun games_reward_fund_deposit(funder: &signer, gateway_addr: address, amount: u64) acquires GatewayInfo, Events {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(amount != 0, ERR_ZERO_DEPOSIT_AMOUNT);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);
        let deposit_coins = coin::withdraw<GGWPCoin>(funder, amount);
        coin::merge(&mut gateway_info.games_reward_fund, deposit_coins);

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<DepositEvent>(
            &mut events.deposit_events,
            DepositEvent { funder: signer::address_of(funder), amount: amount, date: now },
        );
    }

    public entry fun block_project(gateway: &signer, contributor_addr: address, project_id: u64, reason: String) acquires ProjectInfo, Events {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<ProjectInfo>(contributor_addr), ERR_PROJECT_NOT_EXISTS);
        let project_info = borrow_global_mut<ProjectInfo>(contributor_addr);
        assert!(project_info.id == project_id, ERR_INVALID_PROJECT_ID);
        assert!(project_info.is_removed == false, ERR_ALREADY_REMOVED);
        assert!(project_info.is_blocked == false, ERR_ALREADY_BLOCKED);

        project_info.is_blocked = true;

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<BlockProjectEvent>(
            &mut events.block_project_events,
            BlockProjectEvent {
                project_id: project_id,
                contributor: contributor_addr,
                reason: reason,
                date: now
            }
        );
    }

    public entry fun block_player(gateway: &signer, player_addr: address, reason: String) acquires PlayerInfo, Events {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<PlayerInfo>(player_addr), ERR_PLAYER_INFO_NOT_EXISTS);
        let player_info = borrow_global_mut<PlayerInfo>(player_addr);
        assert!(player_info.is_blocked == false, ERR_ALREADY_BLOCKED);

        player_info.is_blocked = true;

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<BlockPlayerEvent>(
            &mut events.block_player_events,
            BlockPlayerEvent {
                player: player_addr,
                reason: reason,
                date: now
            }
        );
    }

    public entry fun unblock_project(gateway: &signer, contributor_addr: address, project_id: u64) acquires ProjectInfo, Events {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<ProjectInfo>(contributor_addr), ERR_PROJECT_NOT_EXISTS);
        let project_info = borrow_global_mut<ProjectInfo>(contributor_addr);
        assert!(project_info.id == project_id, ERR_INVALID_PROJECT_ID);
        assert!(project_info.is_removed == false, ERR_ALREADY_REMOVED);
        assert!(project_info.is_blocked == true, ERR_NOT_BLOCKED);

        project_info.is_blocked = false;

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<UnblockProjectEvent>(
            &mut events.unblock_project_events,
            UnblockProjectEvent {
                project_id: project_info.id,
                contributor: contributor_addr,
                date: now
            }
        );
    }

    public entry fun unblock_player(gateway: &signer, player_addr: address) acquires PlayerInfo, Events {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<PlayerInfo>(player_addr), ERR_PLAYER_INFO_NOT_EXISTS);
        let player_info = borrow_global_mut<PlayerInfo>(player_addr);
        assert!(player_info.is_blocked == true, ERR_NOT_BLOCKED);

        player_info.is_blocked = false;

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<UnblockPlayerEvent>(
            &mut events.unblock_player_events,
            UnblockPlayerEvent {
                player: player_addr,
                date: now
            }
        );
    }

    public entry fun calculate_time_frame(gateway: &signer) acquires GatewayInfo, Events {
        let gateway_addr = signer::address_of(gateway);
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);
        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();

        let since_burn = now - gateway_info.last_burn;
        let current_time_frame = since_burn / gateway_info.time_frame;
        let need_erase = false;
        if (current_time_frame == gateway_info.history_length) {
            need_erase = true;
        };

        // Check double calculate frame
        let since_last_calculate = now - gateway_info.last_calculate;
        let spent_frames_since_last_calculate = since_last_calculate / gateway_info.time_frame;
        if (spent_frames_since_last_calculate == 0) {
            assert!(false, ERR_TIME_FRAME_NOT_PASSED);
        };

        if (need_erase) {
            // Erase history and send unspent reward into accumulative fund
            let unspent_reward = 0;
            let index = 0;
            while (index < gateway_info.history_length) {
                let unspent = erase_history_item(&mut gateway_info.time_frames_history, index, gateway_info.project_counter);
                unspent_reward = unspent_reward + unspent;
                index = index + 1;
            };

            let unspent_reward_coins = coin::extract(&mut gateway_info.games_reward_fund, unspent_reward);
            coin::deposit(gateway_info.accumulative_fund, unspent_reward_coins);

            event::emit_event<BurnRewardsEvent>(
                &mut events.burn_rewards_events,
                BurnRewardsEvent {
                    unspent_reward: unspent_reward,
                    last_burn: gateway_info.last_burn,
                    date: now
                },
            );

            gateway_info.last_burn = gateway_info.last_burn + (current_time_frame * gateway_info.time_frame);
            current_time_frame = 0;
        };

        // Calculate for past none calculated time frame
        let history_index = current_time_frame;

        let frame_history_entry = vector::borrow_mut<FrameHistory>(&mut gateway_info.time_frames_history, history_index);
        let games_reward_fund_amount = coin::value<GGWPCoin>(&gateway_info.games_reward_fund);
        let games_reward_fund_share = games_reward_fund_amount / gateway_info.reward_coefficient;
        // 20% to contributors
        let games_reward_fund_contributors_share = games_reward_fund_share / 100 * 20;
        games_reward_fund_share = games_reward_fund_share - games_reward_fund_contributors_share;
        frame_history_entry.games_reward_fund_share = games_reward_fund_share;

        let total_wins = 0;
        let project_id = 1;
        while (project_id < gateway_info.project_counter) {
            if (table::contains(&gateway_info.games_in_frame, project_id) == false) {
                project_id = project_id + 1;
                continue
            };

            let games_in_frame = table::borrow(&gateway_info.games_in_frame, project_id);
            let project_win_cost = calculate_project_win_cost(games_in_frame, games_reward_fund_share, gateway_info.total_gpass_spent_in_frame);

            if (table::contains(&frame_history_entry.projects_win_cost, project_id) == false) {
                table::add(&mut frame_history_entry.projects_win_cost, project_id, 0);
            };
            let win_cost_val = table::borrow_mut(&mut frame_history_entry.projects_win_cost, project_id);
            *win_cost_val = project_win_cost;

            let contributor_reward = calculate_contributor_reward(
                games_reward_fund_contributors_share,
                games_in_frame.gpass_spent,
                gateway_info.total_gpass_spent_in_frame
            );
            if (table::contains(&gateway_info.contributor_rewards, project_id)) {
                let contributor_reward_val = table::borrow_mut(&mut gateway_info.contributor_rewards, project_id);
                *contributor_reward_val = *contributor_reward_val + contributor_reward;
            } else {
                table::add(&mut gateway_info.contributor_rewards, project_id, contributor_reward);
            };

            total_wins = total_wins + games_in_frame.wins;
            table::remove(&mut gateway_info.games_in_frame, project_id);
            project_id = project_id + 1;
        };

        event::emit_event<CalculateRewardsEvent>(
            &mut events.calculate_rewards_events,
            CalculateRewardsEvent {
                players_share: games_reward_fund_share,
                contributors_share: games_reward_fund_contributors_share,
                total_gpass_spent: gateway_info.total_gpass_spent_in_frame,
                total_wins: total_wins,
                last_calculate: gateway_info.last_calculate,
                date: now,
            },
        );

        gateway_info.last_calculate = gateway_info.last_calculate + (spent_frames_since_last_calculate * gateway_info.time_frame);
        gateway_info.total_gpass_spent_in_frame = 0;
    }

    // Public API

    public entry fun sign_up(contributor: &signer,
        gateway_addr: address,
        project_name: String,
        gpass_cost: u64,
    ) acquires GatewayInfo, Events, ProjectInfo {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        let contributor_addr = signer::address_of(contributor);
        assert!(!string::is_empty(&project_name), ERR_INVALID_PROJECT_NAME);
        assert!(string::length(&project_name) <= MAX_PROJECT_NAME_LEN, ERR_INVALID_PROJECT_NAME);
        assert!(gpass_cost != 0, ERR_INVALID_GPASS_COST);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);
        let new_project_id = gateway_info.project_counter;

        // if project is removed, create new project in this resource
        if (exists<ProjectInfo>(contributor_addr)) {
            let project_info = borrow_global_mut<ProjectInfo>(contributor_addr);
            assert!(project_info.is_removed == true, ERR_ALREADY_INITIALIZED);

            project_info.id = new_project_id;
            project_info.name = project_name;
            project_info.is_blocked = false;
            project_info.is_removed = false;
            project_info.gpass_cost = gpass_cost;
        }
        else {
            move_to(contributor, ProjectInfo {
                id: new_project_id,
                contributor: contributor_addr,
                name: project_name,
                is_blocked: false,
                is_removed: false,
                gpass_cost: gpass_cost,
                get_contributor_reward_events: account::new_event_handle<GetContributorRewardEvent>(contributor),
            });
        };

        gateway_info.project_counter = gateway_info.project_counter + 1;

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<SignUpEvent>(
            &mut events.sign_up_events,
            SignUpEvent {
                name: project_name,
                contributor: contributor_addr,
                project_id: new_project_id,
                date: now
            }
        );
    }

    public entry fun remove(contributor: &signer, gateway_addr: address) acquires ProjectInfo, Events {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        let contributor_addr = signer::address_of(contributor);
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);

        let project_info = borrow_global_mut<ProjectInfo>(contributor_addr);
        assert!(project_info.is_blocked == false, ERR_ALREADY_BLOCKED);
        assert!(project_info.is_removed == false, ERR_ALREADY_REMOVED);

        let events = borrow_global_mut<Events>(gateway_addr);
        let now = timestamp::now_seconds();
        event::emit_event<RemoveEvent>(
            &mut events.remove_events,
            RemoveEvent {
                project_id: project_info.id,
                contributor: contributor_addr,
                date: now
            }
        );

        project_info.is_removed = true;
        project_info.id = 0;
        project_info.name = string::utf8(b"");
        project_info.gpass_cost = 0;
    }

    public entry fun start_game(player: &signer,
        gateway_addr: address,
        ggwp_core_addr: address,
        contributor_addr: address,
        project_id: u64,
    ) acquires GatewayInfo, ProjectInfo, PlayerInfo, Events {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<ProjectInfo>(contributor_addr), ERR_PROJECT_NOT_EXISTS);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        assert!(project_info.id == project_id, ERR_INVALID_PROJECT_ID);
        assert!(project_info.is_blocked == false, ERR_PROJECT_BLOCKED);

        let now = timestamp::now_seconds();
        let player_addr = signer::address_of(player);
        // Create PlayerInfo if not exists
        if (exists<PlayerInfo>(player_addr) == false) {
            let gateway_info = borrow_global<GatewayInfo>(gateway_addr);

            let since_burn = now - gateway_info.last_burn;
            let spent_frames = since_burn / gateway_info.time_frame;
            let last_get_reward = gateway_info.last_burn + (spent_frames * gateway_info.time_frame);

            let time_frames_history = vector::empty<PlayerFrameHistory>();
            let i = 0;
            while (i < gateway_info.history_length) {
                vector::push_back(&mut time_frames_history, PlayerFrameHistory {
                    projects_wins: table::new<u64, u64>(),
                });
                i = i + 1;
            };

            move_to(player, PlayerInfo {
                is_blocked: false,
                last_get_reward: last_get_reward,
                game_sessions: table::new<u64, GameSessionInfo>(),
                time_frames_history: time_frames_history,
                start_game_events: account::new_event_handle<StartGameEvent>(player),
                finalize_game_events: account::new_event_handle<FinalizeGameEvent>(player),
                get_reward_events: account::new_event_handle<GetRewardEvent>(player),
            });

            let events = borrow_global_mut<Events>(gateway_addr);
            event::emit_event<NewPlayerEvent>(
                &mut events.new_player_events,
                NewPlayerEvent {
                    player: player_addr,
                    date: now,
                }
            );
        };

        let player_info = borrow_global_mut<PlayerInfo>(player_addr);
        assert!(player_info.is_blocked == false, ERR_PLAYER_BLOCKED);
        assert!(gpass::get_burn_period_passed(ggwp_core_addr, player_addr) == false, ERR_NOT_ENOUGH_GPASS);
        assert!(gpass::get_balance(player_addr) >= project_info.gpass_cost, ERR_NOT_ENOUGH_GPASS);

        // Check already opened sessions in this project
        if (table::contains(&player_info.game_sessions, project_id)) {
            let game_session_status = table::borrow(&player_info.game_sessions, project_id).status;
            assert!(game_session_status == GAME_STATUS_NULL, ERR_GAME_SESSION_ALREADY_STARTED);
        };

        // Burn gpass_cost GPASS from user wallet
        gpass::burn(player, ggwp_core_addr, project_info.gpass_cost);

        // Create game session in table if not exists
        if (!table::contains(&player_info.game_sessions, project_id)) {
            table::add(&mut player_info.game_sessions,
                project_id,
                GameSessionInfo {
                    status: GAME_STATUS_NULL,
                    id: 0,
                },
            );
        };

        // Update game status to NONE - session created
        let game_session_info = table::borrow_mut(&mut player_info.game_sessions, project_id);
        game_session_info.status = GAME_STATUS_NONE;
        game_session_info.id = game_session_info.id + 1;

        event::emit_event<StartGameEvent>(
            &mut player_info.start_game_events,
            StartGameEvent {
                project_id: project_id,
                session_id: game_session_info.id,
                date: now,
            }
        );
    }

    public entry fun finalize_game(player: &signer,
        gateway_addr: address,
        contributor_addr: address,
        project_id: u64,
        status: u8,
    ) acquires GatewayInfo, ProjectInfo, PlayerInfo {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        assert!(exists<ProjectInfo>(contributor_addr), ERR_PROJECT_NOT_EXISTS);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        assert!(project_info.id == project_id, ERR_INVALID_PROJECT_ID);
        assert!(project_info.is_blocked == false, ERR_PROJECT_BLOCKED);

        let player_addr = signer::address_of(player);
        assert!(exists<PlayerInfo>(player_addr), ERR_PLAYER_INFO_NOT_EXISTS);
        let player_info = borrow_global_mut<PlayerInfo>(player_addr);
        assert!(player_info.is_blocked == false, ERR_PLAYER_BLOCKED);

        assert!(status < 3, ERR_INVALID_GAME_SESSION_STATUS);

        // Check game session status
        assert!(table::contains(&player_info.game_sessions, project_id), ERR_MISSING_GAME_SESSION);
        let game_session_info = table::borrow_mut(&mut player_info.game_sessions, project_id);
        assert!(game_session_info.status == GAME_STATUS_NONE, ERR_GAME_SESSION_ALREADY_FINALIZED);
        game_session_info.status = GAME_STATUS_NULL;

        let now = timestamp::now_seconds();
        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);

        // If user gets rewards in past period
        if (player_info.last_get_reward < gateway_info.last_burn) {
            let since_last_get_reward = now - player_info.last_get_reward;
            let spent_frames = since_last_get_reward / gateway_info.time_frame;
            erase_player_history_skipped(&mut player_info.time_frames_history, 0, gateway_info.history_length, gateway_info.project_counter);
            player_info.last_get_reward = player_info.last_get_reward + (spent_frames * gateway_info.time_frame);
        };

        let since = now - gateway_info.last_burn;
        let current_time_frame = since / gateway_info.time_frame;
        let history_index = current_time_frame + 1;
        if (current_time_frame == gateway_info.history_length - 1) {
            history_index = 0;
        };

        // Add or update in_frame data
        let wins = 0;
        if (status == GAME_STATUS_WIN) {
            wins = 1;
        };

        gateway_info.total_gpass_spent_in_frame = gateway_info.total_gpass_spent_in_frame + project_info.gpass_cost;
        if (table::contains(&gateway_info.games_in_frame, project_id) == false) {
            table::add(&mut gateway_info.games_in_frame, project_id, GamesInFrame {
                gpass_spent: project_info.gpass_cost,
                wins: wins,
            });
        } else {
            let games_in_frame_val = table::borrow_mut(&mut gateway_info.games_in_frame, project_id);
            games_in_frame_val.gpass_spent = games_in_frame_val.gpass_spent + project_info.gpass_cost;
            games_in_frame_val.wins = games_in_frame_val.wins + wins;
        };

        // Add or update history data
        let frame_player_history_entry = vector::borrow_mut<PlayerFrameHistory>(&mut player_info.time_frames_history, history_index);
        let frame_history_entry = vector::borrow_mut<FrameHistory>(&mut gateway_info.time_frames_history, history_index);

        if (status == GAME_STATUS_WIN) {
            if (table::contains(&frame_player_history_entry.projects_wins, project_id) == false) {
                table::add(&mut frame_player_history_entry.projects_wins, project_id, 1);
            } else {
                let project_wins = table::borrow_mut(&mut frame_player_history_entry.projects_wins, project_id);
                *project_wins = *project_wins + 1;
            };
        };

        if (table::contains(&frame_history_entry.projects_win_cost, project_id) == false) {
            table::add(&mut frame_history_entry.projects_win_cost, project_id, 0);
        };

        event::emit_event<FinalizeGameEvent>(
            &mut player_info.finalize_game_events,
            FinalizeGameEvent {
                project_id: project_id,
                session_id: game_session_info.id,
                status: status,
                time_frame: history_index,
                date: now,
            }
        );
    }

    public entry fun get_player_reward(player: &signer,
        gateway_addr: address,
    ) acquires GatewayInfo, PlayerInfo {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        let player_addr = signer::address_of(player);
        assert!(exists<PlayerInfo>(player_addr), ERR_PLAYER_INFO_NOT_EXISTS);
        let player_info = borrow_global_mut<PlayerInfo>(player_addr);
        assert!(player_info.is_blocked == false, ERR_PLAYER_BLOCKED);

        let now = timestamp::now_seconds();
        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);

        let since = now - gateway_info.last_burn;
        let current_index = since / gateway_info.time_frame;

        // Check user if not plays long time - erase his history and return
        if (player_info.last_get_reward < gateway_info.last_burn) {
            let since_last_get_reward = now - player_info.last_get_reward;
            let spent_frames = since_last_get_reward / gateway_info.time_frame;
            if (current_index == 0) {
                erase_player_history_skipped(&mut player_info.time_frames_history, 1, gateway_info.history_length, gateway_info.project_counter);
                player_info.last_get_reward = player_info.last_get_reward + (spent_frames * gateway_info.time_frame);
            } else {
                erase_player_history_skipped(&mut player_info.time_frames_history, 0, gateway_info.history_length, gateway_info.project_counter);
                player_info.last_get_reward = player_info.last_get_reward + (spent_frames * gateway_info.time_frame);
                return
            };
        };

        // If user plays in this burn_period - last_get_reward is updated
        let since = player_info.last_get_reward - gateway_info.last_burn;
        let start_index = since / gateway_info.time_frame;

        let total_reward = 0;
        let total_wins = 0;
        let history_index = start_index;
        while (history_index <= current_index) {
            let frame_player_history_entry = vector::borrow_mut<PlayerFrameHistory>(&mut player_info.time_frames_history, history_index);
            let frame_history = vector::borrow_mut<FrameHistory>(&mut gateway_info.time_frames_history, history_index);

            let project_id = 1;
            while (project_id < gateway_info.project_counter) {
                if (table::contains(&frame_player_history_entry.projects_wins, project_id) == false) {
                    project_id = project_id + 1;
                    continue
                };

                let project_wins = table::borrow_mut(&mut frame_player_history_entry.projects_wins, project_id);

                total_wins = total_wins + *project_wins;
                let project_win_cost = table::borrow(&frame_history.projects_win_cost, project_id);

                let reward_in_project = *project_win_cost * *project_wins;
                frame_history.games_reward_fund_share = frame_history.games_reward_fund_share - reward_in_project;
                total_reward = total_reward + reward_in_project;

                *project_wins = 0;
                project_id = project_id + 1;
            };

            history_index = history_index + 1;
        };

        if (total_reward != 0) {
            // Transfer royalty amount into accumulative fund
            let royalty_amount = calc_royalty_amount(total_reward, gateway_info.royalty);
            let royalty_coins = coin::extract(&mut gateway_info.games_reward_fund, royalty_amount);
            coin::deposit(gateway_info.accumulative_fund, royalty_coins);

            let reward_coins = coin::extract(&mut gateway_info.games_reward_fund, total_reward - royalty_amount);
            coin::deposit(player_addr, reward_coins);
        };

        event::emit_event<GetRewardEvent>(
            &mut player_info.get_reward_events,
            GetRewardEvent {
                reward: total_reward,
                frames: (current_index - start_index) + 1,
                wins: total_wins,
                last_get_reward: player_info.last_get_reward,
                date: now,
            }
        );

        player_info.last_get_reward = player_info.last_get_reward + ((current_index - start_index) * gateway_info.time_frame);
    }

    public entry fun get_contributor_reward(contributor: &signer,
        gateway_addr: address,
    ) acquires GatewayInfo, ProjectInfo {
        assert!(gateway_addr == @gateway, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Events>(gateway_addr), ERR_NOT_INITIALIZED);

        let contributor_addr = signer::address_of(contributor);
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);

        let project_info = borrow_global_mut<ProjectInfo>(contributor_addr);
        assert!(project_info.is_blocked == false, ERR_ALREADY_BLOCKED);
        assert!(project_info.is_removed == false, ERR_ALREADY_REMOVED);

        let gateway_info = borrow_global_mut<GatewayInfo>(gateway_addr);

        assert!(table::contains(&gateway_info.contributor_rewards, project_info.id), ERR_NO_REWARD);
        let reward = table::borrow_mut(&mut gateway_info.contributor_rewards, project_info.id);
        assert!(*reward != 0, ERR_NO_REWARD);

        // Transfer royalty amount into accumulative fund
        let royalty_amount = calc_royalty_amount(*reward, gateway_info.royalty);
        let royalty_coins = coin::extract(&mut gateway_info.games_reward_fund, royalty_amount);
        coin::deposit(gateway_info.accumulative_fund, royalty_coins);

        let reward_coins = coin::extract(&mut gateway_info.games_reward_fund, *reward - royalty_amount);
        coin::deposit(contributor_addr, reward_coins);

        let now = timestamp::now_seconds();
        event::emit_event<GetContributorRewardEvent>(
            &mut project_info.get_contributor_reward_events,
            GetContributorRewardEvent {
                reward: *reward,
                date: now,
            }
        );

        *reward = 0;
    }

    // Getters

    #[view]
    public fun get_accumulative_fund_addr(gateway_addr: address): address acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        gateway_info.accumulative_fund
    }

    #[view]
    public fun games_reward_fund_balance(gateway_addr: address): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        coin::value<GGWPCoin>(&gateway_info.games_reward_fund)
    }

    #[view]
    public fun get_project_counter(gateway_addr: address): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        gateway_info.project_counter
    }

    #[view]
    public fun get_project_id(contributor_addr: address): u64 acquires ProjectInfo {
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        project_info.id
    }

    #[view]
    public fun get_project_gpass_cost(contributor_addr: address): u64 acquires ProjectInfo {
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        project_info.gpass_cost
    }

    #[view]
    public fun get_project_name(contributor_addr: address): String acquires ProjectInfo {
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        project_info.name
    }

    #[view]
    public fun get_project_is_blocked(contributor_addr: address): bool acquires ProjectInfo {
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        project_info.is_blocked
    }

    #[view]
    public fun get_project_is_removed(contributor_addr: address): bool acquires ProjectInfo {
        assert!(exists<ProjectInfo>(contributor_addr), ERR_NOT_INITIALIZED);
        let project_info = borrow_global<ProjectInfo>(contributor_addr);
        project_info.is_removed
    }

    #[view]
    public fun get_player_is_blocked(player_addr: address): bool acquires PlayerInfo {
        assert!(exists<PlayerInfo>(player_addr), ERR_NOT_INITIALIZED);
        let player_info = borrow_global<PlayerInfo>(player_addr);
        player_info.is_blocked
    }

    #[view]
    public fun get_session_status(player_addr: address, project_id: u64): u8 acquires PlayerInfo {
        if (exists<PlayerInfo>(player_addr) == false) {
            return GAME_STATUS_NULL
        };

        let player_info = borrow_global<PlayerInfo>(player_addr);
        if (!table::contains(&player_info.game_sessions, project_id)) {
            return GAME_STATUS_NULL
        };

        let game_session_info = table::borrow(&player_info.game_sessions, project_id);
        return game_session_info.status
    }

    #[view]
    public fun get_session_id(player_addr: address, project_id: u64): u64 acquires PlayerInfo {
        if (exists<PlayerInfo>(player_addr) == false) {
            return 0
        };

        let player_info = borrow_global<PlayerInfo>(player_addr);
        if (!table::contains(&player_info.game_sessions, project_id)) {
            return 0
        };

        let game_session_info = table::borrow(&player_info.game_sessions, project_id);
        return game_session_info.id
    }

    #[view]
    public fun get_is_open_session(player_addr: address, project_id: u64): bool acquires PlayerInfo {
        if (exists<PlayerInfo>(player_addr) == false) {
            return false
        };

        let player_info = borrow_global<PlayerInfo>(player_addr);
        if (!table::contains(&player_info.game_sessions, project_id)) {
            return false
        };

        let game_session_info = table::borrow(&player_info.game_sessions, project_id);
        if (game_session_info.status == GAME_STATUS_NONE) {
            return true
        };
        return false
    }

    #[view]
    public fun get_open_session(player_addr: address, project_id: u64): u64 acquires PlayerInfo {
        if (exists<PlayerInfo>(player_addr) == false) {
            return 0
        };

        let player_info = borrow_global<PlayerInfo>(player_addr);
        if (!table::contains(&player_info.game_sessions, project_id)) {
            return 0
        };

        let game_session_info = table::borrow(&player_info.game_sessions, project_id);
        if (game_session_info.status == GAME_STATUS_NONE) {
            return game_session_info.id
        };
        return 0
    }

    #[view]
    public fun get_history_length(gateway_addr: address): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        return gateway_info.history_length
    }

    #[view]
    public fun get_current_time_frame(gateway_addr: address): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let now = timestamp::now_seconds();
        let since_burn = now - gateway_info.last_burn;
        let current_time_frame = since_burn / gateway_info.time_frame;
        return current_time_frame
    }

    #[view]
    public fun get_total_gpass_spent_in_frame(gateway_addr: address): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        return gateway_info.total_gpass_spent_in_frame
    }

    #[view]
    public fun get_gpass_spent_in_current_frame(gateway_addr: address, project_id: u64): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let gpass_spent = 0;
        if (table::contains(&gateway_info.games_in_frame, project_id) == true) {
            let games_in_frame_val = table::borrow(&gateway_info.games_in_frame, project_id);
            gpass_spent = games_in_frame_val.gpass_spent;
        };
        return gpass_spent
    }

    #[view]
    public fun get_wins_in_current_frame(gateway_addr: address, project_id: u64): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let wins = 0;
        if (table::contains(&gateway_info.games_in_frame, project_id) == true) {
            let games_in_frame_val = table::borrow(&gateway_info.games_in_frame, project_id);
            wins = games_in_frame_val.wins;
        };
        return wins
    }

    #[view]
    public fun get_fund_share(gateway_addr: address, history_index: u64): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let frame_history_entry = vector::borrow<FrameHistory>(&gateway_info.time_frames_history, history_index);
        return frame_history_entry.games_reward_fund_share
    }

    #[view]
    public fun get_win_cost(gateway_addr: address, history_index: u64, project_id: u64): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let frame_history_entry = vector::borrow<FrameHistory>(&gateway_info.time_frames_history, history_index);
        let win_cost = 0;
        if (table::contains(&frame_history_entry.projects_win_cost, project_id) == true) {
            win_cost = *table::borrow(&frame_history_entry.projects_win_cost, project_id);
        };
        return win_cost
    }

    #[view]
     public fun get_current_contributor_reward(gateway_addr: address, project_id: u64): u64 acquires GatewayInfo {
        assert!(exists<GatewayInfo>(gateway_addr), ERR_NOT_INITIALIZED);
        let gateway_info = borrow_global<GatewayInfo>(gateway_addr);
        let reward = 0;
        if (table::contains(&gateway_info.contributor_rewards, project_id) == true) {
            reward = *table::borrow(&gateway_info.contributor_rewards, project_id);
        };
        return reward
    }

    // Utils.
    const PRECISION: u256 = 1000000000000;

    public fun calculate_project_win_cost(
        games_in_frame: &GamesInFrame,
        games_reward_fund_share: u64,
        total_gpass_spent: u64,
    ): u64 {
        if (total_gpass_spent == 0) {
            return 0
        };
        if (games_in_frame.gpass_spent == 0) {
            return 0
        };
        if (games_in_frame.wins == 0) {
            return 0
        };

        let gpass_spent_256_prec: u256 = (games_in_frame.gpass_spent as u256) * PRECISION;
        let total_gpass_spent_256: u256 = (total_gpass_spent as u256);
        let games_reward_fund_share_256_dec_prec: u256 = (games_reward_fund_share as u256) * PRECISION;
        let wins_256_prec: u256 = (games_in_frame.wins as u256) * PRECISION;

        let project_all_rewards_share: u256 = games_reward_fund_share_256_dec_prec * (gpass_spent_256_prec / total_gpass_spent_256);
        let project_win_cost: u256 = project_all_rewards_share / wins_256_prec / PRECISION;

        return (project_win_cost as u64)
    }

    public fun calculate_contributor_reward(
        games_reward_fund_contributors_share: u64,
        gpass_spent: u64,
        total_gpass_spent: u64,
    ): u64 {
        if (total_gpass_spent == 0) {
            return 0
        };
        if (gpass_spent == 0) {
            return 0
        };

        let gpass_spent_256_prec: u256 = (gpass_spent as u256) * PRECISION;
        let total_gpass_spent_256: u256 = (total_gpass_spent as u256);
        let contributors_share_256_dec: u256 = (games_reward_fund_contributors_share as u256);

        let contributor_reward: u256 = contributors_share_256_dec * (gpass_spent_256_prec / total_gpass_spent_256);
        let contributor_reward: u256 = contributor_reward / PRECISION;

        return (contributor_reward as u64)
    }

    public fun erase_history_item(history: &mut vector<FrameHistory>, index: u64, project_counter: u64): u64 {
        let elem = vector::borrow_mut<FrameHistory>(history, index);
        let unspent = elem.games_reward_fund_share;
        elem.games_reward_fund_share = 0;
        let j = 1;
        while (j < project_counter) {
            if (table::contains(&elem.projects_win_cost, j)) {
                table::remove(&mut elem.projects_win_cost, j);
            };
            j = j + 1;
        };

        return unspent
    }

    public fun erase_player_history_skipped(history: &mut vector<PlayerFrameHistory>, skip: u64, history_length: u64, project_counter: u64) {
        let i = 0 + skip;
        while (i < history_length) {
            let elem = vector::borrow_mut<PlayerFrameHistory>(history, i);
            let j = 1;
            while (j < project_counter) {
                if (table::contains(&elem.projects_wins, j)) {
                    table::remove(&mut elem.projects_wins, j);
                };
                j = j + 1;
            };
            i = i + 1;
        };
    }

    /// Get the percent value.
    public fun calc_royalty_amount(amount: u64, royalty: u8): u64 {
        amount / 100 * (royalty as u64)
    }

    #[test_only]
    const DECIMALS: u64 = 100000000;

    #[test]
    public entry fun calculate_project_win_cost_test() {
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 0, wins: 0 }, 0, 0);
        assert!(wc == 0, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 0, wins: 0 }, 0, 10);
        assert!(wc == 0, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 0, wins: 0 }, 0, 10);
        assert!(wc == 0, 1);

        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 1);
        assert!(wc == 10 * DECIMALS, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 2);
        assert!(wc == 5 * DECIMALS, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 3);
        assert!(wc == 333333333, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 5);
        assert!(wc == 2 * DECIMALS, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 6);
        assert!(wc == 166666666, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1, }, 100 * DECIMALS, 6);
        assert!(wc == 1666666666, 1);

        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 20);
        assert!(wc == 50000000, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 200);
        assert!(wc == 5000000, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 10 * DECIMALS, 2000);
        assert!(wc == 500000, 1);

        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1, }, 300000000 * DECIMALS, 1);
        assert!(wc == 300000000 * DECIMALS, 1);
        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1, }, 300000000 * DECIMALS, 6);
        assert!(wc == 4999999999980000, 1);

        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 10, wins: 5, }, 300000000 * DECIMALS, 16);
        assert!(wc == 37500000 * DECIMALS, 1);

        let wc = calculate_project_win_cost(&GamesInFrame { gpass_spent: 1, wins: 1 }, 300000000 * DECIMALS, 1000000);
        assert!(wc == 300 * DECIMALS, 1);
    }

    #[test]
    public entry fun calculate_contributor_reward_test() {
        let cr = calculate_contributor_reward(10 * DECIMALS, 0, 1);
        assert!(cr == 0, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 0, 0);
        assert!(cr == 0, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 1, 1);
        assert!(cr == 10 * DECIMALS, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 1, 2);
        assert!(cr == 5 * DECIMALS, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 1, 5);
        assert!(cr == 2 * DECIMALS, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 1, 10);
        assert!(cr == 1 * DECIMALS, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 1, 100);
        assert!(cr == 10000000, 1);
        let cr = calculate_contributor_reward(10 * DECIMALS, 10, 100);
        assert!(cr == 100000000, 1);

        let cr = calculate_contributor_reward(10 * DECIMALS, 13, 123);
        assert!(cr == 105691056, 1);

        let cr = calculate_contributor_reward(300000000 * DECIMALS, 13, 123);
        assert!(cr == 3170731707300000, 1);

        let cr = calculate_contributor_reward(300000000 * DECIMALS, 28, 1000000);
        assert!(cr == 840000000000, 1);
    }
}

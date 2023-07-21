module woolf_deployer::risky_game {
    use std::error;
    use std::signer;
    use std::vector;

    use aptos_framework::event;
    use aptos_framework::account;

    use woolf_deployer::wool_pouch;
    use woolf_deployer::random;
    use woolf_deployer::traits;
    use woolf_deployer::barn;
    use aptos_std::table::Table;
    use aptos_std::table;
    use std::string;
    use woolf_deployer::utf8_utils;
    use woolf_deployer::token_helper;
    use woolf_deployer::config;
    use aptos_token::token::TokenId;
    use aptos_framework::timestamp;

    //
    // Constants
    //
    const TOTAL_GEN0_GEN1: u64 = 13809;
    const STATE_UNDECIDED: u8 = 0;
    const STATE_OPTED_IN: u8 = 1;
    const STATE_EXECUTED: u8 = 2;

    const STAGE_NOT_STARTED: u8 = 1;
    const STAGE_OPT_IN: u8 = 1;
    const STAGE_EXECUTE: u8 = 2;

    // Total wool in risky game, 10 billin
    const MAXIMUM_WOOL: u64 = 1000000000 * 100000000;
    // FIXME fix those value
    const TOTAL_CLAIMED_WOOL: u64 = 0;
    const TOTAL_STAKED_EARNINGS: u64 = 0;
    const TOTAL_UNSTAKED_EARNINGS: u64 = 0;

    const MAX_ALPHA: u64 = 8;
    const ONE_DAY_IN_SECONDS: u64 = 86400;
    const DAILY_WOOL: u64 = 10000 * 100000000;

    //
    // Errors
    //
    const EPAUSED: u64 = 1;
    const EONLY_ORIGINALS_CAN_PLAY_RISKY_GAME: u64 = 2;
    const EWOLVES_CANT_PLAY_IT_SAFE: u64 = 3;
    const ECANT_CLAIM_TWICE: u64 = 4;
    const EOPPORTUNITY_PASSED: u64 = 5;
    const ESHOULD_BE_SHEEP: u64 = 6;
    const ENOT_TOKEN_OWNER: u64 = 7;
    const ENOT_IN_BARN: u64 = 8;
    const EGAME_STAGE_ERROR: u64 = 9;

    struct SafeClaim has store, drop {
        recipient: address,
        token_ids: vector<u64>,
        amount: u64
    }

    struct OptForRisk has store, drop {
        owner: address,
        token_ids: vector<u64>,
    }

    struct RiskyClaim has store, drop {
        recipient: address,
        token_ids: vector<u64>,
        winners: vector<bool>,
        amount: u64,
    }

    struct WolfClaim has store, drop {
        recipient: address,
        token_ids: vector<u64>,
        amount: u64
    }

    struct Events has key {
        safe_claim_events: event::EventHandle<SafeClaim>,
        opt_for_risk_events: event::EventHandle<OptForRisk>,
        risky_claim_events: event::EventHandle<RiskyClaim>,
        wolf_claim_events: event::EventHandle<WolfClaim>,
    }

    struct Data has key {
        stage: u8, // game stage, 0 -> not started, 1 -> opt in, 2-> claim
        paused: bool,
        safe_game_wool: u64,
        risk_game_wool: u64,
        taxes: u64,
        total_risk_takers: u64,
        token_states: Table<u64, u8>,
        start_time: u64,
    }

    fun init_module(admin: &signer) {
        initialize(admin);
    }

    fun initialize(framework: &signer) {
        move_to(framework, Data {
            stage: STAGE_NOT_STARTED,
            paused: true,
            safe_game_wool: 0,
            risk_game_wool: MAXIMUM_WOOL, // FIXME
            taxes: 0,
            total_risk_takers: 0,
            token_states: table::new(),
            start_time: 0,
        });

        move_to(framework, Events {
            safe_claim_events: account::new_event_handle<SafeClaim>(framework),
            opt_for_risk_events: account::new_event_handle<OptForRisk>(framework),
            risky_claim_events: account::new_event_handle<RiskyClaim>(framework),
            wolf_claim_events: account::new_event_handle<WolfClaim>(framework),
        })
    }

    public entry fun set_stage(owner: &signer, stage: u8) acquires Data {
        assert!(signer::address_of(owner) == @woolf_deployer, error::permission_denied(ENOT_TOKEN_OWNER));
        let data = borrow_global_mut<Data>(@woolf_deployer);
        assert!(!data.paused, error::invalid_state(EPAUSED));
        if (stage == STAGE_OPT_IN) {
            assert!(data.stage == STAGE_NOT_STARTED, error::invalid_state(EGAME_STAGE_ERROR));
            data.start_time = timestamp::now_seconds();
            data.stage == STAGE_OPT_IN;
        } else if (stage == STAGE_EXECUTE) {
            assert!(data.stage == STAGE_OPT_IN, error::invalid_state(EGAME_STAGE_ERROR));
        };
    }

    fun assert_not_paused() acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(data.paused == false, error::permission_denied(EPAUSED));
    }

    fun assert_stage_opt_in() acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(data.stage == 1, error::permission_denied(EGAME_STAGE_ERROR));
    }

    fun assert_stage_execute() acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(data.stage == 2, error::permission_denied(EGAME_STAGE_ERROR));
    }

    public entry fun set_paused(admin: &signer, paused: bool) acquires Data {
        assert!(signer::address_of(admin) == @woolf_deployer, error::permission_denied(ENOT_TOKEN_OWNER));
        let data = borrow_global_mut<Data>(@woolf_deployer);
        data.paused = paused;
    }

    public entry fun play_it_safe_one(player: &signer, token_id: u64, separate_pouches: bool) acquires Data, Events {
        play_it_safe(player, vector<u64>[token_id], separate_pouches)
    }

    // opts into the No Risk option and claims WOOL Pouches
    public entry fun play_it_safe(
        player: &signer,
        token_ids: vector<u64>,
        separate_pouches: bool
    ) acquires Data, Events {
        assert_not_paused();
        assert_stage_opt_in();
        let earned: u64 = 0;
        let i = 0;
        let temp: u64;
        let data = borrow_global_mut<Data>(@woolf_deployer);
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            assert!(owner_of(token_id) == signer::address_of(player), error::permission_denied(ENOT_TOKEN_OWNER));
            assert!(token_id <= TOTAL_GEN0_GEN1, error::out_of_range(EONLY_ORIGINALS_CAN_PLAY_RISKY_GAME));
            assert!(is_sheep(token_id), error::invalid_state(ESHOULD_BE_SHEEP));
            assert!(get_token_state(data, token_id) == STATE_UNDECIDED, error::invalid_state(ECANT_CLAIM_TWICE));

            temp = get_wool_due(data, token_id);
            set_token_state(data, token_id, STATE_EXECUTED);
            if (separate_pouches) {
                wool_pouch::mint_internal(signer::address_of(player), temp * 4 / 5, 365 * 4); // charge 20% tax
            };
            earned = earned + temp;
            i = i + 1;
        };

        data.safe_game_wool = data.safe_game_wool + earned;
        data.taxes = data.taxes + earned / 5;
        if (!separate_pouches) {
            // charge 20% tax
            wool_pouch::mint_internal(signer::address_of(player), earned * 4 / 5, 365 * 4);
        };
        event::emit_event<SafeClaim>(
            &mut borrow_global_mut<Events>(@woolf_deployer).safe_claim_events,
            SafeClaim {
                recipient: signer::address_of(player), token_ids, amount: earned
            },
        );
    }

    public entry fun take_a_risk_one(player: &signer, token_id: u64) acquires Data, Events {
        take_a_risk(player, vector<u64>[token_id])
    }

    // opts into the Yes Risk option
    public entry fun take_a_risk(
        player: &signer,
        token_ids: vector<u64>
    ) acquires Data, Events {
        assert_not_paused();
        assert_stage_opt_in();
        let data = borrow_global_mut<Data>(@woolf_deployer);

        let i = 0;
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            assert!(owner_of(token_id) == signer::address_of(player), error::permission_denied(ENOT_TOKEN_OWNER));
            assert!(token_id <= TOTAL_GEN0_GEN1, error::out_of_range(EONLY_ORIGINALS_CAN_PLAY_RISKY_GAME));
            assert!(is_sheep(token_id), error::invalid_state(ESHOULD_BE_SHEEP));
            assert!(get_token_state(data, token_id) == STATE_UNDECIDED, error::invalid_state(ECANT_CLAIM_TWICE));

            set_token_state(data, token_id, STATE_OPTED_IN);
            data.risk_game_wool = data.risk_game_wool + get_wool_due(data, token_id);
            data.total_risk_takers = data.total_risk_takers + 1;
            i = i + 1;
        };
        event::emit_event<OptForRisk>(
            &mut borrow_global_mut<Events>(@woolf_deployer).opt_for_risk_events,
            OptForRisk {
                owner: signer::address_of(player), token_ids
            },
        );
    }

    public entry fun execute_risk_one(player: &signer, token_id: u64, separate_pouches: bool) acquires Data, Events {
        execute_risk(player, vector<u64>[token_id], separate_pouches)
    }

    // reveals the results of Yes Risk for Sheep and gives WOOL Pouches
    public entry fun execute_risk(
        player: &signer,
        token_ids: vector<u64>,
        separate_pouches: bool
    ) acquires Data, Events {
        assert_not_paused();
        assert_stage_execute();
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let earned = 0;
        let i = 0;
        let winners = vector::empty<bool>();
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            assert!(owner_of(token_id) == signer::address_of(player), error::permission_denied(ENOT_TOKEN_OWNER));
            assert!(token_id <= TOTAL_GEN0_GEN1, error::out_of_range(EONLY_ORIGINALS_CAN_PLAY_RISKY_GAME));
            assert!(is_sheep(token_id), error::invalid_state(ESHOULD_BE_SHEEP));
            assert!(get_token_state(data, token_id) == STATE_OPTED_IN, error::invalid_state(ECANT_CLAIM_TWICE));
            set_token_state(data, token_id, STATE_EXECUTED);
            if (!did_sheep_defeat_wolves(&signer::address_of(player), token_id)) {
                vector::push_back(&mut winners, false);
                continue
            };
            if (separate_pouches) {
                wool_pouch::mint_internal(
                    signer::address_of(player),
                    data.risk_game_wool / data.total_risk_takers,
                    365 * 4
                );
            };
            earned = earned + data.risk_game_wool / data.total_risk_takers;
            vector::push_back(&mut winners, true);
            i = i + 1;
        };
        if (!separate_pouches && earned > 0) {
            wool_pouch::mint_internal(signer::address_of(player), earned, 365 * 4);
        };
        event::emit_event<RiskyClaim>(
            &mut borrow_global_mut<Events>(@woolf_deployer).risky_claim_events,
            RiskyClaim {
                recipient: signer::address_of(player),
                token_ids,
                winners,
                amount: earned,
            },
        );
    }

    public entry fun claim_wolf_earnings_one(
        player: &signer,
        token_id: u64,
        separate_pouches: bool
    ) acquires Data, Events {
        claim_wolf_earnings(player, vector<u64>[token_id], separate_pouches)
    }

    // claims the taxed and Yes Risk earnings for wolves in WOOL Pouches
    public entry fun claim_wolf_earnings(
        player: &signer,
        token_ids: vector<u64>,
        separate_pouches: bool
    ) acquires Data, Events {
        assert_not_paused();
        assert_stage_execute();
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let i = 0;
        let temp;
        let earned = 0;
        let alpha: u64;
        // amount in taxes is 20% of remainder after unclaimed wool from v1 and risk game
        // if there are no sheep playing risk game, wolves win the whole pot
        let total_wolf_earnings = data.taxes + data.risk_game_wool / (if (data.total_risk_takers > 0) 2 else 1);
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            assert!(owner_of(token_id) == signer::address_of(player), error::permission_denied(ENOT_TOKEN_OWNER));
            assert!(token_id <= TOTAL_GEN0_GEN1, error::out_of_range(EONLY_ORIGINALS_CAN_PLAY_RISKY_GAME));
            assert!(is_sheep(token_id), error::invalid_state(ESHOULD_BE_SHEEP));
            assert!(get_token_state(data, token_id) == STATE_UNDECIDED, error::invalid_state(ECANT_CLAIM_TWICE));

            set_token_state(data, token_id, STATE_EXECUTED);
            alpha = (alphaForWolf(token_id) as u64);
            temp = total_wolf_earnings * alpha / barn::total_alpha();
            earned = earned + temp;
            if (separate_pouches) {
                wool_pouch::mint_internal(signer::address_of(player), temp, 365 * 4);
            };
            i = i + 1;
        };

        if (!separate_pouches && earned > 0) {
            wool_pouch::mint_internal(signer::address_of(player), earned, 365 * 4);
        };
        event::emit_event<WolfClaim>(
            &mut borrow_global_mut<Events>(@woolf_deployer).wolf_claim_events,
            WolfClaim {
                recipient: signer::address_of(player), token_ids, amount: earned
            },
        );
    }

    fun get_token_id(token_index: u64): TokenId {
        let name = string::utf8(b"");
        if (is_sheep(token_index)) {
            string::append_utf8(&mut name, b"Sheep #");
        } else {
            string::append_utf8(&mut name, b"Wolf #");
        };
        string::append(&mut name, utf8_utils::to_string(token_index));

        let token_id = token_helper::create_token_id(
            config::collection_name(),
            name,
            1,
        );
        token_id
    }

    fun owner_of(token_index: u64): address {
        // FIXME
        let token_id = get_token_id(token_index);
        assert!(barn::sheep_in_barn(token_id), error::invalid_state(ENOT_IN_BARN));
        barn::get_stake_owner(token_id)
    }

    fun is_sheep(token_index: u64): bool {
        let (sheep, _, _, _, _, _, _, _, _, _) = traits::get_index_traits(token_index);
        sheep
    }

    fun did_sheep_defeat_wolves(player: &address, _token_index: u64): bool {
        // 50/50
        random::rand_u64_range(player, 0, 2) == 0
    }

    fun alphaForWolf(token_index: u64): u8 {
        let (_, _, _, _, _, _, _, _, _, alpha) = traits::get_index_traits(token_index);
        barn::max_alpha() - alpha
    }

    // gets the WOOL due for a Sheep based on their state before Barn v1 was paused
    fun get_wool_due(data: &mut Data, token_index: u64): u64 {
        let token_id = get_token_id(token_index);
        if (barn::sheep_in_barn(token_id)) {
            // Sheep that were staked earn all their earnings up until the risky game
            let value = barn::get_stake_value(token_id);
            return (data.start_time - value) * DAILY_WOOL / ONE_DAY_IN_SECONDS
        } else {
            // Sheep that were not staked receive what they would have earned between the pause and migration
            return (timestamp::now_seconds() - data.start_time) * DAILY_WOOL / ONE_DAY_IN_SECONDS
        }
    }

    fun set_token_state(data: &mut Data, token_index: u64, state: u8) {
        table::upsert(&mut data.token_states, token_index, state);
    }

    fun get_token_state(data: &Data, token_index: u64): u8 {
        if (table::contains(&data.token_states, token_index)) {
            return *table::borrow(&data.token_states, token_index)
        };
        STATE_UNDECIDED
    }
}

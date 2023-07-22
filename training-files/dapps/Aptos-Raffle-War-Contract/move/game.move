module GameDeployer::game{
    use std::signer;
    use std::string::{String};
    use std::vector;
    use std::error;
    use aptos_framework::coin::{Self};
    // use aptos_framework::aptos_coin;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};  
    use aptos_token::token::{Self, TokenId};

    use GameDeployer::utils;

    // Default minimum duration is 10000s > 3h
    const DEFAULT_MINIMUM_DURATION: u64 = 10000;

    // Default victory probability of attack side
    const DEFAULT_ATTACK_PROBABILITY: u64 = 70;

    // Not owner & admin
    const EINVALID_OWNER: u64 = 1;

    // No find Game 
    const EINVALID_game_ID: u64 = 2;

    // No enought end time
    const EWRONG_ENDTIME: u64 = 3;

    // No enought delay time
    const EWRONG_DELAYTIME: u64 = 4;

    // No passed designated time
    const EWRONG_NO_ENDTIME: u64 = 5;

    // Not allowed collection name
    const EINVALID_COLLECTION: u64 = 6;

    // Same tokenId has already been entered
    const EINVALID_TOKENID: u64 = 7;

    // Invalid my tokenId
    const EINVALID_MY_TOKENID: u64 = 8;

    // Invalid target tokenId
    const EINVALID_TARGET_TOKENID: u64 = 9;

    // This is not my tokenId
    const EWRONG_MY_TOKENID: u64 = 10;

    // Game has already activated
    const GAME_ACTIVATED: u64 = 11;

    // Game has not activated yet
    const GAME_NOT_ACTIVATED: u64 = 12;

    // Game not exist
    const EWRONG_GAME_ID: u64 = 13;

    // Lack of apt funds 
    const EINVALID_BALANCE: u64 = 14;

    /// Not registerd collection name to owner
    const EWRONG_NOT_REGISTERED_COLLECTION: u64 = 15;

    /// Already collection name exist
    const EWRONG_ALREADY_REGISTERED_COLLECTION: u64 = 16;

    /// Never entered game log
    const EINVALID_GAME_LOG: u64 = 17;

    struct Game has store, drop, copy{
        game_id: u64,
        game_type: u64,
        ticket_price: u64,
        delay_time: u64,
        end_time: u64,
        active: bool,
        resolved: bool,
        claimed: bool,
        player_ids: vector<address>,
        player_token_ids: vector<TokenId>,
        player_status: vector<bool>,
        players: u64, 
        winner_id_1: address,
        winner_id_2: address,
        winner_id_3: address
    }

    struct GameConfig has key {
        collection_names: vector<String>,
        attack_victory_probability: u64,
        minimum_duration: u64,
        game_ids: vector<u64>,
        games: vector<Game>,
        game_create_event: EventHandle<GameCreateEvent>,
        game_cancel_event: EventHandle<GameCancelEvent>,
    }

    struct GameCreateEvent has copy, drop, store {
        game_id: u64,
        game_type: u64,
        delay_time: u64,
    }

    struct GameCancelEvent has copy, drop, store {
        game_id: u64,
    }

    struct GameRecord has copy, drop, store {
        result: u8,
        target_addr: address,
        status: u8
    }

    struct GameLog has key {
        game_results: vector<vector<GameRecord>>,
        game_ids: vector<u64>,
        game_scores: vector<u64>
    }

    // Private function

    fun get_score(sender_addr: address, game_id: u64): u64 acquires GameLog {
        let game_log = borrow_global_mut<GameLog>(sender_addr);
        let (game_exist, game_id_index) = vector::index_of(&game_log.game_ids, &game_id);
        assert!(game_exist, EWRONG_GAME_ID);
        *vector::borrow(&game_log.game_scores, game_id_index)
    }

    fun rand_generater(_modulus: u64): u64 {
        let now = timestamp::now_microseconds();
        return now % _modulus
    }

    fun write_game_log(game_id: u64, sender_addr: address, target_addr: address, result: u8, status: u8) acquires GameLog {
        let game_log = borrow_global_mut<GameLog>(sender_addr);

        if(!vector::contains(&game_log.game_ids, &game_id)) {
            let game_results = vector::empty();
            vector::push_back(&mut game_log.game_results, game_results);
            vector::push_back(&mut game_log.game_ids, game_id);
            vector::push_back(&mut game_log.game_scores, 0);
        };

        let (_exist, game_id_index) = vector::index_of(&game_log.game_ids, &game_id);
        let game_results = *vector::borrow_mut(&mut game_log.game_results, game_id_index);
        vector::push_back(&mut game_results, GameRecord{
            result,
            target_addr,
            status
        });
        *vector::borrow_mut(&mut game_log.game_scores, game_id_index) = *vector::borrow(&mut game_log.game_scores, game_id_index) + 1;
    }

    // Initialize this module
    fun init_module(sender: &signer) {
        let collection_names = vector::empty();
        let attack_victory_probability = DEFAULT_ATTACK_PROBABILITY;
        let minimum_duration = DEFAULT_MINIMUM_DURATION;
        let game_ids = vector::empty();
        let games = vector::empty();
        let game_create_event = account::new_event_handle<GameCreateEvent>(sender);
        let game_cancel_event = account::new_event_handle<GameCancelEvent>(sender);
        let (resource_signer, _signer_cap) = account::create_resource_account(sender, x"01");
        token::initialize_token_store(&resource_signer);
        token::opt_in_direct_transfer(sender, true);
        move_to(sender, GameConfig{
            collection_names,
            attack_victory_probability,
            minimum_duration, 
            game_ids, 
            games, 
            game_create_event, 
            game_cancel_event
        });
    }

    // init game log per user
    fun initialize_game_log(_sender: &signer) {
        let sender_addr = signer::address_of(_sender);
        if (!exists<GameLog>(sender_addr)) {
            move_to(
                _sender,
                GameLog {
                    game_results: vector::empty(),
                    game_ids: vector::empty(),
                    game_scores: vector::empty()
                }
            );
        };
    }

    public entry fun create_Game (
        sender: &signer, 
        game_type: u64,
        ticket_price: u64,
        delay_time: u64,
        end_time: u64
    ) acquires GameConfig {   
        utils::assert_owner(sender);
        let sender_addr = signer::address_of(sender);
                
        // assert!(token::balance_of(sender_addr, token_id) >= 1, error::invalid_argument(EOWNER_NOT_HAVING_ENOUGH_TOKEN));

        let game_config = borrow_global_mut<GameConfig>(sender_addr);
        
        assert!(game_config.minimum_duration < delay_time, EWRONG_DELAYTIME);  

        let game_id = vector::length(&game_config.games);

        let new_game = Game { 
            game_id,
            game_type,
            ticket_price,
            delay_time, 
            end_time,
            player_ids: vector::empty(),
            player_token_ids: vector::empty(),
            player_status: vector::empty(),
            players: 0,
            active: false,
            claimed: false,
            resolved: false, 
            winner_id_1: sender_addr,
            winner_id_2: sender_addr,
            winner_id_3: sender_addr
        };
        
        vector::push_back<Game>(&mut game_config.games, new_game);
        
        vector::push_back<u64>(&mut game_config.game_ids, game_id);
        
        event::emit_event<GameCreateEvent>(
            &mut game_config.game_create_event,
            GameCreateEvent {
                game_id,
                game_type,
                delay_time
            }
        );
    }

    public entry fun set_active(game_id: u64) acquires GameConfig {
        let game_config = borrow_global_mut<GameConfig>(@GameDeployer);
        let (exist, index) = vector::index_of(&game_config.game_ids, &game_id);
        assert!(exist, error::permission_denied(EINVALID_game_ID));
        let game = vector::borrow_mut(&mut game_config.games, index);
        assert!(timestamp::now_seconds() >= game.end_time, error::permission_denied(EWRONG_NO_ENDTIME));
        assert!(!game.active, error::permission_denied(GAME_ACTIVATED));
        if(game.players >= 3) {
            game.active = true;
        } else {
            if(game.game_type == 0) { game.end_time = game.end_time + 3600; }
            else { game.end_time = game.end_time + 25200; };
        };
    }

    public entry fun enter<CoinType> (
        sender: &signer, 
        game_id: u64,
        creator: address, 
        collection_name: String, 
        token_name: String, 
        property_version: u64, 
    ) acquires GameConfig {
        let sender_addr = signer::address_of(sender);
        let game_config = borrow_global_mut<GameConfig>(@GameDeployer);
        let (exist, index) = vector::index_of(&game_config.game_ids, &game_id);
        assert!(exist, error::permission_denied(EINVALID_game_ID));
        assert!(vector::contains(&game_config.collection_names, &collection_name), error::permission_denied(EINVALID_COLLECTION));
        let game = vector::borrow_mut(&mut game_config.games, index);
        assert!(!game.active, error::permission_denied(GAME_ACTIVATED));
        assert!(coin::balance<CoinType>(sender_addr) > game.ticket_price, error::permission_denied(EINVALID_BALANCE));
        let token_id = token::create_token_id_raw(creator, collection_name, token_name, property_version);
        assert!(!vector::contains(&game.player_token_ids, &token_id), error::permission_denied(EINVALID_TOKENID));
        if(!vector::contains(&game.player_ids, &sender_addr)){
            game.players = game.players + 1;
        };
        initialize_game_log(sender);
        vector::push_back<address>(&mut game.player_ids, sender_addr);
        vector::push_back<TokenId>(&mut game.player_token_ids, token_id);
        vector::push_back<bool>(&mut game.player_status, true);

        coin::transfer<CoinType>(sender, @GameDeployer, game.ticket_price);
    }

    public entry fun attack( 
        sender: &signer, 
        game_id: u64, 
        my_token_creator: address, 
        my_token_collection_name: String, 
        my_token_token_name: String, 
        my_token_property_version: u64, 
        target_token_creator: address, 
        target_token_collection_name: String, 
        target_token_token_name: String, 
        target_token_property_version: u64, 
    ) acquires GameConfig, GameLog {
        let sender_addr = signer::address_of(sender);
        let game_config = borrow_global_mut<GameConfig>(@GameDeployer);
        let (exist, index) = vector::index_of(&game_config.game_ids, &game_id);
        assert!(exist, error::permission_denied(EINVALID_game_ID));
        let game = vector::borrow_mut(&mut game_config.games, index);
        // assert!(game.active, error::permission_denied(GAME_NOT_ACTIVATED));
        let my_id = token::create_token_id_raw(my_token_creator, my_token_collection_name, my_token_token_name, my_token_property_version);
        let target_id = token::create_token_id_raw(target_token_creator, target_token_collection_name, target_token_token_name, target_token_property_version);
        let (my_token_id_exist, my_token_id_index) = vector::index_of(&game.player_token_ids, &my_id);
        assert!(my_token_id_exist, error::permission_denied(EINVALID_MY_TOKENID));
        assert!(vector::borrow(&game.player_ids, my_token_id_index) == &sender_addr, error::permission_denied(EWRONG_MY_TOKENID));
        let (target_token_id_exist, target_token_id_index) = vector::index_of(&game.player_token_ids, &target_id);
        assert!(target_token_id_exist, error::permission_denied(EINVALID_TARGET_TOKENID));

        let rand = rand_generater(100);
        let probability = game_config.attack_victory_probability;

        let my_addr = *vector::borrow(& game.player_ids, my_token_id_index);
        let target_addr = *vector::borrow(& game.player_ids, target_token_id_index);

        if(rand <= probability) { // win
            *vector::borrow_mut(&mut game.player_status, target_token_id_index) = false;
            let _game_status = 0;
            if(rand <= probability * 20 / 100) {
                _game_status = 1;
            } else if(rand <= probability * 40 / 100) {
                _game_status = 2;
            } else if(rand <= probability * 60 / 100) {
                _game_status = 3;
            } else if(rand <= probability * 80 / 100) {
                _game_status = 4;
            } else {
                _game_status = 5;
            };
            write_game_log(game_id, my_addr, target_addr, 1, _game_status);

        } else { // loss
            *vector::borrow_mut(&mut game.player_status, my_token_id_index) = false;
            let _game_status = 0;
            if(rand <= (probability + probability * 20 / 100)) {
                _game_status = 1;
            } else if(rand <= probability * 40 / 100) {
                _game_status = 2;
            } else if(rand <= probability * 60 / 100) {
                _game_status = 3;
            } else if(rand <= probability * 80 / 100) {
                _game_status = 4;
            } else {
                _game_status = 5;
            };
            write_game_log(game_id, target_addr, my_addr, 0, _game_status);
        };
    }

    public entry fun resolve(sender: &signer, game_id: u64) acquires GameConfig, GameLog {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        let (exist, index) = vector::index_of(&game_config.game_ids, &game_id);
        assert!(exist, error::permission_denied(EINVALID_game_ID));
        let game = vector::borrow_mut(&mut game_config.games, index);
        assert!(game.active, error::permission_denied(GAME_NOT_ACTIVATED));
        assert!(timestamp::now_seconds() >= game.end_time + game.delay_time, error::permission_denied(EWRONG_NO_ENDTIME));
        let first_score = 0;
        let second_score = 0;
        let third_score = 0;
        let first_winner = signer::address_of(sender);
        let second_winner = signer::address_of(sender);
        let third_winner = signer::address_of(sender);
        let i = 0;
        while (i < vector::length(&game.player_ids)) {
            let winner = *vector::borrow(&game.player_ids, i);
            let score = get_score(winner, game_id);
            if(score > first_score) {

                third_score = second_score;
                third_winner = second_winner;

                second_score = first_score;
                second_winner = first_winner;

                first_score = score;
                first_winner = winner;

            } else if(score > second_score) {

                third_score = second_score;
                third_winner = second_winner;

                second_score = score;
                second_winner = winner;

            } else if(score > third_score) {

                third_score = score;
                third_winner = winner;

            };
            i = i + 1;
        };
        game.winner_id_1 = first_winner;
        game.winner_id_2 = second_winner;
        game.winner_id_3 = third_winner;
    }

    public entry fun claim<CoinType>(sender: &signer, game_id: u64) acquires GameConfig {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        let (exist, index) = vector::index_of(&game_config.game_ids, &game_id);
        assert!(exist, error::permission_denied(EINVALID_game_ID));
        let game = vector::borrow_mut(&mut game_config.games, index);
        assert!(game.active, error::permission_denied(GAME_NOT_ACTIVATED));
        assert!(timestamp::now_seconds() >= game.end_time + game.delay_time, error::permission_denied(EWRONG_NO_ENDTIME));
        let required_balance = vector::length(&game.player_ids) * game.ticket_price;
        coin::transfer<CoinType>(sender, game.winner_id_1, required_balance * 40 / 100);
        coin::transfer<CoinType>(sender, game.winner_id_2, required_balance * 25 / 100);
        coin::transfer<CoinType>(sender, game.winner_id_3, required_balance * 10 / 100);
    }

    // Admin control

    public entry fun set_minimum_duration(sender: &signer, duration:u64) acquires GameConfig {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        game_config.minimum_duration = duration;
    }

    public entry fun set_attack_probability(sender: &signer, probability:u64) acquires GameConfig {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        game_config.attack_victory_probability = probability;
    }

    public entry fun append_collection_name(sender: &signer, collection_name: String)  acquires GameConfig {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        assert!(!vector::contains(&game_config.collection_names, &collection_name), EWRONG_ALREADY_REGISTERED_COLLECTION);
        vector::push_back(&mut game_config.collection_names, collection_name);
    }

    public entry fun remove_collection_name(sender: &signer, collection_name: String) acquires GameConfig {
        utils::assert_owner(sender);
        let game_config = borrow_global_mut<GameConfig>(signer::address_of(sender));
        let (exist, index) = vector::index_of(&game_config.collection_names, &collection_name);
        assert!(exist, error::not_found(EWRONG_NOT_REGISTERED_COLLECTION));
        vector::remove(&mut game_config.collection_names, index);
    }
}
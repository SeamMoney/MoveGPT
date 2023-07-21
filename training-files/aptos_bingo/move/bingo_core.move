module overmind::bingo_core {
    use std::signer;
    use aptos_framework::account;
    use std::string::String;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::account::SignerCapability;
    use aptos_framework::event::EventHandle;
    // use overmind::bingo_events;
    use overmind::bingo_events::{CreateGameEvent, InsertNumberEvent, JoinGameEvent, BingoEvent, CancelGameEvent, new_create_game_event, new_inser_number_event, new_join_game_event, new_bingo_event, new_cance_game_event};
    use aptos_framework::event;
    use std::vector;
    use aptos_framework::timestamp;
    use std::option::Option;
    use std::option;
    #[test_only]
    use std::string;
    #[test_only]
    use aptos_framework::aptos_coin;

    ////////////
    // ERRORS //
    ////////////

    const SIGNER_NOT_ADMIN: u64 = 0;
    const INVALID_START_TIMESTAMP: u64 = 1;
    const BINGO_NOT_INITIALIZED: u64 = 2;
    const GAME_NAME_TAKEN: u64 = 3;
    const INVALID_NUMBER: u64 = 4;
    const GAME_DOES_NOT_EXIST: u64 = 5;
    const GAME_NOT_STARTED_YET: u64 = 6;
    const NUMBER_DUPLICATED: u64 = 7;
    const INVALID_AMOUNT_OF_COLUMNS_IN_PICKED_NUMBERS: u64 = 8;
    const INVALID_AMOUNT_OF_NUMBERS_IN_COLUMN: u64 = 9;
    const COLUMN_HAS_INVALID_NUMBER: u64 = 10;
    const GAME_ALREADY_STARTED: u64 = 11;
    const INSUFFICIENT_FUNDS: u64 = 12;
    const PLAYER_ALREADY_JOINED: u64 = 13;
    const GAME_HAS_ENDED: u64 = 14;
    const PLAYER_NOT_JOINED: u64 = 15;
    const PLAYER_HAVE_NOT_WON: u64 = 16;

    // Static seed
    const BINGO_SEED: vector<u8> = b"BINGO";

    /*
        Resource being stored in admin account. Holds address of bingo game's PDA account
    */
    struct State has key {
        // PDA address
        bingo: address
    }

    /*
        Resource holding data about on current and past games
    */
    struct Bingo has key {
        // List of games
        games: SimpleMap<String, Game>,
        // SignerCapability instance to recreate PDA's signer
        cap: SignerCapability,
        // Events
        create_game_events: EventHandle<CreateGameEvent>,
        cancel_game_events: EventHandle<CancelGameEvent>
    }

    /*
        Struct holding data about a single game
    */
    struct Game has store {
        // List of players participating in a game.
        // Every inner vector of the value represents a single column of a bingo sheet.
        players: SimpleMap<address, vector<vector<u8>>>,
        // Number of APT needed to participate in a game
        entry_fee: u64,
        // Timestamp of game's start
        start_timestamp: u64,
        // Numbers drawn by the admin for a game
        drawn_numbers: vector<u8>,
        // Boolean flag indicating if a game is ongoing or has finished
        is_finished: bool,
        // Events
        insert_number_events: EventHandle<InsertNumberEvent>,
        join_game_events: EventHandle<JoinGameEvent>,
        bingo_events: EventHandle<BingoEvent>
    }


    public fun min_value_except_zero(
        numbers: &vector<u8>,
    ): u8 {
        let min = *vector::borrow(numbers, 0);
        let index = 0;
        while(index < vector::length(numbers)) {
            let value = *vector::borrow(numbers, index);
            if (min > value && value != 0) {
                min = value;
            };
            index = index + 1;
        };
        min
    }

    public fun min_value(
        numbers: &vector<u8>,
    ): u8 {
        let min = *vector::borrow(numbers, 0);
        let index = 0;
        while(index < vector::length(numbers)) {
            let value = *vector::borrow(numbers, index);
            if (min > value) {
                min = value;
            };
            index = index + 1;
        };
        min
    }

    public fun max_value(
        numbers: &vector<u8>,
    ): u8 {
        let max = *vector::borrow(numbers, 0);
        let index = 0;
        while(index < vector::length(numbers)) {
            let value = *vector::borrow(numbers, index);
            if (max < value) {
                max = value;
            };
            index = index + 1;
        };  
        max
    }

    public fun check_consist_none_vector(data: &vector<Option<u8>>):bool {
        let len = vector::length(data);
        let index = 0;
        while(index < len) {
            if (!(*vector::borrow(data, index) == option::none())){ 
                return false
            };
            index = index + 1;
        };

        true
    }

    /*
        Initializes bingo
        @param admin - signer of the admin
    */
    public entry fun init(admin: &signer) {

        let admin_address = signer::address_of(admin);
        // TODO: Assert that the signer is the admin
        assert_admin(admin_address);

        // TODO: Create a bingo resource account
        let (account_resource_signer, signer_capability) = 
                    account::create_resource_account(admin, BINGO_SEED);

        // TODO: Register the resource account with AptosCoin
        coin::register<AptosCoin>(&account_resource_signer); 

        let signer_address = signer::address_of(&account_resource_signer);
        // TODO: Move State resource to the admin's address
        move_to(admin, State {
            bingo: signer_address
        });

        // TODO: Move Bingo resource to the resource account's address
        let games = simple_map::create<String, Game>();
        let create_game_events = account::new_event_handle<CreateGameEvent>(&account_resource_signer);
        let cancel_game_events = account::new_event_handle<CancelGameEvent>(&account_resource_signer);
        move_to(&account_resource_signer, Bingo {
            games,
            cap: signer_capability,
            create_game_events,
            cancel_game_events
        });
    }

    /*
        Creates a new game of bingo
        @param admin - signer of the admin
        @param game_name - name of the game
        @param entry_fee - entry fee of the game
        @param start_timestamp - start timestamp of the game
    */
    public entry fun create_game(
        admin: &signer,
        game_name: String,
        entry_fee: u64,
        start_timestamp: u64
    ) acquires State, Bingo {
        // TODO: Assert that start timestamp is valid
        assert_start_timestamp_is_valid(start_timestamp);

        // TODO: Assert that bingo is initialized
        let admin_address = signer::address_of(admin);
        assert_bingo_initialized(admin_address);

        let admin_address = signer::address_of(admin);
        let state = borrow_global<State>(admin_address);
        let bingo = borrow_global_mut<Bingo>(state.bingo);
        // TODO: Assert that the game name is not taken
        assert_game_name_not_taken(&bingo.games, &game_name);

        let account_resource_signer = account::create_signer_with_capability(&bingo.cap);
        let insert_number_events = account::new_event_handle<InsertNumberEvent>(&account_resource_signer);
        let join_game_events = account::new_event_handle<JoinGameEvent>(&account_resource_signer);
        let bingo_events = account::new_event_handle<BingoEvent>(&account_resource_signer);

        // TODO: Create a new Game instance
        let players = simple_map::create<address, vector<vector<u8>>>();
        let drawn_numbers = vector::empty<u8>();

        let game = Game {
            players,
            entry_fee,
            start_timestamp,
            drawn_numbers,
            is_finished: false,
            insert_number_events,
            join_game_events,
            bingo_events
        };

        // TODO: Add the game to the bingo's game list
        simple_map::add(&mut bingo.games, game_name, game);

        // TODO: Emit CreateGameEvent event
        let timestamp = timestamp::now_seconds();
        event::emit_event<CreateGameEvent>(
            &mut bingo.create_game_events,
            new_create_game_event( 
                game_name,
                entry_fee,
                start_timestamp,
                timestamp
            )
        );
    }

    /*
        Adds a number drawn by the admin to the vector of drawn numbers for a provided game
        @param admin - signer of the admin
        @param game_name - name of the game
        @param number - number drawn by the admin
    */
    public entry fun insert_number(admin: &signer, game_name: String, number: u8) acquires State, Bingo {

        let admin_address = signer::address_of(admin);

        // TODO: Assert that the drawn number is valid
        assert_inserted_number_is_valid(number);

        // TODO: Assert that bingo is initialized
        assert_bingo_initialized(admin_address);

        // TODO: Assert that the game exists
        let state = borrow_global<State>(admin_address);
        let bingo = borrow_global_mut<Bingo>(state.bingo);
        assert_game_exists(&bingo.games, &game_name);

        // TODO: Assert that the game already started
        let game = simple_map::borrow_mut(&mut bingo.games, &game_name);
        assert_game_already_stared(game.start_timestamp);

        // TODO: Assert that the drawn number is not a duplicate
        assert_number_not_duplicated(&game.drawn_numbers, &number);

        // TODO: Add the drawn number to game's drawn numbers
        vector::push_back(&mut game.drawn_numbers, number);

        // TODO: Emit InsertNumberEvent event
        let timestamp = timestamp::now_seconds();
        event::emit_event<InsertNumberEvent>(
            &mut game.insert_number_events,
            new_inser_number_event( 
                game_name,
                number,
                timestamp
            )
        );
    }

    /*
        Adds the signer to the list of participants of the provided game
        @param player - player wanting to join to the game
        @param game_name - name of the game
        @param numbers - vector of numbers picked by the player
            (should be 5x5 accordingly to https://pl.wikipedia.org/wiki/Bingo#Plansze_do_Bingo)
    */
    public entry fun join_game(player: &signer, game_name: String, numbers: vector<vector<u8>>) acquires State, Bingo {

        let player_address = signer::address_of(player);

        // TODO: Assert that bingo is initialized
        assert_bingo_initialized(@admin);

        // TODO: Assert that amount of picked numbers is correct
        assert_correct_amount_of_picked_numbers(&numbers);

        // TODO: Assert that the numbers are picked in correct way
        assert_numbers_are_picked_correctly(&numbers);

        // TODO: Assert that the game exists
        let state = borrow_global<State>(@admin);
        let bingo = borrow_global_mut<Bingo>(state.bingo);
        assert_game_exists(&bingo.games, &game_name);

        // TODO: Assert that the game has not started yet
        let game = simple_map::borrow_mut(&mut bingo.games, &game_name);
        assert_game_not_started(game.start_timestamp);

        // TODO: Assert that the player has enough APT to join the game
        assert_suffiecient_funds_to_join(player_address, game.entry_fee);

        // TODO: Assert that the player has not joined the game yet
        assert_player_not_joined_yet(&game.players, &player_address);

        // TODO: Add the player to the game's list of players
        simple_map::add(&mut game.players, player_address, numbers);

        // TODO: Transfer entry fee from the player to the bingo PDA
        coin::transfer<AptosCoin>(player, state.bingo, game.entry_fee);

        // TODO: Emit JoinGameEvent event
        let timestamp = timestamp::now_seconds();
        event::emit_event<JoinGameEvent>(
            &mut game.join_game_events,
            new_join_game_event( 
                game_name,
                player_address,
                numbers,
                timestamp
            )
        );

    }

    /*
        Allows a player to declare bingo for provided game
        @param player - player participating in the game
        @param game_name - name of the game
    */
    public entry fun bingo(player: &signer, game_name: String) acquires State, Bingo {

        let player_address = signer::address_of(player);

        // TODO: Assert that bingo is initialized
        assert_bingo_initialized(@admin);

        // TODO: Assert that the game exists
        let state = borrow_global<State>(@admin);
        let bingo = borrow_global_mut<Bingo>(state.bingo);
        assert_game_exists(&bingo.games, &game_name);

        // TODO: Assert that the game has not ended yet
        let game = simple_map::borrow_mut(&mut bingo.games, &game_name);
        assert_game_not_finished(game.is_finished);

        // TODO: Assert that the player joined the game
        assert_player_joined(&game.players, &player_address);

        // TODO: Assert that the player has bingo
        let play_numbers = simple_map::borrow(&game.players, &player_address);
        assert_player_has_bingo(&game.drawn_numbers, *play_numbers);

        // TODO: Change the game's is_finished field's value to true
        game.is_finished = true;

        // TODO: Transfer all players' entry fees to the winner
        let player_length = simple_map::length(&game.players);
        let account_resource_signer = account::create_signer_with_capability(&bingo.cap);
        coin::transfer<AptosCoin>(&account_resource_signer, player_address, game.entry_fee * player_length);

        // TODO: Emit BingoEvent event
        let timestamp = timestamp::now_seconds();
        event::emit_event<BingoEvent>(
            &mut game.bingo_events,
            new_bingo_event( 
                game_name,
                player_address,
                timestamp
            )
        );
    }

    /*
        Cancels an ongoing game
        @param admin - signer of the admin
        @param game_name - name of the game
    */
    public entry fun cancel_game(admin: &signer, game_name: String) acquires State, Bingo {

        let admin_address = signer::address_of(admin);
        // TODO: Assert that bingo is initialized
        assert_bingo_initialized(admin_address);

        // TODO: Assert that the game exists
        let state = borrow_global<State>(admin_address);
        let bingo = borrow_global_mut<Bingo>(state.bingo);
        let account_resource_signer = account::create_signer_with_capability(&bingo.cap);
        assert_game_exists(&bingo.games, &game_name);

        // TODO: Assert that the game has not finished yet
        let game = simple_map::borrow_mut(&mut bingo.games, &game_name);
        assert_game_not_finished(game.is_finished);

        // TODO: Change the game's is_finished field's value to true
        game.is_finished = true;

        // TODO: Transfer the players' entry fees back to them
        let (addresses, _) = simple_map::to_vec_pair(game.players);

        vector::for_each(addresses, |k| {
            coin::transfer<AptosCoin>(&account_resource_signer, k, game.entry_fee);
        });

        // TODO: Emit CancelGameEvent event
        let timestamp = timestamp::now_seconds();
        event::emit_event<CancelGameEvent>(
            &mut bingo.cancel_game_events,
            new_cance_game_event( 
                game_name,
                timestamp
            )
        );
        
    }

    /*
        Checks if a player has bingo in either column, row or diagonal
        @param drawn_numbers - numbers drawn by the admin
        @param player_numbers - numbers picked by the player
        @returns - true if the player has bingo, otherwise false
    */
    fun check_player_numbers(drawn_numbers: &vector<u8>, player_numbers: vector<vector<u8>>): bool {
        // TODO: Iterate through player's numbers and:
        //      1) If a number matches any number in the drawn numbers, then replace it with Option::None
        //      2) If a number is 0, then replace it with Option::None
        //      3) If a number does not match any number in the drawn numbers, then replace it with Option::Some

        // TODO: Call check_columns, check_diagonals and check_rows and return true if any of those returns true
        
        let res = false;
        let clone_player_numbers = vector::empty<vector<Option<u8>>>();
        let len_row = vector::length(&player_numbers);
        let row = 0;
        while(row < len_row) {
            let new_row = vector::empty<Option<u8>>();
            let row_data = vector::borrow(&player_numbers, row);
            let col = 0;
            while(col < len_row) {
                let value = vector::borrow(row_data, col);
                if (*value == 0 ||
                    vector::contains(drawn_numbers, value)
                ) {
                    vector::push_back(&mut new_row, option::none());
                } else {
                    vector::push_back(&mut new_row, option::some(*value));
                };
                col = col + 1;
            };
            vector::push_back(&mut clone_player_numbers, new_row);
            row = row + 1;
        };
 
        if (check_columns(&clone_player_numbers) ||
            check_rows(&clone_player_numbers) ||
            check_diagonals(&clone_player_numbers)
        ) {
            res = true;
        };

        res
    }

    /*
        Checks if a player has bingo in any column
        @param player_numbers - numbers picked by the player
        @returns - true if player has bingo in any column, otherwise false
    */
    inline fun check_columns(player_numbers: &vector<vector<Option<u8>>>): bool {
        // TODO: Return true if any column consists of Option::None only
        let len_row = vector::length(player_numbers);
        let i = 0;
        let res = false;
        while(i < len_row) {
            let row_data = vector::borrow(player_numbers, i);
            if (check_consist_none_vector(row_data)) {
                res = true;
            };
            i = i + 1;
        };

        res
    }

    /*
        Checks if a player has bingo in any row
        @param player_numbers - numbers picked by the player
        @returns - true if player has bingo in any row, otherwise false
    */
    inline fun check_rows(player_numbers: &vector<vector<Option<u8>>>): bool {
        // TODO: Return true if any row consists of Option::None only
        let len_row = vector::length(player_numbers);
        let len_column = len_row;
        let i = 0;
        let res = false;
        while(i < len_column) {
            let index = 0;
            let column = vector::empty<Option<u8>>();
            while(index < len_row) {
                let row_data = vector::borrow(player_numbers, index);
                vector::push_back(&mut column, *vector::borrow(row_data, i));
                index = index + 1;
            };
            if (check_consist_none_vector(&column)) {
                res = true;
            };
            i = i + 1;
        };

        res
    }

    /*
        Checks if a player has bingo in any diagonal
        @param player_numbers - numbers picked by the player
        @returns - true if player has bingo in any diagonal, otherwise false
    */
    inline fun check_diagonals(player_numbers: &vector<vector<Option<u8>>>): bool {
        // TODO: Return true if any diagonal consists of Option::None only
        let len_row = vector::length(player_numbers);
        let len_column = len_row;
        let res = false;
        let i = 0;
        let diagonals = vector::empty<Option<u8>>();
        let second_diagonals = vector::empty<Option<u8>>();
        while(i < len_column) {
            let index = 0;
            while(index < len_row) {
                let row_data = vector::borrow(player_numbers, index);
                let po_row_data = vector::borrow(player_numbers, len_row - index - 1);
                vector::push_back(&mut diagonals, *vector::borrow(row_data, index));
                vector::push_back(&mut second_diagonals, *vector::borrow(po_row_data, index));
                index = index + 1;
            };
            i = i + 1;
        };
        if (check_consist_none_vector(&diagonals)) {
            res = true;
        };
        if (check_consist_none_vector(&second_diagonals)) {
            res = true;
        };

        res
        
    }

    /////////////
    // ASSERTS //
    /////////////

    inline fun assert_admin(admin: address) {
        // TODO: Assert that the provided address is the admin address
        assert!(@admin == admin, SIGNER_NOT_ADMIN);
    }

    inline fun assert_start_timestamp_is_valid(start_timestamp: u64) {
        // TODO: Assert that provided start timestamp is greater than current timestamp
        assert!(start_timestamp > timestamp::now_seconds(), INVALID_START_TIMESTAMP);
    }

    inline fun assert_bingo_initialized(admin: address) acquires State {
        // TODO: Assert that the admin has State resource and bingo PDA has Bingo resource
        assert!(exists<State>(admin), BINGO_NOT_INITIALIZED);
        let state = borrow_global<State>(admin);
        assert!(exists<Bingo>(state.bingo), BINGO_NOT_INITIALIZED);
    }

    inline fun assert_game_name_not_taken(games: &SimpleMap<String, Game>, game_name: &String) {
        // TODO: Assert that the games list does not contain the provided game name
        assert!(!simple_map::contains_key(games, game_name) , GAME_NAME_TAKEN);
    }

    inline fun assert_inserted_number_is_valid(number: u8) {
        // TODO: Assert that the number is in a range <1;75>
        assert!(number > 0 && number < 76, INVALID_NUMBER);
    }

    inline fun assert_game_exists(games: &SimpleMap<String, Game>, game_name: &String) {
        // TODO: Assert that the games list contains the provided game name
        assert!(simple_map::contains_key(games, game_name) , GAME_DOES_NOT_EXIST);
    }

    inline fun assert_game_already_stared(start_timestamp: u64) {
        // TODO: Assert that the provided start timestamp is smaller or equals current timestamp
        assert!(start_timestamp <= timestamp::now_seconds(), GAME_NOT_STARTED_YET);
    }

    inline fun assert_number_not_duplicated(numbers: &vector<u8>, number: &u8) {
        // TODO: Assert that the numbers vector does not contains the provided number
        assert!(!vector::contains(numbers, number) ,NUMBER_DUPLICATED);
    }

    inline fun assert_correct_amount_of_picked_numbers(picked_numbers: &vector<vector<u8>>) {
        // TODO: Assert that the picked numbers is a 2D vector 5x5
        assert!(vector::length(picked_numbers) == 5, INVALID_AMOUNT_OF_COLUMNS_IN_PICKED_NUMBERS);
        assert!(
            vector::length(vector::borrow(picked_numbers, 0)) == 5 &&
            vector::length(vector::borrow(picked_numbers, 1)) == 5 &&
            vector::length(vector::borrow(picked_numbers, 2)) == 5 &&
            vector::length(vector::borrow(picked_numbers, 3)) == 5 &&
            vector::length(vector::borrow(picked_numbers, 4)) == 5,
            INVALID_AMOUNT_OF_NUMBERS_IN_COLUMN
        );
    }

    inline fun assert_numbers_are_picked_correctly(picked_numbers: &vector<vector<u8>>) {
        // TODO: Assert that the numbers are picked correctly accordingily to the rules:
        //      1) The first column must consist of numbers from a range of <1; 15>
        //      2) The second column must consist of numbers from a range of <16; 30>
        //      3) The third column must consist of numbers from a range of <31; 45>
        //      4) The fourth column must consist of numbers from a range of <46; 60>
        //      5) The fifth column must consist of numbers from a range of <61; 75>
        //      6) The middle number of the third column must be 0

        let first_column = vector::borrow(picked_numbers, 0);
        let second_column = vector::borrow(picked_numbers, 1);
        let third_column = vector::borrow(picked_numbers, 2);
        let fourth_column = vector::borrow(picked_numbers, 3);
        let fifth_column = vector::borrow(picked_numbers, 4);
        
        assert!(
            min_value(first_column) >= 1 && max_value(first_column) <= 15 &&
            min_value(second_column) >= 16 && max_value(second_column) <= 30 &&
            min_value_except_zero(third_column) >= 31 && max_value(third_column) <= 45 &&
            min_value(fourth_column) >= 46 && max_value(fourth_column) <= 60 &&
            min_value(fifth_column) >= 61 && max_value(fifth_column) <= 75 &&
            *vector::borrow(third_column, 2) == 0,
            COLUMN_HAS_INVALID_NUMBER
        );
    }

    inline fun assert_game_not_started(start_timestamp: u64) {
        // TODO: Assert that the start timestamp is greater that the current timestamp
        assert!(start_timestamp > timestamp::now_seconds(), GAME_ALREADY_STARTED);
    }

    inline fun assert_suffiecient_funds_to_join(player: address, entry_fee: u64) {
        // TODO: Assert that the player has enough APT coins to participate in a game
        let coins = coin::balance<AptosCoin>(player);
        assert!(coins >= entry_fee, INSUFFICIENT_FUNDS);
    }

    inline fun assert_player_not_joined_yet(players: &SimpleMap<address, vector<vector<u8>>>, player: &address) {
        // TODO: Assert that the players list does not contain the player's address
        assert!(!simple_map::contains_key(players, player), PLAYER_ALREADY_JOINED);
    }

    inline fun assert_game_not_finished(is_finished: bool) {
        // TODO: Assert that the game has not ended yet
        assert!(!is_finished, GAME_HAS_ENDED);
    }

    inline fun assert_player_joined(players: &SimpleMap<address, vector<vector<u8>>>, player: &address) {
        // TODO: Assert that the players list contains the player's address
        assert!(simple_map::contains_key(players, player), PLAYER_NOT_JOINED);
    }

    inline fun assert_player_has_bingo(drawn_numbers: &vector<u8>, player_numbers: vector<vector<u8>>) {
        // TODO: Assert that the player has bingo by comparing their numbers with the drawn ones

        assert!(check_player_numbers(drawn_numbers, player_numbers), PLAYER_HAVE_NOT_WON);
        // let first_column = vector::borrow(&player_numbers, 0);
        // let second_column = vector::borrow(&player_numbers, 1);
        // let third_column = vector::borrow(&player_numbers, 2);
        // let fourth_column = vector::borrow(&player_numbers, 3);
        // let fifth_column = vector::borrow(&player_numbers, 4);
        
        // let row_data = vector[
        //     *vector::borrow(first_column, 0),
        //     *vector::borrow(second_column, 0),
        //     *vector::borrow(third_column, 0),
        //     *vector::borrow(fourth_column, 0),
        //     *vector::borrow(fifth_column, 0),
        // ];

        // assert!(
        //     vector::length(drawn_numbers) == vector::length(first_column) &&
        //     vector::length(drawn_numbers) == vector::length(&row_data),
        //     PLAYER_HAVE_NOT_WON
        // );

        // assert!(
        //     vector_compare(first_column, drawn_numbers) || 
        //     vector_compare(&row_data, drawn_numbers), 
        //     PLAYER_HAVE_NOT_WON
        // );
    }

    ///////////
    // TESTS //
    ///////////

    #[test]
    fun test_init() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        assert!(exists<State>(@admin), 0);

        let state = borrow_global<State>(@admin);
        assert!(state.bingo == account::create_resource_address(&@admin, b"BINGO"), 1);
        assert!(coin::is_account_registered<AptosCoin>(state.bingo), 2);
        assert!(exists<Bingo>(state.bingo), 3);

        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 0, 4);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 5);
        assert!(event::counter(&bingo.create_game_events) == 0, 6);
        assert!(event::counter(&bingo.cancel_game_events) == 0, 7);
    }

    #[test]
    #[expected_failure(abort_code = 0, location = Self)]
    fun test_init_signer_not_admin() {
        let user = account::create_account_for_test(@0xCAFE);
        init(&user);
    }

    #[test]
    fun test_create_game() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let state = borrow_global<State>(@admin);
        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 1, 0);
        assert!(simple_map::contains_key(&bingo.games, &game_name), 1);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 2);
        assert!(event::counter(&bingo.create_game_events) == 1, 3);
        assert!(event::counter(&bingo.cancel_game_events) == 0, 4);

        let game = simple_map::borrow(&bingo.games, &game_name);
        assert!(simple_map::length(&game.players) == 0, 5);
        assert!(game.entry_fee == entry_fee, 6);
        assert!(game.start_timestamp == start_timestamp, 7);
        assert!(vector::length(&game.drawn_numbers) == 0, 8);
        assert!(!game.is_finished, 9);
        assert!(event::counter(&game.insert_number_events) == 0, 10);
        assert!(event::counter(&game.join_game_events) == 0, 11);
        assert!(event::counter(&game.bingo_events) == 0, 12);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = Self)]
    fun test_create_game_invalid_timestamp() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        timestamp::fast_forward_seconds(100);

        let admin = account::create_account_for_test(@admin);
        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 99;
        create_game(&admin, game_name, entry_fee, start_timestamp);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    fun test_create_game_bingo_not_initialized() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = Self)]
    fun test_create_game_name_taken() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);
        create_game(&admin, game_name, entry_fee, start_timestamp);
    }

    #[test]
    fun test_insert_number() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        timestamp::fast_forward_seconds(555);

        let number_drawn = 55;
        insert_number(&admin, game_name, number_drawn);

        let state = borrow_global<State>(@admin);
        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 1, 0);
        assert!(simple_map::contains_key(&bingo.games, &game_name), 1);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 2);
        assert!(event::counter(&bingo.create_game_events) == 1, 3);
        assert!(event::counter(&bingo.cancel_game_events) == 0, 4);

        let game = simple_map::borrow(&bingo.games, &game_name);
        assert!(simple_map::length(&game.players) == 0, 5);
        assert!(game.entry_fee == entry_fee, 6);
        assert!(game.start_timestamp == start_timestamp, 7);
        assert!(vector::length(&game.drawn_numbers) == 1, 8);
        assert!(vector::contains(&game.drawn_numbers, &number_drawn), 9);
        assert!(!game.is_finished, 10);
        assert!(event::counter(&game.insert_number_events) == 1, 11);
        assert!(event::counter(&game.join_game_events) == 0, 12);
        assert!(event::counter(&game.bingo_events) == 0, 13);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = Self)]
    fun test_insert_number_invalid() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        let game_name = string::utf8(b"The first game");
        let number_drawn = 99;
        insert_number(&admin, game_name, number_drawn);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    fun test_insert_number_bingo_not_initialized() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        let game_name = string::utf8(b"The first game");
        let number_drawn = 55;
        insert_number(&admin, game_name, number_drawn);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = Self)]
    fun test_insert_number_game_does_not_exist() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let number_drawn = 55;
        insert_number(&admin, game_name, number_drawn);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = Self)]
    fun test_inser_number_game_not_started_yet() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let game_name = string::utf8(b"The first game");
        let number_drawn = 55;
        insert_number(&admin, game_name, number_drawn);
    }

    #[test]
    #[expected_failure(abort_code = 7, location = Self)]
    fun test_insert_number_duplicated() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        timestamp::fast_forward_seconds(555);

        let number_drawn = 55;
        insert_number(&admin, game_name, number_drawn);
        insert_number(&admin, game_name, number_drawn);
    }

    #[test]
    fun test_join_game() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5648964;
        let start_timestamp = 555;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        let numbers = vector[
            vector[1, 2, 5, 4, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, entry_fee + 1);
        join_game(&player, game_name, numbers);

        let state = borrow_global<State>(@admin);
        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 1, 0);
        assert!(simple_map::contains_key(&bingo.games, &game_name), 1);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 2);
        assert!(event::counter(&bingo.create_game_events) == 1, 3);
        assert!(event::counter(&bingo.cancel_game_events) == 0, 4);

        let game = simple_map::borrow(&bingo.games, &game_name);
        assert!(simple_map::length(&game.players) == 1, 5);
        assert!(simple_map::contains_key(&game.players, &@0xCAFE), 6);
        assert!(simple_map::borrow(&game.players, &@0xCAFE) == &numbers, 7);
        assert!(game.entry_fee == entry_fee, 8);
        assert!(game.start_timestamp == start_timestamp, 9);
        assert!(vector::length(&game.drawn_numbers) == 0, 10);
        assert!(!game.is_finished, 11);
        assert!(event::counter(&game.insert_number_events) == 0, 12);
        assert!(event::counter(&game.join_game_events) == 1, 13);
        assert!(event::counter(&game.bingo_events) == 0, 14);
        assert!(coin::balance<AptosCoin>(@0xCAFE) == 1, 15);
        assert!(coin::balance<AptosCoin>(state.bingo) == entry_fee, 16);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    fun test_join_game_bingo_not_initialized() acquires State, Bingo {
        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 4, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 41, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 8, location = Self)]
    fun test_join_game_invalid_number_of_columns() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 4, 8],
            vector[16, 17, 20, 19, 30],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = Self)]
    fun test_join_game_invalid_amount_of_numbers_in_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 4, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = Self)]
    fun test_join_game_invalid_numbers_first_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 16, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = Self)]
    fun test_join_game_invalid_numbers_second_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 11, 8],
            vector[16, 17, 44, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = Self)]
    fun test_join_game_invalid_numbers_third_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 11, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = Self)]
    fun test_join_game_invalid_numbers_fourth_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[5, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = Self)]
    fun test_join_game_invalid_numbers_fifth_column() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 18]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = Self)]
    fun test_join_game_does_not_exist() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 11, location = Self)]
    fun test_join_game_already_started() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        timestamp::fast_forward_seconds(45462);

        let player = account::create_account_for_test(@0xCAFE);
        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
    }

    #[test]
    #[expected_failure(abort_code = 12, location = Self)]
    fun test_join_game_insufficient_funds() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, 44564);

        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    #[expected_failure(abort_code = 13, location = Self)]
    fun test_join_game_player_already_joined() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, 2 * entry_fee);

        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
        join_game(&player, game_name, numbers);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    fun test_bingo() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, entry_fee);

        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);

        let another_player = account::create_account_for_test(@0xACE);
        coin::register<AptosCoin>(&another_player);
        aptos_coin::mint(&aptos_framework, @0xACE, entry_fee);

        let another_numbers = vector[
            vector[3, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[33, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&another_player, game_name, another_numbers);

        timestamp::fast_forward_seconds(45462);

        let drawn_numbers = vector[1, 16, 31, 46, 66];
        vector::for_each_ref(&drawn_numbers, |number| {
            insert_number(&admin, game_name, *number);
        });

        bingo(&player, game_name);

        let state = borrow_global<State>(@admin);
        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 1, 0);
        assert!(simple_map::contains_key(&bingo.games, &game_name), 1);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 2);
        assert!(event::counter(&bingo.create_game_events) == 1, 3);
        assert!(event::counter(&bingo.cancel_game_events) == 0, 4);

        let game = simple_map::borrow(&bingo.games, &game_name);
        assert!(simple_map::length(&game.players) == 2, 5);
        assert!(simple_map::contains_key(&game.players, &@0xCAFE), 6);
        assert!(simple_map::contains_key(&game.players, &@0xACE), 7);
        assert!(simple_map::borrow(&game.players, &@0xCAFE) == &numbers, 8);
        assert!(simple_map::borrow(&game.players, &@0xACE) == &another_numbers, 9);
        assert!(game.entry_fee == entry_fee, 10);
        assert!(game.start_timestamp == start_timestamp, 11);
        assert!(game.drawn_numbers == drawn_numbers, 12);
        assert!(game.is_finished, 13);
        assert!(event::counter(&game.insert_number_events) == 5, 14);
        assert!(event::counter(&game.join_game_events) == 2, 15);
        assert!(event::counter(&game.bingo_events) == 1, 16);
        assert!(coin::balance<AptosCoin>(state.bingo) == 0, 17);
        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 18);
        assert!(coin::balance<AptosCoin>(@0xCAFE) == 2 * entry_fee, 19);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    fun test_bingo_not_initialized() acquires State, Bingo {
        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        bingo(&player, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = Self)]
    fun test_bingo_game_does_not_exist() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let player = account::create_account_for_test(@0xCAFE);
        let game_name = string::utf8(b"The first game");
        bingo(&player, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 14, location = Self)]
    fun test_bingo_game_has_ended() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        {
            let state = borrow_global<State>(@admin);
            let bingo = borrow_global_mut<Bingo>(state.bingo);
            let game = simple_map::borrow_mut(&mut bingo.games, &game_name);
            game.is_finished = true;
        };

        let player = account::create_account_for_test(@0xCAFE);
        bingo(&player, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 15, location = Self)]
    fun test_bingo_player_not_joined() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        bingo(&player, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 16, location = Self)]
    fun test_bingo_player_not_won() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, entry_fee);

        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);
        bingo(&player, game_name);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    fun test_cancel_game() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let player = account::create_account_for_test(@0xCAFE);
        coin::register<AptosCoin>(&player);
        aptos_coin::mint(&aptos_framework, @0xCAFE, entry_fee);

        let numbers = vector[
            vector[1, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[31, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&player, game_name, numbers);

        let another_player = account::create_account_for_test(@0xACE);
        coin::register<AptosCoin>(&another_player);
        aptos_coin::mint(&aptos_framework, @0xACE, entry_fee);

        let another_numbers = vector[
            vector[3, 2, 5, 10, 8],
            vector[16, 17, 20, 19, 30],
            vector[33, 45, 0, 42, 43],
            vector[46, 50, 54, 49, 55],
            vector[66, 61, 65, 70, 69]
        ];
        join_game(&another_player, game_name, another_numbers);

        cancel_game(&admin, game_name);

        let state = borrow_global<State>(@admin);
        let bingo = borrow_global<Bingo>(state.bingo);
        assert!(simple_map::length(&bingo.games) == 1, 0);
        assert!(simple_map::contains_key(&bingo.games, &game_name), 1);
        assert!(&bingo.cap == &account::create_test_signer_cap(state.bingo), 2);
        assert!(event::counter(&bingo.create_game_events) == 1, 3);
        assert!(event::counter(&bingo.cancel_game_events) == 1, 4);

        let game = simple_map::borrow(&bingo.games, &game_name);
        assert!(simple_map::length(&game.players) == 2, 5);
        assert!(simple_map::contains_key(&game.players, &@0xCAFE), 6);
        assert!(simple_map::contains_key(&game.players, &@0xACE), 7);
        assert!(simple_map::borrow(&game.players, &@0xCAFE) == &numbers, 8);
        assert!(simple_map::borrow(&game.players, &@0xACE) == &another_numbers, 9);
        assert!(game.entry_fee == entry_fee, 10);
        assert!(game.start_timestamp == start_timestamp, 11);
        assert!(vector::length(&game.drawn_numbers) == 0, 12);
        assert!(game.is_finished, 13);
        assert!(event::counter(&game.insert_number_events) == 0, 14);
        assert!(event::counter(&game.join_game_events) == 2, 15);
        assert!(event::counter(&game.bingo_events) == 0, 16);
        assert!(coin::balance<AptosCoin>(state.bingo) == 0, 17);
        assert!(coin::balance<AptosCoin>(@0xACE) == entry_fee, 18);
        assert!(coin::balance<AptosCoin>(@0xCAFE) == entry_fee, 19);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = Self)]
    fun test_cancel_game_bingo_not_initialized() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        let game_name = string::utf8(b"The first game");
        cancel_game(&admin, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = Self)]
    fun test_cancel_game_does_not_exist() acquires State, Bingo {
        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        cancel_game(&admin, game_name);
    }

    #[test]
    #[expected_failure(abort_code = 14, location = Self)]
    fun test_cancel_game_has_ended() acquires State, Bingo {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        init(&admin);

        let game_name = string::utf8(b"The first game");
        let entry_fee = 5984255;
        let start_timestamp = 45462;
        create_game(&admin, game_name, entry_fee, start_timestamp);

        let game_name = string::utf8(b"The first game");
        cancel_game(&admin, game_name);
        cancel_game(&admin, game_name);
    }

    #[test]
    fun test_check_player_numbers() {
        let drawn_numbers = vector[1, 2, 4, 6, 11];
        let player_numbers = vector[
            vector[1, 2, 4, 6, 11],
            vector[16, 18, 17, 25, 24],
            vector[31, 40, 0, 39, 44],
            vector[46, 50, 55, 59, 51],
            vector[61, 62, 75, 74, 70]
        ];
        assert!(check_player_numbers(&drawn_numbers, player_numbers), 0);

        let drawn_numbers = vector[4, 17, 55, 75];
        let player_numbers = vector[
            vector[1, 2, 4, 6, 11],
            vector[16, 18, 17, 25, 24],
            vector[31, 40, 0, 39, 44],
            vector[46, 50, 55, 59, 51],
            vector[61, 62, 75, 74, 70]
        ];
        assert!(check_player_numbers(&drawn_numbers, player_numbers), 1);

        let drawn_numbers = vector[61, 50, 25, 11];
        let player_numbers = vector[
            vector[1, 2, 4, 6, 11],
            vector[16, 18, 17, 25, 24],
            vector[31, 40, 0, 39, 44],
            vector[46, 50, 55, 59, 51],
            vector[61, 62, 75, 74, 70]
        ];
        assert!(check_player_numbers(&drawn_numbers, player_numbers), 2);

        let drawn_numbers = vector[61, 50, 24, 11];
        let player_numbers = vector[
            vector[1, 2, 4, 6, 11],
            vector[16, 18, 17, 25, 24],
            vector[31, 40, 0, 39, 44],
            vector[46, 50, 55, 59, 51],
            vector[61, 62, 75, 74, 70]
        ];
        assert!(!check_player_numbers(&drawn_numbers, player_numbers), 3);
    }

    #[test]
    fun test_check_diagonals() {
        let numbers_fist_diagonal = vector[
            vector[option::none(), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::none(), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::none(), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::none()],
        ];
        assert!(check_diagonals(&numbers_fist_diagonal), 0);

        let numbers_second_diagonal = vector[
            vector[option::some(11), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::some(17), option::some(21), option::none(), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::some(51), option::some(52)],
            vector[option::none(), option::some(61), option::some(70), option::some(74), option::some(63)],
        ];
        assert!(check_diagonals(&numbers_second_diagonal), 1);

        let numbers_both_diagonals = vector[
            vector[option::none(), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::none(), option::some(21), option::none(), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::none(), option::some(52)],
            vector[option::none(), option::some(61), option::some(70), option::some(74), option::none()],
        ];
        assert!(check_diagonals(&numbers_both_diagonals), 2);

        let numbers_random_pattern = vector[
            vector[option::some(11), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::none(), option::some(21), option::none(), option::some(26)],
            vector[option::none(), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::some(51), option::some(52)],
            vector[option::some(71), option::some(61), option::none(), option::some(74), option::some(63)],
        ];
        assert!(!check_diagonals(&numbers_random_pattern), 3);

        let all_numbers = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(!check_diagonals(&all_numbers), 4);
    }

    #[test]
    fun test_check_columns() {
        let first_column = vector[
            vector[option::none(), option::none(), option::none(), option::none(), option::none()],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_columns(&first_column), 0);

        let second_column = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::none(), option::none(), option::none(), option::none(), option::none()],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_columns(&second_column), 1);

        let third_column = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::none(), option::none(), option::none(), option::none(), option::none()],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_columns(&third_column), 2);

        let fourth_column = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::none(), option::none(), option::none(), option::none(), option::none()],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_columns(&fourth_column), 3);

        let fifth_column = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::none(), option::none(), option::none(), option::none(), option::none()],
        ];
        assert!(check_columns(&fifth_column), 4);

        let numbers_random_pattern = vector[
            vector[option::some(11), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::none(), option::some(21), option::none(), option::some(26)],
            vector[option::none(), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::some(51), option::some(52)],
            vector[option::some(71), option::some(61), option::none(), option::some(74), option::some(63)],
        ];
        assert!(!check_columns(&numbers_random_pattern), 5);

        let all_numbers = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(!check_columns(&all_numbers), 6);
    }

    #[test]
    fun test_check_rows() {
        let first_row = vector[
            vector[option::none(), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::none(), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::none(), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::none(), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::none(), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_rows(&first_row), 0);

        let second_row = vector[
            vector[option::some(1), option::none(), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::none(), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::none(), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::none(), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(check_rows(&second_row), 1);

        let third_row = vector[
            vector[option::some(1), option::some(12), option::none(), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::none(), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::none(), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::none(), option::some(74), option::some(75)],
        ];
        assert!(check_rows(&third_row), 2);

        let fourth_row = vector[
            vector[option::some(1), option::some(12), option::some(4), option::none(), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::none(), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::none(), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::none(), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::none(), option::some(75)],
        ];
        assert!(check_rows(&fourth_row), 3);

        let fifth_row = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::none()],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::none()],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::none()],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::none()],
        ];
        assert!(check_rows(&fifth_row), 4);

        let numbers_random_pattern = vector[
            vector[option::some(11), option::some(12), option::some(4), option::some(8), option::none()],
            vector[option::some(16), option::none(), option::some(21), option::none(), option::some(26)],
            vector[option::none(), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::none(), option::some(49), option::some(51), option::some(52)],
            vector[option::some(71), option::some(61), option::none(), option::some(74), option::some(63)],
        ];
        assert!(!check_rows(&numbers_random_pattern), 5);

        let all_numbers = vector[
            vector[option::some(1), option::some(12), option::some(4), option::some(8), option::some(11)],
            vector[option::some(16), option::some(18), option::some(21), option::some(17), option::some(26)],
            vector[option::some(31), option::some(32), option::none(), option::some(44), option::some(41)],
            vector[option::some(46), option::some(51), option::some(49), option::some(50), option::some(52)],
            vector[option::some(63), option::some(61), option::some(70), option::some(74), option::some(75)],
        ];
        assert!(!check_rows(&all_numbers), 6);
    }
}

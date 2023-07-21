module aptos_arcade::match {

    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::vector;

    use aptos_std::type_info;
    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object};

    use aptos_token_objects::collection;

    use aptos_arcade::elo;
    use aptos_arcade::game_admin::{Self, GameAdminCapability, get_game_account_address};

    // error codes

    /// when there are not enough teams
    const ENOT_ENOUGH_TEAMS: u64 = 0;

    /// when the teams are empty
    const ETEAMS_EMPTY: u64 = 1;

    /// error code for when the teams are not the same length
    const ETEAMS_NOT_SAME_LENGTH: u64 = 2;

    /// error code for when a player on a team has not registered an ELO token
    const EPLAYER_NOT_REGISTERED: u64 = 3;

    /// error code for when a match is already complete
    const EMATCH_ALREADY_COMPLETE: u64 = 4;

    /// error code for when the winner index is invalid
    const EINVALID_WINNER_INDEX: u64 = 5;

    // constants

    const COLLECTION_BASE_NAME: vector<u8> = b"{} Matches";
    const COLLECTION_BASE_DESCRIPTION: vector<u8> = b"Match system for {}.";
    const COLLECTION_URI: vector<u8> = b"aptos://match";

    const TOKEN_BASE_NAME: vector<u8> = b"{} Match";
    const TOKEN_BASE_DESCRIPTION: vector<u8> = b"A match token for {}.";
    const TOKEN_URI: vector<u8> = b"aptos://match";

    struct Match<phantom GameType> has key {
        teams: vector<vector<address>>,
        winner_index: Option<u64>
    }

    /// initializes a `MatchCollection `for `GameType`
    /// `game_admin_cap` - reference to a `GameAdminCapability` for `GameType`
    public fun initialize_matches_collection<GameType: drop>(game_admin_cap: &GameAdminCapability<GameType>) {
        // initialize the match collection
        game_admin::create_collection(
            game_admin_cap,
            get_collection_description<GameType>(),
            get_collection_name<GameType>(),
            option::none(),
            get_collection_uri<GameType>(),
            true,
            false,
            false,
        );
    }

    /// creates a match for `GameType` with `teams`
    /// `game_admin_cap` - reference to a `GameAdminCapability` for `GameType`
    /// `teams` - a vector of teams, where each team is a vector of player addresses
    public fun create_match<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        teams: vector<vector<address>>
    ): Object<Match<GameType>> {
        assert_more_than_one_team(&teams);
        assert_at_least_one_player_per_team(&teams);
        assert_teams_are_same_size(&teams);
        assert_all_players_registered<GameType>(teams);


        // mint a token for a player
        let constructor_ref = game_admin::mint_token_game_admin(
            game_admin_cap,
            get_collection_name<GameType>(),
            get_match_description<GameType>(),
            get_match_name<GameType>(),
            option::none(),
            string::utf8(COLLECTION_URI),
            get_game_account_address<GameType>()
        );

        // add ELO rating resource
        let token_signer = object::generate_signer(&constructor_ref);
        move_to(&token_signer, Match<GameType> {
            teams,
            winner_index: option::none()
        });

        // disable token transfer
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);

        // return the match object
        object::object_from_constructor_ref(&constructor_ref)
    }

    /// sets the winner of a match
    /// `game_admin_cap` - reference to a `GameAdminCapability` for `GameType`
    /// `match` - the match to set the winner for
    /// `winner_index` - the index of the winning team
    public fun set_match_result<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        match: Object<Match<GameType>>,
        winner_index: u64
    ) acquires Match {
        let match = borrow_global_mut<Match<GameType>>(object::object_address(&match));
        assert_match_not_complete(match);
        assert_valid_winner_index(winner_index, &match.teams);
        match.winner_index = option::some(winner_index);
        elo::update_match_elo_ratings<GameType>(
            game_admin_cap,
            match.teams,
            winner_index
        );
        win_loss::update_match_win_loss<GameType>(
            game_admin_cap,
            match.teams,
            winner_index
        );
    }

    // view functions

    #[view]
    /// returns the address of the `GameType` match collection
    public fun get_matches_collection_address<GameType>(): address {
        collection::create_collection_address(
            &game_admin::get_game_account_address<GameType>(),
            &get_collection_name<GameType>()
        )
    }

    #[view]
    /// returns the teams and result option for `match`
    /// `match` - the match to get information for
    public fun get_match<GameType>(match: Object<Match<GameType>>): (vector<vector<address>>, Option<u64>) acquires Match {
        let match = borrow_global<Match<GameType>>(object::object_address(&match));
        (match.teams, match.winner_index)
    }

    // helper functions

    /// returns the name for the `GameType` match collection
    fun get_collection_name<GameType>(): String {
        string_utils::format1(&COLLECTION_BASE_NAME, type_info::struct_name(&type_info::type_of<GameType>()))
    }

    /// returns the description for the `GameType` match collection
    fun get_collection_description<GameType>(): String {
        string_utils::format1(&COLLECTION_BASE_DESCRIPTION, type_info::struct_name(&type_info::type_of<GameType>()))
    }

    /// returns the URI for a match collection
    fun get_collection_uri<GameType>(): String {
        string::utf8(COLLECTION_URI)
    }

    /// returns the name for a match token
    fun get_match_name<GameType>(): String {
        string_utils::format1(&TOKEN_BASE_NAME, type_info::struct_name(&type_info::type_of<GameType>()))
    }

    /// returns the description for a match token
    fun get_match_description<GameType>(): String {
        string_utils::format1(&TOKEN_BASE_DESCRIPTION,type_info::struct_name(&type_info::type_of<GameType>()))
    }

    /// returns the URI for a match token
    fun get_match_uri<GameType>(): String {
        string::utf8(TOKEN_URI)
    }

    // assert statements

    /// asserts that there are at least two teams
    /// `teams` - a vector of team vectors
    fun assert_more_than_one_team(teams: &vector<vector<address>>) {
        assert!(vector::length(teams) > 1, ENOT_ENOUGH_TEAMS);
    }

    /// asserts that there is at least one player per team
    /// `teams` - a vector of team vectors
    fun assert_at_least_one_player_per_team(teams: &vector<vector<address>>) {
        assert!(vector::all(teams, | entry | vector::length(entry) > 0), ETEAMS_EMPTY);
    }

    /// asserts that every player has registered an ELO token
    /// `teams` - a vector of team vectors
    fun assert_all_players_registered<GameType>(teams: vector<vector<address>>) {
        vector::for_each(teams, | team | assert_all_players_registered_on_team<GameType>(team));
    }

    /// asserts that every player on a team has registered an ELO token
    /// `team` - a vector of addresses
    fun assert_all_players_registered_on_team<GameType>(team: vector<address>) {
        vector::for_each(team, | player | {
            assert!(
                elo::has_player_registered_elo<GameType>(player) && win_loss::has_player_registered_win_loss<GameType>(player),
                EPLAYER_NOT_REGISTERED
            );
        });
    }

    /// asserts that all teams are the same size
    /// `teams` - a vector of team vectors
    fun assert_teams_are_same_size(teams: &vector<vector<address>>) {
        assert!(
            vector::all(teams, | entry | vector::length(entry) == vector::length(vector::borrow(teams, 0))),
            ETEAMS_NOT_SAME_LENGTH
        );
    }

    /// asserts that `match` is not complete
    /// `match` - the match to check
    fun assert_match_not_complete<GameType>(match: &Match<GameType>) {
        assert!(match.winner_index == option::none(), EMATCH_ALREADY_COMPLETE);
    }

    /// asserts that the `winner_index` is valid for a match
    /// `winner_index` - the index of the winning team
    /// `teams` - the teams in the match
    fun assert_valid_winner_index(winner_index: u64, teams: &vector<vector<address>>) {
        assert!(winner_index < vector::length(teams), EINVALID_WINNER_INDEX);
    }

    // tests

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_token_objects::token;
    #[test_only]
    use aptos_arcade::game_admin::Collection;
    #[test_only]
    use aptos_arcade::profile;
    use aptos_arcade::win_loss;

    #[test_only]
    struct TestGame has drop {}

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_initialize_matches_collection(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        initialize_matches_collection(&game_admin_cap);
        let collection_object = object::address_to_object<Collection>(
            get_matches_collection_address<TestGame>()
        );
        assert!(collection::name(collection_object) == get_collection_name<TestGame>(), 0);
        assert!(collection::description(collection_object) == get_collection_description<TestGame>(), 0);
        assert!(collection::uri(collection_object) == get_collection_uri<TestGame>(), 0);
        assert!(*option::borrow(&collection::count(collection_object)) == 0, 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    fun test_create_match(aptos_arcade: &signer, player1: &signer, player2: &signer) acquires Match {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_matches_collection(&game_admin_cap);
        elo::initialize_elo_collection(&game_admin_cap);
        win_loss::initialize_win_loss(&game_admin_cap);

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        elo::mint_elo_token(&profile::create_profile_cap(player1, &TestGame {}));
        elo::mint_elo_token(&profile::create_profile_cap(player2, &TestGame {}));

        win_loss::mint_win_loss_token(&profile::create_profile_cap(player1, &TestGame {}));
        win_loss::mint_win_loss_token(&profile::create_profile_cap(player2, &TestGame {}));

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        let match_object = create_match(&game_admin_cap, teams);

        assert!(token::name(match_object) == get_match_name<TestGame>(), 0);
        assert!(token::description(match_object) == get_match_description<TestGame>(), 0);
        assert!(token::uri(match_object) == get_match_uri<TestGame>(), 0);
        assert!(object::is_owner(match_object, game_admin::get_game_account_address<TestGame>()), 0);

        let (teams, winning_index) = get_match(match_object);
        assert!(vector::length(&teams) == 2, 0);
        assert!(vector::length(vector::borrow(&teams, 0)) == 1, 0);
        assert!(vector::length(vector::borrow(&teams, 1)) == 1, 0);
        assert!(*vector::borrow(vector::borrow(&teams, 0), 0) == player1_address, 0);
        assert!(*vector::borrow(vector::borrow(&teams, 1), 0) == player2_address, 0);
        assert!(winning_index == option::none(), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    #[expected_failure(abort_code=ENOT_ENOUGH_TEAMS)]
    fun test_create_match_one_team(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        initialize_matches_collection(&game_admin_cap);
        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[vector<address>[player1_address, player2_address]];
        create_match(&game_admin_cap, teams);
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=ETEAMS_EMPTY)]
    fun test_create_match_empty_teams(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        initialize_matches_collection(&game_admin_cap);
        let teams = vector<vector<address>>[vector<address>[], vector<address>[]];
        create_match(&game_admin_cap, teams);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101, player3=@0x102)]
    #[expected_failure(abort_code=ETEAMS_NOT_SAME_LENGTH)]
    fun test_create_match_uneven_teams(aptos_arcade: &signer, player1: &signer, player2: &signer, player3: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        initialize_matches_collection(&game_admin_cap);

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);
        let player3_address = signer::address_of(player3);

        let teams = vector<vector<address>>[
            vector<address>[player1_address, player2_address],
            vector<address>[player3_address]
        ];
        create_match(&game_admin_cap, teams);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    #[expected_failure(abort_code=EPLAYER_NOT_REGISTERED)]
    fun test_create_match_elo_not_registered(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_matches_collection(&game_admin_cap);
        elo::initialize_elo_collection(&game_admin_cap);
        win_loss::initialize_win_loss(&game_admin_cap);

        win_loss::mint_win_loss_token<TestGame>(&profile::create_profile_cap(player1, &TestGame {}));
        win_loss::mint_win_loss_token<TestGame>(&profile::create_profile_cap(player2, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        create_match(&game_admin_cap, teams);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    #[expected_failure(abort_code=EPLAYER_NOT_REGISTERED)]
    fun test_create_match_win_loss_not_registered(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_matches_collection(&game_admin_cap);
        elo::initialize_elo_collection(&game_admin_cap);
        win_loss::initialize_win_loss(&game_admin_cap);

        elo::mint_elo_token<TestGame>(&profile::create_profile_cap(player1, &TestGame {}));
        elo::mint_elo_token<TestGame>(&profile::create_profile_cap(player2, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        create_match(&game_admin_cap, teams);
    }

    #[test_only]
    fun setup_tests(aptos_arcade: &signer, player1: &signer, player2: &signer): GameAdminCapability<TestGame> {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_matches_collection(&game_admin_cap);
        elo::initialize_elo_collection(&game_admin_cap);
        win_loss::initialize_win_loss(&game_admin_cap);

        elo::mint_elo_token(&profile::create_profile_cap(player1, &TestGame {}));
        elo::mint_elo_token(&profile::create_profile_cap(player2, &TestGame {}));

        win_loss::mint_win_loss_token(&profile::create_profile_cap(player1, &TestGame {}));
        win_loss::mint_win_loss_token(&profile::create_profile_cap(player2, &TestGame {}));

        game_admin_cap
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    fun test_set_match_result(aptos_arcade: &signer, player1: &signer, player2: &signer) acquires Match {
        let game_admin_cap = setup_tests(aptos_arcade, player1, player2);

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        let match_object = create_match(&game_admin_cap, teams);

        set_match_result(
            &game_admin_cap,
            match_object,
            0
        );
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    #[expected_failure(abort_code=EMATCH_ALREADY_COMPLETE)]
    fun test_set_match_result_already_set(aptos_arcade: &signer, player1: &signer, player2: &signer) acquires Match {
        let game_admin_cap = setup_tests(aptos_arcade, player1, player2);

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        let match_object = create_match(&game_admin_cap, teams);

        set_match_result(
            &game_admin_cap,
            match_object,
            0
        );
        set_match_result(
            &game_admin_cap,
            match_object,
            1
        );
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    #[expected_failure(abort_code=EINVALID_WINNER_INDEX)]
    fun test_set_match_result_invalid_index(aptos_arcade: &signer, player1: &signer, player2: &signer) acquires Match {
        let game_admin_cap = setup_tests(aptos_arcade, player1, player2);

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        let teams = vector<vector<address>>[
            vector<address>[player1_address],
            vector<address>[player2_address]
        ];
        let match_object = create_match(&game_admin_cap, teams);

        set_match_result(
            &game_admin_cap,
            match_object,
            2
        );
    }
}

module aptos_arcade::elo {

    use std::vector;

    use aptos_framework::object::ConstructorRef;

    use aptos_arcade::stats;
    use aptos_arcade::game_admin::GameAdminCapability;
    use aptos_arcade::profile::ProfileCapability;

    friend aptos_arcade::match;

    // constants

    const INITIAL_ELO_RATING: u64 = 100;
    const ELO_RATING_CHANGE: u64 = 5;

    // structs

    struct EloRating has drop {}

    // public functions

    /// initializes an ELO collection for a game
    /// `game_signer` - must be the account that created `game_struct`
    public fun initialize_elo_collection<GameType: drop>(game_admin_cap: &GameAdminCapability<GameType>): ConstructorRef {
        stats::create_stat(game_admin_cap, INITIAL_ELO_RATING, EloRating {})
    }

    /// mints an ELO token for a player for `GameType`
    /// `player` - can only mint one ELO token per game
    public fun mint_elo_token<GameType: drop>(profile_cap: &ProfileCapability<GameType>): ConstructorRef {
        stats::mint_stat(profile_cap, EloRating {})
    }

    /// updates the ELO ratings for a set of teams
    /// `teams` - a vector of vectors of player addresses
    /// `winner_index` - the index of the winning team
    public(friend) fun update_match_elo_ratings<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        teams: vector<vector<address>>,
        winner_index: u64
    ) {
        vector::enumerate_ref(&teams, |index, team| {
            update_team_elo_ratings<GameType>(
                game_admin_cap,
                *team,
                index == winner_index);
        });
    }

    /// updates the ELO ratings for a team given the outcome of a match
    /// `team` - a vector of player addresses
    /// `win` - true if the team won, false if the team lost
    fun update_team_elo_ratings<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        team: vector<address>,
        win: bool
    ) {
        vector::for_each(team, |player_address| update_player_elo_rating<GameType>(
            game_admin_cap,
            player_address,
            win
        ));
    }

    /// updates the ELO rating for a player given the outcome of a match
    /// `elo_rating_object` - the ELO rating object for the player
    /// `win` - true if the player won, false if the player lost
    fun update_player_elo_rating<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        player_address: address,
        win: bool
    ) {
        let elo_rating = stats::get_player_stat_value<GameType, EloRating>(player_address);
        let new_elo_rating = if(win) {
            elo_rating + ELO_RATING_CHANGE
        } else {
            if(elo_rating > ELO_RATING_CHANGE) {
                elo_rating - ELO_RATING_CHANGE
            } else {
                0
            }
        };
        stats::update_stat(game_admin_cap, player_address, new_elo_rating, EloRating {});
    }

    // view functions

    #[view]
    /// gets the address of the ELO collection object for `GameType`
    public fun get_elo_collection_address<GameType>(): address {
        stats::get_stat_collection_address<GameType, EloRating>()
    }

    #[view]
    /// gets whether or not a player has an ELO rating registered
    public fun has_player_registered_elo<GameType>(player: address): bool {
        stats::get_player_has_stat<GameType, EloRating>(player)
    }

    #[view]
    /// gets the address of the ELO rating token for `player` in `GameType`
    /// `player_address` - the player whose ELO rating token address to get
    public fun get_player_elo_object_address<GameType>(player_address: address): address {
        stats::get_player_stat_token_address<GameType, EloRating>(player_address)
    }

    #[view]
    /// gets the ELO rating for `player` in `GameType`
    /// `player_address` - the player whose ELO rating to get
    public fun get_player_elo_rating<GameType>(player_address: address): u64 {
        stats::get_player_stat_value<GameType, EloRating>(player_address)
    }

    // tests

    #[test_only]
    struct TestGame has drop {}

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::object;
    #[test_only]
    use aptos_arcade::game_admin;
    #[test_only]
    use aptos_arcade::profile;

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_initialize_elo_collection(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        let constructor_ref = initialize_elo_collection(&game_admin_cap);
        assert!(object::address_from_constructor_ref(&constructor_ref) == get_elo_collection_address<TestGame>(), 0)
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_token(aptos_arcade: &signer, player: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));
        initialize_elo_collection(&game_admin_cap);
        let constructor_ref = mint_elo_token(&profile::create_profile_cap(player, &TestGame {}));
        assert!(get_player_elo_rating<TestGame>(signer::address_of(player)) == INITIAL_ELO_RATING, 0);
        assert!(object::address_from_constructor_ref(&constructor_ref) == get_player_elo_object_address<TestGame>(signer::address_of(player)), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_update_player_elo_rating(aptos_arcade: &signer, player: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));
        initialize_elo_collection(&game_admin_cap);
        mint_elo_token(&profile::create_profile_cap(player, &TestGame {}));

        let player_address = signer::address_of(player);

        update_player_elo_rating<TestGame>(&game_admin_cap, player_address,true);
        assert!(get_player_elo_rating<TestGame>(player_address) == INITIAL_ELO_RATING + ELO_RATING_CHANGE, 0);

        update_player_elo_rating<TestGame>(&game_admin_cap, player_address, false);
        assert!(get_player_elo_rating<TestGame>(player_address) == INITIAL_ELO_RATING, 0);

        let i = 0;
        let iterations = INITIAL_ELO_RATING / ELO_RATING_CHANGE + 1;
        while (i < iterations)
        {
            update_player_elo_rating<TestGame>(&game_admin_cap, player_address,false);
            i = i + 1;
        };
        assert!(get_player_elo_rating<TestGame>(player_address) == 0, 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    fun test_update_team_elo_rating(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_elo_collection(&game_admin_cap);
        mint_elo_token(&profile::create_profile_cap(player1, &TestGame {}));
        mint_elo_token(&profile::create_profile_cap(player2, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);
        let team = vector<address>[player1_address, player2_address];

        update_team_elo_ratings<TestGame>(&game_admin_cap,team,true);
        assert!(get_player_elo_rating<TestGame>(player1_address) == INITIAL_ELO_RATING + ELO_RATING_CHANGE, 0);
        assert!(get_player_elo_rating<TestGame>(player2_address) == INITIAL_ELO_RATING + ELO_RATING_CHANGE, 0);

        update_team_elo_ratings<TestGame>(&game_admin_cap, team, false);
        assert!(get_player_elo_rating<TestGame>(player1_address) == INITIAL_ELO_RATING, 0);
        assert!(get_player_elo_rating<TestGame>(player2_address) == INITIAL_ELO_RATING, 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101, player3=@0x102, player4=@0x103)]
    fun test_update_match_elo_rating(
        aptos_arcade: &signer,
        player1: &signer,
        player2: &signer,
        player3: &signer,
        player4: &signer
    ) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player3, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player4, &TestGame {}));
        initialize_elo_collection(&game_admin_cap);
        mint_elo_token(&profile::create_profile_cap(player1, &TestGame {}));
        mint_elo_token(&profile::create_profile_cap(player2, &TestGame {}));
        mint_elo_token(&profile::create_profile_cap(player3, &TestGame {}));
        mint_elo_token(&profile::create_profile_cap(player4, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);
        let player3_address = signer::address_of(player3);
        let player4_address = signer::address_of(player4);

        let team1 = vector<address>[player1_address, player2_address];
        let team2 = vector<address>[player3_address, player4_address];
        let teams = vector<vector<address>>[team1, team2];
        update_match_elo_ratings<TestGame>(
            &game_admin_cap,
            teams,
            0
        );

        assert!(get_player_elo_rating<TestGame>(player1_address) == INITIAL_ELO_RATING + ELO_RATING_CHANGE, 0);
        assert!(get_player_elo_rating<TestGame>(player2_address) == INITIAL_ELO_RATING + ELO_RATING_CHANGE, 0);
        assert!(get_player_elo_rating<TestGame>(player3_address) == INITIAL_ELO_RATING - ELO_RATING_CHANGE, 0);
        assert!(get_player_elo_rating<TestGame>(player4_address) == INITIAL_ELO_RATING - ELO_RATING_CHANGE, 0);
    }
}

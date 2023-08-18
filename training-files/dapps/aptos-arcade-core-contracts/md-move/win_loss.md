```rust
module aptos_arcade::win_loss {
    use std::vector;

    use aptos_arcade::stats;
    use aptos_arcade::game_admin::GameAdminCapability;
    use aptos_arcade::profile::ProfileCapability;

    friend aptos_arcade::match;

    // structs

    struct Wins has drop {}
    struct Losses has drop {}

    // public functions

    /// initializes an ELO collection for a game
    /// `game_signer` - must be the account that created `game_struct`
    public fun initialize_win_loss<GameType: drop>(game_admin_cap: &GameAdminCapability<GameType>) {
        stats::create_stat(game_admin_cap, 0, Wins {});
        stats::create_stat(game_admin_cap, 0, Losses {});
    }

    /// mints an ELO token for a player for `GameType`
    /// `player` - can only mint one ELO token per game
    public fun mint_win_loss_token<GameType: drop>(profile_cap: &ProfileCapability<GameType>) {
        stats::mint_stat(profile_cap, Wins {});
        stats::mint_stat(profile_cap, Losses {});
    }

    /// updates the ELO ratings for a set of teams
    /// `teams` - a vector of vectors of player addresses
    /// `winner_index` - the index of the winning team
    public(friend) fun update_match_win_loss<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        teams: vector<vector<address>>,
        winner_index: u64
    ) {
        vector::enumerate_ref(&teams, |index, team| {
            update_team_win_loss<GameType>(
                game_admin_cap,
                *team,
                index == winner_index);
        });
    }

    /// updates the ELO ratings for a team given the outcome of a match
    /// `team` - a vector of player addresses
    /// `win` - true if the team won, false if the team lost
    fun update_team_win_loss<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        team: vector<address>,
        win: bool
    ) {
        vector::for_each(team, |player_address| update_player_win_loss<GameType>(
            game_admin_cap,
            player_address,
            win
        ));
    }

    /// updates the ELO rating for a player given the outcome of a match
    /// `elo_rating_object` - the ELO rating object for the player
    /// `win` - true if the player won, false if the player lost
    fun update_player_win_loss<GameType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        player_address: address,
        win: bool
    ) {
        if(win) {
            stats::update_stat(
                game_admin_cap, 
                player_address, 
                stats::get_player_stat_value<GameType, Wins>(player_address) + 1, 
                Wins {}
            );
        } else {
            stats::update_stat(
                game_admin_cap,
                player_address,
                stats::get_player_stat_value<GameType, Losses>(player_address) + 1,
                Losses {}
            );
        }
    }

    // view functions

    #[view]
    /// gets whether or not a player has an ELO rating registered
    public fun has_player_registered_win_loss<GameType>(player: address): bool {
        stats::get_player_has_stat<GameType, Wins>(player) && stats::get_player_has_stat<GameType, Losses>(player)
    }

    #[view]
    /// gets the ELO rating for `player` in `GameType`
    /// `player_address` - the player whose ELO rating to get
    public fun get_player_win_loss<GameType>(player_address: address): (u64, u64) {
        (
            stats::get_player_stat_value<GameType, Wins>(player_address), 
            stats::get_player_stat_value<GameType, Losses>(player_address)
        )
    }

    // tests

    #[test_only]
    struct TestGame has drop {}

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_arcade::game_admin;
    #[test_only]
    use aptos_arcade::profile;

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_initialize_win_loss_collection(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        initialize_win_loss(&game_admin_cap);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_token(aptos_arcade: &signer, player: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));
        initialize_win_loss(&game_admin_cap);
        assert!(!has_player_registered_win_loss<TestGame>(signer::address_of(player)), 0);
        mint_win_loss_token(&profile::create_profile_cap(player, &TestGame {}));
        let (wins, losses) = get_player_win_loss<TestGame>(signer::address_of(player));
        assert!(wins == 0 && losses == 0, 0);
        assert!(has_player_registered_win_loss<TestGame>(signer::address_of(player)), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_update_player_win_loss(aptos_arcade: &signer, player: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));
        initialize_win_loss(&game_admin_cap);
        mint_win_loss_token(&profile::create_profile_cap(player, &TestGame {}));

        let player_address = signer::address_of(player);

        update_player_win_loss<TestGame>(&game_admin_cap, player_address,true);
        let (wins, losses) = get_player_win_loss<TestGame>(signer::address_of(player));
        assert!(wins == 1 && losses == 0, 0);

        update_player_win_loss<TestGame>(&game_admin_cap, player_address, false);
        let (wins, losses) = get_player_win_loss<TestGame>(signer::address_of(player));
        assert!(wins == 1 && losses == 1, 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    fun test_update_team_win_loss(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin::create_game_admin_capability(aptos_arcade, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player1, &TestGame {}));
        profile::mint_profile_token(&game_admin::create_minter_capability(player2, &TestGame {}));
        initialize_win_loss(&game_admin_cap);
        mint_win_loss_token(&profile::create_profile_cap(player1, &TestGame {}));
        mint_win_loss_token(&profile::create_profile_cap(player2, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);
        let team = vector<address>[player1_address, player2_address];

        update_team_win_loss<TestGame>(&game_admin_cap,team,true);
        let (wins, losses) = get_player_win_loss<TestGame>(player1_address);
        assert!(wins == 1 && losses == 0, 0);
        let (wins, losses) = get_player_win_loss<TestGame>(player2_address);
        assert!(wins == 1 && losses == 0, 0);

        update_team_win_loss<TestGame>(&game_admin_cap,team,false);
        let (wins, losses) = get_player_win_loss<TestGame>(player1_address);
        assert!(wins == 1 && losses == 1, 0);
        let (wins, losses) = get_player_win_loss<TestGame>(player2_address);
        assert!(wins == 1 && losses == 1, 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101, player3=@0x102, player4=@0x103)]
    fun test_update_match_win_loss(
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
        initialize_win_loss(&game_admin_cap);
        mint_win_loss_token(&profile::create_profile_cap(player1, &TestGame {}));
        mint_win_loss_token(&profile::create_profile_cap(player2, &TestGame {}));
        mint_win_loss_token(&profile::create_profile_cap(player3, &TestGame {}));
        mint_win_loss_token(&profile::create_profile_cap(player4, &TestGame {}));

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);
        let player3_address = signer::address_of(player3);
        let player4_address = signer::address_of(player4);

        let team1 = vector<address>[player1_address, player2_address];
        let team2 = vector<address>[player3_address, player4_address];
        let teams = vector<vector<address>>[team1, team2];
        update_match_win_loss<TestGame>(
            &game_admin_cap,
            teams,
            0
        );

        let (wins, losses) = get_player_win_loss<TestGame>(player1_address);
        assert!(wins == 1 && losses == 0, 0);
        let (wins, losses) = get_player_win_loss<TestGame>(player2_address);
        assert!(wins == 1 && losses == 0, 0);
        let (wins, losses) = get_player_win_loss<TestGame>(player3_address);
        assert!(wins == 0 && losses == 1, 0);
        let (wins, losses) = get_player_win_loss<TestGame>(player4_address);
        assert!(wins == 0 && losses == 1, 0);
    }
}

```
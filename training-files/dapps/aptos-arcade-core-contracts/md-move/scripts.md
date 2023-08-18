```rust
module aptos_arcade::scripts {

    use aptos_framework::object::{Object, ConstructorRef};

    use aptos_arcade::game_admin::{Self, GameAdminCapability};
    use aptos_arcade::profile::{Self, ProfileCapability};
    use aptos_arcade::stats;
    use aptos_arcade::achievement;
    use aptos_arcade::elo;
    use aptos_arcade::match::{Self, Match};

    // game admin functions

    /// initializes the Aptos Arcade modules for a specific game
    /// `game_admin` - must be the deployer of the GameType struct
    /// `witness` - an instance of the GameType struct
    public fun initialize<GameType: drop>(game_admin: &signer, witness: GameType): GameAdminCapability<GameType> {
        let game_admin_cap = game_admin::initialize(game_admin, &witness);
        profile::create_profile_collection(&game_admin_cap);
        elo::initialize_elo_collection(&game_admin_cap);
        win_loss::initialize_win_loss(&game_admin_cap);
        match::initialize_matches_collection(&game_admin_cap);
        game_admin_cap
    }

    /// creates a stat of type StatType for GameType
    /// `game_admin` - must be the deployer of the GameType struct
    /// `default_value` - the default value for the stat
    /// `game_witness` - an instance of the GameType struct
    /// `stat_witness` - an instance of the StatType struct
    public fun create_stat<GameType: drop, StatType: drop>(
        game_admin: &signer,
        default_value: u64,
        game_witness: GameType,
        stat_witness: StatType
    ) {
        stats::create_stat(
            &game_admin::create_game_admin_capability(game_admin, &game_witness),
            default_value,
            stat_witness
        );
    }

    /// updates the value of a stat of type StatType for GameType for a player
    /// `game_admin` - must be the deployer of the GameType struct
    /// `player_address` - the address of the player
    /// `value` - the new value for the stat
    /// `game_witness` - an instance of the GameType struct
    /// `stat_witness` - an instance of the StatType struct
    public fun update_stat_value<GameType: drop, StatType: drop>(
        game_admin: &signer,
        player_address: address,
        value: u64,
        game_witness: GameType,
        stat_witness: StatType
    ) {
        stats::update_stat(
            &game_admin::create_game_admin_capability(game_admin, &game_witness),
            player_address,
            value,
            stat_witness
        );
    }

    /// creates a match between a set of teams
    /// `game_admin` - must be the deployer of the GameType struct
    /// `witness` - an instance of the GameType struct
    /// `teams` - a vector of teams, each team is a vector of player addresses
    public fun create_match<GameType: drop>(
        game_admin: &signer,
        teams: vector<vector<address>>,
        witness: GameType,
    ): Object<Match<GameType>> {
        match::create_match(&game_admin::create_game_admin_capability(game_admin, &witness), teams)
    }

    /// sets the result of a match
    /// `game_admin` - must be the deployer of the GameType struct
    /// `witness` - an instance of the GameType struct
    /// `match` - the match object
    /// `winner_index` - the index of the winning team
    public fun set_match_result<GameType: drop>(
        game_admin: &signer,
        match: Object<Match<GameType>>,
        winner_index: u64,
        witness: GameType,
    ) {
        match::set_match_result(
            &game_admin::create_game_admin_capability(game_admin, &witness),
            match,
            winner_index
        );
    }

    /// creates an achievement of type AchievementType for GameType with a threshold value for a stat of type StatType
    /// `game_admin` - must be the deployer of the GameType struct
    /// `threshold` - the threshold value for the stat
    /// `game_witness` - an instance of the GameType struct
    /// `achievement_witness` - an instance of the AchievementType struct
    public fun create_achievement<GameType: drop, StatType: drop, AchievementType: drop>(
        game_admin: &signer,
        threshold: u64,
        game_witness: GameType,
        achievement_witness: AchievementType
    ): ConstructorRef {
        achievement::create_achievement<GameType, StatType, AchievementType>(
            &game_admin::create_game_admin_capability(game_admin, &game_witness),
            threshold,
            achievement_witness
        )
    }

    // player functions

    /// initializes the Aptos Arcade modules for a specific player
    /// `player` - the player
    /// `witness` - an instance of the GameType struct
    public fun initialize_player<GameType: drop>(player: &signer, witness: GameType): ProfileCapability<GameType> {
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &witness));
        let profile_cap = profile::create_profile_cap(player, &witness);
        elo::mint_elo_token(&profile_cap);
        win_loss::mint_win_loss_token(&profile_cap);
        profile_cap
    }

    /// registers a stat of type StatType for GameType for a player
    /// `player` - the player
    /// `game_witness` - an instance of the GameType struct
    /// `stat_witness` - an instance of the StatType struct
    public fun register_stat<GameType: drop, StatType: drop>(
        player: &signer,
        game_witness: GameType,
        stat_witness: StatType
    ) {
        stats::mint_stat(&profile::create_profile_cap(player, &game_witness), stat_witness);
    }

    /// claims an achievement of type AchievementType for GameType for a player with a threshold value for a stat of type StatType
    /// `player` - the player
    /// `game_witness` - an instance of the GameType struct
    /// `achievement_witness` - an instance of the AchievementType struct
    public fun claim_achievement<GameType: drop, StatType: drop, AchievementType: drop>(
        player: &signer,
        game_witness: GameType,
        achievement_witness: AchievementType
    ): ConstructorRef {
        achievement::collect_achievement<GameType, StatType, AchievementType>(
            &profile::create_profile_cap(player, &game_witness),
            achievement_witness
        )
    }

    // tests

    #[test_only]
    use std::signer;
    use aptos_arcade::win_loss;

    #[test_only]
    struct TestGame has drop {}
    #[test_only]
    struct TestStat has drop {}
    #[test_only]
    struct TestAchievement has drop {}

    #[test(aptos_arcade=@aptos_arcade, player1=@0x100, player2=@0x101)]
    fun test_e2e(aptos_arcade: &signer, player1: &signer, player2: &signer) {
        initialize(aptos_arcade, TestGame {});

        let player1_address = signer::address_of(player1);
        let player2_address = signer::address_of(player2);

        initialize_player(player1, TestGame {});
        initialize_player(player2, TestGame {});

        let threshold = 100;
        let default_value = threshold - 10;

        create_stat(aptos_arcade, default_value, TestGame {}, TestStat {});

        create_achievement<TestGame, TestStat, TestAchievement>(aptos_arcade, threshold, TestGame {}, TestAchievement {});

        register_stat(player1, TestGame {}, TestStat {});
        update_stat_value(aptos_arcade, player1_address, threshold, TestGame {}, TestStat {});
        claim_achievement<TestGame, TestStat, TestAchievement>(player1, TestGame {}, TestAchievement {});

        let match_object = create_match(
            aptos_arcade,
            vector<vector<address>>[
                vector<address>[player1_address],
                vector<address>[player2_address]
            ],
            TestGame {}
        );
        set_match_result(
            aptos_arcade,
            match_object,
            0,
            TestGame {}
        );


    }
}

```
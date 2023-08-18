```rust
module aptos_arena::aptos_arena {

    use std::string::String;
    use std::option::Option;

    use aptos_framework::object::{ConstructorRef, Object};

    use aptos_token_objects::royalty::Royalty;

    use aptos_arcade::scripts;
    use aptos_arcade::game_admin::{Self, GameAdminCapability, MinterCapability};
    use aptos_arcade::elo;
    use aptos_arcade::match::{Match};

    struct AptosArena has drop {}

    // admin functions

    /// initializes the game admin account, elo rating collection, and matches collection
    /// `aptos_arena` - the signer of the aptos arena account
    public fun initialize(aptos_arena: &signer) {
        scripts::initialize(aptos_arena, AptosArena {});
    }

    /// creates a collection under the game admin account
    /// `game_admin` - the signer of the game admin account
    /// `descripion` - the description of the collection
    /// `name` - the name of the collection
    /// `royalty` - the royalty of the collection
    /// `uri` - the uri of the collection
    public fun create_collection(
        game_admin: &signer,
        descripion: String,
        name: String,
        royalty: Option<Royalty>,
        uri: String,
        soulbound: bool,
        mintable: bool,
        one_to_one: bool
    ): ConstructorRef {
        game_admin::create_collection<AptosArena>(
            &create_game_admin_capability(game_admin),
            descripion,
            name,
            royalty,
            uri,
            soulbound,
            mintable,
            one_to_one
        )
    }

    public fun create_stat<StatType: drop>(game_admin: &signer, default_value: u64, witness: StatType) {
        scripts::create_stat(game_admin, default_value, AptosArena {}, witness);
    }

    public fun update_stat_value<StatType: drop>(
        game_admin: &signer,
        player_address: address,
        default_value: u64,
        witness: StatType
    ) {
        scripts::update_stat_value(game_admin, player_address, default_value, AptosArena {}, witness);
    }

    public fun create_achievement<StatType: drop, AchievementType: drop>(
        game_admin: &signer,
        threshold: u64,
        witness: AchievementType
    ): ConstructorRef {
        scripts::create_achievement<AptosArena, StatType, AchievementType>(
            game_admin,
            threshold,
            AptosArena {},
            witness
        )
    }

    /// creates a match between `teams`
    /// `game_admin` - the signer of the game admin account
    /// `teams` - the teams of the match
    public fun create_match(game_admin: &signer, teams: vector<vector<address>>): Object<Match<AptosArena>> {
        scripts::create_match(game_admin, teams, AptosArena {})
    }

    /// sets the result of a match
    /// `game_admin` - the signer of the game admin account
    /// `match` - the match object
    /// `winner_index` - the index of the winning team
    public fun set_match_result(game_admin: &signer, match: Object<Match<AptosArena>>, winner_index: u64) {
        scripts::set_match_result(game_admin, match, winner_index, AptosArena {});
    }

    // player functions

    public fun initialize_player(player: &signer) {
        scripts::initialize_player(player, AptosArena {});
    }

    public fun register_stat<StatType: drop>(player: &signer, witness: StatType) {
        scripts::register_stat(player, AptosArena {}, witness);
    }

    /// mints a token to a player
    /// `player` - the signer of the player account
    /// `collection_name` - the name of the collection
    /// `token_description` - the description of the token
    /// `token_name` - the name of the token
    /// `royalty` - the royalty of the token
    /// `uri` - the uri of the token
    /// `soulbound` - whether the token is soulbound
    public fun mint_token_player(
        player: &signer,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): ConstructorRef {
        game_admin::mint_token_external<AptosArena>(
            &create_minter_capability(player),
            collection_name,
            token_description,
            token_name,
            royalty,
            uri
        )
    }

    /// claims an achievement for a player
    /// `player` - the signer of the player account
    public fun claim_achievement<StatType: drop, AchievementType: drop>(player: &signer, witness: AchievementType) {
        scripts::claim_achievement<AptosArena, StatType, AchievementType>(player, AptosArena {}, witness);
    }

    // access control

    /// creates a GameAdminCapability
    /// `game_admin` - the signer of the game admin account
    fun create_game_admin_capability(game_admin: &signer): GameAdminCapability<AptosArena> {
        game_admin::create_game_admin_capability(game_admin, &AptosArena {})
    }

    /// creates a PlayerCapability
    /// `player` - the signer of the player account
    fun create_minter_capability(player: &signer): MinterCapability<AptosArena> {
        game_admin::create_minter_capability(player, &AptosArena {})
    }

    // view functions

    #[view]
    /// returns the address of the game account
    public fun get_game_account_address(): address {
        game_admin::get_game_account_address<AptosArena>()
    }

    #[view]
    /// returns the collection address for a given collection name
    /// `collection_name` - the name of the collection
    public fun get_collection_address(collection_name: String): address {
        game_admin::get_collection_address<AptosArena>(collection_name)
    }

    #[view]
    /// returns whether a player has minted from a one-to-one collection
    /// `collection_name` - the name of the collection
    /// `player_address` - the address of the player
    public fun has_player_minted(collection_name: String, player_address: address): bool {
        game_admin::has_player_received_token<AptosArena>(collection_name, player_address)
    }

    #[view]
    /// returns the token address for a player in a one-to-one collection
    /// `collection_name` - the name of the collection
    /// `player_address` - the address of the player
    public fun get_player_token_address(collection_name: String, player_address: address): address {
        game_admin::get_player_token_address<AptosArena>(collection_name, player_address)
    }

    #[view]
    /// returns the ELO rating data for a given player address
    /// `player_address` - the address of the player
    public fun get_player_elo_rating(player_address: address): u64 {
        elo::get_player_elo_rating<AptosArena>(player_address)
    }

    #[view]
    /// returns the value of StatType for a given player
    /// `player_address` - the address of the player
    public fun get_stat_value<StatType: drop>(player_address: address): u64 {
        stats::get_player_stat_value<AptosArena, StatType>(player_address)
    }

    // tests

    #[test_only]
    use std::string;
    #[test_only]
    use std::option;
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::object;
    #[test_only]
    use aptos_token_objects::token::Token;
    use aptos_arcade::stats;

    #[test_only]
    struct TestStat has drop {}
    #[test_only]
    struct TestAchievement has drop {}

    #[test(aptos_arena=@aptos_arena, player1=@0x100, player2=@0x101)]
    fun test_e2e(aptos_arena: &signer, player1: &signer, player2: &signer) {

        initialize(aptos_arena);
        initialize_player(player1);
        initialize_player(player2);

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_collection_description");
        let colelction_uri = string::utf8(b"test_collection_uri");
        create_collection(
            aptos_arena,
            collection_description,
            collection_name,
            option::none(),
            colelction_uri,
            true,
            true,
            true,
        );

        let token_name = string::utf8(b"test_token_name");
        let token_description = string::utf8(b"test_token_description");
        let token_uri = string::utf8(b"test_token_uri");

        let constructor_ref = mint_token_player(
            player1,
            collection_name,
            token_description,
            token_name,
            option::none(),
            token_uri,
        );
        assert!(object::is_owner(
            object::object_from_constructor_ref<Token>(&constructor_ref),
            signer::address_of(player1)
        ), 0);

        let elo_rating = get_player_elo_rating(signer::address_of(player1));
        assert!(elo_rating == 100, 0);

        let teams = vector<vector<address>> [
            vector<address>[signer::address_of(player1)],
            vector<address>[signer::address_of(player2)]
        ];
        let match_object = create_match(aptos_arena, teams);
        set_match_result(aptos_arena, match_object, 0);

        let default_value = 100;
        let player1_address = signer::address_of(player1);
        create_stat(aptos_arena, default_value, TestStat {});
        register_stat(player1, TestStat {});
        assert!(get_stat_value<TestStat>(player1_address) == default_value, 0);
        let new_value = 200;
        update_stat_value(aptos_arena, player1_address, new_value, TestStat {});
        assert!(get_stat_value<TestStat>(player1_address) == new_value, 0);

        create_achievement<TestStat, TestAchievement>(aptos_arena, new_value, TestAchievement {});
        claim_achievement<TestStat, TestAchievement>(player1, TestAchievement {});
    }

}

```
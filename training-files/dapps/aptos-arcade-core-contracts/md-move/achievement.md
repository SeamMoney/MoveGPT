```rust
module aptos_arcade::achievement {

    use std::option;
    use std::string::String;

    use aptos_std::string_utils;
    use aptos_std::type_info;

    use aptos_framework::object::{Self, ConstructorRef};

    use aptos_arcade::game_admin::{Self, GameAdminCapability};
    use aptos_arcade::profile::{Self, ProfileCapability};
    use aptos_arcade::stats;

    // error codes

    /// when creating an achievement for a stat that does not exist
    const ESTAT_DOES_NOT_EXIST: u64 = 0;

    /// when a player has not met the threshold to mint an achievement
    const ETHRESHOLD_NOT_MET: u64 = 1;

    // constants

    const BASE_COLLECTION_NAME: vector<u8> = b"{}: {} {}";
    const BASE_COLLECTION_DESCRIPTION: vector<u8> = b"{} achievement for {} {}";
    const BASE_COLLECTION_URI: vector<u8> = b"https://aptosarcade.com/api/achievements/{}/{}/{}";

    const BASE_TOKEN_NAME: vector<u8> = b"{} {}: {} {}";
    const BASE_TOKEN_DESCRIPTION: vector<u8> = b"{}'s {} achievement for {} {}";
    const BASE_TOKEN_URI: vector<u8> = b"https://aptosarcade.com/api/stats/{}/{}/{}/{}";

    // structs

    /// an Achievement is mintable once a player has attained a threshold value of a StatType
    struct Achievement<phantom GameType, phantom StatType, phantom AchievementtType> has key {
        threshold: u64,
    }

    /// creates a new StatType collection for a GameType
    /// `game_admin_cap` - the game admin capability
    /// `witness` - a witness of the StatType
    public fun create_achievement<GameType: drop, StatType: drop, AchievementType: drop>(
        game_admin_cap: &GameAdminCapability<GameType>,
        threshold: u64,
        _witness: AchievementType
    ): ConstructorRef {
        assert_stat_exists<GameType, StatType>();
        let constructor_ref = game_admin::create_collection(
            game_admin_cap,
            get_achievement_collection_description<GameType, StatType, AchievementType>(),
            get_achievement_collection_name<GameType, StatType, AchievementType>(),
            option::none(),
            get_achievement_collection_uri<GameType, StatType, AchievementType>(),
            true,
            true,
            true,
        );
        move_to(&object::generate_signer(&constructor_ref), Achievement<GameType, StatType, AchievementType> {
            threshold,
        });
        constructor_ref
    }

    /// mints a new StatType token for a player in a GameType
    /// `player_cap` - the player capability
    /// `default_value` - the default value of the stat
    /// `witness` - a witness of the StatType
    public fun collect_achievement<GameType: drop, StatType: drop, AchievementType: drop>(
        profile_cap: &ProfileCapability<GameType>,
        _witness: AchievementType
    ): ConstructorRef acquires Achievement {
        let player_address = profile::get_player_address(profile_cap);
        assert_player_meets_threshold<GameType, StatType, AchievementType>(player_address);
        profile::mint_to_profile(
            profile_cap,
            get_achievement_collection_name<GameType, StatType, AchievementType>(),
            get_achievement_token_description<GameType, StatType, AchievementType>(player_address),
            get_achievement_token_name<GameType, StatType, AchievementType>(player_address),
            option::none(),
            get_achievement_token_uri<GameType, StatType, AchievementType>(player_address)
        )
    }

    // view functions

    #[view]
    /// gets the StatType collection address for a GameType
    public fun get_achievement_collection_address<GameType, StatType, AchievementType>(): address {
        game_admin::get_collection_address<GameType>(get_achievement_collection_name<GameType, StatType, AchievementType>())
    }

    #[view]
    /// gets the threshold for an AchievementType
    public fun get_achievement_threshold<GameType, StatType, AchievementType>(): u64 acquires Achievement {
        let achievement_collection_address = get_achievement_collection_address<GameType, StatType, AchievementType>();
        let achievement = borrow_global<Achievement<GameType, StatType, AchievementType>>(achievement_collection_address);
        achievement.threshold
    }

    #[view]
    /// gets whether a player has attained an AchievementType
    public fun get_player_meets_achievement_threshold<GameType, StatType, AchievementType>(player: address): bool
    acquires Achievement {
        let player_stat_value = stats::get_player_stat_value<GameType, StatType>(player);
        let achievement_threshold = get_achievement_threshold<GameType, StatType, AchievementType>();
        player_stat_value >= achievement_threshold
    }

    #[view]
    /// gets the StatType token address for a player in a GameType
    public fun get_has_player_claimed_achievemet<GameType, StatType, AchievementType>(player: address): bool {
        game_admin::has_player_received_token<GameType>(
            get_achievement_collection_name<GameType, StatType, AchievementType>(),
            profile::get_player_profile_address<GameType>(player),
        )
    }

    // string constructors

    /// gets the StatType collection name for a GameType
    fun get_achievement_collection_name<GameType, StatType, AchievementType>(): String {
        string_utils::format3(
            &BASE_COLLECTION_NAME,
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>())
        )
    }

    /// gets the StatType token name for a player in a GameType
    fun get_achievement_collection_description<GameType, StatType, AchievementType>(): String {
        string_utils::format3(
            &BASE_COLLECTION_DESCRIPTION,
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>())
        )
    }

    /// gets the StatType collection URI for a GameType
    fun get_achievement_collection_uri<GameType, StatType, AchievementType>(): String {
        string_utils::format3(
            &BASE_COLLECTION_URI,
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>())
        )
    }

    /// gets the StatType token URI for a player in a GameType
    fun get_achievement_token_name<GameType, StatType, AchievementType>(player: address): String {
        string_utils::format4(
            &BASE_TOKEN_NAME,
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>()),
            player
        )
    }

    /// gets the StatType token description for a player in a GameType
    fun get_achievement_token_description<GameType, StatType, AchievementType>(player: address): String {
        string_utils::format4(
            &BASE_TOKEN_DESCRIPTION,
            player,
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>())
        )
    }

    /// gets the StatType token URI for a player in a GameType
    fun get_achievement_token_uri<GameType, StatType, AchievementType>(player: address): String {
        string_utils::format4(
            &BASE_TOKEN_URI,
            type_info::struct_name(&type_info::type_of<GameType>()),
            type_info::struct_name(&type_info::type_of<StatType>()),
            type_info::struct_name(&type_info::type_of<AchievementType>()),
            player
        )
    }

    // assert statements

    /// asserts that the StatType collection exists for a GameType
    fun assert_stat_exists<GameType, StatType>() {
        assert!(stats::stat_collection_exists<GameType, StatType>(), ESTAT_DOES_NOT_EXIST);
    }

    /// asserts that a player has met the threshold for an AchievementType
    fun assert_player_meets_threshold<GameType, StatType, AchievementType>(player: address) acquires Achievement {
        assert!(get_player_meets_achievement_threshold<GameType, StatType, AchievementType>(player), ETHRESHOLD_NOT_MET);
    }

    // tests

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_token_objects::collection::{Self, Collection};
    #[test_only]
    use aptos_token_objects::token::{Self, Token};

    #[test_only]
    struct TestGame has drop {}

    #[test_only]
    struct TestStat has drop {}

    #[test_only]
    struct TestAchievement has drop {}

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_create_achievement_collection(aptos_arcade: &signer) acquires Achievement {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        stats::create_stat(&game_admin_cap, 90, TestStat {});
        let threshold = 100;
        let constructor_ref = create_achievement<TestGame, TestStat, TestAchievement>(
            &game_admin_cap,
            threshold,
            TestAchievement {}
        );
        let collection_object = object::object_from_constructor_ref<Collection>(&constructor_ref);
        let collection_address = object::address_from_constructor_ref(&constructor_ref);
        assert!(collection::name(collection_object) == get_achievement_collection_name<TestGame, TestStat, TestAchievement>(), 0);
        assert!(collection::description(collection_object) == get_achievement_collection_description<TestGame, TestStat, TestAchievement>(), 0);
        assert!(collection::uri(collection_object) == get_achievement_collection_uri<TestGame, TestStat, TestAchievement>(), 0);
        assert!(collection_address == get_achievement_collection_address<TestGame, TestStat, TestAchievement>(), 0);
        assert!(get_achievement_threshold<TestGame, TestStat, TestAchievement>() == threshold, 0);
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=ESTAT_DOES_NOT_EXIST)]
    fun test_create_achievement_collection_stat_doesnt_exist(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        let threshold = 100;
        create_achievement<TestGame, TestStat, TestAchievement>(
            &game_admin_cap,
            threshold,
            TestAchievement {}
        );
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_collect_achievement(aptos_arcade: &signer, player: &signer) acquires Achievement {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        let default_value = 90;
        stats::create_stat(&game_admin_cap, default_value, TestStat{});
        let threshold = 100;
        create_achievement<TestGame, TestStat, TestAchievement>(
            &game_admin_cap,
            threshold,
            TestAchievement {}
        );
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));

        let player_address = signer::address_of(player);
        stats::mint_stat(&profile::create_profile_cap(player, &TestGame {}), TestStat {});
        assert!(!get_player_meets_achievement_threshold<TestGame, TestStat, TestAchievement>(player_address), 0);
        stats::update_stat(&game_admin_cap, player_address, threshold, TestStat {});
        let constructor_ref = collect_achievement<TestGame, TestStat, TestAchievement>(
            &profile::create_profile_cap<TestGame>(player, &TestGame {}),
            TestAchievement {}
        );
        let token_object = object::object_from_constructor_ref<Token>(&constructor_ref);
        assert!(token::name(token_object) == get_achievement_token_name<TestGame, TestStat, TestAchievement>(player_address), 0);
        assert!(token::description(token_object) == get_achievement_token_description<TestGame, TestStat, TestAchievement>(player_address), 0);
        assert!(token::uri(token_object) == get_achievement_token_uri<TestGame, TestStat, TestAchievement>(player_address), 0);
        assert!(object::is_owner(token_object, profile::get_player_profile_address<TestGame>(player_address)), 0);
        assert!(get_has_player_claimed_achievemet<TestGame, TestStat, TestAchievement>(player_address), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    #[expected_failure(abort_code=ETHRESHOLD_NOT_MET)]
    fun test_collect_achievement_doesnt_meet_threshold(aptos_arcade: &signer, player: &signer) acquires Achievement {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        profile::create_profile_collection(&game_admin_cap);
        let default_value = 90;
        stats::create_stat(&game_admin_cap, default_value, TestStat {});
        let threshold = 100;
        create_achievement<TestGame, TestStat, TestAchievement>(&game_admin_cap, threshold, TestAchievement {});
        profile::mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));

        stats::mint_stat(&profile::create_profile_cap(player, &TestGame {}), TestStat {});
        collect_achievement<TestGame, TestStat, TestAchievement>(
            &profile::create_profile_cap(player, &TestGame {}),
            TestAchievement {}
        );
    }
}

```
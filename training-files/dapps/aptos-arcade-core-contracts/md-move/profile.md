```rust
module aptos_arcade::profile {

    use std::option;
    use std::string::String;

    use aptos_std::string_utils;
    use aptos_std::type_info;

    use aptos_framework::object::{Self, ConstructorRef, ExtendRef};

    use aptos_arcade::game_admin::{Self, GameAdminCapability, MinterCapability};
    use std::signer;
    use std::option::Option;
    use aptos_token_objects::royalty::Royalty;

    // error codes

     const ENO_PROFILE: u64 = 0;

    // constants

    const COLLECTION_BASE_NAME: vector<u8> = b"{} Profile";
    const COLLECTION_BASE_DESCRIPTION: vector<u8> = b"Gamer profile collection for {}.";
    const COLLECTION_BASE_URI: vector<u8> = b"https://aptosarcade.com/api/profiles/{}";

    const TOKEN_BASE_NAME: vector<u8> = b"{}'s {} Profile";
    const TOKEN_BASE_DESCRIPTION: vector<u8> = b"{}'s gamer profile for {}.";
    const TOKEN_URI: vector<u8> = b"https://aptosarcade.com/api/profiles/{}/{}";

    // structs

    struct Profile has key {
        extend_ref: ExtendRef
    }

    struct ProfileCapability<phantom GameType> has drop {
        player_address: address,
        minter_cap: MinterCapability<GameType>
    }

    /// creates the profile token collection for GameType
    /// `game_admin` - must be the deployer of the GameType struct
    public fun create_profile_collection<GameType>(game_admin_cap: &GameAdminCapability<GameType>): ConstructorRef {
        game_admin::create_collection(
            game_admin_cap,
            get_collection_description<GameType>(),
            get_collection_name<GameType>(),
            option::none(),
            get_collection_uri<GameType>(),
            true,
            true,
            true
        )
    }

    /// mints a profile token for GameType
    /// `player_cap` - the MinterCapability for the player minting a profile
    public fun mint_profile_token<GameType: drop>(minter_cap: &MinterCapability<GameType>) {
        let player_address = game_admin::get_minter_address(minter_cap);
        let constructor_ref = game_admin::mint_token_external(
            minter_cap,
            get_collection_name<GameType>(),
            get_token_description<GameType>(player_address),
            get_token_name<GameType>(player_address),
            option::none(),
            get_token_uri<GameType>(player_address),
        );

        move_to(&object::generate_signer(&constructor_ref), Profile {
            extend_ref: object::generate_extend_ref(&constructor_ref)
        });
    }

    /// mints a token to a profile
    public fun mint_to_profile<GameType>(
        profile_cap: &ProfileCapability<GameType>,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String
    ): ConstructorRef {
        game_admin::mint_token_external(
            &profile_cap.minter_cap,
            collection_name,
            token_description,
            token_name,
            royalty,
            uri
        )
    }

    /// creates a ProfileCapability for GameType for `player`
    public fun create_profile_cap<GameType: drop>(player: &signer, witness: &GameType): ProfileCapability<GameType>
    acquires Profile {
        let player_address = signer::address_of(player);
        assert_player_has_profile<GameType>(player_address);
        let profile = borrow_global<Profile>(get_player_profile_address<GameType>(player_address));
        ProfileCapability<GameType> {
            player_address,
            minter_cap: game_admin::create_minter_capability<GameType>(
                &object::generate_signer_for_extending(&profile.extend_ref),
                witness
            )
        }
    }

    // getter functions

    public fun get_player_address<GameType>(profile_cap: &ProfileCapability<GameType>): address {
        profile_cap.player_address
    }

    // view functions

    #[view]
    /// returns the profile collection address for GameType
    public fun get_profile_collection_address<GameType>(): address {
        game_admin::get_collection_address<GameType>(get_collection_name<GameType>())
    }

    #[view]
    /// returns whether a player has minted a profile for GameType
    public fun has_player_minted_profile<GameType>(player_address: address): bool {
        game_admin::has_player_received_token<GameType>(get_collection_name<GameType>(), player_address)
    }

    #[view]
    /// returns the profile address of a player for GameType
    /// `player` - the player address
    public fun get_player_profile_address<GameType>(player_address: address): address {
        game_admin::get_player_token_address<GameType>(get_collection_name<GameType>(), player_address)
    }

    // helper functions

    /// returns the name for the `GameType` profile collection
    fun get_collection_name<GameType>(): String {
        string_utils::format1(
            &COLLECTION_BASE_NAME,
            type_info::struct_name(&type_info::type_of<GameType>())
        )
    }

    /// returns the description for the `GameType` profile collection
    fun get_collection_description<GameType>(): String {
        string_utils::format1(
            &COLLECTION_BASE_DESCRIPTION,
            type_info::struct_name(&type_info::type_of<GameType>())
        )
    }

    /// returns the URI for the `GameType` profile collection
    fun get_collection_uri<GameType>(): String {
        string_utils::format1(
            &COLLECTION_BASE_URI,
            type_info::struct_name(&type_info::type_of<GameType>())
        )
    }

    /// returns the name for the `GameType` profile token
    /// `player` - the player address
    fun get_token_name<GameType>(player: address): String {
        string_utils::format2(
            &TOKEN_BASE_NAME,
            player,
            type_info::struct_name(&type_info::type_of<GameType>())
        )
    }

    /// returns the description for the `GameType` profile token
    /// `player` - the player address
    fun get_token_description<GameType>(player: address): String {
        string_utils::format2(
            &TOKEN_BASE_DESCRIPTION,
            player,
            type_info::struct_name(&type_info::type_of<GameType>())
        )
    }

    /// returns the URI for the `GameType` profile token
    /// `player` - the player address
    fun get_token_uri<GameType>(player: address): String {
        string_utils::format2(
            &TOKEN_URI,
            type_info::struct_name(&type_info::type_of<GameType>()),
            player
        )
    }

    // assert statements

    fun assert_player_has_profile<GameType>(player_address: address) {
        assert!(has_player_minted_profile<GameType>(player_address), ENO_PROFILE)
    }

    // tests

    #[test_only]
    use std::string;
    #[test_only]
    use aptos_token_objects::collection::{Self, Collection};
    #[test_only]
    use aptos_token_objects::token::{Self, Token};

    #[test_only]
    struct TestGame has drop {}

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_create_profile_collection(aptos_arcade: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        let constructor_ref = create_profile_collection(&game_admin_cap);
        let collection_object = object::object_from_constructor_ref<Collection>(&constructor_ref);
        let collection_address = object::address_from_constructor_ref(&constructor_ref);
        assert!(collection::name(collection_object) == get_collection_name<TestGame>(), 0);
        assert!(collection::description(collection_object) == get_collection_description<TestGame>(), 0);
        assert!(collection::uri(collection_object) == get_collection_uri<TestGame>(), 0);
        assert!(collection_address == get_profile_collection_address<TestGame>(), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_player_profile(aptos_arcade: &signer, player: &signer) {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        create_profile_collection(&game_admin_cap);
        mint_profile_token(
            &game_admin::create_minter_capability(player, &TestGame {}),
        );
        let player_address = signer::address_of(player);
        assert_player_has_profile<TestGame>(player_address);
        let token_object = object::address_to_object<Token>(get_player_profile_address<TestGame>(player_address));
        assert!(token::name(token_object) == get_token_name<TestGame>(player_address), 0);
        assert!(token::description(token_object) == get_token_description<TestGame>(player_address), 0);
        assert!(token::uri(token_object) == get_token_uri<TestGame>(player_address), 0);
        assert!(object::is_owner(token_object, player_address), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_to_profile(aptos_arcade: &signer, player: &signer) acquires Profile {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        create_profile_collection(&game_admin_cap);
        mint_profile_token(&game_admin::create_minter_capability(player, &TestGame {}));

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        game_admin::create_collection(
            &game_admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            true,
            true
        );

        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        let constructor_ref = mint_to_profile(
            &create_profile_cap<TestGame>(player, &TestGame {}),
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri
        );

        let player_address = signer::address_of(player);
        let token_object = object::object_from_constructor_ref<Token>(&constructor_ref);
        assert!(object::is_owner(token_object, get_player_profile_address<TestGame>(player_address)), 0)
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    #[expected_failure(abort_code=ENO_PROFILE)]
    fun test_mint_to_profile_before_creating_profile(aptos_arcade: &signer, player: &signer) acquires Profile {
        let game_admin_cap = game_admin::initialize(aptos_arcade, &TestGame {});
        create_profile_collection(&game_admin_cap);

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        game_admin::create_collection(
            &game_admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            true,
            true
        );

        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        mint_to_profile(
            &create_profile_cap<TestGame>(player, &TestGame {}),
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri
        );
    }
}

```
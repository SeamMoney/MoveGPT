```rust
module aptos_arcade::game_admin {

    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};

    use aptos_std::string_utils;
    use aptos_std::type_info;
    use aptos_std::smart_table::{Self, SmartTable};

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::object::{Self, ConstructorRef};

    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::royalty::Royalty;

    // error codes

    /// when the signer is not the game admin
    const ESIGNER_NOT_ADMIN: u64 = 0;

    /// when calling initialize with a `GameType` that has already been initialized
    const EGAME_ACCOUNT_ALREADY_INITIALIZED: u64 = 1;

    /// when calling a function that requires the game account for a `GameTyoe` to be initialized, but it is not
    const EGAME_ACCOUNT_NOT_INITIALIZED: u64 = 2;

    /// when a collection is already initialized
    const ECOLLECTION_ALREADY_INITIALIZED: u64 = 3;

    /// when a collection is not initialized
    const ECOLLECTION_NOT_INITIALIZED: u64 = 4;

    /// when a player has already received a one-to-one token
    const EALREADY_MINTED_ONE_TO_ONE_TOKEN: u64 = 5;

    /// when a collection does not allow player mint
    const ECOLLECTION_DOES_NOT_ALLOW_PLAYER_MINT: u64 = 6;


    // constants

    const ACCOUNT_SEED_TEMPLATE: vector<u8> = b"{} Account";

    // structs

    /// holds the `SignerCapability` for the game admin account
    struct GameAdmin<phantom GameType> has key {
        /// `SignerCapability` for the game admin account
        signer_cap: SignerCapability
    }

    /// holds information about a collection
    struct Collection has key {
        /// whether the tokens can be transferred after mint
        soulbound: bool,
        /// whether an account that is not the game admin can mint
        mintable: bool,
        /// mapping from minter address to minted object address
        /// option::none for collections that are not one-to-one
        one_to_one_mapping: Option<SmartTable<address, address>>
    }

    // access control structs

    /// used to access game admin functions
    struct GameAdminCapability<phantom GameType> has drop, store {}

    /// used to access external mint functions
    struct MinterCapability<phantom GameType> has drop, store {
        minter_address: address
    }

    // initialization

    /// initializes the game admin for the given `GameType`
    /// `game_admin` - must be the deployer of the `GameType` struct
    /// `witness` - ensures that the `GameType` struct is the same as the one that was deployed
    public fun initialize<GameType: drop>(game_admin: &signer, _witness: &GameType): GameAdminCapability<GameType> {
        assert_game_admin_not_initialized<GameType>();
        assert_signer_is_game_admin<GameType>(game_admin);
        let (_, signer_cap) = account::create_resource_account(game_admin, get_game_account_seed<GameType>());
        move_to(game_admin, GameAdmin<GameType> { signer_cap });
        GameAdminCapability<GameType> {}
    }

    // collection creation

    /// creates a collection for the given `GameType` under the game admin resource account
    /// `game_admin_cap` - must be a game admin capability for the given `GameType`
    /// `description` - description of the collection
    /// `name` - name of the collection
    /// `royalty` - royalty of the collection
    /// `uri` - uri of the collection
    /// `soulbound` - whether the collection is soulbound
    /// `can_player_mint` - whether the collection allows player mint
    /// `one_to_one` - whether the collection is one-to-one
    public fun create_collection<GameType>(
        _game_admin_cap: &GameAdminCapability<GameType>,
        descripion: String,
        name: String,
        royalty: Option<Royalty>,
        uri: String,
        soulbound: bool,
        can_player_mint: bool,
        one_to_one: bool,
    ): ConstructorRef acquires GameAdmin {
        assert_collection_not_initialized<GameType>(name);
        let game_account_signer = get_game_account_signer<GameType>();
        let constructor_ref = collection::create_unlimited_collection(
            &game_account_signer,
            descripion,
            name,
            royalty,
            uri
        );

        let one_to_one_mapping = if(one_to_one) {
            option::some(smart_table::new())
        } else {
            option::none()
        };
        move_to(&object::generate_signer(&constructor_ref), Collection {
            soulbound,
            mintable: can_player_mint,
            one_to_one_mapping
        });

        constructor_ref
    }

    // token creation

    /// mints a token for `collection_name` for the given `GameType` under the game admin resource account
    /// `game_admin_cap` - must be a game admin capability for the given `GameType`
    /// `collection_name` - name of the collection
    /// `token_description` - description of the token
    /// `token_name` - name of the token
    /// `royalty` - royalty of the token
    /// `uri` - uri of the token
    /// `to_address` - address to mint the token to
    public fun mint_token_game_admin<GameType>(
        _game_admin_cap: &GameAdminCapability<GameType>,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
        to_address: address
    ): ConstructorRef acquires GameAdmin, Collection {
        mint_token<GameType>(
            collection_name,
            token_description,
            token_name,
            royalty,
            uri,
            to_address
        )
    }

    /// mints a token for `collection_name` for the given `GameType` to the minter; collection must be mintable
    /// `minter_cap` - MinterCapability for GameType
    /// `collection_name` - name of the collection
    /// `token_description` - description of the token
    /// `token_name` - name of the token
    /// `royalty` - royalty of the token
    /// `uri` - uri of the token
    /// `soulbound` - whether the token is soulbound
    public fun mint_token_external<GameType>(
        minter_cap: &MinterCapability<GameType>,
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): ConstructorRef acquires GameAdmin, Collection {
        assert_mintable<GameType>(collection_name);
        mint_token<GameType>(
            collection_name,
            token_description,
            token_name,
            royalty,
            uri,
            minter_cap.minter_address
        )
    }

    /// mints a token for `collection_name` for the given `GameType` under the game admin resource account
    /// `collection_name` - name of the collection
    /// `token_description` - description of the token
    /// `token_name` - name of the token
    /// `royalty` - royalty of the token
    /// `uri` - uri of the token
    /// `to_address` - address to mint the token to
    fun mint_token<GameType>(
        collection_name: String,
        token_description: String,
        token_name: String,
        royalty: Option<Royalty>,
        uri: String,
        to_address: address
    ): ConstructorRef acquires GameAdmin, Collection {
        assert_collection_initialized<GameType>(collection_name);

        let collection = borrow_global_mut<Collection>(
            get_collection_address<GameType>(collection_name)
        );

        let constructor_ref = token::create_from_account(
            &get_game_account_signer<GameType>(),
            collection_name,
            token_description,
            token_name,
            royalty,
            uri
        );

        if(option::is_some(&collection.one_to_one_mapping))
        {
            assert_can_mint_one_to_one<GameType>(
                option::borrow(&collection.one_to_one_mapping),
                to_address
            );
            smart_table::add(
                option::borrow_mut(&mut collection.one_to_one_mapping),
                to_address,
                object::address_from_constructor_ref(&constructor_ref)
            );
        };

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, to_address);
        if(collection.soulbound) {
            object::disable_ungated_transfer(&transfer_ref);
        };

        constructor_ref
    }

    // access control

    /// creates a game admin capability for the given `GameType`
    /// `game_admin` - must be the deployer of the `GameType` struct
    /// `witness` - ensures that the `GameType` struct is the same as the one that was deployed
    public fun create_game_admin_capability<GameType: drop>(game_admin: &signer, _witness: &GameType): GameAdminCapability<GameType> {
        assert_game_admin_initialized<GameType>();
        assert_signer_is_game_admin<GameType>(game_admin);
        GameAdminCapability<GameType> {}
    }

    /// creates a player capability for the given `GameType`
    /// `player` - must be the player of the `GameType` struct
    /// `witness` - ensures that the `GameType` struct is the same as the one that was deployed
    public fun create_minter_capability<GameType: drop>(minter: &signer, _witness: &GameType): MinterCapability<GameType> {
        assert_game_admin_initialized<GameType>();
        MinterCapability<GameType> {
            minter_address: signer::address_of(minter)
        }
    }

    /// gets the address of the player who created the given `PlayerCapability`
    /// `minter_cap` - the MinterCapability
    public fun get_minter_address<GameType>(minter_cap: &MinterCapability<GameType>): address {
        minter_cap.minter_address
    }

    // signer helpers

    /// returns the signer of the game admin resource account for the given `GameType`
    fun get_game_account_signer<GameType>(): signer acquires GameAdmin {
        let game_admin_address = type_info::account_address(&type_info::type_of<GameType>());
        let game_admin = borrow_global<GameAdmin<GameType>>(game_admin_address);
        account::create_signer_with_capability(&game_admin.signer_cap)
    }

    // view functions

    #[view]
    /// returns the address of the game account for the given `GameType`
    public fun get_game_account_address<GameType>(): address {
        account::create_resource_address(
            &type_info::account_address(&type_info::type_of<GameType>()),
            get_game_account_seed<GameType>()
        )
    }

    #[view]
    /// returns whether or not a collection with the given `collection_name` exists for the given `GameType`
    /// `collection_name` - name of the collection
    public fun does_collection_exist<GameType>(collection_name: String): bool {
        exists<Collection>(get_collection_address<GameType>(collection_name))
    }

    #[view]
    /// returns the address of the collection for the given `GameType` and `collection_name`
    /// `collection_name` - name of the collection
    public fun get_collection_address<GameType>(collection_name: String): address {
        collection::create_collection_address(
            &get_game_account_address<GameType>(),
            &collection_name
        )
    }

    #[view]
    /// returns whether a collection is one-to-one
    /// `collection_name` - name of the collection
    public fun is_collection_one_to_one<GameType>(collection_name: String): bool acquires Collection {
        let collection_address = get_collection_address<GameType>(collection_name);
        let collection = borrow_global<Collection>(collection_address);
        option::is_some(&collection.one_to_one_mapping)
    }

    #[view]
    /// returns whether a player has received a token in a one-to-one collection
    /// `collection_name` - name of the collection
    /// `player_address` - address of the player
    public fun has_player_received_token<GameType>(collection_name: String, player_address: address): bool
    acquires Collection {
        let collection_address = get_collection_address<GameType>(collection_name);
        let collection = borrow_global<Collection>(collection_address);
        smart_table::contains(option::borrow(&collection.one_to_one_mapping), player_address)
    }

    #[view]
    /// returns the address of a player's token in a one-to-one collection
    /// `collection_name` - name of the collection
    /// `player_address` - address of the player
    public fun get_player_token_address<GameType>(collection_name: String, player_address: address): address
    acquires Collection {
        let collection_address = get_collection_address<GameType>(collection_name);
        let collection = borrow_global<Collection>(collection_address);
        *smart_table::borrow(option::borrow(&collection.one_to_one_mapping), player_address)
    }

    // helper functions

    /// returns the account address for `GameType`
    fun get_account_address<GameType>(): address {
        type_info::account_address(&type_info::type_of<GameType>())
    }

    /// returns the seed for the game account for the given `GameType`
    fun get_game_account_seed<GameType>(): vector<u8> {
        *string::bytes(&string_utils::format1(
            &ACCOUNT_SEED_TEMPLATE,
            type_info::struct_name(&type_info::type_of<GameType>())
        ))
    }

    // assert statements

    /// asserts that the given `signer` is the game admin for the given `GameType`
    /// `game_admin` - must be the deployer of the `GameType` struct
    fun assert_signer_is_game_admin<GameType>(game_admin: &signer) {
        assert!(signer::address_of(game_admin) == get_account_address<GameType>(), ESIGNER_NOT_ADMIN);
    }

    /// asserts that the game admin resource account has not been initialized
    fun assert_game_admin_not_initialized<GameType>() {
        assert!(!exists<GameAdmin<GameType>>(get_account_address<GameType>()),EGAME_ACCOUNT_ALREADY_INITIALIZED);
    }

    /// asserts that the game admin resource account has been initialized
    fun assert_game_admin_initialized<GameType>() {
        assert!(exists<GameAdmin<GameType>>(get_account_address<GameType>()),EGAME_ACCOUNT_NOT_INITIALIZED);
    }

    /// asserts that the collection has not been initialized
    /// `collection_name` - name of the collection
    fun assert_collection_not_initialized<GameType>(collection_name: String) {
        assert!(!does_collection_exist<GameType>(collection_name), ECOLLECTION_ALREADY_INITIALIZED)
    }

    /// asserts that the collection has been initialized
    /// `collection_name` - name of the collection
    fun assert_collection_initialized<GameType>(collection_name: String) {
        assert!(does_collection_exist<GameType>(collection_name), ECOLLECTION_NOT_INITIALIZED)
    }

    /// asserts that a player can mint a token
    /// `collection_name` - name of the collection
    fun assert_mintable<GameType>(collection_name: String) acquires Collection {
        let collection_address = get_collection_address<GameType>(collection_name);
        let collection = borrow_global<Collection>(collection_address);
        assert!(collection.mintable, ECOLLECTION_DOES_NOT_ALLOW_PLAYER_MINT);
    }

    /// asserts that an address can mint a one-to-one token
    fun assert_can_mint_one_to_one<GameType>(one_to_one_mapping: &SmartTable<address, address>, to_address: address) {
        assert!(!smart_table::contains(one_to_one_mapping, to_address), EALREADY_MINTED_ONE_TO_ONE_TOKEN);
    }

    // tests

    #[test_only]
    use aptos_token_objects::token::Token;

    #[test_only]
    struct TestGame has drop {}

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_initialize(aptos_arcade: &signer) {
        assert_game_admin_not_initialized<TestGame>();
        initialize<TestGame>(aptos_arcade, &TestGame {});
        assert_game_admin_initialized<TestGame>();
    }

    #[test(not_aptos_arcade=@0x100)]
    #[expected_failure(abort_code=ESIGNER_NOT_ADMIN)]
    fun test_initialize_unauthorized(not_aptos_arcade: &signer) {
        initialize<TestGame>(not_aptos_arcade, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=EGAME_ACCOUNT_ALREADY_INITIALIZED)]
    fun test_initialize_twice(aptos_arcade: &signer) {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        initialize<TestGame>(aptos_arcade, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_create_game_admin_cap(aptos_arcade: &signer) {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade, not_aptos_arcade=@0x100)]
    #[expected_failure(abort_code=ESIGNER_NOT_ADMIN)]
    fun test_create_game_admin_cap_unauthorized(aptos_arcade: &signer, not_aptos_arcade: &signer) {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        create_game_admin_capability<TestGame>(not_aptos_arcade, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=EGAME_ACCOUNT_NOT_INITIALIZED)]
    fun test_create_game_admin_cap_uninitialized(aptos_arcade: &signer) {
        create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_create_minter_cap(aptos_arcade: &signer, player: &signer) {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        assert!(signer::address_of(player) == get_minter_address(&minter_cap), 0);
    }

    #[test(player=@0x100)]
    #[expected_failure(abort_code=EGAME_ACCOUNT_NOT_INITIALIZED)]
    fun test_create_minter_cap_uninitialized(player: &signer) {
        create_minter_capability<TestGame>(player, &TestGame {});
    }

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_create_collection(aptos_arcade: &signer) acquires GameAdmin {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});
        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        let constructor_ref = create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            false,
            false
        );
        assert_collection_initialized<TestGame>(collection_name);
        let collection_object = object::object_from_constructor_ref<Collection>(&constructor_ref);
        assert!(collection::creator(collection_object) == get_game_account_address<TestGame>(), 0);
        assert!(collection::name(collection_object) == collection_name, 0);
        assert!(collection::description(collection_object) == collection_description, 0);
        assert!(collection::uri(collection_object) == collection_uri, 0);
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=ECOLLECTION_ALREADY_INITIALIZED)]
    fun test_create_collection_twice(aptos_arcade: &signer) acquires GameAdmin {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});
        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            false,
            false
        );
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            false,
            false
        );
    }

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_create_one_to_one_collection(aptos_arcade: &signer) acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});
        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            false,
            true
        );
        assert!(is_collection_one_to_one<TestGame>(collection_name), 0)
    }

    #[test(aptos_arcade=@aptos_arcade)]
    fun test_mint_token_admin(aptos_arcade: &signer) acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            false,
            false
        );

        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        let token_constructor_ref = mint_token_game_admin(
            &admin_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
            get_game_account_address<TestGame>()
        );
        let token_object = object::object_from_constructor_ref<Token>(&token_constructor_ref);
        assert!(token::creator(token_object) == get_game_account_address<TestGame>(), 0);
        assert!(token::name(token_object) == token_name, 0);
        assert!(token::description(token_object) == token_description, 0);
        assert!(token::uri(token_object) == token_uri, 0);
        assert!(object::is_owner(token_object, get_game_account_address<TestGame>()), 0);
    }

    #[test(aptos_arcade=@aptos_arcade)]
    #[expected_failure(abort_code=ECOLLECTION_NOT_INITIALIZED)]
    fun test_mint_token_admin_collection_does_not_exist(aptos_arcade: &signer) acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        mint_token_game_admin(
            &admin_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
            get_game_account_address<TestGame>()
        );
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_token_transferrable_player(aptos_arcade: &signer, player: &signer)
    acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            false,
            true,
            false
        );

        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        let token_constructor_ref = mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
        let token_object = object::object_from_constructor_ref<Token>(&token_constructor_ref);
        assert!(token::creator(token_object) == get_game_account_address<TestGame>(), 0);
        assert!(token::name(token_object) == token_name, 0);
        assert!(token::description(token_object) == token_description, 0);
        assert!(token::uri(token_object) == token_uri, 0);
        assert!(object::is_owner(token_object, signer::address_of(player)), 0);
        object::transfer(player, token_object, get_game_account_address<TestGame>());
        assert!(object::is_owner(token_object, get_game_account_address<TestGame>()), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_token_nontransferrable_player(aptos_arcade: &signer, player: &signer)
    acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            true,
            false
        );

        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        let token_constructor_ref = mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
        let token_object = object::object_from_constructor_ref<Token>(&token_constructor_ref);
        assert!(token::creator(token_object) == get_game_account_address<TestGame>(), 0);
        assert!(token::name(token_object) == token_name, 0);
        assert!(token::description(token_object) == token_description, 0);
        assert!(token::uri(token_object) == token_uri, 0);
        assert!(object::is_owner(token_object, signer::address_of(player)), 0);
        assert!(!object::ungated_transfer_allowed(token_object), 0);
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    fun test_mint_token_one_to_one_collection(aptos_arcade: &signer, player: &signer)
    acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            true,
            true
        );

        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        let token_constructor_ref = mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
        let token_object = object::object_from_constructor_ref<Token>(&token_constructor_ref);
        let player_address = signer::address_of(player);
        assert!(object::is_owner(token_object, player_address), 0);
        assert!(!object::ungated_transfer_allowed(token_object), 0);
        assert!(
            get_player_token_address<TestGame>(
                collection_name,
                player_address
            ) == object::address_from_constructor_ref(&token_constructor_ref), 0
        );
        assert!(has_player_received_token<TestGame>(collection_name, player_address), 0)
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    #[expected_failure(abort_code=EALREADY_MINTED_ONE_TO_ONE_TOKEN)]
    fun test_mint_token_one_to_one_collection_twice(aptos_arcade: &signer, player: &signer)
    acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            true,
            true
        );

        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
        mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
    }

    #[test(aptos_arcade=@aptos_arcade, player=@0x100)]
    #[expected_failure(abort_code=ECOLLECTION_DOES_NOT_ALLOW_PLAYER_MINT)]
    fun test_mint_token_no_player_mint(aptos_arcade: &signer, player: &signer)
    acquires GameAdmin, Collection {
        initialize<TestGame>(aptos_arcade, &TestGame {});
        let admin_cap = create_game_admin_capability<TestGame>(aptos_arcade, &TestGame {});

        let collection_name = string::utf8(b"test_collection");
        let collection_description = string::utf8(b"test_description");
        let collection_uri = string::utf8(b"test_uri");
        let collection_royalty = option::none<Royalty>();
        create_collection(
            &admin_cap,
            collection_description,
            collection_name,
            collection_royalty,
            collection_uri,
            true,
            false,
            true
        );

        let minter_cap = create_minter_capability<TestGame>(player, &TestGame {});
        let token_name = string::utf8(b"test_token");
        let token_description = string::utf8(b"test_description");
        let token_uri = string::utf8(b"test_uri");
        let token_royalty = option::none<Royalty>();
        mint_token_external(
            &minter_cap,
            collection_name,
            token_description,
            token_name,
            token_royalty,
            token_uri,
        );
    }
}

```
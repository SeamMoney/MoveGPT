```rust
module aptos_arena::ranged_weapon {

    use std::string::{Self, String};
    use std::option;

    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object, TransferRef};

    use aptos_arena::utils;
    use aptos_arena::aptos_arena;

    // errors

    // constants

    const COLLECTION_NAME: vector<u8> = b"RANGED_WEAPON";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Ranged weapon for Aptos Arena";
    const COLLECTION_URI: vector<u8> = b"https://aptosarcade.com/api/ranged/";

    const TOKEN_DESCRIPTION: vector<u8> = b"Ranged weapon for Aptos Arena";
    const TOKEN_NAME: vector<u8> = b"RANGED_WEAPON";
    const TOKEN_BASE_URI: vector<u8> = b"https://aptosarcade.com/api/ranged/{}";

    const NUM_RANGED_WEAPONS: u64 = 5;

    struct RangedWeapon has key {
        power: u64,
        type: u64,
        range: u64,
        transfer_ref: TransferRef
    }

    /// create the ranged weapon collection
    /// `aptos_arena` - the transaction signer; must be the deployer
    public fun initialize(aptos_arena: &signer) {
        aptos_arena::create_collection(
            aptos_arena,
            get_collection_description(),
            get_collection_name(),
            option::none(),
            get_collection_uri(),
            false,
            true,
            true
        );
    }

    // public functions


    /// mints a ranged weapon for `player`
    /// `player` - the player to mint for
    public fun mint(player: &signer): Object<RangedWeapon> {
        let ranged_weapon_type = utils::rand_int(NUM_RANGED_WEAPONS) + 1;
        let constructor_ref = aptos_arena::mint_token_player(
            player,
            get_collection_name(),
            get_token_description(),
            get_token_name(),
            option::none(),
            get_token_uri(ranged_weapon_type),
        );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::enable_ungated_transfer(&transfer_ref);

        // create the ranged weapon struct and move it to the token signer
        move_to(&object::generate_signer(&constructor_ref), RangedWeapon {
            power: 0,
            type: ranged_weapon_type,
            range: 0,
            transfer_ref
        });

        object::object_from_constructor_ref(&constructor_ref)
    }

    /// trnasfers `ranged_weapon` to `to`
    /// `ranged_weapon` - the ranged weapon to transfer
    /// `to` - the address to transfer to
    public fun transfer_ranged_weapon(ranged_weapon: &Object<RangedWeapon>, to: address) acquires RangedWeapon {
        let ranged_weapon_struct = borrow_global<RangedWeapon>(object::object_address(ranged_weapon));
        let linear_transfer_ref = object::generate_linear_transfer_ref(&ranged_weapon_struct.transfer_ref);
        object::transfer_with_ref(linear_transfer_ref, to);
    }

    // helper functions

    /// gets the name of the collection
    fun get_collection_name(): String {
        string::utf8(COLLECTION_NAME)
    }

    /// gets the description of the collection
    fun get_collection_description(): String {
        string::utf8(COLLECTION_DESCRIPTION)
    }

    /// gets the uri of the collection
    fun get_collection_uri(): String {
        string::utf8(COLLECTION_URI)
    }

    /// gets the name of the token
    fun get_token_name(): String {
        string::utf8(TOKEN_NAME)
    }

    /// gets the description of the token
    fun get_token_description(): String {
        string::utf8(TOKEN_DESCRIPTION)
    }

    /// gets the uri of the token
    /// `ranged_weapon_type` - the type of the ranged weapon
    fun get_token_uri(ranged_weapon_type: u64): String {
        string_utils::format1(&TOKEN_BASE_URI, ranged_weapon_type)
    }

    // view functions

    #[view]
    /// returns the address of the player collection
    public fun get_collection_address(): address {
        aptos_arena::get_collection_address(get_collection_name())
    }

    #[view]
    /// returns whether a player has minted a ranged weapon
    public fun has_player_minted(player_address: address): bool {
        aptos_arena::has_player_minted(get_collection_name(), player_address)
    }

    #[view]
    /// returns the data of a ranged weapon
    public fun get_ranged_weapon_data(ranged_weapon_obj: Object<RangedWeapon>): (u64, u64) acquires RangedWeapon {
        let ranged_weapon = borrow_global<RangedWeapon>(object::object_address(&ranged_weapon_obj));
        (ranged_weapon.power, ranged_weapon.type)
    }

    // tests

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_token_objects::collection;

    #[test_only]
    fun setup_tests(aptos_arena: &signer) {
        genesis::setup();
        aptos_arena::initialize(aptos_arena);
    }

    #[test(aptos_arena = @aptos_arena)]
    fun test_initialize(aptos_arena: &signer) {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        assert!(get_collection_address() == collection::create_collection_address(
            &aptos_arena::get_game_account_address(),
            &get_collection_name()
        ), 0)
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    fun test_mint_ranged_weapon(aptos_arena: &signer, player: &signer) acquires RangedWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let ranged_weapon_obj = mint(player);
        assert!(exists<RangedWeapon>(object::object_address(&ranged_weapon_obj)), 0);
        assert!(has_player_minted(signer::address_of(player)), 0);
        let (
            power,
            type
        ) = get_ranged_weapon_data(ranged_weapon_obj);
        assert!(power == 0, 0);
        assert!(type == timestamp::now_seconds() % NUM_RANGED_WEAPONS + 1, 1);
    }

    #[test(aptos_arena = @aptos_arena, player1 = @0x5, player2=@0x6)]
    fun test_transfer_ranged_weapon(aptos_arena: &signer, player1: &signer, player2: &signer) acquires RangedWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let ranged_weapon_obj = mint(player1);
        let player2_address = signer::address_of(player2);
        transfer_ranged_weapon(&ranged_weapon_obj, player2_address);
        assert!(object::is_owner(ranged_weapon_obj, player2_address), 0);
    }
}

```
```rust
module aptos_arena::melee_weapon {

    use std::string;
    use std::option;
    use std::string::{String};

    use aptos_std::string_utils;

    use aptos_framework::object::{Self, Object, TransferRef};

    use aptos_token_objects::collection;

    use aptos_arena::utils;
    use aptos_arena::aptos_arena;

    // constants

    const COLLECTION_NAME: vector<u8> = b"MELEE_WEAPON";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Melee weapon for Aptos Arena";
    const COLLECTION_URI: vector<u8> = b"https://aptosarcade.com/api/melee-weapon/";

    const TOKEN_DESCRIPTION: vector<u8> = b"Melee weapon for Aptos Arena";
    const TOKEN_NAME: vector<u8> = b"MELEE_WEAPON";
    const TOKEN_BASE_URI: vector<u8> = b"https://aptosarcade.com/api/melee-weapon/{}";

    const NUM_MELEE_WEAPONS: u64 = 5;

    struct MeleeWeapon has key {
        power: u64,
        type: u64,
        knockback: u64,
        transfer_ref: TransferRef
    }

    /// create the melee weapon collection
    /// `deployer` - the transaction signer; must be the deployer
    public fun initialize(game_admin: &signer) {
       aptos_arena::create_collection(
            game_admin,
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

    public fun mint(player: &signer): Object<MeleeWeapon> {
        let melee_weapon_type = utils::rand_int(NUM_MELEE_WEAPONS) + 1;
        let constructor_ref = aptos_arena::mint_token_player(
            player,
            get_collection_name(),
            get_token_description(),
            get_token_name(),
            option::none(),
            get_token_uri(melee_weapon_type),
        );

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::enable_ungated_transfer(&transfer_ref);

        // create the melee weapon struct and move it to the token signer
        move_to(&object::generate_signer(&constructor_ref), MeleeWeapon {
            power: 0,
            type: melee_weapon_type,
            knockback: 0,
            transfer_ref
        });

        object::object_from_constructor_ref(&constructor_ref)
    }

    /// trnasfers `melee_weapon` to `to`
    /// `melee_weapon` - the melee weapon to transfer
    /// `to` - the address to transfer to
    public fun transfer_melee_weapon(melee_weapon: &Object<MeleeWeapon>, to: address) acquires MeleeWeapon {
        let melee_weapon_struct = borrow_global<MeleeWeapon>(object::object_address(melee_weapon));
        let linear_transfer_ref = object::generate_linear_transfer_ref(&melee_weapon_struct.transfer_ref);
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
    /// `melee_weapon_type` - the type of the ranged weapon
    fun get_token_uri(melee_weapon_type: u64): String {
        string_utils::format1(&TOKEN_BASE_URI, melee_weapon_type)
    }

    // view functions

    #[view]
    /// returns the address of the player collection
    public fun get_collection_address(): address {
        collection::create_collection_address(
            &aptos_arena::get_game_account_address(),
            &string::utf8(COLLECTION_NAME)
        )
    }

    #[view]
    /// returns whether a player has minted a melee weapon
    public fun has_player_minted(player: address): bool {
        aptos_arena::has_player_minted(get_collection_name(), player)
    }

    #[view]
    /// returns the data of a melee weapon
    public fun get_melee_weapon_data(melee_weapon_obj: Object<MeleeWeapon>): (u64, u64) acquires MeleeWeapon {
        let melee_weapon = borrow_global<MeleeWeapon>(object::object_address(&melee_weapon_obj));
        (melee_weapon.power, melee_weapon.type)
    }

    // tests

    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::genesis;
    #[test_only]
    use aptos_framework::timestamp;

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
        ), 0);
    }

    #[test(aptos_arena = @aptos_arena, player = @0x5)]
    fun test_mint_melee_weapon(aptos_arena: &signer, player: &signer) acquires MeleeWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let melee_weapon_obj = mint(player);
        assert!(exists<MeleeWeapon>(object::object_address(&melee_weapon_obj)), 0);
        assert!(has_player_minted(signer::address_of(player)), 0);
        let (
            power,
            type
        ) = get_melee_weapon_data(melee_weapon_obj);
        assert!(power == 0, 0);
        assert!(type == timestamp::now_seconds() % NUM_MELEE_WEAPONS + 1, 1);
    }

    #[test(aptos_arena = @aptos_arena, player1 = @0x5, player2=@0x6)]
    fun test_transfer_melee_weapon(aptos_arena: &signer, player1: &signer, player2: &signer)
    acquires MeleeWeapon {
        setup_tests(aptos_arena);
        initialize(aptos_arena);
        let melee_weapon_obj = mint(player1);
        let player2_address = signer::address_of(player2);
        transfer_melee_weapon(&melee_weapon_obj, player2_address);
        assert!(object::is_owner(melee_weapon_obj, player2_address), 0);
    }
}

```
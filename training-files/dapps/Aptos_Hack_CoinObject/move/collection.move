/// This defines an object-based Collection. A collection acts as a set organizer for a group of
/// tokens. This includes aspects such as a general description, project URI, name, and may contain
/// other useful generalizations across this set of tokens.
///
/// Being built upon objects enables collections to be relatively flexible. As core primitives it
/// supports:
/// * Common fields: name, uri, description, creator
/// * A mutability config for uri and description
/// * Optional support for collection-wide royalties
/// * Optional support for tracking of supply
///
/// This collection does not directly support:
/// * Events on mint or burn -- that's left to the collection creator.
///
/// TODO:
/// * Add Royalty reading and consider mutation
/// * Consider supporting changing the name of the collection.
/// * Consider supporting changing the aspects of supply
/// * Add aggregator support when added to framework
/// * Update ObjectId to be an acceptable param to move
module coin_objects::collection {
    use std::error;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};

    use aptos_framework::object::{Self, CreatorRef, ObjectId};

    friend coin_objects::token;

    /// The collections supply is at its maximum amount
    const EEXCEEDS_MAX_SUPPLY: u64 = 0;
    /// The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 1;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 2;
    /// Attempted to mutate an immutable field
    const EFIELD_NOT_MUTABLE: u64 = 3;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents the common fields for a collection.
    struct Collection has key {
        /// The creator of this collection.
        creator: address,
        /// A brief description of the collection.
        description: String,
        /// Determines which fields are mutable.
        mutability_config: MutabilityConfig,
        /// An optional categorization of similar token.
        name: String,
        /// The Uniform Resource Identifier (uri) pointing to the JSON file stored in off-chain
        /// storage; the URL length will likely need a maximum any suggestions?
        uri: String,
    }

    /// This config specifies which fields in the TokenData are mutable
    struct MutabilityConfig has copy, drop, store {
        description: bool,
        uri: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// The royalty of a token within this collection -- this optional
    struct Royalty has drop, key {
        numerator: u64,
        denominator: u64,
        /// The recipient of royalty payments. See the `shared_account` for how to handle multiple
        /// creators.
        payee_address: address,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Aggregable supply tracker, this is can be used for maximum parallel minting but only for
    /// for uncapped mints. Currently disabled until this library is in the framework.
    struct AggregableSupply has key {
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Fixed supply tracker, this is useful for ensuring that a limited number of tokens are minted.
    struct FixedSupply has key {
        current_supply: u64,
        max_supply: u64,
    }

    public fun create_fixed_collection(
        creator: &signer,
        description: String,
        max_supply: u64,
        mutability_config: MutabilityConfig,
        name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): CreatorRef {
        let collection_seed = create_collection_id_seed(&name);
        let creator_ref = object::create_named_object(creator, collection_seed);
        let object_signer = object::generate_signer(&creator_ref);

        let collection = Collection {
            creator: signer::address_of(creator),
            description,
            mutability_config,
            name,
            uri,
        };
        move_to(&object_signer, collection);

        let supply = FixedSupply {
            current_supply: 0,
            max_supply,
        };
        move_to(&object_signer, supply);

        if (option::is_some(&royalty)) {
            move_to(&object_signer, option::extract(&mut royalty))
        };

        creator_ref
    }

    public fun create_aggregable_collection(
        creator: &signer,
        description: String,
        mutability_config: MutabilityConfig,
        name: String,
        royalty: Option<Royalty>,
        uri: String,
    ): CreatorRef {
        let collection_seed = create_collection_id_seed(&name);
        let creator_ref = object::create_named_object(creator, collection_seed);
        let object_signer = object::generate_signer(&creator_ref);

        let collection = Collection {
            creator: signer::address_of(creator),
            description,
            mutability_config,
            name,
            uri,
        };
        move_to(&object_signer, collection);

        let supply = AggregableSupply { };
        move_to(&object_signer, supply);

        if (option::is_some(&royalty)) {
            move_to(&object_signer, option::extract(&mut royalty))
        };

        creator_ref
    }

    public fun init_royalty(object_signer: &signer, royalty: Royalty) {
        move_to(object_signer, royalty);
    }

    public fun create_collection_id(creator: &address, name: &String): ObjectId {
        object::create_object_id(creator, create_collection_id_seed(name))
    }

    public fun create_collection_id_seed(name: &String): vector<u8> {
        *string::bytes(name)
    }

    public fun create_mutability_config(description: bool, uri: bool): MutabilityConfig {
        MutabilityConfig { description, uri }
    }

    public fun create_royalty(numerator: u64, denominator: u64, payee_address: address): Royalty {
        Royalty { numerator, denominator, payee_address }
    }

    public(friend) fun increment_supply(creator: &address, name: &String) acquires FixedSupply {
        let collection_id = object::object_id_address(&create_collection_id(creator, name));
        if (exists<FixedSupply>(collection_id)) {
            let supply = borrow_global_mut<FixedSupply>(collection_id);
            supply.current_supply = supply.current_supply + 1;
            assert!(
                supply.current_supply <= supply.max_supply,
                error::out_of_range(EEXCEEDS_MAX_SUPPLY),
            );
        }
    }

    public(friend) fun decrement_supply(creator: &address, name: &String) acquires FixedSupply {
        let collection_id = object::object_id_address(&create_collection_id(creator, name));
        if (exists<FixedSupply>(collection_id)) {
            let supply = borrow_global_mut<FixedSupply>(collection_id);
            supply.current_supply = supply.current_supply - 1;
        }
    }

    /// Entry function for creating a collection
    public entry fun create_collection(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        mutable_description: bool,
        mutable_uri: bool,
        max_supply: u64,
        enable_royalty: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
        royalty_payee_address: address,
    ) {
        let mutability_config = create_mutability_config(mutable_description, mutable_uri);
        let royalty = if (enable_royalty) {
            option::some(create_royalty(
                royalty_numerator,
                royalty_denominator,
                royalty_payee_address,
            ))
        } else {
            option::none()
        };

        if (max_supply == 0) {
            create_aggregable_collection(
                creator,
                description,
                mutability_config,
                name,
                royalty,
                uri,
            )
        } else {
            create_fixed_collection(
                creator,
                description,
                max_supply,
                mutability_config,
                name,
                royalty,
                uri,
            )
        };
    }

    // Accessors

    public fun is_collection(collection_id: ObjectId): bool {
        exists<Collection>(object::object_id_address(&collection_id))
    }

    public fun creator(collection_id: ObjectId): address acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).creator
    }

    public fun description(collection_id: ObjectId): String acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).description
    }

    public fun is_description_mutable(collection_id: ObjectId): bool acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).mutability_config.description
    }

    public fun is_uri_mutable(collection_id: ObjectId): bool acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).mutability_config.uri
    }

    public fun name(collection_id: ObjectId): String acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).name
    }

    public fun uri(collection_id: ObjectId): String acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );
        borrow_global<Collection>(object::object_id_address(&collection_id)).uri
    }

    // Mutators

    public fun set_description(
        creator: &signer,
        collection_id: ObjectId,
        description: String,
    ) acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );

        let collection = borrow_global_mut<Collection>(object::object_id_address(&collection_id));
        assert!(
            collection.creator == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );

        assert!(
            collection.mutability_config.description,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );

        collection.description = description;
    }

    public fun set_uri(
        creator: &signer,
        collection_id: ObjectId,
        uri: String,
    ) acquires Collection {
        assert!(
            exists<Collection>(object::object_id_address(&collection_id)),
            error::not_found(ECOLLECTION_DOES_NOT_EXIST),
        );

        let collection = borrow_global_mut<Collection>(object::object_id_address(&collection_id));
        assert!(
            collection.creator == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );

        assert!(
            collection.mutability_config.uri,
            error::permission_denied(EFIELD_NOT_MUTABLE),
        );

        collection.uri = uri;
    }

    // Tests

    #[test(creator = @0x123, trader = @0x456)]
    entry fun test_create_and_transfer(creator: &signer, trader: &signer) {
        let creator_address = signer::address_of(creator);
        let collection_name = string::utf8(b"collection name");
        create_immutable_collection_helper(creator, *&collection_name);

        let collection_id = create_collection_id(&creator_address, &collection_name);
        assert!(object::owner(collection_id) == creator_address, 1);
        object::transfer(creator, collection_id, signer::address_of(trader));
        assert!(object::owner(collection_id) == signer::address_of(trader), 1);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x80001, location = aptos_framework::object)]
    entry fun test_duplicate_collection(creator: &signer) {
        let collection_name = string::utf8(b"collection name");
        create_immutable_collection_helper(creator, *&collection_name);
        create_immutable_collection_helper(creator, collection_name);
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    entry fun test_immutable_set_description(creator: &signer) acquires Collection {
        let collection_name = string::utf8(b"collection name");
        create_immutable_collection_helper(creator, *&collection_name);
        let collection_id = create_collection_id(&signer::address_of(creator), &collection_name);
        set_description(creator, collection_id, string::utf8(b"fail"));
    }

    #[test(creator = @0x123)]
    #[expected_failure(abort_code = 0x50003, location = Self)]
    entry fun test_immutable_set_uri(creator: &signer) acquires Collection {
        let collection_name = string::utf8(b"collection name");
        create_immutable_collection_helper(creator, *&collection_name);
        let collection_id = create_collection_id(&signer::address_of(creator), &collection_name);
        set_uri(creator, collection_id, string::utf8(b"fail"));
    }

    #[test(creator = @0x123)]
    entry fun test_mutable_set_description(creator: &signer) acquires Collection {
        let collection_name = string::utf8(b"collection name");
        create_mutable_collection_helper(creator, *&collection_name);
        let collection_id = create_collection_id(&signer::address_of(creator), &collection_name);
        let description = string::utf8(b"no fail");
        assert!(description != description(collection_id), 0);
        set_description(creator, collection_id, *&description);
        assert!(description == description(collection_id), 1);
    }

    #[test(creator = @0x123)]
    entry fun test_mutable_set_uri(creator: &signer) acquires Collection {
        let collection_name = string::utf8(b"collection name");
        create_mutable_collection_helper(creator, *&collection_name);
        let collection_id = create_collection_id(&signer::address_of(creator), &collection_name);
        let uri = string::utf8(b"no fail");
        assert!(uri != uri(collection_id), 0);
        set_uri(creator, collection_id, *&uri);
        assert!(uri == uri(collection_id), 1);
    }

    // Test helpers

    #[test_only]
    fun create_immutable_collection_helper(creator: &signer, name: String) {
        create_collection(
            creator,
            string::utf8(b"collection description"),
            name,
            string::utf8(b"collection uri"),
            false,
            false,
            1,
            false,
            0,
            0,
            signer::address_of(creator),
        );
    }

    #[test_only]
    fun create_mutable_collection_helper(creator: &signer, name: String) {
        create_collection(
            creator,
            string::utf8(b"collection description"),
            name,
            string::utf8(b"collection uri"),
            true,
            true,
            1,
            true,
            10,
            10,
            signer::address_of(creator),
        );
    }
}

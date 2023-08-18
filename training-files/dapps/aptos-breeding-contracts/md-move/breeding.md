```rust
module aptos_breeding_contract::breeding {
    use aptos_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenMutabilityConfig, create_token_mutability_config, create_collection, create_tokendata, TokenId};

    use std::bcs;
    use std::error;
    use std::signer;
    use std::string::{Self, String, utf8};
    use std::vector;

    struct NFTMintConfig has key {
        signer_cap: SignerCapability,
    }

    struct BreedingConfig has key {
        collections: Table<String, CollectionConfig>,
        last_breed_timestamps: Table<TokenId, u64>,
    }

    struct CollectionConfig has store {
        collection_name: String,
        collection_description: String,
        collection_maximum: u64,
        collection_uri: String,
        collection_mutate_config: vector<bool>,
        token_name_base: String,
        royalty_payee_address: address,
        token_description: String,
        token_maximum: u64,
        token_mutate_config: TokenMutabilityConfig,
        royalty_points_den: u64,
        royalty_points_num: u64,
        parent_collection_creator: address,
        parent_collection_name: String,
        token_counter: u64,
        breed_lock_period: u64,
    }

    const ENOT_AUTHORIZED: u64 = 1;

    const EBREED_CONFIG_NOT_FOUND: u64 = 2;

    const EVECTOR_LENGTH_UNMATCHED: u64 = 3;

    const EINVALID_ROYALTY_NUMERATOR_DENOMINATOR: u64 = 4;

    const EPARENT_COLLECTION_NOT_FOUND: u64 = 5;

    const ECOLLECTION_HAS_PARENT: u64 = 6;

    const ECOLLECTION_DOES_NOT_HAVE_PARENT: u64 = 7;

    const ECOLLECTION_NOT_MATCH: u64 = 8;

    const EPARENT_NOT_FOUND: u64 = 9;

    const EBREED_LOCK_PERIOD_NOT_PASSED: u64 = 10;

    fun assert_breeding_config_exists() {
        assert!(exists<BreedingConfig>(@aptos_breeding_contract), EBREED_CONFIG_NOT_FOUND);
    }

    fun assert_collection_not_have_parent(collection_name: String) acquires BreedingConfig {
        let breeding_config = borrow_global<BreedingConfig>(@aptos_breeding_contract);
        assert!(table::borrow(&breeding_config.collections, collection_name).parent_collection_name == utf8(b""), ECOLLECTION_HAS_PARENT);
    }

    fun assert_collection_has_parent(collection_name: String) acquires BreedingConfig {
        let breeding_config = borrow_global<BreedingConfig>(@aptos_breeding_contract);
        assert!(table::borrow(&breeding_config.collections, collection_name).parent_collection_name != utf8(b""), ECOLLECTION_DOES_NOT_HAVE_PARENT);
    }

    fun assert_collection_matches(collection_name: String, parent_collection_name: String) acquires BreedingConfig {
        let breeding_config = borrow_global<BreedingConfig>(@aptos_breeding_contract);
        assert!(table::borrow(&breeding_config.collections, collection_name).parent_collection_name != parent_collection_name, ECOLLECTION_NOT_MATCH);
    }

    fun get_resource_signer(): signer acquires NFTMintConfig {
        let nft_mint_config = borrow_global_mut<NFTMintConfig>(@aptos_breeding_contract);
        return create_signer_with_capability(&nft_mint_config.signer_cap)
    }

    /// Initialize NFTMintConfig for this module.
    fun init_module(admin: &signer) {
        // Construct a seed vector that pseudo-randomizes the resource address generated.
        let seed_vec = bcs::to_bytes(&timestamp::now_seconds());
        let (_, resource_signer_cap) = account::create_resource_account(admin, seed_vec);

        move_to(admin, NFTMintConfig {
            signer_cap: resource_signer_cap,
        });
    }

    public entry fun set_collection_config_and_create_collection(
        admin: &signer,
        parent_collection_creator: address,
        parent_collection_name: String,
        collection_name: String,
        collection_uri: String,
        collection_maximum: u64,
        collection_description: String,
        token_name_base: String,
        collection_mutate_config: vector<bool>,
        royalty_payee_address: address,
        token_description: String,
        token_maximum: u64,
        token_mutate_config: vector<bool>,
        royalty_points_den: u64,
        royalty_points_num: u64,
        breed_lock_period: u64,
    ) acquires NFTMintConfig, BreedingConfig {
        assert!(signer::address_of(admin) == @aptos_breeding_contract, error::permission_denied(ENOT_AUTHORIZED));
        assert!(vector::length(&collection_mutate_config) == 3 && vector::length(&token_mutate_config) == 5, error::invalid_argument(EVECTOR_LENGTH_UNMATCHED));
        assert!(royalty_points_den > 0 && royalty_points_num < royalty_points_den, error::invalid_argument(EINVALID_ROYALTY_NUMERATOR_DENOMINATOR));

        let nft_mint_config = borrow_global_mut<NFTMintConfig>(@aptos_breeding_contract);
        let resource_signer = create_signer_with_capability(&nft_mint_config.signer_cap);

        if (!exists<BreedingConfig>(@aptos_breeding_contract)) {
          move_to(admin, BreedingConfig {
            collections: table::new(),
            last_breed_timestamps: table::new(),
          });
        };

        let breeding_config = borrow_global_mut<BreedingConfig>(@aptos_breeding_contract);
        
        // check if parent collection exists
        assert!(token::check_collection_exists(parent_collection_creator, parent_collection_name), EPARENT_COLLECTION_NOT_FOUND);

        table::add(
            &mut breeding_config.collections, 
            parent_collection_name,
            CollectionConfig {
                collection_name,
                collection_description,
                collection_maximum,
                collection_uri,
                collection_mutate_config,
                token_name_base,
                royalty_payee_address,
                token_description,
                token_maximum,
                token_mutate_config: create_token_mutability_config(&token_mutate_config),
                royalty_points_den,
                royalty_points_num,
                parent_collection_creator,
                parent_collection_name,
                token_counter: 1,
                breed_lock_period
            }
        );

        create_collection(&resource_signer, collection_name, collection_description, collection_uri, collection_maximum, collection_mutate_config);
    }

    public entry fun breed(
        user: &signer,
        parent_collection_creator: address,
        parent_collection_name: String,
        parent_collection_token_names: vector<String>,
        property_keys: vector<String>,
        property_types: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTMintConfig, BreedingConfig {
        assert_breeding_config_exists();
        assert_collection_has_parent(parent_collection_name);
        assert!(vector::length(&property_keys) == vector::length(&property_types), error::invalid_argument(EVECTOR_LENGTH_UNMATCHED));
        let resource_signer = get_resource_signer();

        let breeding_config = borrow_global_mut<BreedingConfig>(@aptos_breeding_contract);
        let collection_config = table::borrow_mut(&mut breeding_config.collections, parent_collection_name);
        let token_name = collection_config.token_name_base;
        string::append_utf8(&mut token_name, b": ");
        let num = u64_to_string(collection_config.token_counter);
        string::append(&mut token_name, num);

        let breed_lock_period = &collection_config.breed_lock_period;

        // generate metadata
        let i = 0;
        let p_keys = vector::empty<String>();
        let p_values = vector::empty<vector<u8>>();
        let p_types = vector::empty<String>();

        while (i < vector::length(&parent_collection_token_names)) {
            let token_id = token::create_token_id_raw(
                parent_collection_creator,
                parent_collection_name,
                *vector::borrow(&parent_collection_token_names, i),
                *vector::borrow(&property_versions, i),
            );
            assert!(token::balance_of(signer::address_of(user), token_id) > 0, EPARENT_NOT_FOUND);

            let now = &timestamp::now_seconds();
            if (table::contains(&breeding_config.last_breed_timestamps, token_id)) {
                let last_breed_timestamp = table::borrow_mut(&mut breeding_config.last_breed_timestamps, token_id);
                assert!(*last_breed_timestamp + *breed_lock_period >= *now, EBREED_LOCK_PERIOD_NOT_PASSED);
                *last_breed_timestamp = *now;
            } else {
                table::add(&mut breeding_config.last_breed_timestamps, token_id, *now);
            };

            // TODO determine metadata and push to arrays

            i = i + 1;
        };

        let token_data_id = create_tokendata(
            &resource_signer,
            collection_config.collection_name,
            token_name,
            collection_config.token_description,
            collection_config.token_maximum,
            string::utf8(b"token uri"),
            collection_config.royalty_payee_address,
            collection_config.royalty_points_den,
            collection_config.royalty_points_num,
            collection_config.token_mutate_config,
            p_keys,
            p_values,
            p_types,
        );

        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::direct_transfer(&resource_signer, user, token_id, 1);
    }


    fun u64_to_string(value: u64): String {
        if (value == 0) {
            return utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        utf8(buffer)
    }

    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    public fun set_up_test(
        admin_account: &signer,
        creator: &signer,
        user: &signer,
        aptos_framework: &signer,
        timestamp: u64,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(timestamp);
        create_account_for_test(signer::address_of(admin_account));
        init_module(admin_account);

        create_account_for_test(signer::address_of(creator));
        create_account_for_test(signer::address_of(user));
    }
    
    #[test (admin_account = @0x74444b619d11c1c074101998067a3830a34b9371764169b5b52993fad7594748, creator = @0x123, user = @0x234, aptos_framework = @aptos_framework)]
    public entry fun test_happy_path(
        admin_account: signer,
        creator: signer,
        user: signer,
        aptos_framework: signer,
    ) acquires NFTMintConfig, BreedingConfig {
        set_up_test(&admin_account, &creator, &user, &aptos_framework, 10);

        token::opt_in_direct_transfer(&user, true);

        // create parent collection
        let collection_name = string::utf8(b"Dragon Genesis 1");
        token::create_collection(
            &creator,
            collection_name,
            string::utf8(b"Collection: Dragon Genesis 1"),
            string::utf8(b"https://aptos.dev"),
            2,
            vector<bool>[false, false, false],
            
        );
        let token_name_one = string::utf8(b"Dragon #1");
        token::create_token_script(
            &creator,
            collection_name,
            token_name_one,
            string::utf8(b"Dragon Token"),
            1,
            1,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(&creator),
            100,
            0,
            vector<bool>[false, false, false, false, false],
            vector::empty(),
            vector::empty(),
            vector::empty(),
            // vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")],
            // vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)],
            // vector<String>[string::utf8(b"u64"), string::utf8(b"u64")],
        );

        token::transfer_with_opt_in(&creator, signer::address_of(&creator), collection_name, token_name_one, 0, signer::address_of(&user), 1);

        let token_name_two = string::utf8(b"Dragon #2");
        token::create_token_script(
            &creator,
            collection_name,
            token_name_two,
            string::utf8(b"Dragon Token"),
            1,
            1,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(&creator),
            100,
            0,
            vector<bool>[false, false, false, false, false],
            vector::empty(),
            vector::empty(),
            vector::empty(),
            // vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")],
            // vector<vector<u8>>[bcs::to_bytes<u64>(&12), bcs::to_bytes<u64>(&2)],
            // vector<String>[string::utf8(b"u64"), string::utf8(b"u64")],
        );

        token::transfer_with_opt_in(&creator, signer::address_of(&creator), collection_name, token_name_two, 0, signer::address_of(&user), 1);

        set_collection_config_and_create_collection(
            &admin_account,
            signer::address_of(&creator),
            collection_name,
            string::utf8(b"Dragon Gen 2"),
            string::utf8(b"https://example.com"),
            100,
            string::utf8(b"Collection: Dragon Gen 2"),
            string::utf8(b"Gen 2"),
            vector<bool>[false, false, false],
            signer::address_of(&admin_account),
            string::utf8(b"Gen 2"),
            1,
            vector<bool>[false, false, false, false, false],
            100,
            0,
            3600 * 24 * 3,
        );

        breed(
            &user, 
            signer::address_of(&creator),
            collection_name,
            vector<String>[token_name_one, token_name_two],
            vector::empty(),
            vector::empty(),
            vector<u64>[0, 0],
        );
    }
}

```
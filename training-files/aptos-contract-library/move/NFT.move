module wav3::NFT {

    use std::bcs;
    use std::error;
    use std::signer;
    use std::option;
    use std::vector;
    use std::string::{Self, String};

    use aptos_framework::block;
    use aptos_token::property_map;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenDataId};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account::{Self, create_signer_with_capability};

    const ECOLLECTION_ALREADY_EXISTS: u64 = 1;
    const EIMAGE_URI_TOO_LONG: u64 = 2;
    const EANIMATION_URI_TOO_LONG: u64 = 3;
    const EWEBSITE_URI_TOO_LONG: u64 = 4;
    const ETOKEN_DATA_ALREADY_EXISTS: u64 = 5;
    const ECOLLECTION_NOT_PUBLISHED: u64 = 6;
    const ENOT_A_MULTI_EDITION: u64 = 7;
    const ESOCIAL_MEDIA_ALREADY_REGISTER: u64 = 8;
    const ESOCIAL_MEDIA_NOT_REGISTER: u64 = 9;
    const ECOLLECTIONS_NOT_PUBLISHED: u64 = 10;
    const EUTF_CONVERT_ERROR: u64 = 11;
    const EMINT_NOT_MERGABLE: u64 = 12;
    const EFIELD_NOT_MUTABLE: u64 = 13;
    const ENO_MUTATE_CAPABILITY: u64 = 14;

    const MAX_URI_LENGTH: u64 = 512;

    // Property key stored in default_properties controlling who can burn the token.
    // the corresponding property value is BCS serialized bool.
    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";
    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    const TOKEN_PROPERTY_MUTABLE: vector<u8> = b"TOKEN_PROPERTY_MUTATBLE";
    const WAV3_STANDARD_PROPERTY_KEYS: vector<u8> = b"WAV3_STANDARD_PROPERTY_KEYS";

    struct TokenId has store, copy, drop {
        collection_id: CollectionId,
        token_name: String
    }

    struct CollectionId has store, copy, drop {
        contract: address,
        creator: address,
        collection_name: String
    }

    struct CollectionExtend has store {
        social_media: SimpleMap<String, String>,
        symbol: String,
        image_uri: String,
        animation_uri: String,
        website: String,
        standard_version: u64,
        commercial_standard: String,
        update_block_height: u64,
        royalty_policy: String,
        multi_edtion: bool,
        mint_mergable: bool,
        uri_scheme: String,
        uri_content_type: String
    }

    struct TokenDataExtend has store {
        image_uri: String,
        animation_uri: String,
        image_checksum: u64,
        mutability_config: MutabilityConfig,
        update_block_height: u64,
    }

    struct MutabilityConfig has copy, drop, store {
        image_uri: bool
    }

    /// Represent collection and token metadata for a creator
    struct Collections has key {
        collection_extend_data: Table<String, CollectionExtend>,
        token_extend_data: Table<TokenDataId, TokenDataExtend>,
        create_collection_events: EventHandle<CreateCollectionEvent>,
        create_token_data_events: EventHandle<CreateTokenDataEvent>,
        mutate_token_image_events: EventHandle<MutateTokenImageEvent>,
        social_media_events: EventHandle<SocialMediaEvent>,
    }

    struct MutateOnceCap has drop, store {
        image_uri: bool,
        property: bool
    }

    struct MintCap has drop, store {
    }

    struct ResourceAccountCap has key {
        cap: account::SignerCapability
    }

    struct CreateCollectionEvent has drop, store {
        symbol: String,
        image_uri: String,
        animation_uri: String,
        website: String,
        standard_version: u64,
        commercial_standard: String,
        royalty_policy: String,
        multi_edtion: bool,
        mint_mergable: bool
    }

    struct CreateTokenDataEvent has drop, store {
        image_uri: String,
        animation_uri: String,
    }

    struct MutateTokenImageEvent has drop, store {
        creator: address,
        collection_name: String,
        token_name: String,
        old_image_uri: String,
        new_image_uri: String
    }

    struct SocialMediaEvent has drop, store {
        creator: address,
        collection_name: String,
        social_media_type: String,
        social_media: String
    }

    public entry fun create_collection(
        account: &signer,
        name: String,
        description: String,
        maximum: u64,
        mutate_setting: vector<bool>,
        symbol: String,
        image_uri: String,
        animation_uri: String,
        website: String,
        standard_version: u64,
        commercial_standard: String,
        royalty_policy: String,
        multi_edtion: bool,
        mint_mergable: bool,
        uri_scheme: String,
        uri_content_type: String
    ) acquires Collections, ResourceAccountCap {
        init_creator(account);
        let account_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account_signer(account_addr);
        let resource_account = signer::address_of(&resource_account_signer);
        let collections = borrow_global_mut<Collections>(resource_account);
        let collection_extend_data = &mut collections.collection_extend_data;
        assert!(
            !table::contains(collection_extend_data, name),
            error::already_exists(ECOLLECTION_ALREADY_EXISTS),
        );
        let uri = get_collection_uri(uri_scheme, uri_content_type, resource_account, name);

        token::create_collection(&resource_account_signer, name, description, uri, maximum, mutate_setting);

        assert!(string::length(&image_uri) <= MAX_URI_LENGTH, error::invalid_argument(EIMAGE_URI_TOO_LONG));
        assert!(string::length(&animation_uri) <= MAX_URI_LENGTH, error::invalid_argument(EANIMATION_URI_TOO_LONG));
        assert!(string::length(&website) <= MAX_URI_LENGTH, error::invalid_argument(EWEBSITE_URI_TOO_LONG));

        table::add(collection_extend_data, name, CollectionExtend {
            social_media: simple_map::create<String, String>(),
            symbol,
            image_uri,
            animation_uri,
            website,
            standard_version,
            commercial_standard,
            update_block_height: block::get_current_block_height(),
            royalty_policy,
            multi_edtion,
            mint_mergable,
            uri_scheme,
            uri_content_type
        });
        event::emit_event<CreateCollectionEvent>(
            &mut collections.create_collection_events,
            CreateCollectionEvent {
                symbol,
                image_uri,
                animation_uri,
                website,
                standard_version,
                commercial_standard,
                royalty_policy,
                multi_edtion,
                mint_mergable
            }
        );
    }

    public fun create_collection_back_mint_cap(
        account: &signer,
        name: String,
        description: String,
        maximum: u64,
        mutate_setting: vector<bool>,
        symbol: String,
        image_uri: String,
        animation_uri: String,
        website: String,
        standard_version: u64,
        commercial_standard: String,
        royalty_policy: String,
        multi_edtion: bool,
        mint_mergable: bool,
        uri_scheme: String,
        uri_content_type: String
    ): MintCap acquires Collections, ResourceAccountCap {
        create_collection(
            account,
            name,
            description,
            maximum,
            mutate_setting,
            symbol,
            image_uri,
            animation_uri,
            website,
            standard_version,
            commercial_standard,
            royalty_policy,
            multi_edtion,
            mint_mergable,
            uri_scheme,
            uri_content_type
        );
        MintCap {}
    }

    fun get_resource_account_signer(market_address: address): signer acquires ResourceAccountCap {
        let resource_account_cap = borrow_global<ResourceAccountCap>(market_address);
        let resource_signer_from_cap = create_signer_with_capability(&resource_account_cap.cap);
        resource_signer_from_cap
    }

    fun init_creator(
        creator: &signer,
    ) acquires ResourceAccountCap {
        let account_addr = signer::address_of(creator);
        if (!exists<ResourceAccountCap>(account_addr)) {
            let block_height = block::get_current_block_height();
            let seed = bcs::to_bytes(&block_height);
            let (account_signer, cap) = account::create_resource_account(creator, seed);
            move_to(creator, ResourceAccountCap{
                cap
            });
            token::initialize_token_store(&account_signer);
        };
        let resource_account_signer = get_resource_account_signer(account_addr);
        if (!exists<Collections>(signer::address_of(&resource_account_signer))) {
            move_to(
                &resource_account_signer,
                Collections{
                    collection_extend_data: table::new(),
                    token_extend_data: table::new(),
                    create_collection_events: account::new_event_handle<CreateCollectionEvent>(&resource_account_signer),
                    create_token_data_events: account::new_event_handle<CreateTokenDataEvent>(&resource_account_signer),
                    mutate_token_image_events: account::new_event_handle<MutateTokenImageEvent>(&resource_account_signer),
                    social_media_events: account::new_event_handle<SocialMediaEvent>(&resource_account_signer),
                },
            )
        };
    }

    public entry fun create_tokendata(
        account: &signer,
        collection: String,
        name: String,
        description: String,
        maximum: u64,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        token_mutate_config_vec: vector<bool>,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        image_uri: String,
        animation_uri: String,
        image_checksum: u64,
        mutability_config_vec: vector<bool>,
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        internal_create_tokendata(
            account_addr,
            collection,
            name,
            description,
            maximum,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config_vec,
            property_keys,
            property_values,
            property_types,
            image_uri,
            animation_uri,
            image_checksum,
            mutability_config_vec
        );
    }

    public fun create_tokendata_with_cap(
        creator: address,
        collection: String,
        name: String,
        description: String,
        maximum: u64,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        token_mutate_config_vec: vector<bool>,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        image_uri: String,
        animation_uri: String,
        image_checksum: u64,
        mutability_config_vec: vector<bool>,
        _mint_cap: &MintCap
    ) acquires Collections, ResourceAccountCap {
        internal_create_tokendata(
            creator,
            collection,
            name,
            description,
            maximum,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config_vec,
            property_keys,
            property_values,
            property_types,
            image_uri,
            animation_uri,
            image_checksum,
            mutability_config_vec
        );
    }

    fun internal_create_tokendata(
        creator: address,
        collection: String,
        name: String,
        description: String,
        maximum: u64,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        token_mutate_config_vec: vector<bool>,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        image_uri: String,
        animation_uri: String,
        image_checksum: u64,
        mutability_config_vec: vector<bool>,
    ) acquires Collections, ResourceAccountCap {
        let resource_account_signer = get_resource_account_signer(creator);
        let resource_account = signer::address_of(&resource_account_signer);
        assert!(
            exists<Collections>(resource_account),
            error::not_found(ECOLLECTIONS_NOT_PUBLISHED),
        );
        let collections = borrow_global_mut<Collections>(resource_account);
        assert!(
            table::contains(&collections.collection_extend_data, collection),
            error::already_exists(ECOLLECTION_NOT_PUBLISHED),
        );
        let collection_extend = table::borrow(&collections.collection_extend_data, collection);
        let token_mutate_config = token::create_token_mutability_config(&token_mutate_config_vec);
        let token_property_keys_string  = get_property_keys(&property_keys);
        let token_uri = get_token_uri(collection_extend.uri_scheme, collection_extend.uri_content_type, resource_account, collection, name);
        vector::push_back(&mut property_keys, string::utf8(WAV3_STANDARD_PROPERTY_KEYS));
        vector::push_back(&mut property_values, bcs::to_bytes(&token_property_keys_string));
        vector::push_back(&mut property_types, string::utf8(b"0x1::string::String"));
        let token_data_id = token::create_tokendata(
            &resource_account_signer,
            collection,
            name,
            description,
            maximum,
            token_uri,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config,
            property_keys,
            property_values,
            property_types,
        );
        assert!(string::length(&image_uri) <= MAX_URI_LENGTH, error::invalid_argument(EIMAGE_URI_TOO_LONG));
        assert!(string::length(&animation_uri) <= MAX_URI_LENGTH, error::invalid_argument(EANIMATION_URI_TOO_LONG));
        assert!(
            !table::contains(&collections.token_extend_data, token_data_id),
            error::already_exists(ETOKEN_DATA_ALREADY_EXISTS),
        );
        let mutability_config = create_token_mutability_config(mutability_config_vec);

        table::add(&mut collections.token_extend_data, token_data_id, TokenDataExtend {
            image_uri,
            animation_uri,
            image_checksum,
            mutability_config,
            update_block_height: block::get_current_block_height()
        });
        event::emit_event<CreateTokenDataEvent>(
            &mut collections.create_token_data_events,
            CreateTokenDataEvent {
                image_uri,
                animation_uri
            }
        );
    }

    public fun mint_nft_with_cap_back_mutate_cap(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        _mint_cap: &MintCap
    ): MutateOnceCap acquires Collections, ResourceAccountCap {
        internal_mint_nft(
            account,
            creator,
            collection_name,
            token_name,
            property_keys,
            property_values,
            property_types
        );
        MutateOnceCap {
            image_uri: true,
            property: true
        }
    }

    public fun mint_nft_with_cap(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>,
        _mint_cap: &MintCap
    ) acquires Collections, ResourceAccountCap {
        internal_mint_nft(
            account,
            creator,
            collection_name,
            token_name,
            property_keys,
            property_values,
            property_types
        );
    }

    public entry fun mint_nft(
        account: &signer,
        collection_name: String,
        token_name: String,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        internal_mint_nft(
            account,
            account_addr,
            collection_name,
            token_name,
            property_keys,
            property_values,
            property_types
        );
    }

    fun internal_mint_nft(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_keys: vector<String>,
        property_values: vector<vector<u8>>,
        property_types: vector<String>
    ) acquires Collections, ResourceAccountCap {
        let resource_account_signer = get_resource_account_signer(creator);
        let resource_account = signer::address_of(&resource_account_signer);
        let token_data_id = token::create_token_data_id(resource_account, collection_name, token_name);
        let collections = borrow_global_mut<Collections>(resource_account);
        let collection_extend_data = table::borrow(& collections.collection_extend_data, collection_name);
        if (!collection_extend_data.multi_edtion) {
            let res_opt =token::get_token_supply(resource_account, token_data_id);
            let cur_supply = option::extract(&mut res_opt);
            assert!(cur_supply < 2, ENOT_A_MULTI_EDITION);
        };
        let token_id = token::mint_token(&resource_account_signer, token_data_id, 1);
        let properties = token::get_property_map(resource_account, token_id);
        let token_property_keys_string = property_map::read_string(&properties, &string::utf8(WAV3_STANDARD_PROPERTY_KEYS));
        let token_property_keys_string = update_property_keys(token_property_keys_string, &property_keys);
        vector::push_back(&mut property_keys, string::utf8(WAV3_STANDARD_PROPERTY_KEYS));
        vector::push_back(&mut property_values, bcs::to_bytes(&token_property_keys_string));
        vector::push_back(&mut property_types, string::utf8(b"0x1::string::String"));
        let token_id = token::mutate_one_token(
        &resource_account_signer,
        resource_account,
        token_id,
        property_keys,
        property_values,
        property_types
        );
        let token = token::withdraw_token(&resource_account_signer, token_id, 1);
        token::deposit_token(account, token);
    }

    public entry fun mint_token(
    account: &signer,
    collection_name: String,
    token_name: String,
    amount: u64
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account_signer(account_addr);
        let resource_account = signer::address_of(&resource_account_signer);
        let token_data_id = token::create_token_data_id(resource_account, collection_name, token_name);
        let collections = borrow_global<Collections>(resource_account);
        let collection_extend_data = table::borrow(&collections.collection_extend_data, collection_name);
        assert!(!collection_extend_data.mint_mergable, EMINT_NOT_MERGABLE);
        if (!collection_extend_data.multi_edtion) {
            let res_opt = token::get_token_supply(resource_account, token_data_id);
            let cur_supply = option::extract(&mut res_opt);
            assert!(cur_supply < 2, ENOT_A_MULTI_EDITION);
        };
        let token_id = token::mint_token(&resource_account_signer, token_data_id, amount);
        let token = token::withdraw_token(&resource_account_signer, token_id, amount);
        token::deposit_token(account, token);
    }


    public entry fun add_social_media(
        account: &signer,
        collection_name: String,
        social_media_type: String,
        social_media: String
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account_signer(account_addr);
        let resource_account = signer::address_of(&resource_account_signer);
        let collections = borrow_global_mut<Collections>(resource_account);
        let collection_extend_data = table::borrow_mut(
            &mut  collections.collection_extend_data, collection_name
        );
        assert!(
            !simple_map::contains_key(&collection_extend_data.social_media, &social_media_type),
            ESOCIAL_MEDIA_ALREADY_REGISTER
        );
        simple_map::add(&mut collection_extend_data.social_media, social_media_type, social_media);
        collection_extend_data.update_block_height = block::get_current_block_height();
        event::emit_event(&mut collections.social_media_events, SocialMediaEvent{
            creator: resource_account,
            collection_name,
            social_media_type,
            social_media
        });
    }

    public fun create_token_mutability_config(mutability_vec: vector<bool>): MutabilityConfig {
        let image_uri_update = vector::pop_back(&mut mutability_vec);
        MutabilityConfig {
            image_uri: image_uri_update
        }
    }

    public entry fun update_social_media(
        account: &signer,
        collection_name: String,
        social_media_type: String,
        social_media: String
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account_signer(account_addr);
        let resource_account = signer::address_of(&resource_account_signer);
        let collections = borrow_global_mut<Collections>(resource_account);
        let collection_extend_data = table::borrow_mut(
            &mut collections.collection_extend_data, collection_name
        );
        assert!(
            simple_map::contains_key(&collection_extend_data.social_media, &social_media_type),
            ESOCIAL_MEDIA_NOT_REGISTER
        );
        let social_meida_ref = simple_map::borrow_mut(
            &mut collection_extend_data.social_media,
            &social_media_type
        );
        *social_meida_ref = social_media;
        collection_extend_data.update_block_height = block::get_current_block_height();
        event::emit_event(&mut collections.social_media_events, SocialMediaEvent{
            creator: resource_account,
            collection_name,
            social_media_type,
            social_media
        });
    }

    public entry fun mutate_token_properties(
        account: &signer,
        token_owner: address,
        collection_name: String,
        token_name: String,
        token_property_version: u64,
        amount: u64,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        internal_mutate_token_properties(
            account_addr,
            token_owner,
            collection_name,
            token_name,
            token_property_version,
            amount,
            keys,
            values,
            types
        );
    }

    public fun mutate_token_propertis_with_cap(
        creator_address: address,
        token_owner: address,
        collection_name: String,
        token_name: String,
        token_property_version: u64,
        amount: u64,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
        mutate_once_cap: &mut MutateOnceCap
    ) acquires Collections, ResourceAccountCap {
        assert!(mutate_once_cap.property, ENO_MUTATE_CAPABILITY);
        internal_mutate_token_properties(
            creator_address,
            token_owner,
            collection_name,
            token_name,
            token_property_version,
            amount,
            keys,
            values,
            types
        );
        mutate_once_cap.property = false;
    }

    fun internal_mutate_token_properties(
        creator_address: address,
        token_owner: address,
        collection_name: String,
        token_name: String,
        token_property_version: u64,
        amount: u64,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires Collections, ResourceAccountCap {
        let resource_account_signer = get_resource_account_signer(creator_address);
        let resource_account = signer::address_of(&resource_account_signer);
        let collections = borrow_global_mut<Collections>(resource_account);
        let token_data_id = token::create_token_data_id(resource_account, collection_name, token_name);
        let token_extend_data = table::borrow_mut(
            &mut  collections.token_extend_data, token_data_id
        );
        let token_id = token::create_token_id(token_data_id, token_property_version);
        let properties = token::get_property_map(token_owner, token_id);
        let token_property_keys_string = property_map::read_string(&properties, &string::utf8(WAV3_STANDARD_PROPERTY_KEYS));
        let token_property_keys_string = update_property_keys(token_property_keys_string, &keys);
        vector::push_back(&mut keys, string::utf8(WAV3_STANDARD_PROPERTY_KEYS));
        vector::push_back(&mut values, *string::bytes(&token_property_keys_string));
        vector::push_back(&mut types, string::utf8(b"0x1::string::String"));
        token::mutate_token_properties(
            &resource_account_signer,
            token_owner,
            resource_account,
            collection_name,
            token_name,
            token_property_version,
            amount,
            keys,
            values,
            types,
        );
        token_extend_data.update_block_height = block::get_current_block_height();
    }

    public entry fun mutate_token_image_uri(
        account: &signer,
        collection_name: String,
        token_name: String,
        uri: String,
        image_checksum: u64
    ) acquires Collections, ResourceAccountCap {
        let account_addr = signer::address_of(account);
        internal_mutate_token_image_uri(
            account_addr,
            collection_name,
            token_name,
            uri,
            image_checksum
        );
    }

    public fun mutate_token_image_uri_with_cap(
        creator_address: address,
        collection_name: String,
        token_name: String,
        uri: String,
        image_checksum: u64,
        mutate_once_cap: &mut MutateOnceCap
    ) acquires Collections, ResourceAccountCap {
        assert!(mutate_once_cap.image_uri, ENO_MUTATE_CAPABILITY);
        internal_mutate_token_image_uri(
            creator_address,
            collection_name,
            token_name,
            uri,
            image_checksum
        );
        mutate_once_cap.image_uri = false;
    }

    fun internal_mutate_token_image_uri(
        creator_address: address,
        collection_name: String,
        token_name: String,
        uri: String,
        image_checksum: u64
    ) acquires Collections, ResourceAccountCap {
        assert!(string::length(&uri) <= MAX_URI_LENGTH, error::invalid_argument(EIMAGE_URI_TOO_LONG));
        let resource_account_signer = get_resource_account_signer(creator_address);
        let resource_account = signer::address_of(&resource_account_signer);
        let collections = borrow_global_mut<Collections>(resource_account);
        let token_id = token::create_token_data_id(resource_account, collection_name, token_name);
        let token_extend_data = table::borrow_mut(
            &mut  collections.token_extend_data, token_id
        );
        assert!(token_extend_data.mutability_config.image_uri, EFIELD_NOT_MUTABLE);
        let old_image_uri = *&token_extend_data.image_uri;
        token_extend_data.image_uri = uri;
        token_extend_data.image_checksum = image_checksum;
        token_extend_data.update_block_height = block::get_current_block_height();

        event::emit_event(&mut collections.mutate_token_image_events, MutateTokenImageEvent{
            creator: resource_account,
            collection_name,
            token_name,
            old_image_uri,
            new_image_uri: uri
        });
    }

    public entry fun burn_token_by_creator(
        account: &signer,
        token_owner: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        amount: u64,
    ) acquires ResourceAccountCap {
        let account_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account_signer(account_addr);
        token::burn_by_creator(
            &resource_account_signer,
            token_owner,
            collection_name,
            token_name,
            property_version,
            amount
        );
    }

    public fun create_token_data_id(creator: address, collection: String, token_name: String): TokenDataId acquires ResourceAccountCap {
        let resource_account_signer = get_resource_account_signer(creator);
        token::create_token_data_id(signer::address_of(&resource_account_signer), collection, token_name)
    }

    fun get_collection_uri(uri_scheme: String, uri_content_type: String, creator: address, collection_name: String): String {
        let collection_id = CollectionId {
            contract: @wav3,
            creator,
            collection_name
        };
        let collection_id_bcs_vec = bcs::to_bytes(&collection_id);
        let collection_id_bcs_hex_string = vec_u8_to_hex_string(collection_id_bcs_vec);
        let uri = copy uri_scheme;
        string::append_utf8(&mut uri, b"/collection/");
        string::append(&mut uri, collection_id_bcs_hex_string);
        string::append_utf8(&mut uri, b".");
        string::append(&mut uri, uri_content_type);
        uri
    }

    fun get_token_uri(uri_scheme: String, uri_content_type: String, creator: address, collection_name: String, token_name: String): String {
        let token_id = TokenId{
            collection_id: CollectionId {
                contract: @wav3,
                creator,
                collection_name
            },
            token_name
        };
        let token_id_bcs_vec = bcs::to_bytes(&token_id);
        let token_id_bcs_hex_string = vec_u8_to_hex_string(token_id_bcs_vec);
        let uri = copy uri_scheme;
        string::append_utf8(&mut uri, b"/token/");
        string::append(&mut uri, token_id_bcs_hex_string);
        string::append_utf8(&mut uri, b".");
        string::append(&mut uri, uri_content_type);
        uri
    }

    fun address_to_string(addr: address): String {
        let address_vec = bcs::to_bytes(&addr);
        vec_u8_to_hex_string(address_vec)
    }

    fun vec_u8_to_hex_string(vec_u8: vector<u8>): String {
        let vec_utf8 = vector::empty<u8>();
        let i = 0;
        let len = vector::length(&vec_u8);
        while(i < len) {
            let val = *vector::borrow(&vec_u8, i);
            let high_4 = val >> 4;
            let low_4 = val << 4 >> 4;
            vector::push_back(&mut vec_utf8, hex_to_utf8(high_4));
            vector::push_back(&mut vec_utf8, hex_to_utf8(low_4));
            i = i + 1;
        };
        string::utf8(vec_utf8)
    }

    fun hex_to_utf8(num: u8): u8 {
        assert!(num < 16, error::invalid_argument(EUTF_CONVERT_ERROR));
        if (num < 10) {
            num + 48
        } else {
            num + 55
        }
    }

    fun get_property_keys(property_keys: &vector<String>): String {
        let token_preserved_keys = vector<String>[
            string::utf8(BURNABLE_BY_CREATOR),
            string::utf8(BURNABLE_BY_OWNER),
            string::utf8(TOKEN_PROPERTY_MUTABLE),
            string::utf8(WAV3_STANDARD_PROPERTY_KEYS)
        ];
        let token_property_keys_string = string::utf8(b"");
        let len = vector::length<String>(property_keys);
        let i = 0;
        while (i < len) {
            let key = vector::borrow<String>(property_keys, i);
            if (!vector::contains(&token_preserved_keys, key)) {
                string::append(&mut token_property_keys_string, *key);
                string::append(&mut token_property_keys_string, string::utf8(b"/"));
            };
            i = i + 1;
        };
        token_property_keys_string
    }

    fun update_property_keys(token_property_keys: String, property_keys: &vector<String>): String {
        let token_preserved_keys = vector<String>[
            string::utf8(BURNABLE_BY_CREATOR),
            string::utf8(BURNABLE_BY_OWNER),
            string::utf8(TOKEN_PROPERTY_MUTABLE),
            string::utf8(WAV3_STANDARD_PROPERTY_KEYS)
        ];
        let len = vector::length<String>(property_keys);
        let i = 0;
        while (i < len) {
            let key = vector::borrow<String>(property_keys, i);
            let str_len = string::length(&token_property_keys);
            if (!vector::contains(&token_preserved_keys, key)) {
                if (string::index_of(&token_property_keys, key) == str_len) {
                    string::append(&mut token_property_keys, *key);
                    string::append(&mut token_property_keys, string::utf8(b"/"));
                };
            };
            i = i + 1;
        };
        token_property_keys
    }
}
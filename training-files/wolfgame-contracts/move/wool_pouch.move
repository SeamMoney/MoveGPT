module woolf_deployer::wool_pouch {
    use std::signer;
    use std::error;
    use std::vector;
    use std::string::{Self, String};

    use aptos_std::table::Table;
    use aptos_std::table;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, TokenId, Token, TokenDataId};
    use aptos_token::property_map;

    use woolf_deployer::wool;
    use woolf_deployer::utf8_utils;
    use woolf_deployer::token_helper;

    friend woolf_deployer::woolf;
    friend woolf_deployer::risky_game;

    //
    // Errors
    //
    const ENOT_OWNER: u64 = 1;
    const ENOT_CONTROLLERS: u64 = 2;
    const EINSUFFICIENT_POUCH: u64 = 3;
    const EPAUSED: u64 = 4;
    const EPOUCH_NOT_FOUND: u64 = 5;
    const ENO_MORE_EARNINGS_AVAILABLE: u64 = 6;
    const ENOT_ADMIN: u64 = 7;

    //
    // constants
    //
    const START_VALUE: u64 = 1 * 100000000;
    const ONE_DAY_IN_SECONDS: u64 = 86400;

    struct Pouch has store {
        // whether or not first 10,000 WOOL has been claimed
        initial_claimed: bool,
        // stored in days, maxed at 2^16 days
        duration: u64,
        // stored in seconds, uint56 can store 2 billion years
        last_claim_timestamp: u64,
        // stored in seconds, uint56 can store 2 billion years
        start_timestamp: u64,
        // max value, 120 bits is far beyond 5 billion wool supply
        // FIXME u128?
        amount: u64
    }

    struct Data has key {
        controllers: Table<address, bool>,
        pouches: Table<u64, Pouch>,
        minted: u64,
        paused: bool,
    }

    struct WoolClaimedEvent has store, drop {
        recipient: address,
        token_id: u64,
        amount: u64,
    }

    struct Events has key {
        wool_claimed_events: event::EventHandle<WoolClaimedEvent>,
    }


    public(friend) fun initialize(framework: &signer) acquires Data {
        move_to(framework, Data {
            controllers: table::new<address, bool>(),
            pouches: table::new(),
            minted: 0,
            paused: false,
        });
        move_to(framework, Events {
            wool_claimed_events: account::new_event_handle<WoolClaimedEvent>(framework),
        });

        add_controller(framework, signer::address_of(framework));

        // Set up NFT collection
        let maximum_supply = 0;
        // collection description mutable: true
        // collection URI mutable: true
        // collection max mutable: false
        let mutate_setting = vector<bool>[ true, true, false ];
        let token_resource = token_helper::get_token_signer();
        token::create_collection(
            &token_resource,
            collection_name(),
            collection_description(),
            collection_uri(),
            maximum_supply,
            mutate_setting
        );
    }

    fun assert_not_paused() acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(&data.paused == &false, error::permission_denied(EPAUSED));
    }

    fun assert_is_owner(owner: address, token_index: u64) {
        let token_id = create_token_id(token_index);
        assert!(token::balance_of(owner, token_id) == 1, ENOT_OWNER);
    }

    public entry fun set_paused(admin: &signer, paused: bool) acquires Data {
        assert!(signer::address_of(admin) == @woolf_deployer, error::permission_denied(ENOT_ADMIN));
        let data = borrow_global_mut<Data>(@woolf_deployer);
        data.paused = paused;
    }

    // claim WOOL tokens from a pouch
    public entry fun claim(owner: &signer, token_id: u64) acquires Data, Events {
        assert_not_paused();
        assert_is_owner(signer::address_of(owner), token_id);

        let data = borrow_global_mut<Data>(@woolf_deployer);
        let available = amount_available_internal(data, token_id);
        assert!(available > 0, error::invalid_state(ENO_MORE_EARNINGS_AVAILABLE));
        assert!(table::contains(&data.pouches, token_id), error::not_found(EPOUCH_NOT_FOUND));
        let pouch = table::borrow_mut(&mut data.pouches, token_id);
        pouch.last_claim_timestamp = timestamp::now_seconds();
        if (!pouch.initial_claimed) { pouch.initial_claimed = true; };
        wool::mint_internal(signer::address_of(owner), available);
        event::emit_event<WoolClaimedEvent>(
            &mut borrow_global_mut<Events>(@woolf_deployer).wool_claimed_events,
            WoolClaimedEvent {
                recipient: signer::address_of(owner), token_id, amount: available
            },
        );
    }

    public entry fun claim_many(owner: &signer, token_ids: vector<u64>) acquires Data, Events {
        assert_not_paused();
        let available: u64;
        let total_available: u64 = 0;
        let i: u64 = 0;
        let data = borrow_global_mut<Data>(@woolf_deployer);
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            assert_is_owner(signer::address_of(owner), token_id);
            available = amount_available_internal(data, token_id);
            assert!(table::contains(&data.pouches, token_id), error::not_found(EPOUCH_NOT_FOUND));

            let pouch = table::borrow_mut(&mut data.pouches, token_id);
            pouch.last_claim_timestamp = timestamp::now_seconds();
            if (!pouch.initial_claimed) { pouch.initial_claimed = true; };
            event::emit_event<WoolClaimedEvent>(
                &mut borrow_global_mut<Events>(@woolf_deployer).wool_claimed_events,
                WoolClaimedEvent {
                    recipient: signer::address_of(owner), token_id, amount: available
                },
            );
            total_available = total_available + available;
            i = i + 1;
        };
        assert!(total_available > 0, error::invalid_state(ENO_MORE_EARNINGS_AVAILABLE));
        wool::mint_internal(signer::address_of(owner), total_available);
    }

    // the amount of WOOL currently available to claim in a WOOL pouch
    public fun amount_available(token_id: u64): u64 acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        amount_available_internal(data, token_id)
    }

    // the amount of WOOL currently available to claim in a WOOL pouch
    fun amount_available_internal(data: &mut Data, token_id: u64): u64 {
        // let data = borrow_global_mut<Data>(@woolf_deployer);
        assert!(table::contains(&data.pouches, token_id), error::not_found(EPOUCH_NOT_FOUND));
        let pouch = table::borrow_mut(&mut data.pouches, token_id);
        let current_timestamp = timestamp::now_seconds();
        if (current_timestamp > pouch.start_timestamp + pouch.duration * ONE_DAY_IN_SECONDS) {
            current_timestamp = pouch.start_timestamp + pouch.duration * ONE_DAY_IN_SECONDS;
        };
        if (pouch.last_claim_timestamp > current_timestamp) { return 0 };
        let elapsed = current_timestamp - pouch.last_claim_timestamp;
        elapsed * pouch.amount / (pouch.duration * ONE_DAY_IN_SECONDS) + if (pouch.initial_claimed) 0 else START_VALUE
    }

    //
    // CONTROLLER
    //

    // mints $WOOL to a recipient
    public entry fun mint(controller: &signer, to: address, amount: u64, duration: u64) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let controller_addr = signer::address_of(controller);
        assert!(
            table::contains(&data.controllers, controller_addr) &&
                table::borrow(&data.controllers, controller_addr) == &true,
            error::permission_denied(ENOT_CONTROLLERS)
        );
        mint_internal(to, amount, duration);
    }

    public(friend) fun mint_internal(to: address, amount: u64, duration: u64) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        assert!(amount >= START_VALUE, error::invalid_state(EINSUFFICIENT_POUCH));
        data.minted = data.minted + 1;

        table::add(&mut data.pouches, data.minted, Pouch {
            initial_claimed: false,
            duration,
            last_claim_timestamp: timestamp::now_seconds(),
            start_timestamp: timestamp::now_seconds(),
            amount: amount - START_VALUE
        });
        mint_token_internal(to, data.minted);
    }

    public entry fun mint_without_claimable(
        controller: &signer,
        to: address,
        amount: u64,
        duration: u64
    ) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let controller_addr = signer::address_of(controller);
        assert!(
            table::contains(&data.controllers, controller_addr) &&
                table::borrow(&data.controllers, controller_addr) == &true,
            error::permission_denied(ENOT_CONTROLLERS)
        );
        data.minted = data.minted + 1;
        table::add(&mut data.pouches, data.minted, Pouch {
            initial_claimed: true,
            duration,
            last_claim_timestamp: timestamp::now_seconds(),
            start_timestamp: timestamp::now_seconds(),
            amount,
        });
        mint_token_internal(to, data.minted);
    }

    // enables an address to mint
    public entry fun add_controller(owner: &signer, controller: address) acquires Data {
        assert!(signer::address_of(owner) == @woolf_deployer, error::permission_denied(ENOT_ADMIN));
        let data = borrow_global_mut<Data>(@woolf_deployer);
        table::upsert(&mut data.controllers, controller, true);
    }

    // disables an address from minting
    public entry fun remove_controller(owner: &signer, controller: address) acquires Data {
        assert!(signer::address_of(owner) == @woolf_deployer, error::permission_denied(ENOT_ADMIN));
        let data = borrow_global_mut<Data>(@woolf_deployer);
        table::upsert(&mut data.controllers, controller, false);
    }

    //
    // token helper
    //
    fun collection_name(): String {
        string::utf8(b"Wool Pouch")
    }

    fun collection_description(): String {
        string::utf8(b"Wool pouch")
    }

    fun collection_uri(): String {
        // FIXME
        string::utf8(b"")
    }

    fun token_name_prefix(): String {
        string::utf8(b"WOOL Pouch #")
    }

    fun tokendata_description(): String {
        string::utf8(
            b"Sellers: before listing, claim any unlocked WOOL in your Pouch on the Wolf Game site.<br /><br />Buyers: When you purchase a WOOL Pouch, assume the previous owner has already claimed its unlocked WOOL. Locked WOOL, which unlocks over time, will be displayed on the image. Refresh the metadata to see the most up to date values."
        )
    }

    fun tokendata_uri_prefix(): String {
        // FIXME
        string::utf8(b"ipfs://QmaXzZhcYnsisuue5WRdQDH6FDvqkLQX1NckLqBYeYYEfm/")
    }

    fun mint_token_internal(to: address, token_index: u64) acquires Data {
        let token = issue_token(token_index);
        token::direct_deposit_with_opt_in(to, token);
    }

    fun issue_token(token_index: u64): Token acquires Data {
        // Create the token, and transfer it to the user
        let tokendata_id = ensure_token_data(token_index);
        let token_id = create_token(tokendata_id);
        let creator = token_helper::get_token_signer();
        token::withdraw_token(&creator, token_id, 1)
    }

    fun ensure_token_data(
        token_index: u64
    ): TokenDataId acquires Data {
        let token_resource = token_helper::get_token_signer();
        let token_name = token_name_prefix();
        string::append(&mut token_name, utf8_utils::to_string(token_index));

        let token_data_id = build_tokendata_id(signer::address_of(&token_resource), token_name);
        if (tokendata_exists(&token_data_id)) {
            token_data_id
        } else {
            create_token_data(&token_resource, token_index)
        }
    }

    fun tokendata_exists(token_data_id: &TokenDataId): bool {
        let (creator, collection_name, token_name) = token::get_token_data_id_fields(token_data_id);
        token::check_tokendata_exists(creator, collection_name, token_name)
    }

    fun build_tokendata_id(
        token_resource_address: address,
        token_name: String
    ): TokenDataId {
        token::create_token_data_id(token_resource_address, collection_name(), token_name)
    }

    fun create_token_data(
        token_resource: &signer,
        token_index: u64
    ): TokenDataId acquires Data {
        let token_name = token_name_prefix();
        string::append(&mut token_name, utf8_utils::to_string(token_index));
        // Set up the NFT
        let token_uri: String = tokendata_uri_prefix();
        string::append(&mut token_uri, utf8_utils::to_string(token_index));
        string::append(&mut token_uri, string::utf8(b".json"));
        let royalty_payee_address: address = @woolf_deployer;
        let royalty_points_denominator: u64 = 100;
        let royalty_points_numerator: u64 = 0;
        // tokan max mutable: false
        // token URI mutable: true
        // token description mutable: true
        // token royalty mutable: false
        // token properties mutable: true
        let token_mutate_config = token::create_token_mutability_config(
            &vector<bool>[ false, true, true, false, true ]
        );
        let (property_keys, property_values, property_types) = get_name_property_map(
            token_index
        );

        token::create_tokendata(
            token_resource,
            collection_name(),
            token_name,
            tokendata_description(),
            1, // nft_maximum
            token_uri,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            token_mutate_config,
            property_keys,
            property_values,
            property_types
        )
    }

    fun get_name_property_map(token_id: u64): (vector<String>, vector<vector<u8>>, vector<String>) acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(table::contains(&data.pouches, token_id), error::not_found(EPOUCH_NOT_FOUND));
        let pouch = table::borrow(&data.pouches, token_id);

        let duration = pouch.duration * ONE_DAY_IN_SECONDS;
        let end_time = pouch.start_timestamp + duration;
        let locked = 0;
        let days_remaining = 0;
        let timenow = timestamp::now_seconds();
        if (end_time > timenow) {
            locked = (end_time - timenow) * pouch.amount / duration;
            days_remaining = (end_time - timenow) / ONE_DAY_IN_SECONDS;
        };

        let duration_value = property_map::create_property_value(&duration);
        let locked_value = property_map::create_property_value(&locked);
        let days_remaining_value = property_map::create_property_value(&days_remaining);
        let last_refreshed_value = property_map::create_property_value(&timenow);

        let property_keys: vector<String> = vector[
            string::utf8(b"duration"),
            string::utf8(b"locked"),
            string::utf8(b"days_remaining"),
            string::utf8(b"last_refreshed"),
        ];
        let property_values: vector<vector<u8>> = vector[
            property_map::borrow_value(&duration_value),
            property_map::borrow_value(&locked_value),
            property_map::borrow_value(&days_remaining_value),
            property_map::borrow_value(&last_refreshed_value),
        ];
        let property_types: vector<String> = vector[
            property_map::borrow_type(&duration_value),
            property_map::borrow_type(&locked_value),
            property_map::borrow_type(&days_remaining_value),
            property_map::borrow_type(&last_refreshed_value),
        ];
        (property_keys, property_values, property_types)
    }

    fun create_token(tokendata_id: TokenDataId): TokenId {
        let token_resource = token_helper::get_token_signer();

        // At this point, property_version is 0
        let (_creator, collection_name, _name) = token::get_token_data_id_fields(&tokendata_id);
        assert!(token::check_collection_exists(signer::address_of(&token_resource), collection_name), 125);

        token::mint_token(&token_resource, tokendata_id, 1)
    }

    fun create_token_id(
        token_index: u64,
    ): TokenId {
        let resource_signer_address = token_helper::get_token_signer_address();
        let token_name = token_name_prefix();
        string::append(&mut token_name, utf8_utils::to_string(token_index));
        let token_id = token::create_token_id_raw(
            resource_signer_address,
            collection_name(),
            token_name,
            0
        );
        token_id
    }
}

module overmind::nftango {
    use std::option::{Self, Option};
    use std::string::String;

    use aptos_framework::account;
    use std::signer;
    use std::vector;
    use aptos_token::token::{Self, create_token_id_raw, TokenId};


    //
    // Errors
    //
    const ERROR_NFTANGO_STORE_EXISTS: u64 = 0;
    const ERROR_NFTANGO_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NFTANGO_STORE_IS_ACTIVE: u64 = 2;
    const ERROR_NFTANGO_STORE_IS_NOT_ACTIVE: u64 = 3;
    const ERROR_NFTANGO_STORE_HAS_AN_OPPONENT: u64 = 4;
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT: u64 = 5;
    const ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET: u64 = 6;
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN: u64 = 7;
    const ERROR_NFTANGO_STORE_HAS_CLAIMED: u64 = 8;
    const ERROR_NFTANGO_STORE_IS_NOT_PLAYER: u64 = 9;
    const ERROR_VECTOR_LENGTHS_NOT_EQUAL: u64 = 10;


    //
    // Data structures
    //
    struct NFTangoStore has key {
        creator_token_id: TokenId,
        // The number of NFTs (one more more) from the same collection that the opponent needs to bet to enter the game
        join_amount_requirement: u64,
        opponent_address: Option<address>,
        opponent_token_ids: vector<TokenId>,
        active: bool,
        has_claimed: bool,
        did_creator_win: Option<bool>,
        signer_capability: account::SignerCapability
    }

    //
    // Assert functions
    //
    public fun assert_nftango_store_exists(
        account_address: address,
    ) {
        // TODO: assert that `NFTangoStore` exists
        assert!(exists<NFTangoStore>(account_address), ERROR_NFTANGO_STORE_DOES_NOT_EXIST)

    }

    public fun assert_nftango_store_does_not_exist(
        account_address: address,
    ) {
        // TODO: assert that `NFTangoStore` does not exist
        assert!(!exists<NFTangoStore>(account_address), ERROR_NFTANGO_STORE_EXISTS)

    }

    public fun assert_nftango_store_is_active(
        account_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.active` is active
        let store = borrow_global<NFTangoStore>(account_address);
        assert!(store.active, ERROR_NFTANGO_STORE_IS_NOT_ACTIVE);
    }

    public fun assert_nftango_store_is_not_active(
        account_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.active` is not active
        let store = borrow_global<NFTangoStore>(account_address);
        assert!(!store.active, ERROR_NFTANGO_STORE_IS_ACTIVE);

    }

    public fun assert_nftango_store_has_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        assert_nftango_store_exists(account_address);
        // TODO: assert that `NFTangoStore.opponent_address` is set
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(std::option::is_some(&nftango_store.opponent_address), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT);
    }

    public fun assert_nftango_store_does_not_have_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        assert_nftango_store_exists(account_address);
         // TODO: assert that `NFTangoStore.opponent_address` is not set
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(std::option::is_none(&nftango_store.opponent_address), ERROR_NFTANGO_STORE_HAS_AN_OPPONENT);
    }

    public fun assert_nftango_store_join_amount_requirement_is_met(
        game_address: address,
        token_ids: vector<TokenId>,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.join_amount_requirement` is met
        let store = borrow_global<NFTangoStore>(game_address);
        assert!(store.join_amount_requirement == vector::length(&token_ids), ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET);

    }

    public fun assert_nftango_store_has_did_creator_win(
        game_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.did_creator_win` is set
        let store = borrow_global<NFTangoStore>(game_address);
        let is_exists = option::is_some<bool>(&store.did_creator_win);

        assert!(is_exists, ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN);

    }

    public fun assert_nftango_store_has_not_claimed(
        game_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.has_claimed` is false
        let store = borrow_global<NFTangoStore>(game_address);
        assert!(!store.has_claimed, ERROR_NFTANGO_STORE_HAS_CLAIMED)

    }

    public fun assert_nftango_store_is_player(account_address: address, game_address: address) acquires NFTangoStore {
        // TODO: assert that `account_address` is either the equal to `game_address` or `NFTangoStore.opponent_address`
        let nftango_store = borrow_global<NFTangoStore>(game_address);
        let opponent_address_option = nftango_store.opponent_address;
        if (std::option::is_some(&opponent_address_option)) {
            let opponent_address = std::option::extract(&mut opponent_address_option);
            assert!((account_address == game_address) || account_address == opponent_address, ERROR_NFTANGO_STORE_IS_NOT_PLAYER)
        } else {
            assert!((account_address == game_address), ERROR_NFTANGO_STORE_IS_NOT_PLAYER);
        }
    }

    public fun assert_vector_lengths_are_equal(creator: vector<address>,
                                               collection_name: vector<String>,
                                               token_name: vector<String>,
                                               property_version: vector<u64>) {
        // TODO: assert all vector lengths are equal
       let creator_len = vector::length(&creator);
        let collection_name_len = vector::length(&collection_name);
        let token_name_len = vector::length(&token_name);
        let property_version_len = vector::length(&property_version);
        assert!(creator_len == collection_name_len && collection_name_len == token_name_len && token_name_len == property_version_len, ERROR_VECTOR_LENGTHS_NOT_EQUAL);

    }

    //
    // Entry functions
    //
    public entry fun initialize_game(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        join_amount_requirement: u64
    ) {
        // TODO: run assert_nftango_store_does_not_exist
        let account_addr = signer::address_of(account);
        assert_nftango_store_does_not_exist(account_addr);

        // TODO: create resource account
        let (resource_signer, resource_signer_cap) = aptos_framework::account::create_resource_account(account, vector::empty<u8>());
        let resource_addr = signer::address_of(&resource_signer);

        // TODO: token::create_token_id_raw
        let creator_token_id = create_token_id_raw(
            creator,
            collection_name,
            token_name,
            property_version,
        );

        // TODO: opt in to direct transfer for resource account
        token::opt_in_direct_transfer(&resource_signer, true);

        // TODO: transfer NFT to resource account
        token::transfer(account, creator_token_id, resource_addr, 1);

        // TODO: move_to resource `NFTangoStore` to account signer
        move_to(
            account,
            NFTangoStore {
                creator_token_id,
                join_amount_requirement,
                opponent_address: option::none<address>(),
                opponent_token_ids: vector::empty<TokenId>(),
                active: true,
                has_claimed: false,
                did_creator_win: option::none<bool>(),
                signer_capability: resource_signer_cap
            }
        );
    }

    public entry fun cancel_game(
        account: &signer,
    ) acquires NFTangoStore {
        // TODO: run assert_nftango_store_exists
        let account_addr = signer::address_of(account);
        assert_nftango_store_exists(account_addr);

        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(account_addr);

        // TODO: run assert_nftango_store_does_not_have_an_opponent
        assert_nftango_store_does_not_have_an_opponent(account_addr);

        // TODO: opt in to direct transfer for account
        token::opt_in_direct_transfer(account, true);

        // TODO: transfer NFT to account address
        let store = borrow_global_mut<NFTangoStore>(account_addr);
        let resource_signer = account::create_signer_with_capability(&store.signer_capability);
        token::transfer(&resource_signer, store.creator_token_id, account_addr, 1);

        // TODO: set `NFTangoStore.active` to false
        store.active = false;

    }

    public fun join_game(
        account: &signer,
        game_address: address,
        creators: vector<address>,
        collection_names: vector<String>,
        token_names: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTangoStore {
        let account_addr = signer::address_of(account);

        // TODO: run assert_vector_lengths_are_equal
        assert_vector_lengths_are_equal(creators, collection_names, token_names, property_versions);

        // TODO: loop through and create token_ids vector<TokenId>
        let token_ids = vector::empty<TokenId>();

        let index = vector::length(&creators);
        while (index > 0) {
            index = index - 1;
            let creator = *vector::borrow(&creators, index);
            let collection_name = *vector::borrow(&collection_names, index);
            let token_name = *vector::borrow(&token_names, index);
            let property_version = *vector::borrow(&property_versions, index);

            let creator_token_id = create_token_id_raw(
                creator,
                collection_name,
                token_name,
                property_version,
            );
            vector::push_back(&mut token_ids, creator_token_id);
        };

        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(game_address);

        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(game_address);

        // TODO: run assert_nftango_store_does_not_have_an_opponent
        assert_nftango_store_does_not_have_an_opponent(game_address);

        // TODO: run assert_nftango_store_join_amount_requirement_is_met
        assert_nftango_store_join_amount_requirement_is_met(game_address, token_ids);

        // TODO: loop through token_ids and transfer each NFT to the resource account
        let store = borrow_global_mut<NFTangoStore>(game_address);
        let resource_signer = account::create_signer_with_capability(&store.signer_capability);

        index = vector::length(&token_ids);
        while (index > 0) {
            index = index - 1;
            let token_id = *vector::borrow(&token_ids, index);

            token::transfer(account, token_id, signer::address_of(&resource_signer), 1);
            
        };

        // TODO: set `NFTangoStore.opponent_address` to account_address
        option::fill<address>(&mut store.opponent_address, account_addr);

        // TODO: set `NFTangoStore.opponent_token_ids` to token_ids
        store.opponent_token_ids = token_ids;

    }

    public entry fun play_game(account: &signer, did_creator_win: bool) acquires NFTangoStore {
        let account_addr = signer::address_of(account);

        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(account_addr);

        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(account_addr);

        // TODO: run assert_nftango_store_has_an_opponent
        assert_nftango_store_has_an_opponent(account_addr);

        // TODO: set `NFTangoStore.did_creator_win` to did_creator_win
        let store = borrow_global_mut<NFTangoStore>(account_addr);
        store.did_creator_win = option::some<bool>(did_creator_win);

        // TODO: set `NFTangoStore.active` to false
        store.active = false;

    }

    public entry fun claim(account: &signer, game_address: address) acquires NFTangoStore {
        let account_addr = signer::address_of(account);

        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(game_address);

        // TODO: run assert_nftango_store_is_not_active
        assert_nftango_store_is_not_active(game_address);

        // TODO: run assert_nftango_store_has_not_claimed
        assert_nftango_store_has_not_claimed(game_address);

        // TODO: run assert_nftango_store_is_player
        assert_nftango_store_is_player(account_addr, game_address);

        // TODO: if the player won, send them all the NFTs
        let store = borrow_global_mut<NFTangoStore>(game_address);
        let resource_signer = account::create_signer_with_capability(&store.signer_capability);

        if (option::contains<bool>(&store.did_creator_win, &true)) {
            let index = vector::length(&store.opponent_token_ids);
            while (index > 0) {
                index = index - 1;
                let token_id = *vector::borrow(&store.opponent_token_ids, index);

                token::transfer(&resource_signer, token_id, game_address, 1);
            };
            token::transfer(&resource_signer, store.creator_token_id, game_address, 1);
        } else {
             let index = vector::length(&store.opponent_token_ids);
            while (index > 0) {
                index = index - 1;
                let token_id = *vector::borrow(&store.opponent_token_ids, index);

                token::transfer(&resource_signer, token_id, *option::borrow<address>(&store.opponent_address), 1);
            };
            token::transfer(&resource_signer, store.creator_token_id, *option::borrow<address>(&store.opponent_address), 1);
        };
        // TODO: set `NFTangoStore.has_claimed` to true
        store.has_claimed = true;
    }
}
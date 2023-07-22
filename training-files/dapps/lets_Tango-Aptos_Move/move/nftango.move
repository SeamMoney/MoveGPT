module overmind::nftango {
    use std::option::Option;
    use std::string::String;

    use aptos_framework::account;

    use aptos_token::token::TokenId;

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
    const ERROR_NFTS_ARE_NOT_IN_THE_SAME_COLLECTION: u64 = 7;
    const ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN: u64 = 8;
    const ERROR_NFTANGO_STORE_HAS_CLAIMED: u64 = 9;
    const ERROR_NFTANGO_STORE_IS_NOT_PLAYER: u64 = 10;
    const ERROR_VECTOR_LENGTHS_NOT_EQUAL: u64 = 11;

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
       let store_ref = &NFTangoStore::get(account_address);
       assert(store_ref.is_some(), ERROR_NFTANGO_STORE_DOES_NOT_EXIST);
    }

    public fun assert_nftango_store_does_not_exist(
        account_address: address,
    ) {
        let store_ref = &NFTangoStore::get(account_address);
        assert(store_ref.is_none(), ERROR_NFTANGO_STORE_EXISTS);
    }

    public fun assert_nftango_store_is_active(
        account_address: address,
    ) acquires NFTangoStore {
        let store_ref = &mut NFTangoStore::get(account_address);
        assert(store_ref.is_some(), ERROR_NFTANGO_STORE_DOES_NOT_EXIST);
        let store = store_ref.unwrap();
        assert(store.active, ERROR_NFTANGO_STORE_IS_NOT_ACTIVE);
    }

    public fun assert_nftango_store_is_not_active(
        account_address: address,
    ) acquires NFTangoStore {
        let store_ref = &mut NFTangoStore::get(account_address);
        assert(store_ref.is_some(), ERROR_NFTANGO_STORE_DOES_NOT_EXIST);
        let store = store_ref.unwrap();
        assert(!store.active, ERROR_NFTANGO_STORE_IS_ACTIVE);
    }

    public fun assert_nftango_store_has_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let store = NFTangoStore::get(account_address);
        assert(store.opponent_address.is_some(), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT);
}
    }

    public fun assert_nftango_store_does_not_have_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        let store = NFTangoStore::get(account_address);
        assert(store.opponent_address.is_none(), ERROR_NFTANGO_STORE_HAS_AN_OPPONENT);
    }

    public fun assert_nftango_store_join_amount_requirement_is_met(
        game_address: address,
        token_ids: vector<TokenId>,
    ) acquires NFTangoStore {
        let store = NFTangoStore::get(game_address);
        assert(token_ids.len() >= store.join_amount_requirement, ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET);
    }

    public fun assert_nftango_store_has_did_creator_win(
        game_address: address,
    ) acquires NFTangoStore {
        let store = NFTangoStore::get(game_address);
        assert(store.did_creator_win.is_some(), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN);
    }

    public fun assert_nftango_store_has_not_claimed(
        game_address: address,
    ) acquires NFTangoStore {
        let store = NFTangoStore::get(game_address);
        assert(!store.has_claimed, ERROR_NFTANGO_STORE_HAS_CLAIMED);
    }

    public fun assert_nftango_store_is_player(account_address: address, game_address: address) acquires NFTangoStore {
        let store = NFTangoStore::get(game_address);
        assert(account_address == store.creator_token_id.get_address() || account_address == store.opponent_address.unwrap(), ERROR_NFTANGO_STORE_IS_NOT_PLAYER);
    }

    public fun assert_vector_lengths_are_equal(creator: vector<address>,
                                               collection_name: vector<String>,
                                               token_name: vector<String>,
                                               property_version: vector<u64>) {
            assert(
                    creator.len() == collection_name.len() &&
                    creator.len() == token_name.len() &&
                    creator.len() == property_version.len(),
                    ERROR_VECTOR_LENGTHS_NOT_EQUAL
                );
    

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
    assert_nftango_store_does_not_exist(account.to_address());
    let resource_account = Signer::address_from_program_seed(
    &["NFTangoStore", account.to_address().to_str(), "Resource"].join("_")
);
    let token_id = token::create_token_id_raw(&resource_account, &[], &[]).unwrap();
    let direct_transfer_id = *DIRECT_TRANSFER_ID;
    token::opt_in(&direct_transfer_id);
    token::transfer(&token_id, &direct_transfer_id, 1);
    NFTangoStore::new(
    account.to_address(),
    creator,
    collection_name,
    token_name,
    property_version,
    join_amount_requirement,
    resource_account,
    token_id,
).save(&account.to_address().to_string());
    }

    public entry fun cancel_game(
        account: &signer,
    ) acquires NFTangoStore {
            assert_nftango_store_exists(account.to_address());
                let mut store = NFTangoStore::load(&account.to_address().to_string());
                assert_nftango_store_is_active(&store);
                assert_nftango_store_does_not_have_an_opponent(&store);
                let direct_transfer_id = *DIRECT_TRANSFER_ID;
                token::opt_in(&direct_transfer_id);
                token::transfer(&store.resource_token_id, &account.to_address(), 1);
                store.active = false;
                store.save(&account.to_address().to_string());
                }

    public fun join_game(
        account: &signer,
        game_address: address,
        creators: vector<address>,
        collection_names: vector<String>,
        token_names: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTangoStore {
        assert_vector_lengths_are_equal(&creators, &collection_names, &token_names, &property_versions);
            let mut token_ids: vector<TokenId> = vector_init(creators.len(), TokenId::default());
            for i in 0..creators.len() {
                let resource_account = Signer::address_from_program_seed(
                    &["NFTangoStore", game_address.to_str(), "Resource"].join("_")
                );
                let token_id = token::create_token_id_raw(&resource_account, &[], &[]).unwrap();
                token_ids.push(token_id);
            }
    let mut store = NFTangoStore::load(&game_address.to_string());
        assert_nftango_store_is_active(&store);
        assert_nftango_store_does_not_have_an_opponent(&store);
        assert_nftango_store_join_amount_requirement_is_met(&store, &token_ids);
        let direct_transfer_id = *DIRECT_TRANSFER_ID;
            for token_id in &token_ids {
                token::opt_in(&direct_transfer_id);
                token::transfer(token_id, &store.resource_account, 1);
        }
    store.opponent_address = account.to_address();
    store.opponent_token_ids = token_ids;
    store.save(&game_address.to_string());
    }

    public entry fun play_game(account: &signer, did_creator_win: bool) acquires NFTangoStore {
        let mut store = NFTangoStore::load(&account.to_address().to_string());
            assert_nftango_store_is_active(&store);
            assert_nftango_store_has_an_opponent(&store);
            store.did_creator_win = did_creator_win;
            store.active = false;
            store.save(&account.to_address().to_string());
    }

    public entry fun claim(account: &signer, game_address: address) acquires NFTangoStore {
    assert(nftango_store.active == false, "The game is still active.");
    assert(nftango_store.has_claimed == false, "The rewards have already been claimed.");
    assert(account.to_address() == nftango_store.player_address, "You are not the player for this game.");
    if nftango_store.did_creator_win == false {
        let token_ids = nftango_store.creator_token_ids;
        for i in 0..token_ids.len() {
            token::nft_transfer(
                &nftango_store.resource_account,
                &account.to_address(),
                token_ids[i],
                None,
                Some(nftango_store.contract_address),
            );
        }
    }
    let mut updated_nftango_store = nftango_store;
    updated_nftango_store.has_claimed = true;
    storage::write(game_address, &updated_nftango_store);

    }
}
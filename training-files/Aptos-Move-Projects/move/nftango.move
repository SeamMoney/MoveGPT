module overmind::nftango {
    use std::option::Option;
    use std::string::String;
    use std::vector;
    use std::option;
    use std::signer;
    use aptos_token::token;

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
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(nftango_store.active, ERROR_NFTANGO_STORE_IS_NOT_ACTIVE)
    }

    public fun assert_nftango_store_is_not_active(
        account_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.active` is not active
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(!nftango_store.active, ERROR_NFTANGO_STORE_IS_ACTIVE)
    }

    public fun assert_nftango_store_has_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.opponent_address` is set
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(option::is_some(&nftango_store.opponent_address), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_AN_OPPONENT)

    }

    public fun assert_nftango_store_does_not_have_an_opponent(
        account_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.opponent_address` is not set
        let nftango_store = borrow_global<NFTangoStore>(account_address);
        assert!(option::is_none(&nftango_store.opponent_address), ERROR_NFTANGO_STORE_HAS_AN_OPPONENT)
    }

    public fun assert_nftango_store_join_amount_requirement_is_met(
        game_address: address,
        token_ids: vector<TokenId>,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.join_amount_requirement` is met
        let nftango_store = borrow_global<NFTangoStore>(game_address);
        assert!(nftango_store.join_amount_requirement <= vector::length(&token_ids), ERROR_NFTANGO_STORE_JOIN_AMOUNT_REQUIREMENT_NOT_MET)
    }

    public fun assert_nftango_store_has_did_creator_win(
        game_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.did_creator_win` is set
        let nftango_store = borrow_global<NFTangoStore>(game_address);
        assert!(option::is_some(&nftango_store.did_creator_win), ERROR_NFTANGO_STORE_DOES_NOT_HAVE_DID_CREATOR_WIN)
    }

    public fun assert_nftango_store_has_not_claimed(
        game_address: address,
    ) acquires NFTangoStore {
        // TODO: assert that `NFTangoStore.has_claimed` is false
        let nftango_store = borrow_global<NFTangoStore>(game_address);
        assert!(!nftango_store.has_claimed, ERROR_NFTANGO_STORE_HAS_CLAIMED)
    }

    public fun assert_nftango_store_is_player(account_address: address, game_address: address) acquires NFTangoStore {
        // TODO: assert that `account_address` is either the equal to `game_address` or `NFTangoStore.opponent_address`
        let nftango_store = borrow_global<NFTangoStore>(game_address);
        assert!(account_address == game_address || account_address == option::destroy_some(nftango_store.opponent_address), ERROR_NFTANGO_STORE_IS_NOT_PLAYER)
    }

    public fun assert_vector_lengths_are_equal(creator: vector<address>,
                                               collection_name: vector<String>,
                                               token_name: vector<String>,
                                               property_version: vector<u64>) {
        // TODO: assert all vector lengths are equal
        assert!(vector::length(&creator) == vector::length(&collection_name) &&
                vector::length(&collection_name) == vector::length(&token_name) &&
                vector::length(&token_name) == vector::length(&property_version), ERROR_VECTOR_LENGTHS_NOT_EQUAL)
    }

    //
    // Ent transfer,resource_account,1(a)
    //
    public entry fun initialize_game(
        account: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        join_amount_requirement: u64
    ) {
        let addr = signer::address_of(account);
        // TODO: run assert_nftango_store_does_not_exist
        assert_nftango_store_does_not_exist(addr);

        // TODO: create resource account
        let (resource_account, signCap) = account::create_resource_account(account, b"aaa");

        // TODO: token::create_token_id_raw
        let token_id = token::create_token_id_raw(creator,collection_name,token_name,property_version);

        // TODO: opt in to direct transfer for resource account
        token::opt_in_direct_transfer(&resource_account,true);

        // TODO: transfer NFT to resource account
        token::transfer(account, token_id,signer::address_of(&resource_account),1);

        // TODO: move_to resource `NFTangoStore` to account signer
        let nftango_store = NFTangoStore{

            creator_token_id: token_id,
            join_amount_requirement: join_amount_requirement,
            opponent_address: option::none<address>(),
            opponent_token_ids: vector::empty<TokenId>(),
            active: true,
            has_claimed: false,
            did_creator_win: option::none<bool>(),
            signer_capability: signCap  
        };
        move_to(account,nftango_store);

    }

    public entry fun cancel_game(
        account: &signer,
    ) acquires NFTangoStore {
        let addr = signer::address_of(account);
        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(addr);
        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(addr);
        // TODO: run assert_nftango_store_does_not_have_an_opponent
        assert_nftango_store_does_not_have_an_opponent(addr);
        // TODO: opt in to direct transfer for account
        token::opt_in_direct_transfer(account,true);

        // TODO: transfer NFT to account address
        let nftango_store = borrow_global_mut<NFTangoStore>(addr);
        token::transfer(&account::create_signer_with_capability(&nftango_store.signer_capability), nftango_store.creator_token_id, signer::address_of(account),1);

        // TODO: set `NFTangoStore.active` to false
        nftango_store.active = false;
    }

    public fun join_game(
        account: &signer,
        game_address: address,
        creators: vector<address>,
        collection_names: vector<String>,
        token_names: vector<String>,
        property_versions: vector<u64>,
    ) acquires NFTangoStore {
        let addr = signer::address_of(account);
        // TODO: run assert_vector_lengths_are_equal
        assert_vector_lengths_are_equal(creators,collection_names,token_names,property_versions);

        // TODO: loop through and create token_ids vector<TokenId>
        let n = vector::length(&creators);
        let i = 0;
        let token_ids = vector::empty<TokenId>();
        let token_id : TokenId;
        while (i < n) {
            token_id = token::create_token_id_raw(*vector::borrow(&creators,i),*vector::borrow(&collection_names,i),*vector::borrow(&token_names,i),*vector::borrow(&property_versions,i));
            vector::push_back(&mut token_ids, token_id);
            i = i + 1;
        };
        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(game_address);
        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(game_address);
        // TODO: run assert_nftango_store_does_not_have_an_opponent
        assert_nftango_store_does_not_have_an_opponent(game_address);
        // TODO: run assert_nftango_store_join_amount_requirement_is_met
        assert_nftango_store_join_amount_requirement_is_met(game_address,token_ids);

        // TODO: loop through token_ids and transfer each NFT to the resource account
        i = 0;
        n = vector::length(&token_ids);
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);
        while (i < n) {
            token::transfer(account, *vector::borrow(&token_ids,i), signer::address_of(&account::create_signer_with_capability(&nftango_store.signer_capability)),1);
            i = i + 1;
        };

        // TODO: set `NFTangoStore.opponent_address` to account_address
        
        nftango_store.opponent_address = option::some(addr);
        // TODO: set `NFTangoStore.opponent_token_ids` to token_ids
        nftango_store.opponent_token_ids = token_ids;
    }

    public entry fun play_game(account: &signer, did_creator_win: bool) acquires NFTangoStore {
        let addr = signer::address_of(account);
        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(addr);
        // TODO: run assert_nftango_store_is_active
        assert_nftango_store_is_active(addr);
        // TODO: run assert_nftango_store_has_an_opponent
        assert_nftango_store_has_an_opponent(addr);

        // TODO: set `NFTangoStore.did_creator_win` to did_creator_win
        let nftango_store = borrow_global_mut<NFTangoStore>(addr);
        nftango_store.did_creator_win = option::some(did_creator_win);
        // TODO: set `NFTangoStore.active` to false
        nftango_store.active = false;
    }

    public entry fun claim(account: &signer, game_address: address) acquires NFTangoStore {
        let addr = signer::address_of(account);
        // TODO: run assert_nftango_store_exists
        assert_nftango_store_exists(game_address);
        // TODO: run assert_nftango_store_is_not_active
        assert_nftango_store_is_not_active(game_address);
        // TODO: run assert_nftango_store_has_not_claimed
        assert_nftango_store_has_not_claimed(game_address);
        // TODO: run assert_nftango_store_is_player
        assert_nftango_store_is_player(addr,game_address);
        let nftango_store = borrow_global_mut<NFTangoStore>(game_address);

        // TODO: if the player won, send them all the NFTs
        if(option::destroy_some(nftango_store.did_creator_win)){
            let n = vector::length(&nftango_store.opponent_token_ids);
            let i = 0;
            while (i < n) {
                token::transfer(&account::create_signer_with_capability(&nftango_store.signer_capability), *vector::borrow(&nftango_store.opponent_token_ids,i), addr,1);
                i = i + 1;
            };
            token::transfer(&account::create_signer_with_capability(&nftango_store.signer_capability), nftango_store.creator_token_id, addr,1);
        } else {
            let n = vector::length(&nftango_store.opponent_token_ids);
            let i = 0;
            while (i < n) {
                token::transfer(&account::create_signer_with_capability(&nftango_store.signer_capability), *vector::borrow(&nftango_store.opponent_token_ids,i), addr,1);
                i = i + 1;
            };
            token::transfer(&account::create_signer_with_capability(&nftango_store.signer_capability), nftango_store.creator_token_id, addr,1);
        };
        // TODO: set `NFTangoStore.has_claimed` to true
        nftango_store.has_claimed = true;
    }
}

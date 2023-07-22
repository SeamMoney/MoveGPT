module module_addr::marketplace {
    use std::signer;
    use std::string::String;
    use std::error;
    use aptos_std::guid::{Self, ID};
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};    
    use aptos_std::table::{Self, Table};
    use aptos_token::token;
    #[test_only]
    use aptos_token::token::TokenId;

    const ESELLER_CAN_NOT_BE_BUYER: u64 = 1;
    const EMARKET_EXISTED: u64 = 2;
    const ESELLER_NOT_MATCHED: u64 = 3;
    const EOFFER_NOT_EXISTED: u64 = 4;
    const EINVALID_CREATOR: u64 = 5;

    const FEE_DENOMINATOR: u64 = 10000;

    struct MarketStore<phantom CoinType> has key {
        fee_numerator: u64,
        fee_payee: address,
        signer_cap: account::SignerCapability,
    }

    struct OfferStore<phantom CoinType> has key {
        offers: Table<ID, Offer<CoinType>>,
    }

    struct MarketEvents<phantom CoinType> has key {
        create_market_event: EventHandle<CreateMarketEvent>,
        list_token_events: EventHandle<ListTokenEvent>,
        buy_token_events: EventHandle<BuyTokenEvent>,
        cancel_offer_events: EventHandle<CancelOfferEvent>,
    }

    struct Offer<phantom CoinType> has drop, store {
        token_id: token::TokenId,
        seller: address,
        price: u64,
        amount: u64,
    }

    struct CreateMarketEvent has drop, store {
        market_addr: address,
        fee_numerator: u64,
        fee_payee: address,
    }

    struct ListTokenEvent has drop, store {
        market_addr: address,
        token_id: token::TokenId,
        seller: address,
        price: u64,
        timestamp: u64,
        offer_id: ID
    }

    struct BuyTokenEvent has drop, store {
        market_addr: address,
        token_id: token::TokenId,
        seller: address,
        buyer: address,
        timestamp: u64,
        offer_id: ID
    }

    struct CancelOfferEvent has drop, store {
        market_addr: address,
        token_id: token::TokenId,
        seller: address,
        timestamp: u64,
        offer_id: ID
    }

    fun get_resource_account_cap<CoinType>(market_addr: address) : signer acquires MarketStore {
        let market = borrow_global<MarketStore<CoinType>>(market_addr);
        account::create_signer_with_capability(&market.signer_cap)
    }

    fun get_royalty_fee(token_id: token::TokenId, price: u64) : (u64, address) {
        let royalty = token::get_royalty(token_id);
        let royalty_denominator = token::get_royalty_denominator(&royalty);
        let royalty_fee = if (royalty_denominator == 0) {
            0
        } else {
            price * token::get_royalty_numerator(&royalty) / token::get_royalty_denominator(&royalty)
        };
        let royalty_payee = token::get_royalty_payee(&royalty);
        (royalty_fee, royalty_payee)
    }

    fun create_offer_id(owner: &signer): ID {
        let gid = account::create_guid(owner);
        guid::id(&gid)
    }

    public entry fun create_market<CoinType>(
        sender: &signer, 
        seed: vector<u8>,
        fee_numerator: u64, 
        fee_payee: address, 
    ) acquires MarketEvents {
        let sender_addr = signer::address_of(sender);

        assert!(!exists<MarketStore<CoinType>>(sender_addr), error::already_exists(EMARKET_EXISTED));
        assert!(!exists<OfferStore<CoinType>>(sender_addr), error::already_exists(EMARKET_EXISTED));

        if(!exists<MarketEvents<CoinType>>(sender_addr)){
            move_to(sender, MarketEvents<CoinType> {
                create_market_event: account::new_event_handle<CreateMarketEvent>(sender),
                list_token_events: account::new_event_handle<ListTokenEvent>(sender),
                buy_token_events: account::new_event_handle<BuyTokenEvent>(sender),
                cancel_offer_events: account::new_event_handle<CancelOfferEvent>(sender),
            });
        };
        let (resource_signer, signer_cap) = account::create_resource_account(sender, seed);
        token::initialize_token_store(&resource_signer);

        move_to(sender, MarketStore<CoinType> {
            fee_numerator,
            fee_payee, 
            signer_cap,
        });

        move_to(sender, OfferStore<CoinType> {
            offers: table::new<ID, Offer<CoinType>>(),
        });

        // Make sure marketplace payee register coin
        if (!coin::is_account_registered<CoinType>(sender_addr)){
            coin::register<CoinType>(sender);
        };

        // Emit event
        let market_events = borrow_global_mut<MarketEvents<CoinType>>(sender_addr);
        event::emit_event(&mut market_events.create_market_event, CreateMarketEvent { 
            market_addr: sender_addr, 
            fee_numerator, 
            fee_payee 
        });
    }

    public entry fun list_token<CoinType>(
        seller: &signer,
        market_addr: address,
        creator: address, 
        collection: String, 
        name: String, 
        property_version: u64, 
        amount: u64,
        price: u64
    ) acquires OfferStore, MarketEvents, MarketStore {
        assert!(creator == @owner_addr, error::invalid_state(EINVALID_CREATOR));

        let resource_signer = get_resource_account_cap<CoinType>(market_addr);
        let seller_addr = signer::address_of(seller);
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);

        // Make sure seller register coin
        if (!coin::is_account_registered<CoinType>(seller_addr)){
            coin::register<CoinType>(seller);
        };
        
        // Transfer token to Market module
        let token = token::withdraw_token(seller, token_id, amount);
        token::deposit_token(&resource_signer, token);

        let offer_store = borrow_global_mut<OfferStore<CoinType>>(market_addr);
        let offer_id = create_offer_id(&resource_signer);
        table::add(&mut offer_store.offers, offer_id, Offer {
            token_id, seller: seller_addr, price, amount
        });

        // Emit event
        let market_events = borrow_global_mut<MarketEvents<CoinType>>(market_addr);
        event::emit_event(&mut market_events.list_token_events, ListTokenEvent {
            market_addr,
            token_id, 
            seller: seller_addr, 
            price, 
            timestamp: timestamp::now_microseconds(),
            offer_id
        });
    } 

    public entry fun buy_token<CoinType>(
        buyer: &signer,
        market_addr: address,
        offer_id_creation_number: u64
    ) acquires OfferStore, MarketStore, MarketEvents {
        let resource_signer = get_resource_account_cap<CoinType>(market_addr);
        let offer_id = guid::create_id(signer::address_of(&resource_signer), offer_id_creation_number);
        // Get offer info
        let offer_store = borrow_global_mut<OfferStore<CoinType>>(market_addr);
        // Validate
        assert!(table::contains(&offer_store.offers, offer_id), error::not_found(EOFFER_NOT_EXISTED));
        let offer = table::borrow(&offer_store.offers, offer_id);
        let seller = offer.seller;
        let price = offer.price;

        let buyer_addr = signer::address_of(buyer);
        assert!(seller != buyer_addr, error::invalid_state(ESELLER_CAN_NOT_BE_BUYER));

        // Calculate Fees
        let token_id = offer.token_id;
        let (royalty_fee, royalty_payee) = get_royalty_fee(token_id, price); // Creator will receive
        coin::transfer<CoinType>(buyer, royalty_payee, royalty_fee);

        let market_store = borrow_global<MarketStore<CoinType>>(market_addr);
        let market_fee = (price * market_store.fee_numerator) / FEE_DENOMINATOR; // Market payee will receive
        coin::transfer<CoinType>(buyer, market_store.fee_payee, market_fee);

        let coin_amount = price - market_fee - royalty_fee; // Seller will receive
        coin::transfer<CoinType>(buyer, seller, coin_amount);

        // Make sure seller register coin
        token::initialize_token_store(buyer);

        // Transfer token to Buyer
        let amount = offer.amount;
        let token = token::withdraw_token(&resource_signer, token_id, amount);
        token::deposit_token(buyer, token);

        // Remove offer id
        table::remove(&mut offer_store.offers, offer_id);

        // Emit event
        let market_events = borrow_global_mut<MarketEvents<CoinType>>(market_addr);
        event::emit_event(&mut market_events.buy_token_events, BuyTokenEvent {
            market_addr,
            token_id, 
            seller, 
            buyer: buyer_addr,
            timestamp: timestamp::now_microseconds(),
            offer_id
        });
    }

    public entry fun cancel_offer<CoinType>(
        sender: &signer,
        market_addr: address,
        offer_id_creation_number: u64
    ) acquires OfferStore, MarketStore, MarketEvents {
        let resource_signer = get_resource_account_cap<CoinType>(market_addr);
        let offer_id = guid::create_id(signer::address_of(&resource_signer), offer_id_creation_number);
        // Get offer info
        let offer_store = borrow_global_mut<OfferStore<CoinType>>(market_addr);
        // Validate
        assert!(table::contains(&offer_store.offers, offer_id), error::not_found(EOFFER_NOT_EXISTED));
        let offer = table::borrow(&offer_store.offers, offer_id);
        let seller = offer.seller;

        let sender_addr = signer::address_of(sender);
        assert!(seller == sender_addr, error::permission_denied(ESELLER_NOT_MATCHED));

        // Transfer token back to seller
        let token_id = offer.token_id;
        let token_amount = offer.amount;
        let token = token::withdraw_token(&resource_signer, token_id, token_amount);
        token::deposit_token(sender, token);

        // Remove offer id
        table::remove(&mut offer_store.offers, offer_id);

        // Emit event
        let market_events = borrow_global_mut<MarketEvents<CoinType>>(market_addr);
        event::emit_event(&mut market_events.cancel_offer_events, CancelOfferEvent {
            market_addr,
            token_id, 
            seller, 
            timestamp: timestamp::now_microseconds(),
            offer_id
        });
    }

    #[test(token_creator = @0x122, token_owner = @0x123, coin_owner = @0x124, market_owner = @0x125, aptos_framework = @aptos_framework)]
    public entry fun test_list_then_buy(
        token_creator: &signer,
        token_owner: &signer, 
        coin_owner: &signer, 
        market_owner: &signer,
        aptos_framework: &signer
    ): TokenId acquires OfferStore, MarketStore, MarketEvents { 
        // Initialize
        let token_id = test_init(token_creator, token_owner, coin_owner, market_owner, aptos_framework);

        // Create market FakeMoney
        let market_addr = signer::address_of(market_owner);
        create_market<coin::FakeMoney>(
            market_owner,
            x"ABCD",
            200, // fee numerator 2%
            market_addr,
        );

        // Listing 50 tokens
        let offer_creation_num_id = get_guid_creation_num<coin::FakeMoney>(market_addr);
        list_token<coin::FakeMoney>(
            token_owner,
            market_addr,
            signer::address_of(token_creator),
            token::get_collection_name(),
            token::get_token_name(),
            0, // property_version
            50, // amount
            1000, // price = 1000 FakeMoney
        );
        // all tokens in token escrow or transferred. Token owner has 50 tokens in token_store
        assert!(token::balance_of(signer::address_of(token_owner), token_id) == 50, error::internal(100));
        buy_token<coin::FakeMoney>(
            coin_owner,
            market_addr,
            offer_creation_num_id,
        );
        // coin owner only has 10000 - 1000 = 9000 coins left
        let coin_owner_coin_balance = coin::balance<coin::FakeMoney>(signer::address_of(coin_owner));
        assert!(coin_owner_coin_balance == 9000, coin_owner_coin_balance);
        // marketplace owner will receive 2% (20)
        let market_owner_coin_balance = coin::balance<coin::FakeMoney>(signer::address_of(market_owner));
        assert!(market_owner_coin_balance == 20, market_owner_coin_balance);
        // creator will receive receive 1% (10)
        let token_creator_coin_balance = coin::balance<coin::FakeMoney>(signer::address_of(token_creator));
        assert!(token_creator_coin_balance == 10, token_creator_coin_balance);
        // seller will receive 970 coins
        let token_owner_coin_balance = coin::balance<coin::FakeMoney>(signer::address_of(token_owner));
        assert!(token_owner_coin_balance == 970, token_owner_coin_balance);
        token_id
    } 

    #[test(token_creator = @0x122, token_owner = @0x123, coin_owner = @0x124, market_owner = @0x125, aptos_framework = @aptos_framework)]
    public entry fun test_cancel_listing(
        token_creator: &signer,
        token_owner: &signer, 
        coin_owner: &signer, 
        market_owner: &signer,
        aptos_framework: &signer
    ) acquires OfferStore, MarketStore, MarketEvents { 
        // Initialize
        let token_id = test_list_then_buy(token_creator, token_owner, coin_owner, market_owner, aptos_framework);
        let market_addr = signer::address_of(market_owner);

        // Relist 50 tokens
        let offer_creation_num_id = get_guid_creation_num<coin::FakeMoney>(market_addr);
        list_token<coin::FakeMoney>(
            token_owner,
            market_addr,
            signer::address_of(token_creator),
            token::get_collection_name(),
            token::get_token_name(),
            0, // property_version
            50, // amount
            2000, // price = 1000 FakeMoney
        );
        // all tokens in token escrow or transferred. Token owner has 0 token in token_store
        assert!(token::balance_of(signer::address_of(token_owner), token_id) == 0, error::internal(100));
        cancel_offer<coin::FakeMoney>(
            token_owner,
            market_addr,
            offer_creation_num_id,
        );
        // 50 tokens from the cancelled offer are refunded to token owner
        assert!(token::balance_of(signer::address_of(token_owner), token_id) == 50, error::internal(100));
    } 

    #[test(token_creator = @0x122, token_owner = @0x123, coin_owner = @0x124, market_owner = @0x125, aptos_framework = @aptos_framework)]
    #[expected_failure(abort_code = 327683)]
    public entry fun test_invalid_cancel_listing(
        token_creator: &signer,
        token_owner: &signer, 
        coin_owner: &signer, 
        market_owner: &signer,
        aptos_framework: &signer
    ) acquires OfferStore, MarketStore, MarketEvents { 
        // Initialize
        let token_id = test_list_then_buy(token_creator, token_owner, coin_owner, market_owner, aptos_framework);
        let market_addr = signer::address_of(market_owner);

        // Relist 50 tokens
        let offer_creation_num_id = get_guid_creation_num<coin::FakeMoney>(market_addr);
        list_token<coin::FakeMoney>(
            token_owner,
            market_addr,
            signer::address_of(token_creator),
            token::get_collection_name(),
            token::get_token_name(),
            0, // property_version
            50, // amount
            2000, // price = 1000 FakeMoney
        );
        // all tokens in token escrow or transferred. Token owner has 0 token in token_store
        assert!(token::balance_of(signer::address_of(token_owner), token_id) == 0, error::internal(100));
        cancel_offer<coin::FakeMoney>(
            coin_owner,
            market_addr,
            offer_creation_num_id,
        );
    } 

    #[test_only]
    fun get_guid_creation_num<CoinType>(
        market_addr: address,
    ): u64 acquires MarketStore { 
        let resource_signer = get_resource_account_cap<CoinType>(market_addr);
        account::get_guid_next_creation_num(signer::address_of(&resource_signer))
    }

    #[test_only]
    fun test_init(
        token_creator: &signer, 
        token_owner: &signer, 
        coin_owner: &signer, 
        market_owner: &signer,
        aptos_framework: &signer
    ): TokenId { 
        // Initialize
        account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test(10000000);
        // Token owner
        account::create_account_for_test(signer::address_of(token_creator));
        account::create_account_for_test(signer::address_of(token_owner));
        let token_id = token::create_collection_and_token(
            token_creator, // creator
            100, // amount
            100, // collection max
            100, // token max
            vector<String>[], // keys
            vector<vector<u8>>[], // values
            vector<String>[], // types
            vector<bool>[false, false, false], // collection mutate setting
            vector<bool>[false, false, true, false, false], // token mutate setting -> royalty mutate = true
        );
        let new_royalty = token::create_royalty(
            1,
            100,
            signer::address_of(token_creator)
        ); // 1%
        let token_data_id = token::create_token_data_id(
            signer::address_of(token_creator),
            token::get_collection_name(),
            token::get_token_name(),
        );
        token::mutate_tokendata_royalty(token_creator, token_data_id, new_royalty);
        token::direct_transfer(token_creator, token_owner, token_id, 100);
        // Coin owner
        account::create_account_for_test(signer::address_of(coin_owner));
        coin::create_fake_money(aptos_framework, coin_owner, 10000); // issue 10000 FakeMoney
        coin::transfer<coin::FakeMoney>(aptos_framework, signer::address_of(coin_owner), 10000);
        coin::register<coin::FakeMoney>(token_owner);
        coin::register<coin::FakeMoney>(token_creator);
        // Marketplace owner
        account::create_account_for_test(signer::address_of(market_owner));
        token_id
    }
}
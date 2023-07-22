module rarewave::marketplace {
    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_framework::guid;
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};
    use aptos_token::token;
    use aptos_token::token_coin_swap::{ list_token_for_swap, exchange_coin_for_token };
    use aptos_token::token_transfers::{ offer, claim };
    use aptos_token::token_transfers;

    const ESELLER_CAN_NOT_BE_BUYER: u64 = 1;
    const INVALID_SIGNER: u64 = 2;

    const FEE_DENOMINATOR: u64 = 10000;

    struct Market has key {
        market_address: address,
        fee_numerator: u64,
        fee_payee: address,
        source: address,
        signer_cap: account::SignerCapability
    }

    struct MarketEvents has key {
        create_market_event: EventHandle<CreateMarketEvent>,
        list_token_events: EventHandle<ListTokenEvent>,
        buy_token_events: EventHandle<BuyTokenEvent>
    }

    struct OfferStore has key {
        offers: Table<token::TokenId, Offer>
    }

    struct Offer has drop, store {
        seller: address,
        price: u64,
    }

    struct CreateMarketEvent has drop, store {
        fee_numerator: u64,
        fee_payee: address,
    }

    struct ListTokenEvent has drop, store {
        token_id: token::TokenId,
        seller: address,
        price: u64,
        timestamp: u64,
        offer_id: u64
    }

    struct BuyTokenEvent has drop, store {
        token_id: token::TokenId,
        seller: address,
        buyer: address,
        price: u64,
        timestamp: u64,
        offer_id: u64
    }

    fun get_resource_account_cap(market_address : address) : signer acquires Market{
        let market = borrow_global<Market>(market_address);
        account::create_signer_with_capability(&market.signer_cap)
    }

    fun get_royalty_fee_rate(token_id: token::TokenId) : u64{
        let royalty = token::get_royalty(token_id);
        let royalty_denominator = token::get_royalty_denominator(&royalty);
        let royalty_fee_rate = if (royalty_denominator == 0) {
            0
        } else {
            token::get_royalty_numerator(&royalty) / token::get_royalty_denominator(&royalty)
        };
        royalty_fee_rate
    }

    public entry fun create_market<CoinType>(sender: &signer, fee_numerator: u64, fee_payee: address) {
        let sender_addr = signer::address_of(sender);
        let (_resource, resource_cap) = account::create_resource_account(sender, x"01");
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        token::initialize_token_store(&_resource);

         move_to(&resource_signer_from_cap, Market{
             market_address: signer::address_of(&resource_signer_from_cap),
             fee_numerator,
             fee_payee,
             source: sender_addr,
             signer_cap: resource_cap
        });

        move_to(&resource_signer_from_cap, MarketEvents{
            create_market_event: account::new_event_handle<CreateMarketEvent>(&resource_signer_from_cap),
            list_token_events: account::new_event_handle<ListTokenEvent>(&resource_signer_from_cap),
            buy_token_events: account::new_event_handle<BuyTokenEvent>(&resource_signer_from_cap)
        });

        move_to(&resource_signer_from_cap, OfferStore{
            offers: table::new()
        });

        coin::register<CoinType>(&resource_signer_from_cap);
    }

    public entry fun list_token<CoinType>(
        seller: &signer,
        market_address:address,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        price: u64
    ) acquires MarketEvents, Market, OfferStore {
        let resource_signer = get_resource_account_cap(market_address);
        let seller_addr = signer::address_of(seller);

        // get token id and withdraw token from seller
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let token = token::withdraw_token(seller, token_id, 1);

        // deposit token to market and create offer
        token::deposit_token(&resource_signer, token);
        token_transfers::offer(&resource_signer, creator, token_id, 1);
        let offer_store = borrow_global_mut<OfferStore>(market_address);
        table::add(&mut offer_store.offers, token_id, Offer {
            seller: seller_addr, price
        });

        let guid = account::create_guid(&resource_signer);
        let market_events = borrow_global_mut<MarketEvents>(market_address);
        event::emit_event(&mut market_events.list_token_events, ListTokenEvent{
            token_id,
            seller: seller_addr,
            price,
            timestamp: timestamp::now_microseconds(),
            offer_id: guid::creation_num(&guid)
        });
    }

    public entry fun buy_token<CoinType>(
        buyer: &signer,
        market_address: address,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        offer_id: u64
    ) acquires MarketEvents, Market, OfferStore{
        let buyer_addr = signer::address_of(buyer);

        // get token id
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);

        // get order info
        let offer_store = borrow_global_mut<OfferStore>(market_address);
        let seller = table::borrow(&offer_store.offers, token_id).seller;
        let price = table::borrow(&offer_store.offers, token_id).price;

        // check if seller is buyer
        assert!(seller != buyer_addr, ESELLER_CAN_NOT_BE_BUYER);

        // claim nft
        claim(buyer, seller, token_id);

        // calculate fee
        let market = borrow_global<Market>(market_address);
        let market_fee = price * market.fee_numerator / FEE_DENOMINATOR;
        let amount = price - market_fee;

        // transfer coin
        coin::transfer<CoinType>(buyer, market_address, market_fee);
        coin::transfer<CoinType>(buyer, seller, amount);

        // remove offer
        table::remove(&mut offer_store.offers, token_id);

        // emit event
        let market_events = borrow_global_mut<MarketEvents>(market_address);
        event::emit_event(&mut market_events.buy_token_events, BuyTokenEvent{
            token_id,
            seller,
            buyer: buyer_addr,
            price,
            timestamp: timestamp::now_microseconds(),
            offer_id
        });
    }

    public entry fun withdraw_fee<CoinType>(account: &signer, market_address: address, amount: u64) acquires Market {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<Market>(market_address);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);

        let resource_signer = get_resource_account_cap(market_address);

        coin::transfer<CoinType>(&resource_signer, account_addr, amount);
    }
}
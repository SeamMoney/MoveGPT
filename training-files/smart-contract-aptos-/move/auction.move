module auction::marketplace{
    use std::signer;
    use std::option;
    use std::string;
    use aptos_token::token::{ Self, TokenId };
    use aptos_framework::event::{ Self, EventHandle };
    use aptos_framework::account;
    use aptos_std::table;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;

    const MODULE_ADMIN: address = @auction;

    const INVALID_ADMIN_ADDR: u64 = 1;

    struct AuctionItem has key, store {
        seller: address,
        sell_price: u64,
        duration: u64,
        start_time: u64,
        current_bid: u64,
        current_bidder: address,
        locked_token: option::Option<token::Token>,
    }

    struct AuctionData has key {
        auction_items: table::Table<TokenId, AuctionItem>,
        auction_events: EventHandle<AuctionEvent>,
        bid_events: EventHandle<BidEvent>,
        claim_token_events: EventHandle<ClaimTokenEvent>,
    }

    struct CoinEscrow has key{
        locked_coins: table::Table<TokenId, coin::Coin<AptosCoin>>
    }

    struct AuctionEvent has store, drop {
        id: TokenId,
        duration: u64,
        sell_price: u64
    }

    struct BidEvent has store,drop{
        id: TokenId,
        bid: u64,
    }
    struct ClaimTokenEvent has store, drop {
        id: TokenId,
    }

    public entry fun initialize_auction(
        admin: &signer,
    ){
        let admin_addr = signer::address_of(admin);
        assert!( admin_addr == MODULE_ADMIN, INVALID_ADMIN_ADDR);

        if (!exists<AuctionData>(admin_addr)){
            move_to(admin, AuctionData{
                auction_items: table::new<TokenId, AuctionItem>(),
                auction_events: account::new_event_handle<AuctionEvent>(admin),
                bid_events: account::new_event_handle<BidEvent>(admin),
                claim_token_events: account::new_event_handle<ClaimTokenEvent>(admin),
            })
        };
        if (!exists<CoinEscrow>(admin_addr)){
            move_to(admin, CoinEscrow{
                locked_coins: table::new<TokenId, coin::Coin<AptosCoin>>()
            })
        }
    }

    public entry fun sell_nft(
        seller: &signer,
        creator: address,
        collection_name: vector<u8>,
        name: vector<u8>,
        sell_price: u64,
        duration: u64
    ) acquires AuctionData{
        let seller_addr = signer::address_of(seller);
        let auction_data = borrow_global_mut<AuctionData>(MODULE_ADMIN);
        let auction_items = &mut auction_data.auction_items;
        let token_id = token::create_token_id_raw(creator, string::utf8(collection_name), string::utf8(name),0);

        if (!coin::is_account_registered<AptosCoin>(seller_addr)){
            managed_coin::register<AptosCoin>(seller);
        };

        assert!(!table::contains(auction_items, copy token_id), 1);

        event::emit_event<AuctionEvent>(
            &mut auction_data.auction_events,
            AuctionEvent {
                id: copy token_id,
                duration,
                sell_price,
            }
        );

        let locked_token = token::withdraw_token(seller, token_id, 1);

        let start_time = timestamp::now_seconds();

        table::add(auction_items, token_id, AuctionItem {
            seller: seller_addr,
            sell_price,
            duration,
            start_time,
            current_bid: sell_price - 1,
            current_bidder: seller_addr,
            locked_token: option::some(locked_token)
        });
    }

    public entry fun bid(
        bidder: &signer,
        creator: address,
        collection_name: vector<u8>,
        name: vector<u8>,
        bid: u64
    ) acquires AuctionData, CoinEscrow {
        let token_id = token::create_token_id_raw(creator, string::utf8(collection_name), string::utf8(name),0);
        let auction_data = borrow_global_mut<AuctionData>(MODULE_ADMIN);
        let auction_items = &mut auction_data.auction_items;
        let auction_item = table::borrow_mut(auction_items, token_id);
        assert!(is_auction_active(auction_item.start_time, auction_item.duration), 1);
        assert!(bid > auction_item.current_bid, 1);

        let bidder_addr = signer::address_of(bidder);
        assert!(auction_item.seller != bidder_addr, 1);
        event::emit_event<BidEvent>( &mut auction_data.bid_events, BidEvent{
            id: token_id,
            bid
        });

        let lock_coins = &mut borrow_global_mut<CoinEscrow>(MODULE_ADMIN).locked_coins;

        if  (auction_item.current_bidder != auction_item.seller){
            let coins = table::remove(lock_coins, token_id);
            coin::deposit<AptosCoin>(auction_item.current_bidder, coins);
        };

        let coins = coin::withdraw<AptosCoin>(bidder, bid);
        table::add(lock_coins, token_id, coins);

        auction_item.current_bidder = bidder_addr;
        auction_item.current_bid = bid;
    }

    public entry fun claim_token(
        higher: &signer,
        creator: address,
        collection_name: vector<u8>,
        name: vector<u8>
    ) acquires AuctionData, CoinEscrow{
        let token_id = token::create_token_id_raw(creator, string::utf8(collection_name), string::utf8(name),0);
        let higher_addr = signer::address_of(higher);

        let auction_data = borrow_global_mut<AuctionData>(MODULE_ADMIN);
        let auction_items = &mut auction_data.auction_items;
        let auction_item = table::borrow_mut(auction_items, token_id);
        assert!(is_auction_complete(auction_item.start_time, auction_item.duration), 1);
        assert!( higher_addr == auction_item.current_bidder, 1);
        event::emit_event<ClaimTokenEvent>(
            &mut auction_data.claim_token_events,
            ClaimTokenEvent {
                id: token_id
            }
        );
        let token = option::extract(&mut auction_item.locked_token);
        token::deposit_token(higher, token);

        let locked_coins = &mut borrow_global_mut<CoinEscrow>(MODULE_ADMIN).locked_coins;
        if (table::contains(locked_coins, token_id)){
            let coins = table::remove(locked_coins, token_id);
            coin::deposit<AptosCoin>(auction_item.seller, coins);
        };
        let AuctionItem{ seller:_, sell_price: _, duration: _, start_time: _, current_bid: _, current_bidder: _, locked_token: locked_token } = table::remove(auction_items, token_id);

        option::destroy_none(locked_token);
    }

    public entry fun claim_coins(
        seller: &signer,
        creator: address,
        collection_name: vector<u8>,
        name: vector<u8>)
    acquires CoinEscrow, AuctionData {
        let token_id = token::create_token_id_raw(creator, string::utf8(collection_name), string::utf8(name),0 );
        let seller_addr = signer::address_of(seller);
        let auction_data = borrow_global_mut<AuctionData>(MODULE_ADMIN);
        let auction_items = &mut auction_data.auction_items;
        assert!(table::contains(auction_items, token_id), 1);
        let auction_item = table::borrow(auction_items, token_id);

        assert!(is_auction_complete(auction_item.start_time, auction_item.duration), 1);
        assert!(seller_addr == auction_item.seller, 1);

        let locked_coins = &mut borrow_global_mut<CoinEscrow>(MODULE_ADMIN).locked_coins;
        assert!(table::contains(locked_coins, token_id), 1);
        let coins = table::remove(locked_coins, token_id);
        coin::deposit<AptosCoin>(seller_addr, coins);
    }

    fun is_auction_active( start_time: u64, duration: u64): bool {
        let current_time = timestamp::now_seconds();
        current_time <= start_time + duration && current_time >= start_time
    }

    fun is_auction_complete(start_time: u64, duration: u64): bool {
        let current_time = timestamp::now_seconds();
        current_time > start_time + duration
    }

    #[test_only]
    public fun isLockedToken(tokenId: TokenId):bool acquires AuctionData{
        let auction_data = borrow_global_mut<AuctionData>(MODULE_ADMIN);
        let auction_items = &mut auction_data.auction_items;

        table::contains(auction_items, tokenId)
    }
}
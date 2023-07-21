module _1200_dollars_per_hour::auction_house{

  friend _1200_dollars_per_hour::english_auction;

  use std::signer;
  use std::option::{Self, Option};
  use aptos_std::table::{Self, Table};
  use aptos_token::token::{ Self, TokenId, Token };
  use aptos_framework::event::{ Self, EventHandle };
  use aptos_framework::account;
  use aptos_framework::timestamp;
  use aptos_framework::coin::{Self, Coin};

  const CURATOR : address = @_1200_dollars_per_hour;
  const EMPTY_BIDDER : address = @0x0;

  const TYPE_ENGLISH_AUCTION : u64 = 0;
  const TYPE_DUTCH_AUCTION : u64 = 1;

  const EINVALID_CURATOR_ADDRESS: u64 = 100;
  const EAUCTION_EXISTED: u64= 101;
  const EAUCTION_EXPIRED: u64 = 102;
  const EONLY_SELLER_OR_CURATOR_CAN_CANCEL_AUCTION: u64= 103;
  const EONLY_SELLER_OR_CURATOR_CAN_EXTEND_AUCTION_DURATION: u64= 104;
  const EONLY_SELLER_OR_CURATOR_CAN_UPDATE_AUCTION_RESERVE_PRICE: u64= 105;
  const ESELLER_CAN_NOT_BE_BIDDER: u64 = 106;
  const EMUST_GREATER_OR_EQUAL_THAN_RESERVE_PRICE: u64 = 107;
  const EAUCTION_HAS_NOT_BEGUN: u64 = 108;
  const EAUCTION_HAS_NOT_COMPLETED: u64 = 109;
  const EAUCTION_NOT_CLAIMABLE: u64 = 110;
  const EAUCTION_COINS_CLAIMED: u64 = 111;

  struct AuctionHouseConfig has key, store {
    service_fee_numerator: u64,
    creator_fee_numerator: u64
  }

  struct Auction has key, store {
    token_id: TokenId,
    seller: address,
    duration: u64,
    create_time: u64,
    first_bid_time: u64,
    starting_price: u64,
    // For English Auction: If the seller doesn't receive any bids equal to or greater than the reserve, the auction will end without a sale.
    // For Dutch Auction: manifest as ending price.
    reserve_price: u64,
    // The current highest bid price
    current_price: u64,       
    current_bidder: address,
    // Auction type
    type: u64, 
    token: Option<Token>,
  }

  struct AuctionCreatedEvent has store, drop {
    token_id: TokenId,
    duration: u64,
    starting_price: u64,
    reserve_price: u64,
    seller: address,
  }

  struct AuctionReservePriceUpdatedEvent has store, drop{
    token_id: TokenId,
    reserve_price: u64
  }

  struct AuctionBidEvent has store, drop {
    token_id: TokenId,
    bidder: address,
    price: u64,
    is_first_bid: bool,
    is_duration_extended: bool,
  }

  struct AuctionClaimTokenEvent has store, drop {
    token_id: TokenId
  }

  struct AuctionCanceledEvent has store, drop {
    token_id: TokenId,
  }

  struct AuctionEndedEvent has store, drop {
    token_id: TokenId,
  }

  struct AuctionDurationExtendedEvent has store, drop {
    token_id: TokenId,
    duration: u64,
  }

  struct AuctionHouse has key {
    config: AuctionHouseConfig,
    auction_items: table::Table<TokenId, Auction>,
    auction_created_events: EventHandle<AuctionCreatedEvent>,
    auction_bid_events: EventHandle<AuctionBidEvent>,
    auction_canceled_events: EventHandle<AuctionCanceledEvent>,
    auction_claim_token_events: EventHandle<AuctionClaimTokenEvent>,
    auction_duration_extended_events: EventHandle<AuctionDurationExtendedEvent>,
    auction_reserve_price_updated_events: EventHandle<AuctionReservePriceUpdatedEvent>,
  }

  struct CoinEscrow<phantom CoinType: store> has key {
    locked_coins: Table<TokenId, Coin<CoinType>>,
  }

  public entry  fun initial_auction_hourse<CoinType: store>(sender: &signer, service_fee_numerator: u64, creator_fee_numerator: u64) {
    let sender_addr = signer::address_of(sender);
    assert!(sender_addr == CURATOR, EINVALID_CURATOR_ADDRESS);

    if(!exists<AuctionHouse>(sender_addr)){
      let config = AuctionHouseConfig{
        service_fee_numerator,
        creator_fee_numerator
      };
      move_to(sender, AuctionHouse{
        config,
        auction_items: table::new<TokenId, Auction>(),
        auction_created_events: account::new_event_handle<AuctionCreatedEvent>(sender),
        auction_bid_events: account::new_event_handle<AuctionBidEvent>(sender),
        auction_canceled_events: account::new_event_handle<AuctionCanceledEvent>(sender),
        auction_claim_token_events: account::new_event_handle<AuctionClaimTokenEvent>(sender),
        auction_duration_extended_events: account::new_event_handle<AuctionDurationExtendedEvent>(sender),
        auction_reserve_price_updated_events: account::new_event_handle<AuctionReservePriceUpdatedEvent>(sender),
      });
    };

    if(!exists<CoinEscrow<CoinType>>(sender_addr)){
      move_to(sender, CoinEscrow {
        locked_coins: table::new<TokenId, coin::Coin<CoinType>>()
      })
    }
  }

  public(friend) fun create_auction<CoinType>(seller: &signer, token_id: TokenId, duration: u64, starting_price: u64, reserve_price: u64, type: u64) acquires AuctionHouse {
    let seller_addr = signer::address_of(seller);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;

    if (!coin::is_account_registered<CoinType>(seller_addr)){
      coin::register<CoinType>(seller);
    };

    assert!(!table::contains(auction_items, token_id), EAUCTION_EXISTED);

    let locked_token = token::withdraw_token(seller, token_id, 1);

    table::add(auction_items, token_id, Auction{
      token_id,
      seller: seller_addr,
      duration,
      create_time: timestamp::now_seconds(),
      first_bid_time: 0,
      starting_price,
      reserve_price,
      current_price: 0,       
      current_bidder: EMPTY_BIDDER,
      token: option::some(locked_token),
      type
    });

    event::emit_event<AuctionCreatedEvent>(&mut auction_house.auction_created_events, AuctionCreatedEvent {
      token_id,
      duration,
      starting_price,
      reserve_price,
      seller: seller_addr,
    });
  }

  public(friend) fun cancel_auction<CoinType: store>(sender: &signer , token_id: TokenId) acquires AuctionHouse, CoinEscrow {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    assert!(timestamp::now_seconds() < ended_time_of_auction(auction), EAUCTION_EXPIRED);
    assert!(sender_addr == auction.seller || sender_addr == CURATOR, EONLY_SELLER_OR_CURATOR_CAN_CANCEL_AUCTION);

    let locked_coins = &mut borrow_global_mut<CoinEscrow<CoinType>>(CURATOR).locked_coins;
    let coins = table::remove(locked_coins, token_id);
    coin::deposit<CoinType>(auction.current_bidder, coins);
    event::emit_event<AuctionCanceledEvent>(&mut auction_house.auction_canceled_events, AuctionCanceledEvent{
      token_id
    });
  }

  public(friend) fun bid_auction<CoinType: store>(sender: &signer, token_id: TokenId, price: u64) acquires AuctionHouse, CoinEscrow {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    assert!(sender_addr != auction.seller, ESELLER_CAN_NOT_BE_BIDDER);
    assert!(auction.first_bid_time == 0 || timestamp::now_seconds() < auction.first_bid_time + auction.duration, EAUCTION_EXPIRED);
    assert!(auction.reserve_price <= price, EMUST_GREATER_OR_EQUAL_THAN_RESERVE_PRICE);

    let locked_coins = &mut borrow_global_mut<CoinEscrow<CoinType>>(CURATOR).locked_coins;

    // If this is the first valid bid, we should set the starting time now.
    // If it's not, then we should refund the last bidder
    let is_first_bid = false;
    if(auction.first_bid_time == 0){
      auction.first_bid_time = timestamp::now_seconds();
      is_first_bid = true;
    } else if (auction.current_bidder != EMPTY_BIDDER){
      let coins = table::remove(locked_coins, token_id);
      coin::deposit<CoinType>(auction.current_bidder, coins);
    };

    let coins = coin::withdraw<CoinType>(sender, price);
    table::add(locked_coins, token_id, coins);

    auction.current_bidder = sender_addr;
    auction.current_price = price;

    event::emit_event<AuctionBidEvent>(&mut auction_house.auction_bid_events, AuctionBidEvent{
      token_id,
      bidder: sender_addr,
      price,
      is_first_bid,
      is_duration_extended: false,
    });

    // TODO extend duration with config.timebuffer
  }

  public(friend) fun claim_token<CoinType: store>(sender: &signer, token_id: TokenId) acquires AuctionHouse, CoinEscrow {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    
    assert!(sender_addr == auction.current_bidder, EAUCTION_NOT_CLAIMABLE);
    assert!(auction.first_bid_time != 0, EAUCTION_HAS_NOT_BEGUN);
    assert!(timestamp::now_seconds() < auction.first_bid_time + auction.duration, EAUCTION_HAS_NOT_COMPLETED);
    
    let locked_coins = &mut borrow_global_mut<CoinEscrow<CoinType>>(CURATOR).locked_coins;

    if(table::contains(locked_coins, token_id)){
      let coins = table::remove(locked_coins, token_id);
      coin::deposit<CoinType>(auction.seller, coins);
    };

    let token = option::extract(&mut auction.token);
    token::deposit_token(sender, token);

    let Auction{ token_id: _, seller: _, duration: _, create_time: _, first_bid_time: _, starting_price: _, reserve_price: _, current_price: _, current_bidder: _, type: _, token: locked_token } = table::remove(auction_items, token_id);
    option::destroy_none(locked_token);

    event::emit_event<AuctionClaimTokenEvent>(&mut auction_house.auction_claim_token_events, AuctionClaimTokenEvent{
      token_id
    });
  }

  public(friend) fun claim_coins<CoinType: store>(sender: &signer, token_id: TokenId) acquires AuctionHouse, CoinEscrow {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    
    assert!(sender_addr == auction.seller, EAUCTION_NOT_CLAIMABLE);
    assert!(auction.first_bid_time != 0, EAUCTION_HAS_NOT_BEGUN);
    assert!(timestamp::now_seconds() < auction.first_bid_time + auction.duration, EAUCTION_HAS_NOT_COMPLETED);
    
    let locked_coins = &mut borrow_global_mut<CoinEscrow<CoinType>>(CURATOR).locked_coins;
    assert!(table::contains(locked_coins, token_id), EAUCTION_COINS_CLAIMED);

    let coins = table::remove(locked_coins, token_id);
    coin::deposit<CoinType>(auction.seller, coins);
  }

  public(friend) fun extend_auction_duration(sender: &signer, token_id: TokenId, duration: u64) acquires AuctionHouse {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    assert!(sender_addr == auction.seller || sender_addr == CURATOR, EONLY_SELLER_OR_CURATOR_CAN_EXTEND_AUCTION_DURATION);
    auction.duration = duration;
  }

  public(friend) fun update_auction_reserve_price(sender: &signer, token_id: TokenId, reserve_price: u64) acquires AuctionHouse {
    let sender_addr = signer::address_of(sender);
    let auction_house = borrow_global_mut<AuctionHouse>(CURATOR);
    let auction_items = &mut auction_house.auction_items;
    let auction = table::borrow_mut<TokenId, Auction>(auction_items, token_id);
    assert!(sender_addr == auction.seller || sender_addr == CURATOR, EONLY_SELLER_OR_CURATOR_CAN_UPDATE_AUCTION_RESERVE_PRICE);
    auction.reserve_price = reserve_price;
  }

  fun ended_time_of_auction(auction: &Auction): u64 {
    if(auction.first_bid_time == 0) {
      auction.create_time + auction.duration
    } else {
      auction.first_bid_time + auction.duration
    }
  }

}
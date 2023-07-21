module alcohol_auction::auction {
  use aptos_framework::event;
  use aptos_framework::timestamp;
  use aptos_framework::account;
  use aptos_framework::signer;
  use aptos_framework::aptos_coin;
  use aptos_framework::coin;
  use aptos_token::token_transfers;
  use aptos_token::token;
  use aptos_std::table_with_length;
  use std::string::String;

  // error codes
  const EWRONG_AUCTION_ID: u64 = 0;
  const EDEADLINE_IN_PAST: u64 = 1;
  const EAUCTION_IS_FINISHED: u64 = 2;
  const EBID_TOO_LOW: u64 = 3;
  const EAUCTION_IS_NOT_OVER_YET: u64 = 4;
  const ENOT_AUCTION_WINNER: u64 = 5;
  const EBOTTLE_ALREADY_REDEEMED: u64 = 6;

  // auction status codes
  const AUCTION_LIVE: u64 = 1;
  const AUCTION_FINISHED: u64 = 2;
  const AUCTION_BOTTLE_REDEEMED: u64 = 3;

  struct AuctionStartEvent has store, drop {
    starting_price: u64,
    token_name: String,
    deadline: u64
  }

  struct AuctionFinalizeEvent has store, drop {
    auction_id: u64,
    auction_winner: address,
    final_bid: u64
  }

  struct NewBidEvent has store, drop {
    new_top_bid: u64,
    new_top_bidder: address
  }

  struct BottleRedeemEvent has store, drop {
    auction_id: u64,
    timestamp: u64
  }

  struct Auction has store {
    status: u64,
    token_id: aptos_token::token::TokenId,
    top_bid: u64,
    top_bidder: address,
    new_bid_events: event::EventHandle<NewBidEvent>,
    deadline: u64
  }

  struct ModuleData has key {
    auctions: table_with_length::TableWithLength<u64, Auction>,
    auction_start_events: event::EventHandle<AuctionStartEvent>,
    auction_finalize_events: event::EventHandle<AuctionFinalizeEvent>,
    bottle_redeem_events: event::EventHandle<BottleRedeemEvent>
  }

  fun init_module(account: &signer) {
    move_to(
      account,
      ModuleData {
        auctions: table_with_length::new<u64, Auction>(),
        auction_start_events: account::new_event_handle<AuctionStartEvent>(account),
        auction_finalize_events: account::new_event_handle<AuctionFinalizeEvent>(account),
        bottle_redeem_events: account::new_event_handle<BottleRedeemEvent>(account)
      }
    )
  }

  public entry fun start_new_auction(
    admin: &signer,
    deadline: u64,
    starting_price: u64,
    token_name: String,
    token_description: String,
    token_metadata_uri: String
  ) acquires ModuleData {
    alcohol_auction::access_control::admin_only(admin);
    assert!(timestamp::now_seconds() < deadline, EDEADLINE_IN_PAST);
    let auction_id = get_auction_id();
    let module_data = borrow_global_mut<ModuleData>(@alcohol_auction);
    let resource_account_signer = alcohol_auction::access_control::get_signer();
    let token_id = alcohol_auction::token::mint(token_name, token_description, token_metadata_uri);
    let auction = Auction {
      status: AUCTION_LIVE,
      token_id,
      top_bid: starting_price,
      top_bidder: @alcohol_auction,
      new_bid_events: account::new_event_handle<NewBidEvent>(&resource_account_signer),
      deadline
    };
    table_with_length::add(&mut module_data.auctions, auction_id, auction);
    event::emit_event(
      &mut module_data.auction_start_events,
      AuctionStartEvent {
        starting_price,
        token_name,
        deadline
      }
    );
  }

  public fun bid(
    bidder: &signer,
    auction_id: u64,
    coin: coin::Coin<aptos_coin::AptosCoin>
  ) acquires ModuleData {
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    assert!(auction_status(auction_id) == AUCTION_LIVE && !auction_is_over(auction_id), EAUCTION_IS_FINISHED);
    let module_data = borrow_global_mut<ModuleData>(@alcohol_auction);
    let auctions = &mut module_data.auctions;
    let auction = table_with_length::borrow_mut(auctions, auction_id);
    assert!(coin::value(&coin) > auction.top_bid, EBID_TOO_LOW);
    let new_top_bid = coin::value(&coin);
    let new_top_bidder = signer::address_of(bidder);
    // accept the new bid
    coin::deposit<aptos_coin::AptosCoin>(@alcohol_auction, coin);
    let previous_top_bidder = auction.top_bidder;
    if (previous_top_bidder != @alcohol_auction) {
      // return the previous highest bid to the bidder if there was at least one legitimate bid
      let previous_top_bid = auction.top_bid;
      let resource_account_signer = alcohol_auction::access_control::get_signer();
      coin::transfer<aptos_coin::AptosCoin>(&resource_account_signer, auction.top_bidder, previous_top_bid);
    };
    auction.top_bid = new_top_bid;
    auction.top_bidder = new_top_bidder;
    event::emit_event(
      &mut auction.new_bid_events,
      NewBidEvent {
        new_top_bid,
        new_top_bidder,
      }
    );
  }

  public entry fun accept_bid_price(
    admin: &signer,
    auction_id: u64
  ) acquires ModuleData {
    alcohol_auction::access_control::admin_only(admin);
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    assert!(auction_status(auction_id) == AUCTION_LIVE, EAUCTION_IS_FINISHED);
    finalize_auction_unchecked(auction_id);
  }

  public entry fun finalize_auction(
    auction_id: u64
  ) acquires ModuleData {
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    assert!(auction_status(auction_id) == AUCTION_LIVE, EAUCTION_IS_FINISHED);
    assert!(auction_is_over(auction_id), EAUCTION_IS_NOT_OVER_YET);
    finalize_auction_unchecked(auction_id);
  }

  public entry fun redeem_bottle(
    owner: &signer,
    auction_id: u64
  ) acquires ModuleData {
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    let auction_status = auction_status(auction_id);
    if (auction_status == AUCTION_LIVE) {
      abort EAUCTION_IS_NOT_OVER_YET
    } else if (auction_status == AUCTION_BOTTLE_REDEEMED) {
      abort EBOTTLE_ALREADY_REDEEMED
    };
    let module_data = borrow_global_mut<ModuleData>(@alcohol_auction);
    let auctions = &mut module_data.auctions;
    let auction = table_with_length::borrow_mut(auctions, auction_id);
    auction.status = AUCTION_BOTTLE_REDEEMED;
    alcohol_auction::token::burn(&auction.token_id, signer::address_of(owner), 1);
    event::emit_event(
      &mut module_data.bottle_redeem_events,
      BottleRedeemEvent{
        auction_id,
        timestamp: timestamp::now_seconds()
      }
    );
  }

  fun finalize_auction_unchecked(
    auction_id: u64
  ) acquires ModuleData {
    let module_data = borrow_global_mut<ModuleData>(@alcohol_auction);
    let auctions = &mut module_data.auctions;
    let auction = table_with_length::borrow_mut(auctions, auction_id);
    auction.status = AUCTION_FINISHED;
    let resource_account_signer = alcohol_auction::access_control::get_signer();
    let top_bidder = auction.top_bidder;
    // Transfer APT and offer a token only if there was at least one legitimate bettor
    if (top_bidder != @alcohol_auction) {
      // transfer APT to the admin
      coin::transfer<aptos_coin::AptosCoin>(&resource_account_signer, alcohol_auction::access_control::get_admin(), auction.top_bid);
      // offer won token to the top bidder so he can later accept it
      token_transfers::offer(&resource_account_signer, top_bidder, auction.token_id, 1);
    } else {
      // otherwise just offer the token to the admin
      token_transfers::offer(&resource_account_signer, alcohol_auction::access_control::get_admin(), auction.token_id, 1);
    };
    event::emit_event(
      &mut module_data.auction_finalize_events,
      AuctionFinalizeEvent {
        auction_id,
        auction_winner: auction.top_bidder,
        final_bid: auction.top_bid
      }
    );
  }

  #[view]
  public fun get_auction_id(): u64 acquires ModuleData {
    let module_data = borrow_global_mut<ModuleData>(@alcohol_auction);
    table_with_length::length(&module_data.auctions)
  }

  #[view]
  public fun get_auction_status(auction_id: u64): u64 acquires ModuleData {
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    auction_status(auction_id)
  }

  #[view]
  public fun get_auction_token_id(auction_id: u64): token::TokenId acquires ModuleData {
    assert!(auction_exists(auction_id), EWRONG_AUCTION_ID);
    table_with_length::borrow(&borrow_global<ModuleData>(@alcohol_auction).auctions, auction_id).token_id
  }

  fun auction_status(auction_id: u64): u64 acquires ModuleData {
    table_with_length::borrow(&borrow_global<ModuleData>(@alcohol_auction).auctions, auction_id).status
  }

  fun auction_exists(auction_id: u64): bool acquires ModuleData {
    table_with_length::contains(&borrow_global<ModuleData>(@alcohol_auction).auctions, auction_id)
  }

  fun auction_is_over(auction_id: u64): bool acquires ModuleData {
    table_with_length::borrow(&borrow_global<ModuleData>(@alcohol_auction).auctions, auction_id).deadline < timestamp::now_seconds()
  }

  #[test_only]
  public fun init_module_test(account: &signer) {
    init_module(account);
  }

  #[test_only]
  public fun get_auction_live_status(): u64 {
    AUCTION_LIVE
  }

  #[test_only]
  public fun get_auction_bottle_redeemed_status(): u64 {
    AUCTION_BOTTLE_REDEEMED
  }

  #[test_only]
  public fun auction_exists_test(auction_id: u64): bool acquires ModuleData {
    auction_exists(auction_id)
  }
}

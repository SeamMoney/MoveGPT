module _1200_dollars_per_hour::english_auction {

  use _1200_dollars_per_hour::auction_house::{Self as ah};
  use aptos_token::token::{ Self };
  use std::string::String;

  const TYPE_ENGLISH_AUCTION : u64 = 0;
  const TYPE_DUTCH_AUCTION : u64 = 1;

  public entry fun create_auction<CoinType>(sender: &signer, creator: address, collection: String, name: String, property_version: u64, duration: u64, starting_price: u64, reserve_price: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::create_auction<CoinType>(sender, token_id, duration, starting_price, reserve_price, TYPE_ENGLISH_AUCTION);
  }

  public entry fun cancel_auction<CoinType: store>(sender: &signer, creator: address, collection: String, name: String, property_version: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::cancel_auction<CoinType>(sender, token_id);
  }

  public entry fun extend_auction_duration(sender: &signer, creator: address, collection: String, name: String, property_version: u64, duration: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::extend_auction_duration(sender, token_id, duration);
  }

  public entry fun update_auction_reserve_price(sender: &signer, creator: address, collection: String, name: String, property_version: u64, reserve_price: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::update_auction_reserve_price(sender, token_id, reserve_price);
  }

  public entry fun bid_auction<CoinType: store>(sender: &signer, creator: address, collection: String, name: String, property_version: u64, price: u64) {
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::bid_auction<CoinType>(sender, token_id, price);
  }

  public entry fun claim_token<CoinType: store>(sender: &signer, creator: address, collection: String, name: String, property_version: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::claim_token<CoinType>(sender, token_id);
  }

  public entry fun claim_coins<CoinType: store>(sender: &signer, creator: address, collection: String, name: String, property_version: u64){
    let token_id = token::create_token_id_raw(creator, collection, name, property_version);
    ah::claim_coins<CoinType>(sender, token_id);
  }
}
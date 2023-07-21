module Escrow::Escrow {
  
  use std::signer;
  use aptos_framework::account;
  use aptos_framework::coin;
  use aptos_framework::aptos_coin::AptosCoin;
  use aptos_framework::timestamp;
  use aptos_framework::event::{Self, EventHandle};

  //
  // Constants
  //

  const INFO_SEED: vector<u8> = b"INFO_SEED";
  const DEFAULT_APT_FEE: u64 = 100000; /// 0.001 APT

  //
  // Escrow Status
  //
  
  const ESCROW_STATUS_INITED: u64 = 0;
  const ESCROW_STATUS_FUNDED: u64 = 1;
  const ESCROW_STATUS_ACCEPTED: u64 = 2;
  const ESCROW_STATUS_RELEASED: u64 = 3;
  const ESCROW_STATUS_REFUNDED: u64 = 4;
  const ESCROW_STATUS_OWNERWITHDRAW: u64 = 5;

  //
  // Errors
  //
  
  const EINVALID_OWNER: u64 = 1;
  const EESCROW_ALREADY_INITED: u64 = 2;
  const EINVALID_PARTIES: u64 = 3;
  const EINVALID_ACTION: u64 = 4;
  const EINVALID_AMOUNT: u64 = 5;
  const EINVALID_STATUS: u64 = 6;
  const EINVALID_TIME: u64 = 7;
  const EINVALID_COMMISSION_RATE: u64 = 8;

  //
  // Data Type
  //
  
  struct EscrowInfo has key {
      // owner address of escrow
      owner_addr: address,
      // Fee amount in aptos
      commission_rate: u64,
      // minimum deposit amount
      min_amount: u64,
      // fee receiver wallet
      commission_wallet: address,
      // buyer address
      buyer: address,
      // seller address
      seller: address,
      // deposit time in unix timestamp
      deposit_time: u64,
      // escrow status
      status: u64,
      // coins in escrow
      escrow_coins: coin::Coin<AptosCoin>
  }
  
  //
  // View Functions
  //
  #[view]
  public fun is_escrow_inited(): bool {
    exists<EscrowInfo>(account::create_resource_address(&@Escrow, INFO_SEED))
  }
  
  #[view]
  public fun calculate_amount_to_transfer(escrow_info: &mut EscrowInfo): (u64, u64) {
      let deal_amount = coin::value(&escrow_info.escrow_coins);
      let amt_after_commission = deal_amount -
          ((deal_amount * escrow_info.commission_rate) / 100);
      let commission_amount = deal_amount - amt_after_commission;
      (amt_after_commission, commission_amount)
  }

  //
  // Entry Functions
  //

  // constructor
  
  public entry fun initialize_deal(
    owner: &signer, 
    commission_wallet: address, 
    min_amount: u64,
    commission_rate: u64
  ) {
    // initCheck
    assert!(!is_escrow_inited(), EESCROW_ALREADY_INITED);
    let owner_addr = signer::address_of(owner);
    let (resource_account, _) = account::create_resource_account(owner, INFO_SEED);
    move_to<EscrowInfo>(&resource_account, EscrowInfo {
      owner_addr,
      min_amount,
      commission_rate,
      commission_wallet,
      buyer: owner_addr,
      seller: owner_addr,
      deposit_time: 0,
      status: 0,
      escrow_coins: coin::zero<AptosCoin>()
    });
  }

  public entry fun set_escrow_parties(
    sender: &signer,
    buyer: address,
    seller: address
  ) 
    acquires EscrowInfo
  {
    let sender_addr = signer::address_of(sender);
    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // initByOwner
    assert!(sender_addr == escrow_info.owner_addr, EINVALID_OWNER);
    // differentWalletAddresses
    assert!(buyer != seller, EINVALID_PARTIES);
    // differentWalletAddresses
    assert!(buyer != sender_addr, EINVALID_PARTIES);

    escrow_info.buyer = buyer;
    escrow_info.seller = seller;
  }

  public entry fun deposit(
    sender: &signer,
    deposit_amount: u64
  ) acquires EscrowInfo
  { 
    let sender_addr = signer::address_of(sender);
    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // partiese defined
    assert!(escrow_info.buyer != escrow_info.seller, EINVALID_PARTIES);
    // buyer only
    assert!(sender_addr == escrow_info.buyer, EINVALID_ACTION);
    // min amount
    assert!(deposit_amount >= escrow_info.min_amount, EINVALID_AMOUNT);

    escrow_info.status = ESCROW_STATUS_FUNDED;
    escrow_info.deposit_time = timestamp::now_seconds();

    // keep money in escrow
    let escrow_money = coin::withdraw<AptosCoin>(sender, deposit_amount);
    coin::merge<AptosCoin>(&mut escrow_info.escrow_coins, escrow_money);
  }

  
  public entry fun accept_deal(sender: &signer) 
    acquires EscrowInfo
  {
    let sender_addr = signer::address_of(sender);
    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // state funded
    assert!(escrow_info.status == ESCROW_STATUS_FUNDED, EINVALID_STATUS);
    // seller only
    assert!(sender_addr == escrow_info.seller, EINVALID_ACTION);
    escrow_info.status = ESCROW_STATUS_ACCEPTED;
  }

  public entry fun release_fund(sender: &signer) 
    acquires EscrowInfo 
  {
    let sender_addr = signer::address_of(sender);
    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // state accepted
    assert!(escrow_info.status == ESCROW_STATUS_ACCEPTED, EINVALID_STATUS);
    // buyer or seller only
    assert!(sender_addr == escrow_info.seller || sender_addr == escrow_info.buyer, EINVALID_ACTION);
    
    // change escrow status
    escrow_info.status = ESCROW_STATUS_RELEASED;

    let (amt_after_commission, commission_amount) = calculate_amount_to_transfer(escrow_info);
    
    // send real amount to buyer or seller
    let escrow_coin = coin::extract<AptosCoin>(&mut escrow_info.escrow_coins, amt_after_commission);
    if (sender_addr == escrow_info.seller) {
      coin::deposit<AptosCoin>(escrow_info.buyer, escrow_coin);
    } else {
      coin::deposit<AptosCoin>(escrow_info.seller, escrow_coin);
    };

    // send comission to commision wallet
    let commision_coin = coin::extract<AptosCoin>(&mut escrow_info.escrow_coins, commission_amount);
    coin::deposit<AptosCoin>(escrow_info.commission_wallet, commision_coin);
  }

  public entry fun withdraw_fund(sender: &signer) 
    acquires EscrowInfo 
  {
    let sender_addr = signer::address_of(sender);
    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // state funded
    assert!(escrow_info.status == ESCROW_STATUS_FUNDED, EINVALID_STATUS);
    // buyer only
    assert!(sender_addr == escrow_info.buyer, EINVALID_ACTION);

    // change escrow status
    escrow_info.status = ESCROW_STATUS_REFUNDED;

    let (amt_after_commission, commission_amount) = calculate_amount_to_transfer(escrow_info);
    
    // retrieve money to buyer
    let escrow_coin = coin::extract<AptosCoin>(&mut escrow_info.escrow_coins, amt_after_commission);
    coin::deposit<AptosCoin>(escrow_info.buyer, escrow_coin);

    // send comission to commision wallet
    let commision_coin = coin::extract<AptosCoin>(&mut escrow_info.escrow_coins, commission_amount);
    coin::deposit<AptosCoin>(escrow_info.commission_wallet, commision_coin);
  }


  // only-buyer
  public entry fun post_six_months(sender: &signer) 
    acquires EscrowInfo 
  {
    let sender_addr = signer::address_of(sender);
    let now_time = timestamp::now_seconds();

    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // onlyowner
    assert!(sender_addr == escrow_info.owner_addr, EINVALID_OWNER);
    // minimum time period
    let six_month = 60 * 60 * 24 * 180;
    assert!(now_time >= escrow_info.deposit_time + six_month, EINVALID_TIME);

    // change escrow status
    escrow_info.status = ESCROW_STATUS_OWNERWITHDRAW;

    let coin_amount = coin::value(&escrow_info.escrow_coins);
    // transfer fees to admin
    let escrow_coin = coin::extract<AptosCoin>(&mut escrow_info.escrow_coins, coin_amount);
    coin::deposit<AptosCoin>(sender_addr, escrow_coin);
  }
  
  // only-admin
  public entry fun change_commission_rate(sender: &signer, new_rate: u64) 
    acquires EscrowInfo 
  {
    let sender_addr = signer::address_of(sender);

    let info_addr = account::create_resource_address(&@Escrow, INFO_SEED);
    let escrow_info = borrow_global_mut<EscrowInfo>(info_addr);
    // onlyowner
    assert!(sender_addr == escrow_info.owner_addr, EINVALID_OWNER);

    // dealCommisonRate
    assert!(new_rate > 0 && new_rate < 100, EINVALID_COMMISSION_RATE);

    escrow_info.commission_rate = new_rate;
  }
  
}
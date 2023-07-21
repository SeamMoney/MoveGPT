module Staking::stake {
    
    // Simple NFT staking module that takes in a specified NFT collection and return a coin at fixed rate.

    // Imports
    use std::signer;
    use std::string::String;
    use std::error;

    // Iterables for easy access of staked tokens
    use Staking::iterable_table::{Self, IterableTable};
    use Staking::standard_coin::StandardCoin;

    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_token::token::{Self, Token, TokenId, withdraw_token, deposit_token};

    //
    // Errors.
    //
    
    const ETOKEN_NOT_IN_ESCROW: u64 = 1; /// Token is not in escrow
    const ETOKEN_CANNOT_MOVE_OUT_OF_ESCROW_BEFORE_LOCKUP_TIME: u64 = 2; /// Token cannot be moved out of escrow before the lockup time
    const ENOT_ENOUGH_COIN: u64 = 3; /// Not enough coin to buy token
    const ENOT_OWNER: u64 = 4; /// Not owner
    const ENOT_INITIALIZED: u64 = 5; /// Not initialized
    const ENOT_APART_OF_COLLECTION: u64 = 6; /// NFT provided not apart of expected collection
    const ENOT_TOKEN_OWNER: u64 = 7; /// NFT provided not apart of expected collection
    const ENO_COINSTORE_FOUND: u64 = 8; /// Coin store for rewards not found

    // Store utility token to be distributed.
    struct NFTCoinStore has store, key {
        coin_store: coin::Coin<StandardCoin>,
    }

    struct StakingInfo has store, key {
        creator_addr: address,
        collection_name: String,
        lock_time_seconds: u64,
        lump_sum_pay: u64,
        total_staked: u64,
        stake_limit: u64,
    }

    // StakedTokenEscrow holds the token that cannot be withdrawn or transferred.
    struct StakedTokenEscrow has store {
        token: Token, 
        staker: address,
        start_stake_seconds: u64, 
        end_stake_seconds: u64,
    }

    // StakedTokenEscrowStore holds a map of token id to their tokenEscrow
    struct StakedTokenEscrowStore has store, key {
        staked_nfts: IterableTable<TokenId, StakedTokenEscrow>
    }

    // Initialize StakedTokenEscrowStore to store StakedTokenEscrows (which holds each token)
    fun initialize_token_store_escrow(token_owner: &signer) {
        let addr = signer::address_of(token_owner);

        // Check if user already has an existing StakedTokenEscrowStore
        if (!exists<StakedTokenEscrowStore>(addr)) {

            // If it does not exist, create a new StakedTokenEscrowStore and push it to global state.
            let token_store_escrow = StakedTokenEscrowStore {
                staked_nfts: iterable_table::new<TokenId, StakedTokenEscrow>()
            };
            move_to(token_owner, token_store_escrow);
        }
    }

    // Function to deposit a NFT into an Staked Token Escrow, then add it to StakedTokenEscrowStore of a user.
    public fun deposit_nft_to_escrow(
        token_owner: &signer, 
        token_id: TokenId, 
        tokens: Token
    ) acquires StakedTokenEscrowStore, StakingInfo {
        let nfts_in_escrow = &mut borrow_global_mut<StakedTokenEscrowStore>(signer::address_of(token_owner)).staked_nfts;
        let add_lock_time = borrow_global<StakingInfo>(@Staking).lock_time_seconds;
        let current_time = timestamp::now_seconds();
        let token_escrow = StakedTokenEscrow {
            token: tokens,
            staker: signer::address_of(token_owner),
            start_stake_seconds: current_time,
            end_stake_seconds: current_time + add_lock_time
        };
        iterable_table::add(nfts_in_escrow, token_id, token_escrow);
    }

    // Private function to withdraw coins from CoinStore.
    fun withdraw_coins_from_coinstore_internal(
        _token_owner_addr: address,
        _token_id: TokenId
    ): coin::Coin<StandardCoin> acquires NFTCoinStore, StakingInfo {

        let amount = borrow_global<StakingInfo>(@Staking).lump_sum_pay;
        let coinstore = &mut borrow_global_mut<NFTCoinStore>(@Staking).coin_store;
        let to_withdraw = coin::extract<StandardCoin>(coinstore, amount);
        to_withdraw
    }

    // Private function to withdraw NFT from a StakedTokenEscrowStore of a user.
    fun withdraw_nft_from_escrow_internal(
        token_owner_addr: address,
        token_id: TokenId
    ): Token acquires StakedTokenEscrowStore {
        let nfts_in_escrow = &mut borrow_global_mut<StakedTokenEscrowStore>(token_owner_addr).staked_nfts;
        assert!(iterable_table::contains(nfts_in_escrow, token_id), error::not_found(ETOKEN_NOT_IN_ESCROW));
        let nft_escrow = iterable_table::borrow_mut(nfts_in_escrow, token_id);
        assert!(timestamp::now_seconds() > (nft_escrow.end_stake_seconds), error::invalid_argument(ETOKEN_CANNOT_MOVE_OUT_OF_ESCROW_BEFORE_LOCKUP_TIME));

        // destroy StakedTokenEscrow as we only have a NON-FUNGIBLE TOKEN
        let StakedTokenEscrow {
                token: tokens,
                staker: owner,
                start_stake_seconds: _,
                end_stake_seconds: _
            } = iterable_table::remove(nfts_in_escrow, token_id);
        assert!(owner == token_owner_addr, error::invalid_argument(ENOT_TOKEN_OWNER));
        tokens
    }

    /// Function to withdraw tokens from the token escrow. It needs a signer to authorize
    public fun withdraw_token_from_escrow(
        token_owner: &signer,
        token_id: TokenId,
    ): Token acquires StakedTokenEscrowStore {
        withdraw_nft_from_escrow_internal(signer::address_of(token_owner), token_id)
    }

    /// Function to withdraw coins from token escrow. It needs a signer to authorize
    public fun withdraw_coins_from_coinstore(
        token_owner: &signer,
        token_id: TokenId,
    ): coin::Coin<StandardCoin> acquires NFTCoinStore, StakingInfo {
        withdraw_coins_from_coinstore_internal(signer::address_of(token_owner), token_id)
    }

    public entry fun init (
        account: &signer,
        creator: address,
        collection: String,
        amount: u64,
        lock_time: u64,
        lump_sum: u64,
        collection_size: u64,
    ) {
        let signer_addr = signer::address_of(account);
        assert!(signer_addr == @Staking, error::invalid_argument(ENOT_OWNER));
        
        move_to(
            account,
            StakingInfo {
                creator_addr: creator,
                collection_name: collection,
                lock_time_seconds: lock_time,
                lump_sum_pay: lump_sum,
                total_staked: 0,
                stake_limit: collection_size,
            },
        );

        let token_deposit = coin::withdraw<StandardCoin>(account, amount);
        move_to<NFTCoinStore>(
            account,
            NFTCoinStore {
                coin_store: token_deposit
            }
        );
    }

    public entry fun update_staking_params(
        account: &signer,
        creator: address,
        collection: String,
        lock_time: u64,
    ) acquires StakingInfo {
        let signer_addr = signer::address_of(account);
        assert!(signer_addr == @Staking, error::invalid_argument(ENOT_OWNER));

        let existing_staking_info = borrow_global_mut<StakingInfo>(@Staking);
        existing_staking_info.creator_addr = creator;
        existing_staking_info.collection_name = collection;
        existing_staking_info.lock_time_seconds = lock_time;
    }

    public entry fun deposit_more_coins(
        account: &signer,
        amount: u64,
    ) acquires NFTCoinStore {
        let signer_addr = signer::address_of(account);
        assert!(signer_addr == @Staking, error::invalid_argument(ENOT_OWNER));
        
        if (!exists<NFTCoinStore>(signer_addr)) {
            let token_deposit = coin::withdraw<StandardCoin>(account, amount);
            move_to<NFTCoinStore>(
            account,
            NFTCoinStore {
                coin_store: token_deposit
            }
        );
        } else {
            let existing_coins = borrow_global_mut<NFTCoinStore>(signer_addr);
            let deposit = coin::withdraw<StandardCoin>(account, amount);
            coin::merge<StandardCoin>(&mut existing_coins.coin_store, deposit);
        };
    }

    public entry fun stake_token(
        token_owner: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
    ) acquires StakedTokenEscrowStore, StakingInfo {
        // Check if contract has been initialized
        assert!(exists<StakingInfo>(@Staking), error::invalid_argument(ENOT_INITIALIZED));

        // Check if real NFTs
        let correct_creators_addr = borrow_global<StakingInfo>(@Staking).creator_addr;
        let provided_token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let correct_token_id = token::create_token_id_raw(correct_creators_addr, collection, name, property_version);
        assert!(provided_token_id == correct_token_id, error::invalid_argument(ENOT_APART_OF_COLLECTION));

        let correct_collection_name = borrow_global<StakingInfo>(@Staking).collection_name;
        assert!(collection == correct_collection_name, error::invalid_argument(ENOT_APART_OF_COLLECTION));

        initialize_token_store_escrow(token_owner);

        let token = withdraw_token(token_owner, correct_token_id, 1);
        deposit_nft_to_escrow(token_owner, correct_token_id, token);

        // keep track of total staked
        let current_staking_info = borrow_global_mut<StakingInfo>(@Staking);
        let new_staked_amount = current_staking_info.total_staked + 1;
        current_staking_info.total_staked = new_staked_amount;
    }

    public entry fun unstake_token(
        token_owner: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
    ) acquires StakedTokenEscrowStore, StakingInfo, NFTCoinStore {

        // Initialize coin store for standard coin during withdrawal
        let signer_addr = signer::address_of(token_owner);
        if (coin::is_account_registered<StandardCoin>(signer_addr) == false) {
            coin::register<StandardCoin>(token_owner);
        };

        // Check if contract has been initialized
        assert!(exists<StakingInfo>(@Staking), error::invalid_argument(ENOT_INITIALIZED));

        // Get creator address initialized by owner and see if it matches
        let correct_creators_addr = borrow_global<StakingInfo>(@Staking).creator_addr;
        let provided_token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let correct_token_id = token::create_token_id_raw(correct_creators_addr, collection, name, property_version);
        assert!(provided_token_id == correct_token_id, error::invalid_argument(ENOT_APART_OF_COLLECTION));

        // Return tokens
        let token = withdraw_token_from_escrow(token_owner, correct_token_id);
        deposit_token(token_owner, token);

        // Send payout of coins
        let coins = withdraw_coins_from_coinstore(token_owner, correct_token_id);
        coin::deposit<StandardCoin>(signer_addr, coins);

        // keep track of total staked
        let current_staking_info = borrow_global_mut<StakingInfo>(@Staking);
        let new_staked_amount = current_staking_info.total_staked - 1;
        current_staking_info.total_staked = new_staked_amount;
    }

    // #[test_only]
    // use aptos_framework::account;
    // use aptos_framework::aptos_coin::AptosCoin;
    // use aptos_framework::managed_coin;
}
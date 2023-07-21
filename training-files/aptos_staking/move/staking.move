


module contract_addr::staking {
    use std::signer;
    use std::error;
    use std::string::{Self, String};
    use std::vector;

    use aptos_token::token::{Self, TokenId};

    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;

    use aptos_std::table::{Self, Table};
    use aptos_std::type_info;

    // ERRORS
    const ERROR_ACCOUNT_IS_NOT_AN_OWNER: u64 = 0;
    const ERROR_ACCOUNT_IS_NOT_COLLECTION_CREATOR: u64 = 1;
    const ERROR_STAKING_POOL_IS_ALREADY_INITIALIZED: u64 = 2;
    const ERROR_STAKING_POOL_IS_NOT_INITIALIZED: u64 = 3;
    const ERROR_COLLECTION_DATA_IS_NOT_CORRECT: u64 = 4;
    const ERROR_TOKEN_IS_STAKED: u64 = 5;
    const ERROR_TOKEN_IS_NOT_STAKED: u64 = 6;
    const ERROR_TOKEN_STAKING_BALANCE_TOO_LOW: u64 = 7;
    const ERROR_STAKING_DATA_IS_NOT_INITIALIZED: u64 = 8;
    const ERROR_ADDRESS_AND_STAKER_ARE_NOT_EQUAL: u64 = 9;
    const ERROR_COIN_NAME_IS_NOT_CORRECT: u64 = 10;
    const ERROR_MULTIPLIER_IS_ZERO: u64 = 11;

    // STRUCTS

    struct StakingPool<phantom CollectionType> has key {
        collection: String,
        creator: address,
        amount_staked: u64,
        coin_name: String,
        reward_interval: u64,
        reward: u64,
        stake_events: EventHandle<StakeEvent>,
        unstake_events: EventHandle<UnstakeEvent>,
        claim_events: EventHandle<ClaimEvent>
    }

    struct ResourceCapability has key {
        signer_cap: SignerCapability,
    }

    struct ResourceStakingData<phantom CollectionType> has key, drop {
        staker: address,
        staking_capability: account::SignerCapability
    }

    struct StakingData<phantom CollectionType> has key {
        token_staking_datas: Table<TokenId, TokenStakingData>,
        amount_staked: u64,
        claimed: u64,
    }

    struct TokenStakingData has store, drop {
        start_timestamp_seconds: u64,
        staking_address: address,
    }

    struct StakeEvent has drop, store {
        token_name: String,
        account_address: address,
    }

    struct UnstakeEvent has drop, store {
        token_name: String,
        account_address: address,
    }

    struct ClaimEvent has drop, store {
        token_name: String,
        account_address: address,
        amount: u64
    }

    
    // ASSERTS
    
    fun assert_address_is_owner(account_address: address) {
        assert!(
            account_address == @contract_addr,
            error::invalid_argument(ERROR_ACCOUNT_IS_NOT_AN_OWNER)
        );
    }

    fun assert_account_is_collection_creator(account_address: address, collection_name: String)  {
        assert!(
            token::check_collection_exists(account_address, collection_name),
            error::invalid_state(ERROR_ACCOUNT_IS_NOT_COLLECTION_CREATOR)
        );
    }

    fun assert_staking_pool_is_not_initialized<CollectionType>() {
        assert!(
            !exists<StakingPool<CollectionType>>(@contract_addr),
            error::invalid_state(ERROR_STAKING_POOL_IS_ALREADY_INITIALIZED)
        );
    }

    fun assert_staking_pool_is_initialized<CollectionType>() {
        assert!(
            exists<StakingPool<CollectionType>>(@contract_addr),
            error::invalid_state(ERROR_STAKING_POOL_IS_NOT_INITIALIZED)
        );
    }

    fun assert_collection_data_is_correct<CollectionType>(collection: String, creator: address) acquires StakingPool {
        let staking_pool = borrow_global<StakingPool<CollectionType>>(@contract_addr);

        assert!(
            staking_pool.collection == collection && staking_pool.creator == creator,
            error::invalid_state(ERROR_COLLECTION_DATA_IS_NOT_CORRECT)
        );
    }

    fun assert_token_is_not_staked<CollectionType>(account_address: address, token_id: TokenId) acquires StakingData {
        let staking_data = borrow_global<StakingData<CollectionType>>(account_address);
        
        assert!(
            !table::contains(&staking_data.token_staking_datas, token_id),
            error::invalid_state(ERROR_TOKEN_IS_STAKED)
        );
    }

    fun assert_token_is_staked<CollectionType>(account_address: address, token_id: TokenId) acquires StakingData {
        let staking_data = borrow_global<StakingData<CollectionType>>(account_address);
        
        assert!(
            table::contains(&staking_data.token_staking_datas, token_id),
            error::invalid_state(ERROR_TOKEN_IS_NOT_STAKED)
        );
    }

    fun assert_staking_data_is_initialized<CollectionType>(account_address: address) {
        assert!(
            exists<StakingData<CollectionType>>(account_address),
            error::invalid_state(ERROR_STAKING_DATA_IS_NOT_INITIALIZED)
        );
    }

    fun assert_address_and_staker_are_equal<CollectionType>(account_address: address, resouce_address: address) acquires ResourceStakingData {
        let resource_staking_data = borrow_global<ResourceStakingData<CollectionType>>(resouce_address);

        assert!(
            resource_staking_data.staker == account_address,
            error::invalid_argument(ERROR_ADDRESS_AND_STAKER_ARE_NOT_EQUAL)
        );
    }

    fun assert_coin_name_is_correct<CollectionType, CoinType>() acquires StakingPool {
        let staking_pool = borrow_global<StakingPool<CollectionType>>(@contract_addr);

        let coin_name = type_info::type_name<CoinType>();

        assert!(
            coin_name == staking_pool.coin_name,
            error::invalid_argument(ERROR_COIN_NAME_IS_NOT_CORRECT)
        );
    }

    fun assert_reward_multiplier_is_not_zero(multiplier: u64) {
        assert!(
            multiplier != 0,
            error::invalid_state(ERROR_MULTIPLIER_IS_ZERO)
        );
    }


    public fun init_pool<CollectionType, CoinType>(
        account: &signer,
        collection: String,
        creator: address,
        reward_interval: u64,
        reward: u64
    ) {
        let account_address = signer::address_of(account);
        
        assert_address_is_owner(account_address);

        assert_account_is_collection_creator(creator, collection);

        assert_staking_pool_is_not_initialized<CollectionType>();

        // getting info about coin type that users will get as reward for staking
        let coin_name = type_info::type_name<CoinType>();

        move_to(account, StakingPool<CollectionType> {
            collection,
            creator,
            amount_staked: 0,
            coin_name,
            reward_interval,
            reward,
            stake_events: account::new_event_handle<StakeEvent>(account),
            unstake_events: account::new_event_handle<UnstakeEvent>(account),
            claim_events: account::new_event_handle<ClaimEvent>(account)
        });
    }

    public fun stake<CollectionType>(
        account: &signer,
        creator: address,
        collection: String,
        token_name: String,
        property_version: u64
    ) acquires StakingPool, StakingData {
        let account_address = signer::address_of(account);

        assert_staking_pool_is_initialized<CollectionType>();

        assert_collection_data_is_correct<CollectionType>(collection, creator);
        

        // initializing StakingData
        if (!exists<StakingData<CollectionType>>(account_address)) {
            move_to(account, StakingData<CollectionType> {
                token_staking_datas: table::new(),
                amount_staked: 0,
                claimed: 0
            });
        };

        let token_id = token::create_token_id_raw(creator, collection, token_name, property_version);

        assert_token_is_not_staked<CollectionType>(account_address, token_id);

        let seed = vector::empty<u8>();
        let collection_bytes = *string::bytes(&collection);
        let token_name_bytes = *string::bytes(&token_name);
        vector::append(&mut seed, collection_bytes);
        vector::append(&mut seed, token_name_bytes);

        // creating resource account
        let (resource, signer_cap) = account::create_resource_account(account, seed);

        // enable opt-in (enable transfering NFTs)
        token::opt_in_direct_transfer(&resource, true);

        // transfer token to the resource account
        let resource_address = signer::address_of(&resource);
        token::transfer(account, token_id, resource_address, 1);

        // store data inside the resource account
        let staking_data = borrow_global_mut<StakingData<CollectionType>>(account_address);

        let token_staking_data = TokenStakingData {
            start_timestamp_seconds: timestamp::now_seconds(),
            staking_address: resource_address,
        };

        // saving TokenStakingData in the user resource table
        table::add(&mut staking_data.token_staking_datas, token_id, token_staking_data);
        staking_data.amount_staked = staking_data.amount_staked + 1;

        // saving resourceStakingData inside the resource account
        move_to(&resource, ResourceStakingData<CollectionType> {
            staker: account_address,
            staking_capability: signer_cap
        });

        increase_staked_amount<CollectionType>(1);
    }

    public fun unstake<CollectionType>(
        account: &signer,
        creator: address,
        collection: String,
        token_name: String,
        property_version: u64
    ) acquires StakingPool, StakingData, ResourceStakingData {
        let account_address = signer::address_of(account);

        assert_staking_pool_is_initialized<CollectionType>();

        assert_staking_data_is_initialized<CollectionType>(account_address);

        let token_id = token::create_token_id_raw(creator, collection, token_name, property_version);

        assert_token_is_staked<CollectionType>(account_address, token_id);

        let staking_data = borrow_global_mut<StakingData<CollectionType>>(account_address);

        // getting TokenStakingData from user resource
        let token_staking_data = table::borrow(&staking_data.token_staking_datas, token_id);

        assert_address_and_staker_are_equal<CollectionType>(account_address, token_staking_data.staking_address);
        
        // getting ResourceStakingData from resource account
        let resource_staking_data = borrow_global<ResourceStakingData<CollectionType>>(token_staking_data.staking_address);

        // removing token from the table
        table::remove(&mut staking_data.token_staking_datas, token_id);

        // decreasing staked tokens
        staking_data.amount_staked = staking_data.amount_staked - 1;

        // getting resource account as signer
        let resource = account::create_signer_with_capability(&resource_staking_data.staking_capability);

        // sending token back to the user
        token::transfer(&resource, token_id, account_address, 1);

        // deleting ResourceStakingData from resource account
        let resouce_address = signer::address_of(&resource);
        move_from<ResourceStakingData<CollectionType>>(resouce_address);

        decrease_staked_amount<CollectionType>(1);
    }


    public fun claim<CollectionType, CoinType>(
        account: &signer,
        creator: address,
        collection: String,
        token_name: String,
        property_version: u64
    ) acquires StakingData, StakingPool {
        let account_address = signer::address_of(account);

        assert_staking_pool_is_initialized<CollectionType>();

        assert_staking_data_is_initialized<CollectionType>(account_address);

        let token_id = token::create_token_id_raw(creator, collection, token_name, property_version);

        assert_token_is_staked<CollectionType>(account_address, token_id);

        assert_coin_name_is_correct<CollectionType, CoinType>();

        let staking_data = borrow_global_mut<StakingData>(account_address);

        let token_staking_data = table::borrow_mut(&mut staking_data.token_staking_datas, token_id);

        let current_timestamp = timestamp::now_seconds(); 

        // time left from previous claiming
        let time_left = current_timestamp - token_staking_data.start_timestamp_seconds;

        let staking_pool = borrow_global<StakingPool>(@contract_addr);

        let reward_multiplier = time_left / staking_pool.reward_interval;

        assert_reward_multiplier_is_not_zero(reward_multiplier);
        
        let tokens_to_send = staking_pool.reward * reward_multiplier;

        token_staking_data.start_timestamp_seconds = current_timestamp;
        staking_data.claimed =  staking_data.claimed + tokens_to_send;

        // register CoinType under user account
        // this function will also check if user has already registered CoinType
        coin::register<CoinType>(account);

        let vault_capabilities = borrow_global<ResourceCapability>(@contract_addr);

        // getting signer caps to the module
        let vault = account::create_signer_with_capability(&vault_capabilities.signer_cap);

        coin::transfer<CoinType>(&vault, account_address, tokens_to_send);
    }


    fun init_module(owner: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(owner, @contract_addr);

        move_to(owner, ResourceCapability {
            signer_cap: resource_signer_cap
        });
    }


    fun increase_staked_amount<CollectionType>(amount: u64) acquires StakingPool {
        let staking_pool = borrow_global_mut<StakingPool<CollectionType>>(@contract_addr);
        staking_pool.amount_staked = staking_pool.amount_staked + amount;
    }

    fun decrease_staked_amount<CollectionType>(amount: u64) acquires StakingPool {
        let staking_pool = borrow_global_mut<StakingPool<CollectionType>>(@contract_addr);
        
        // checking if there are enough staked tokens
        assert!(
            staking_pool.amount_staked >= amount,
            error::invalid_state(ERROR_TOKEN_STAKING_BALANCE_TOO_LOW)
        );

        staking_pool.amount_staked = staking_pool.amount_staked - amount;
    }

}
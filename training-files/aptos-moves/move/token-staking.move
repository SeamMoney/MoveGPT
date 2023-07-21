//! Contract to stake tokens is Aptos
//! Created by Mokshya Protocol
module staking::tokenstaking {
    use std::signer;
    use std::string::{String,append};
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_token::token::{Self,check_collection_exists,balance_of,direct_transfer};
    use aptos_std::type_info;
    use aptos_std::simple_map::{Self, SimpleMap};
    use std::bcs::to_bytes;

    struct MokshyaStaking has key {
        collection:String,
        // amount of token paid in a week for staking one token,
        // changed to dpr (daily percentage return)in place of apr addressing demand
        dpr:u64,
        //the statust of the staking can be turned off by the creator to stop payments
        state:bool,
        //the amount stored in the vault to distribute for token staking
        amount:u64,
        coin_type: address,
        treasury_cap:account::SignerCapability,        //treasury_cap
    }
    struct MokshyaReward has drop,key {
        staker: address,  //staker
        token_name: String,
        collection_name: String,  // collection name
        withdraw_amount: u64,
        treasury_cap: account::SignerCapability,
        start_time: u64,
        tokens: u64,  //amount of tokens
    }

    struct ResourceInfo has key {
        resource_map: SimpleMap<String, address>,
    }

    const ENO_NO_COLLECTION:u64=0;
    const ENO_STAKING_EXISTS:u64=1;
    const ENO_NO_STAKING:u64=2;
    const ENO_NO_TOKEN_IN_TOKEN_STORE:u64=3;
    const ENO_STOPPED:u64=4;
    const ENO_COINTYPE_MISMATCH:u64=5;
    const ENO_STAKER_MISMATCH:u64=6;
    const ENO_INSUFFICIENT_FUND:u64=7;
    const ENO_INSUFFICIENT_TOKENS:u64=7;

    // Function for creating and modifying staking
    public entry fun create_staking<CoinType>(
        creator: &signer,
        dpr:u64,    // rate of payment,
        collection_name:String,  // the name of the collection owned by Creator
        total_amount:u64,
    ) acquires ResourceInfo{
        let creator_addr = signer::address_of(creator);
        //verify the creator has the collection
        assert!(check_collection_exists(creator_addr,collection_name), ENO_NO_COLLECTION);

        //resource account to store funds and data
        let (staking_treasury, staking_treasury_cap) = account::create_resource_account(
            creator,
            to_bytes(&collection_name)
        );
        let staking_treasur_signer_from_cap = account::create_signer_with_capability(
            &staking_treasury_cap
        );
        let staking_address = signer::address_of(&staking_treasury);
        assert!(!exists<MokshyaStaking>(staking_address),ENO_STAKING_EXISTS);
        create_add_resource_info(creator, collection_name, staking_address);
        managed_coin::register<CoinType>(&staking_treasur_signer_from_cap); 
        //the creator need to make sure the coins are sufficient otherwise the contract
        //turns off the state of the staking
        coin::transfer<CoinType>(creator, staking_address, total_amount);
        move_to<MokshyaStaking>(&staking_treasur_signer_from_cap, MokshyaStaking{
            collection: collection_name,
            dpr,
            state:true,
            amount:total_amount,
            coin_type:coin_address<CoinType>(),
            treasury_cap:staking_treasury_cap,
        });
    }
    public entry fun update_dpr(
        creator: &signer,
        dpr:u64,//rate of payment,
        collection_name:String, //the name of the collection owned by Creator 
    )acquires MokshyaStaking, ResourceInfo
    {
        let creator_addr = signer::address_of(creator);
        //verify the creator has the collection
        assert!(check_collection_exists(creator_addr,collection_name), ENO_NO_COLLECTION);
        //get staking address
        let staking_address = get_resource_address(creator_addr,collection_name);
        assert!(exists<MokshyaStaking>(staking_address),ENO_NO_STAKING);// the staking doesn't exists
        let staking_data = borrow_global_mut<MokshyaStaking>(staking_address);
        //let staking_treasur_signer_from_cap = account::create_signer_with_capability(&staking_data.treasury_cap);
        staking_data.dpr=dpr;
    }
    public entry fun creator_stop_staking(
        creator: &signer,
        collection_name: String,  // the name of the collection owned by Creator
    )acquires MokshyaStaking, ResourceInfo {
        let creator_addr = signer::address_of(creator);
        //verify the creator has the collection
        assert!(check_collection_exists(creator_addr,collection_name), ENO_NO_COLLECTION);

        //get staking address
        let staking_address = get_resource_address(creator_addr,collection_name);
        assert!(exists<MokshyaStaking>(staking_address),ENO_NO_STAKING);  // the staking doesn't exists
        let staking_data = borrow_global_mut<MokshyaStaking>(staking_address);
        staking_data.state = false;
    }
    public entry fun deposit_staking_rewards<CoinType>(
        creator: &signer,
        collection_name: String, // collection's name that owned by the Creator.
        amount: u64,
    ) acquires MokshyaStaking, ResourceInfo {
        let creator_addr = signer::address_of(creator);
        //verify the creator has the collection
        assert!(check_collection_exists(creator_addr,collection_name), ENO_NO_COLLECTION);
        //
         assert!(exists<ResourceInfo>(creator_addr), ENO_NO_STAKING);
        let staking_address = get_resource_address(creator_addr,collection_name);        let staking_data = borrow_global_mut<MokshyaStaking>(staking_address);
        //the creator need to make sure the coins are sufficient otherwise the contract
        //turns off the state of the staking
        assert!(coin_address<CoinType>()==staking_data.coin_type,ENO_COINTYPE_MISMATCH);
        coin::transfer<CoinType>(creator,staking_address, amount);
        staking_data.amount= staking_data.amount+amount;
        
    }
    // Functions for staking and earning rewards
    public entry fun stake_token(
        staker: &signer,   // account stake token to earn APTs .
        creator_addr: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        tokens:u64,
    )acquires MokshyaStaking, ResourceInfo
    {
        let staker_addr = signer::address_of(staker);
        let token_id = token::create_token_id_raw(creator_addr, collection_name, token_name, property_version);
        // verifying the token owner has the token
        assert!(balance_of(staker_addr, token_id) >= tokens, ENO_NO_TOKEN_IN_TOKEN_STORE);
        // verify the creator has the collection
        assert!(check_collection_exists(creator_addr,collection_name), ENO_NO_COLLECTION);
        //verifying whether the creator has started the staking or not
        let staking_address = get_resource_address(creator_addr,collection_name);
        assert!(exists<MokshyaStaking>(staking_address), ENO_NO_STAKING);// the staking doesn't exists
        let staking_data = borrow_global<MokshyaStaking>(staking_address);

        assert!(staking_data.state, ENO_STOPPED);
        let seed = collection_name;
        let seed2 = token_name;
        append(&mut seed,seed2);
        let (reward_treasury, reward_treasury_cap) = account::create_resource_account(staker, to_bytes(&seed)); //resource account to store funds and data
        let reward_treasur_signer_from_cap = account::create_signer_with_capability(&reward_treasury_cap);
        let reward_treasury_address = signer::address_of(&reward_treasury);
        assert!(!exists<MokshyaReward>(reward_treasury_address), ENO_STAKING_EXISTS);
        create_add_resource_info(staker, seed, reward_treasury_address);
        let now = aptos_framework::timestamp::now_seconds();
        direct_transfer(staker,&reward_treasur_signer_from_cap, token_id,tokens);
        move_to<MokshyaReward>(&reward_treasur_signer_from_cap, MokshyaReward{
            staker:staker_addr,
            token_name,
            collection_name,
            withdraw_amount:0,
            treasury_cap:reward_treasury_cap,
            start_time:now,
            tokens,
        });
    }

    public entry fun claim_reward<CoinType>(
        staker:&signer, 
        collection_name:String, //the name of the collection owned by Creator 
        token_name:String,
        creator:address,
    ) acquires MokshyaStaking,MokshyaReward,ResourceInfo{
        let staker_addr = signer::address_of(staker);
        // verifying whether the creator has started the staking or not
        let staking_address = get_resource_address(creator, collection_name);
        assert!(exists<MokshyaStaking>(staking_address), ENO_NO_STAKING);// the staking doesn't exists
        let staking_data = borrow_global_mut<MokshyaStaking>(staking_address);
        let staking_treasur_signer_from_cap = account::create_signer_with_capability(&staking_data.treasury_cap);
        assert!(staking_data.state, ENO_STOPPED);
        let seed = collection_name;
        let seed2 = token_name;
        append(&mut seed,seed2);

        let reward_treasury_address = get_resource_address(staker_addr, seed);
        assert!(exists<MokshyaReward>(reward_treasury_address), ENO_STAKING_EXISTS);
        let reward_data = borrow_global_mut<MokshyaReward>(reward_treasury_address);
        assert!(reward_data.staker==staker_addr, ENO_STAKER_MISMATCH);
        let dpr = staking_data.dpr;
        let now = aptos_framework::timestamp::now_seconds();
        let reward = (((now-reward_data.start_time)*dpr)/86400) * reward_data.tokens;
        let release_amount = reward - reward_data.withdraw_amount;
        assert!(coin_address<CoinType>()==staking_data.coin_type,ENO_COINTYPE_MISMATCH);
        if (staking_data.amount<release_amount) {
            staking_data.state=false;
            assert!(staking_data.amount>release_amount,ENO_INSUFFICIENT_FUND);
        };
        if (!coin::is_account_registered<CoinType>(staker_addr)) {
            managed_coin::register<CoinType>(staker);
        };
        coin::transfer<CoinType>(&staking_treasur_signer_from_cap,staker_addr,release_amount);
        staking_data.amount = staking_data.amount - release_amount;
        reward_data.withdraw_amount = reward_data.withdraw_amount + release_amount;
    }
    public entry fun unstake_token<CoinType>(
        staker: &signer,
        creator: address,
        collection_name: String,
        token_name: String,
        property_version: u64,
        tokens: u64,
    ) acquires MokshyaStaking, MokshyaReward, ResourceInfo {
        let staker_addr = signer::address_of(staker);
        //verifying whether the creator has started the staking or not
        let staking_address = get_resource_address(creator, collection_name);
        assert!(exists<MokshyaStaking>(staking_address), ENO_NO_STAKING);// the staking doesn't exists
        let staking_data = borrow_global_mut<MokshyaStaking>(staking_address);
        let staking_treasur_signer_from_cap = account::create_signer_with_capability(&staking_data.treasury_cap);
        assert!(staking_data.state, ENO_STOPPED);
        let seed = collection_name;
        let seed2 = token_name;
        append(&mut seed,seed2);

        let reward_treasury_address = get_resource_address(staker_addr, seed);
        assert!(exists<MokshyaReward>(reward_treasury_address), ENO_STAKING_EXISTS);
        let reward_data = borrow_global_mut<MokshyaReward>(reward_treasury_address);
        let reward_treasury_signer_from_cap = account::create_signer_with_capability(&reward_data.treasury_cap);
        assert!(reward_data.staker == staker_addr, ENO_STAKER_MISMATCH);
        let dpr = staking_data.dpr;
        let now = aptos_framework::timestamp::now_seconds();
        let reward = ((now-reward_data.start_time)*dpr)/86400;
        let release_amount = reward - reward_data.withdraw_amount;
        assert!(coin_address<CoinType>()==staking_data.coin_type,ENO_COINTYPE_MISMATCH);
        if (staking_data.amount < release_amount) {
            staking_data.state = false;
        };
        if (staking_data.amount > release_amount) {
            if (!coin::is_account_registered<CoinType>(staker_addr)) {
                managed_coin::register<CoinType>(staker);
            };
            coin::transfer<CoinType>(&staking_treasur_signer_from_cap, staker_addr, release_amount);
            staking_data.amount = staking_data.amount - release_amount;
        };
        let token_id = token::create_token_id_raw(creator, collection_name, token_name, property_version);
        let balanceToken = balance_of(reward_treasury_address, token_id);
        assert!(balanceToken >= tokens,ENO_INSUFFICIENT_TOKENS); // insufficient tokens...
        direct_transfer(&reward_treasury_signer_from_cap, staker, token_id, tokens);
        if ( balanceToken > tokens) {
            reward_data.tokens = reward_data.tokens - tokens;
        };
        if ( balanceToken == tokens) {
            let dropdata = move_from<MokshyaReward>(reward_treasury_address);
            let MokshyaReward{
                staker: _,
                token_name: _,
                collection_name: _,
                withdraw_amount: _,
                treasury_cap: _,
                start_time: _,
                tokens: _,
            } = dropdata;
        };
    }

    // helper functions
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    fun create_add_resource_info(account:&signer, string:String, resource:address) acquires ResourceInfo {
        // resource: reward_treasury_address
        let account_addr = signer::address_of(account);
        if (!exists<ResourceInfo>(account_addr)) {
            move_to(account, ResourceInfo { resource_map: simple_map::create() })
        };
        let maps = borrow_global_mut<ResourceInfo>(account_addr);
        simple_map::add(&mut maps.resource_map, string, resource);
    }

    fun get_resource_address(addr: address, string: String): address acquires ResourceInfo {
        // string: `collection+token` , it works as key of a simple map.
        assert!(exists<ResourceInfo>(addr), ENO_NO_STAKING);
        let maps = borrow_global<ResourceInfo>(addr);
        let staking_address = *simple_map::borrow(&maps.resource_map, &string);
        staking_address
    }

    #[test_only] 
    use std::string;
    use std::bcs;
    use aptos_framework::timestamp;

    struct MokshyaMoney { }

    #[test(creator = @0xa11ce, receiver = @0xb0b, token_staking = @staking)]
    fun test_create_staking(creator: signer, receiver: signer, token_staking: signer)
      acquires ResourceInfo,MokshyaStaking{
       let sender_addr = signer::address_of(&creator);
       let receiver_addr = signer::address_of(&receiver);
        aptos_framework::account::create_account_for_test(sender_addr);
        aptos_framework::account::create_account_for_test(receiver_addr);
        // use `managed_coin` to issue coin. its name is b"Mokshya Money", like Bitcoin .
        aptos_framework::managed_coin::initialize<MokshyaMoney>(
            &token_staking,
            b"Mokshya Money",
            b"MOK",
            10,
            true
        );
        aptos_framework::managed_coin::register<MokshyaMoney>(&creator);
        aptos_framework::managed_coin::mint<MokshyaMoney>(&token_staking, sender_addr, 100);
        token::create_collection(
            &creator,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Collection for Test"),
            string::utf8(b"https://github.com/mokshyaprotocol"),
            2,
            vector<bool>[false, false, false],
        );
        let default_keys = vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")]; 
        let default_vals = vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)];
        let default_types = vector<String>[string::utf8(b"u64"), string::utf8(b"u64")];
        let mutate_setting = vector<bool>[false, false, false, false, false];
        token::create_token_script(
            &creator,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            string::utf8(b"Collection for Test"),
            2,
            5,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(&creator),
            100,
            0,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );

        let token_id = token::create_token_id_raw(
            signer::address_of(&creator),
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            0
        );
        let token = token::withdraw_token(&creator, token_id, 1);
        token::deposit_token(&receiver, token);
        create_staking<MokshyaMoney>(
               &creator,
               20,
               string::utf8(b"Mokshya Collection"),
               90
        );
        update_dpr(&creator,30, string::utf8(b"Mokshya Collection"), );
        creator_stop_staking( &creator,string::utf8(b"Mokshya Collection"), );
        deposit_staking_rewards<MokshyaMoney>(
            &creator,
            string::utf8(b"Mokshya Collection"),
            5
        );
        let resource_address= get_resource_address(sender_addr,string::utf8(b"Mokshya Collection"));
        let staking_data = borrow_global<MokshyaStaking>(resource_address);
        assert!(staking_data.state==false, 91);
        assert!(staking_data.dpr==30, 92);
        assert!(staking_data.amount==95, 91);
    }

    #[test(creator = @0xa11ce, receiver = @0xb0b, token_staking = @staking, framework = @0x1)]
    fun test_staking_token(
        creator: signer,
        receiver: signer,
        token_staking: signer,
        framework: signer,
    )acquires ResourceInfo,MokshyaStaking,MokshyaReward{
       let sender_addr = signer::address_of(&creator);
       let receiver_addr = signer::address_of(&receiver);
       // set up global time for testing purpose
        timestamp::set_time_has_started_for_testing(&framework);
       // create accounts 
        aptos_framework::account::create_account_for_test(sender_addr);
        aptos_framework::account::create_account_for_test(receiver_addr);
        // create reward coin
        aptos_framework::managed_coin::initialize<MokshyaMoney>(
            &token_staking,
            b"Mokshya Money",
            b"MOK",
            10,
            true
        );
        aptos_framework::managed_coin::register<MokshyaMoney>(&creator);
        aptos_framework::managed_coin::mint<MokshyaMoney>(&token_staking,sender_addr,100); 
        //create collection  
        token::create_collection(
            &creator,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Collection for Test"),
            string::utf8(b"https://github.com/mokshyaprotocol"),
            2,
            vector<bool>[false, false, false],
        );
        //token data
        let default_keys = vector<String>[string::utf8(b"attack"), string::utf8(b"num_of_use")]; 
        let default_vals = vector<vector<u8>>[bcs::to_bytes<u64>(&10), bcs::to_bytes<u64>(&5)];
        let default_types = vector<String>[string::utf8(b"u64"), string::utf8(b"u64")];
        let mutate_setting = vector<bool>[false, false, false, false, false];
        //create token
        token::create_token_script(
            &creator,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            string::utf8(b"Collection for Test"),
            2,
            5,
            string::utf8(b"https://aptos.dev"),
            signer::address_of(&creator),
            100,
            0,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let token_id= token::create_token_id_raw(signer::address_of(&creator), string::utf8(b"Mokshya Collection"),
        string::utf8(b"Mokshya Token #1"), 0);
        let token = token::withdraw_token(&creator, token_id, 1);
        token::deposit_token(&receiver, token);
        create_staking<MokshyaMoney>(
               &creator,
               20,
               string::utf8(b"Mokshya Collection"),
               90);
        stake_token(
            &receiver,
            sender_addr,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            0,
            1);
        let seed = string::utf8(b"Mokshya Collection");
        let seed2 = string::utf8(b"Mokshya Token #1");
        append(&mut seed,seed2);
        let reward_treasury_address = get_resource_address(receiver_addr,seed);
        assert!(balance_of(reward_treasury_address,token_id)==1,999);
        assert!(balance_of(receiver_addr,token_id)==0,99);
        claim_reward<MokshyaMoney>(
            &receiver,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            sender_addr,
        );
        unstake_token<MokshyaMoney>( 
            &receiver,
            sender_addr,
            string::utf8(b"Mokshya Collection"),
            string::utf8(b"Mokshya Token #1"),
            0,
            1);
        assert!(balance_of(receiver_addr,token_id)==1,89);
        assert!(balance_of(reward_treasury_address,token_id)==0,79);
        assert!(!exists<MokshyaReward>(reward_treasury_address),61);
    } 
}
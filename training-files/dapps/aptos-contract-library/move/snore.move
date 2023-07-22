module snore::snore{
    use std::signer;
    use std::string;
    use std::vector;
    use std::bcs;
    use aptos_std::table;
    use aptos_std::simple_map;
    use aptos_framework::coin;
    use aptos_std::type_info;
    use aptos_token::token;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::managed_coin;

    const INVALID_PARAMETER:u64 = 1;
    const INVALID_REWARD_TOKEN:u64 = 2;
    const INVALID_INSUFFICIENT_BALANCE:u64 = 3;
    const ALREADY_EXIST_POOL: u64 = 4;
    const INVALID_TOKEN: u64 = 5;
    const CAN_NOT_STAKE: u64 = 6;
    const NOT_STAKED: u64 = 7;
    const INVALID_PERMISSION: u64 = 8;
    const EXCEED_LENGTH_LIMIT:u64 = 9;
    const INVALID_ADMIN:u64 = 10;
    const ALREADY_EXIST_SNORE:u64 = 11;
    const INVALID_POOL_CREATOR:u64 = 12;
    const INVALID_COLLECTION:u64 = 13;

    const MODULE_SNORE: address = @snore;
    const FEE_ADDR: address = @fee;

    const FEE: u64 = 300000; // 0.003 APTOS
    const MAX_COLLECTION_DESC:u64 = 180;
    const MAX_LENGTH_URL: u64 = 200;

    struct SnorePoolList has key{
        current_id: u64,
        pool_id_list: vector<u64>,
        pool_table: table::Table<u64, SnorePool>, // maps domain to DomainInfo
    }

    struct SnorePool has store, drop{
        pool_creator: address,
        collection_creator: address,
        collection_name: string::String,
        collection_desc: string::String,
        collection_img_url: string::String,
        nft_total_count: u64,
        staking_amount: u64,
        staking_duration: u64, // days
        reward_per_day: u64, // per one NFT per day
        deposit_coin_amount: u64,
        reward_coin_name: string::String,
        twitter_url: string::String,
        discord_url: string::String,
        telegram_url: string::String,
        pool_addr: address,
        pool_signer_cap: account::SignerCapability,
        is_start: bool
    }

    struct SnoreStakeInfo has store, copy, drop {
        token_id: token::TokenId,
        staked_time: u64,  //in seconds
        claimed_time: u64, // in seconds
    }
    //for users
    struct SnoreStake has key{
        stake_infos: simple_map::SimpleMap<u64,vector<SnoreStakeInfo>>, //key: pool_id
        pool_id_list: vector<u64> // list of pool_id
    }

    public entry fun initSnore(admin: &signer){
       let admin_addr = signer::address_of(admin);
       assert!( admin_addr == MODULE_SNORE, INVALID_ADMIN);
       assert!(!exists<SnorePoolList>(admin_addr), ALREADY_EXIST_SNORE);

       if (!coin::is_account_registered<AptosCoin>(admin_addr)){
           managed_coin::register<AptosCoin>(admin);
       };

       move_to(admin, SnorePoolList{
         current_id: 0,
         pool_id_list: vector::empty(),
         pool_table: table::new<u64, SnorePool>(),
       });
    }

    public entry fun startPool<CoinType>(
        creator: &signer,
        collection_creator: address,
        collection_name: vector<u8>,
        collection_desc: vector<u8>,
        collection_img_url: vector<u8>,
        nft_total_count: u64,
        staking_duration: u64,
        reward_per_day: u64,
        deposit_coin_amount: u64,
        twitter_url: vector<u8>,
        discord_url: vector<u8>,
        telegram_url: vector<u8>,
    ) acquires SnorePoolList{

        assert!( staking_duration >0, INVALID_PARAMETER);
        assert!( reward_per_day >0, INVALID_PARAMETER);

        assert!( token::check_collection_exists(collection_creator, string::utf8(collection_name)), INVALID_COLLECTION);

        let creator_addr = signer::address_of(creator);
        let seed = bcs::to_bytes(&MODULE_SNORE);
        vector::append(&mut seed, bcs::to_bytes(&collection_creator));
        vector::append(&mut seed, collection_name);

        let (pool_signer, pool_signer_capability) = account::create_resource_account(creator, seed);

        assert!( coin::is_account_registered<CoinType>(creator_addr), INVALID_REWARD_TOKEN);
        assert!( coin::balance<CoinType>(creator_addr) >= deposit_coin_amount, INVALID_INSUFFICIENT_BALANCE);

        let needed_reward_amount = nft_total_count * reward_per_day * staking_duration / 86400;

        assert!(needed_reward_amount <= deposit_coin_amount, INVALID_INSUFFICIENT_BALANCE);
        let collection_desc_str = string::utf8(collection_desc);
        let collection_img_url_str = string::utf8(collection_img_url);
        let twitter_url_str = string::utf8(twitter_url);
        let discord_url_str = string::utf8(discord_url);
        let telegram_url_str = string::utf8(telegram_url);

        assert!(string::length(&collection_desc_str) <= MAX_COLLECTION_DESC, EXCEED_LENGTH_LIMIT);
        assert!(string::length(&collection_img_url_str) <= MAX_LENGTH_URL, EXCEED_LENGTH_LIMIT);
        assert!(string::length(&twitter_url_str) <= MAX_LENGTH_URL, EXCEED_LENGTH_LIMIT);
        assert!(string::length(&discord_url_str) <= MAX_LENGTH_URL, EXCEED_LENGTH_LIMIT);
        assert!(string::length(&telegram_url_str) <= MAX_LENGTH_URL, EXCEED_LENGTH_LIMIT);

        //token::initialize_token_script(&pool_signer);

        if (!coin::is_account_registered<CoinType>(signer::address_of(&pool_signer))){
	      managed_coin::register<CoinType>(&pool_signer);
        };

        //transfer reward_coin to Pool addr
        coin::transfer<CoinType>(creator, signer::address_of(&pool_signer), deposit_coin_amount);

        let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);

        let new_pool_id = snore_pool_list.current_id + 1;
        vector::push_back(&mut snore_pool_list.pool_id_list, new_pool_id);
        table::add(&mut snore_pool_list.pool_table, new_pool_id, SnorePool{
            pool_creator: creator_addr,
            collection_creator,
            collection_name: string::utf8(collection_name),
            collection_desc: collection_desc_str,
            collection_img_url: collection_img_url_str,
            nft_total_count,
            staking_amount: 0,
            staking_duration,
            reward_per_day,
            deposit_coin_amount,
            reward_coin_name: type_info::type_name<CoinType>(),
            twitter_url: twitter_url_str,
            discord_url: discord_url_str,
            telegram_url: telegram_url_str,
            pool_addr: signer::address_of(&pool_signer),
            pool_signer_cap: pool_signer_capability,
            is_start: true
        });
        snore_pool_list.current_id = snore_pool_list.current_id + 1;
    }

    public entry fun stake<CoinType>(
        user: &signer,
	    pool_id: u64,
        token_name: vector<u8>
    ) acquires SnorePoolList, SnoreStake {
        let user_addr = signer::address_of(user);

        let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);
	    let pool_info = table::borrow_mut(&mut snore_pool_list.pool_table, pool_id);

        let collection_creator = pool_info.collection_creator;
        let collection_name = pool_info.collection_name;
        let token_id = token::create_token_id_raw(
            collection_creator,
            collection_name,
            string::utf8(token_name),
            0
        );

        assert!( token::balance_of(user_addr, token_id) != 0, INVALID_TOKEN);

        if (!coin::is_account_registered<CoinType>(user_addr)){
            managed_coin::register<CoinType>(user);
        };

        let pool_signer = account::create_signer_with_capability(&pool_info.pool_signer_cap);
        assert!( pool_info.staking_amount < pool_info.nft_total_count, CAN_NOT_STAKE);
        assert!( pool_info.is_start, CAN_NOT_STAKE);
        assert!( pool_info.reward_coin_name == type_info::type_name<CoinType>(), INVALID_PARAMETER);

        if (exists<SnoreStake>(user_addr) ){
            let stake_data = borrow_global_mut<SnoreStake>(user_addr);
            if ( vector::contains<u64>(&stake_data.pool_id_list, &pool_id) ){
                let stake_infos = simple_map::borrow_mut(&mut stake_data.stake_infos, &pool_id);
                vector::push_back(stake_infos, SnoreStakeInfo{
                    token_id,
                    staked_time: timestamp::now_seconds(),
                    claimed_time: timestamp::now_seconds()
                });
            }else{
                vector::push_back(&mut stake_data.pool_id_list, pool_id);
                let stake_infos = vector::empty<SnoreStakeInfo>();
                vector::push_back(&mut stake_infos, SnoreStakeInfo{
                    token_id,
                    staked_time: timestamp::now_seconds(),
                    claimed_time: timestamp::now_seconds()
                });
                simple_map::add(&mut stake_data.stake_infos, pool_id, stake_infos);
            };
        } else{
            let stake_info_list = vector::empty<SnoreStakeInfo>();
            vector::push_back(&mut stake_info_list, SnoreStakeInfo{
                token_id,
                staked_time: timestamp::now_seconds(),
                claimed_time: timestamp::now_seconds()
            });
            let stake_infos = simple_map::create();
            simple_map::add(&mut stake_infos, pool_id, stake_info_list);
            let pool_id_list = vector::empty<u64>();
            vector::push_back(&mut pool_id_list, pool_id);

            move_to(user, SnoreStake{
                stake_infos,
                pool_id_list
            })
        };

        pool_info.staking_amount = pool_info.staking_amount + 1;
        //transfer NFT to Pool_Signer
        token::direct_transfer(user, &pool_signer, token_id, 1 );
        //fee
        coin::transfer<AptosCoin>(user, FEE_ADDR, FEE);
    }

    public entry fun unstake<CoinType>(
        user: &signer,
        pool_id: u64,
        token_name: vector<u8>
    ) acquires SnorePoolList, SnoreStake {
        let user_addr = signer::address_of(user);

        let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);
        let pool_info = table::borrow_mut(&mut snore_pool_list.pool_table, pool_id);

        let collection_creator = pool_info.collection_creator;
        let collection_name = pool_info.collection_name;

        let pool_signer = account::create_signer_with_capability(&pool_info.pool_signer_cap);
        let token_id = token::create_token_id_raw(
            collection_creator,
            collection_name,
            string::utf8(token_name),
            0
        );
        assert!( exists<SnoreStake>(user_addr), NOT_STAKED );
        assert!( pool_info.reward_coin_name == type_info::type_name<CoinType>(), INVALID_PARAMETER);

        if (!coin::is_account_registered<CoinType>(user_addr)){
            managed_coin::register<CoinType>(user);
        };

        let stake_data = borrow_global_mut<SnoreStake>(user_addr);

        let stake_infos = simple_map::borrow_mut(&mut stake_data.stake_infos, &pool_id);
        let len = vector::length(stake_infos);
        let i = 0;
        let token_index = 0;
        let token_staked = false;
        while( i < len ){
            let stake_info = vector::borrow(stake_infos, i);
            if (stake_info.token_id == token_id){
                token_staked = true;
                token_index = i;
                break
            };
            i = i + 1;
        };
        assert!(token_staked, NOT_STAKED);
        let stake_info = vector::borrow(stake_infos,token_index);

        let now_seconds = timestamp::now_seconds();

        let interval =
            if (stake_info.staked_time + pool_info.staking_duration < now_seconds){
                stake_info.staked_time + pool_info.staking_duration - stake_info.claimed_time
            }else{
                now_seconds - stake_info.claimed_time
            };

        //transfer reward token
        let reward_amount = interval * (pool_info.reward_per_day) / 86400;
        if (reward_amount >0){
            coin::transfer<CoinType>(&pool_signer, user_addr, reward_amount);
        };

        //remove stake info
        vector::remove(stake_infos, token_index);
        //transfer NFt from Pool to User
        token::direct_transfer(&pool_signer, user, token_id, 1 );
        //fee
        coin::transfer<AptosCoin>(user, MODULE_SNORE, FEE);

        pool_info.staking_amount = pool_info.staking_amount - 1;
    }

    public entry fun claim<CoinType>(
        user: &signer,
        pool_id: u64,
    ) acquires SnorePoolList, SnoreStake{
        let user_addr = signer::address_of(user);

    	let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);
	    let pool_info = table::borrow_mut(&mut snore_pool_list.pool_table, pool_id);

        let pool_signer = account::create_signer_with_capability(&pool_info.pool_signer_cap);
        assert!( exists<SnoreStake>(user_addr), NOT_STAKED );
        assert!( pool_info.reward_coin_name == type_info::type_name<CoinType>(), INVALID_PARAMETER);

        if (!coin::is_account_registered<CoinType>(user_addr)){
            managed_coin::register<CoinType>(user);
        };

        let stake_data = borrow_global_mut<SnoreStake>(user_addr);
        let stake_infos = simple_map::borrow_mut(&mut stake_data.stake_infos, &pool_id);

        let stake_count = vector::length(stake_infos);
        let i: u64 = 0;
        let total_reward_amount: u64 = 0;
        let now_seconds = timestamp::now_seconds();

        // let new_updated_time = vector::empty<u64>();

        while (i < stake_count) {
            // let update_time = vector::borrow<u64>(&mut stake_data.update_time, i);
            let stake_info = vector::borrow_mut(stake_infos, i);
            let claimed_time = stake_info.claimed_time;
            let staked_time = stake_info.staked_time;

            let interval =
            if (staked_time + pool_info.staking_duration < now_seconds){
                stake_info.claimed_time = staked_time + pool_info.staking_duration;
                staked_time + pool_info.staking_duration - claimed_time
            }else{
                stake_info.claimed_time = now_seconds;
                now_seconds - claimed_time
            };
            
            total_reward_amount = total_reward_amount + interval * pool_info.reward_per_day / 86400;
            i = i + 1;
        };
        if (total_reward_amount> 0){
            coin::transfer<CoinType>(&pool_signer, user_addr, total_reward_amount);
        };
        //fee
        coin::transfer<AptosCoin>(user, MODULE_SNORE, FEE);
    }

    public entry fun stop_staking(creator: &signer, pool_id: u64) acquires SnorePoolList {
        let creator_addr = signer::address_of(creator);
        let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);
	    let pool_info = table::borrow_mut(&mut snore_pool_list.pool_table, pool_id);
	    assert!(pool_info.pool_creator == creator_addr || creator_addr == MODULE_SNORE, INVALID_POOL_CREATOR);
        pool_info.is_start = false;
    }

    public entry fun withdraw_from_pool<CoinType>(
        admin: &signer,
        pool_id: u64,
        amount: u64
    ) acquires SnorePoolList {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == MODULE_SNORE, INVALID_ADMIN);
        let snore_pool_list = borrow_global_mut<SnorePoolList>(MODULE_SNORE);
	    let pool_info = table::borrow_mut(&mut snore_pool_list.pool_table, pool_id);
        let pool_signer = account::create_signer_with_capability(&pool_info.pool_signer_cap);

        if (!coin::is_account_registered<CoinType>(admin_addr)){
            managed_coin::register<CoinType>(admin);
        };
        coin::transfer<CoinType>(&pool_signer, admin_addr, amount);
    }

   #[test_only]
   public fun get_resource_account(pool_id: u64): signer acquires SnorePoolList {
      let snore_pool_list = borrow_global<SnorePoolList>(MODULE_SNORE);
      let pool_info = table::borrow(&snore_pool_list.pool_table, pool_id);
      account::create_signer_with_capability(&pool_info.pool_signer_cap)
   }
}

```rust

module beast_collector::beast_exploration {
    use std::error;
    use aptos_framework::coin::{Self};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};    
    use beast_collector::utils;    
    use beast_collector::beast_generator;    
    use std::signer;    
    
    use std::string::{Self, String};    
    use aptos_token::token::{Self};     
    use aptos_token::property_map::{Self};    
    use aptos_framework::guid;
    use aptos_framework::account;

    const ENOT_AUTHORIZED:u64 = 1;
    const EREQUIRED_EVOLUTION: u64 = 2;

    const BEAST_COLLECTION_NAME:vector<u8> = b"W&W Beast";            

    const BEAST_EXP: vector<u8> = b"W_EXP";
    const BEAST_LEVEL: vector<u8> = b"W_LEVEL";
    const BEAST_RARITY: vector<u8> = b"W_RARITY"; // very common(1),Common(2), Rare(3), Very Rare(4), Epic (5), Legendary(6), Mythic(7)
    const BEAST_EVO_STAGE: vector<u8> = b"W_EVO_STAGE"; // 1 , 2, 3
    const BEAST_DUNGEON_TIME: vector<u8> = b"W_DUNGEON_TIME";
    const BEAST_BREEDING_TIME: vector<u8> = b"W_BREEDING";
    const BEAST_EVOLUTION_TIME: vector<u8> = b"W_EVOLUTION";      

    struct Exploration has store, key {          
        signer_cap: account::SignerCapability,        
        jackpot_events: EventHandle<JackpotEvent>,
    }        

    struct JackpotEvent has drop, store {
        lucky_guy: address,        
    }

    fun get_resource_account_cap(exp_address : address) : signer acquires Exploration {
        let launchpad = borrow_global<Exploration>(exp_address);
        account::create_signer_with_capability(&launchpad.signer_cap)
    }

    entry fun admin_deposit<CoinType>(sender: &signer, amount: u64,        
        ) acquires Exploration {                
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                        
        let coins = coin::withdraw<CoinType>(sender, amount);        
        coin::deposit(signer::address_of(&resource_signer), coins);   
    }

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires Exploration {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    entry fun init<WarCoinType>(sender: &signer) {
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"09");
        if(!exists<Exploration>(sender_addr)){            
            move_to(sender, Exploration {                
                signer_cap,
                jackpot_events: account::new_event_handle<JackpotEvent>(sender),                
            });
        };
        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };
    }   

    entry fun beast_exploration<WarCoinType>(
        receiver: &signer, beast_token_name: String, _beast_token_creator:address, property_version:u64, exporation_address:address,
        ) acquires Exploration {
        if(!coin::is_account_registered<WarCoinType>(signer::address_of(receiver))){
            coin::register<WarCoinType>(receiver);
        };
        let coin_address = utils::coin_address<WarCoinType>();
        assert!(coin_address == @war_coin, error::permission_denied(ENOT_AUTHORIZED));
        let token_id = token::create_token_id_raw(@beast_creator, string::utf8(BEAST_COLLECTION_NAME), beast_token_name, property_version);        
        let resource_signer = get_resource_account_cap(exporation_address);
        let pm = token::get_property_map(signer::address_of(receiver), token_id);
        let guid = account::create_guid(&resource_signer);        
        let uuid = guid::creation_num(&guid);        
        let random_exp = utils::random_with_nonce(signer::address_of(&resource_signer), 30, uuid) + 1;                                     

        let coins = coin::withdraw<WarCoinType>(&resource_signer, 50000000); // 0.5 WAR
        coin::deposit(signer::address_of(receiver), coins);        
        let ex_time = property_map::read_u64(&pm, &string::utf8(BEAST_DUNGEON_TIME));
        assert!(ex_time < timestamp::now_seconds(), error::permission_denied(ENOT_AUTHORIZED));
        beast_generator::add_exp(receiver, &resource_signer, @beast_gen_address, token_id, random_exp);
    }

    entry fun beast_exploration_2<WarCoinType>(
        receiver: &signer, 
        beast_token_name:String, _beast_token_creator:address, property_version:u64, 
        exporation_address:address) acquires Exploration {            
        let token_id = token::create_token_id_raw(@beast_creator,string::utf8(BEAST_COLLECTION_NAME), beast_token_name, property_version);        
        let pm = token::get_property_map(signer::address_of(receiver), token_id);
        let evo_stage = property_map::read_u64(&pm, &string::utf8(BEAST_EVO_STAGE));
        assert!(evo_stage > 1, error::permission_denied(EREQUIRED_EVOLUTION));
        let resource_signer = get_resource_account_cap(exporation_address);
        let coin_address = utils::coin_address<WarCoinType>();
        assert!(coin_address == @war_coin, error::permission_denied(ENOT_AUTHORIZED));
        let price_to_pay = 100000000; // 1 WAR Coin
        let coins_to_pay = coin::withdraw<WarCoinType>(receiver, price_to_pay);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);
        
        let resource_signer = get_resource_account_cap(exporation_address);        
        let guid = account::create_guid(&resource_signer);        
        let uuid = guid::creation_num(&guid);        
        let random_exp = utils::random_with_nonce(signer::address_of(&resource_signer), 30, uuid) + 1;        
        // earning
        let earned = utils::random_with_nonce(signer::address_of(&resource_signer), 3, uuid) + 1;
        let coins = coin::withdraw<WarCoinType>(&resource_signer, earned * 100000000);                
        coin::deposit(signer::address_of(receiver), coins);
        
        // jackpot number = 777
        let random_idx = utils::random_with_nonce(signer::address_of(&resource_signer), 1000, uuid) + 1;
        if(random_idx == 777) {
            let coins = coin::withdraw<WarCoinType>(&resource_signer, 1000 * 100000000);                
            coin::deposit(signer::address_of(receiver), coins);
            let game_events = borrow_global_mut<Exploration>(exporation_address);               
            event::emit_event(&mut game_events.jackpot_events, JackpotEvent {            
                lucky_guy: signer::address_of(receiver),                
            });
        };        

        let ex_time = property_map::read_u64(&pm, &string::utf8(BEAST_DUNGEON_TIME));        
        assert!(ex_time < timestamp::now_seconds(), error::permission_denied(ENOT_AUTHORIZED));
        beast_generator::add_exp(receiver, &resource_signer, @beast_gen_address, token_id, random_exp);        
    }

    entry fun beast_exploration_3<WarCoinType>(
        receiver: &signer, 
        beast_token_name:String, _beast_token_creator:address, property_version:u64, 
        exporation_address:address) acquires Exploration {
            
        let token_id = token::create_token_id_raw(@beast_creator,string::utf8(BEAST_COLLECTION_NAME), beast_token_name, property_version);        
        let pm = token::get_property_map(signer::address_of(receiver), token_id);
        let evo_stage = property_map::read_u64(&pm, &string::utf8(BEAST_EVO_STAGE));
        assert!(evo_stage > 2, error::permission_denied(EREQUIRED_EVOLUTION));
        let resource_signer = get_resource_account_cap(exporation_address);
        let coin_address = utils::coin_address<WarCoinType>();
        assert!(coin_address == @war_coin, error::permission_denied(ENOT_AUTHORIZED));
        let price_to_pay = 200000000; // 2 WAR Coin
        let coins_to_pay = coin::withdraw<WarCoinType>(receiver, price_to_pay);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);
        
        let resource_signer = get_resource_account_cap(exporation_address);        
        let guid = account::create_guid(&resource_signer);        
        let uuid = guid::creation_num(&guid);        
        let random_exp = utils::random_with_nonce(signer::address_of(&resource_signer), 30, uuid) + 1;        
        // earning
        let earned = utils::random_with_nonce(signer::address_of(&resource_signer), 6, uuid) + 1;
        let coins = coin::withdraw<WarCoinType>(&resource_signer, earned * 100000000);                
        coin::deposit(signer::address_of(receiver), coins);
        
        // jackpot number = 777
        let random_idx = utils::random_with_nonce(signer::address_of(&resource_signer), 1000, uuid) + 1;
        if(random_idx == 777) {
            let coins = coin::withdraw<WarCoinType>(&resource_signer, 1000 * 100000000);                
            coin::deposit(signer::address_of(receiver), coins);
            let game_events = borrow_global_mut<Exploration>(exporation_address);               
            event::emit_event(&mut game_events.jackpot_events, JackpotEvent {            
                lucky_guy: signer::address_of(receiver),                
            });
        };        
        let ex_time = property_map::read_u64(&pm, &string::utf8(BEAST_DUNGEON_TIME));        
        assert!(ex_time < timestamp::now_seconds(), error::permission_denied(ENOT_AUTHORIZED));
        beast_generator::add_exp(receiver, &resource_signer, @beast_gen_address, token_id, random_exp);        
    }    
}

```
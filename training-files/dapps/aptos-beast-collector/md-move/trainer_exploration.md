```rust

module beast_collector::trainer_exploration {
    use std::error;
    use aptos_framework::timestamp;
    use beast_collector::utils;
    use beast_collector::trainer_generator;
    use beast_collector::egg_generator;
    use std::signer;    
    use std::string::{Self, String};    
    use aptos_token::token::{Self};     
    use aptos_token::property_map::{Self};    
    use aptos_framework::guid;
    use aptos_framework::account;

    const TRAINER_COLLECTION_NAME:vector<u8> = b"W&W Beast Collector";
    
    const PROPERTY_EXP: vector<u8> = b"W_EXP"; // 100 MAX, 100 EXP => 1 LEVEL UP
    const PROPERTY_LEVEL: vector<u8> = b"W_LEVEL"; // 5 LEVEL MAX, 5 LEVEL with 100 EXP can upgrade GRADE of trainer
    const PROPERTY_NEXT_EXPLORATION_TIME: vector<u8> = b"W_NEXT_EXPLORATION_TIME";
    const PROPERTY_GRADE: vector<u8> = b"W_GRADE"; // Trainer(1) / Pro Trainer(2) / Semi champion(3) / World champion(4) / Master (5) 

    const ENOT_AUTHORIZED:u64 = 1;

    struct Exploration has store, key {          
        signer_cap: account::SignerCapability,        
    }
        

    fun get_resource_account_cap(exp_address : address) : signer acquires Exploration {
        let launchpad = borrow_global<Exploration>(exp_address);
        account::create_signer_with_capability(&launchpad.signer_cap)
    }

    entry fun init(sender: &signer) {
        let sender_addr = signer::address_of(sender);                
        let (_resource_signer, signer_cap) = account::create_resource_account(sender, x"03");                                
        if(!exists<Exploration>(sender_addr)){            
            move_to(sender, Exploration {                
                signer_cap,                
            });
        };
    }   

    entry fun trainer_exploration<CoinType>(receiver: &signer, 
        trainer_token_name:String, trainer_creator:address, property_version:u64, exporation_address:address, egg_contract:address, 
        trainer_contract:address) acquires Exploration {
        assert!(trainer_creator == @trainer_creator, error::permission_denied(ENOT_AUTHORIZED));
        let token_id = token::create_token_id_raw(trainer_creator, string::utf8(TRAINER_COLLECTION_NAME), trainer_token_name, property_version);        
        let resource_signer = get_resource_account_cap(exporation_address);
        let pm = token::get_property_map(signer::address_of(receiver), token_id);        
        let grade = property_map::read_u64(&pm, &string::utf8(PROPERTY_GRADE));
        let ex_time = property_map::read_u64(&pm, &string::utf8(PROPERTY_NEXT_EXPLORATION_TIME));
        assert!(ex_time < timestamp::now_seconds(), error::permission_denied(ENOT_AUTHORIZED));
        assert!(grade < 6 && grade > 0, error::permission_denied(ENOT_AUTHORIZED));
        // Trainer(1) / Pro Trainer(2) / Semi champion(3) / World champion(4) / Master (5) 
        let percentage = if(grade == 1) {
            65
        } else if (grade == 2) {
            70
        } else if (grade == 3) {
            75
        } else if (grade == 4) {
            80
        } else if (grade == 5){
            85
        } else {
            10
        };
        let guid = account::create_guid(&resource_signer);        
        let uuid = guid::creation_num(&guid);        
        let random_idx = utils::random_with_nonce(signer::address_of(&resource_signer), 100, uuid) + 1;
        let random_exp = utils::random_with_nonce(signer::address_of(&resource_signer), 20, uuid + 1) + 1;
        trainer_generator::add_exp(receiver, &resource_signer, trainer_contract, token_id, random_exp);                
        if(random_idx < percentage) {
            // get egg receiver: &signer, auth: &signer, minter_address:address, token_name:String, egg_type: u64            
            let random_eggcount = utils::random_with_nonce(signer::address_of(&resource_signer), 2, uuid + 2) + 1;
            let i = 0;
            while(i < random_eggcount) {
                let random_rarity = utils::random_with_nonce(signer::address_of(receiver), 3, i + 1) + 1;
                egg_generator::mint_egg(receiver, &resource_signer, egg_contract, random_rarity); 
                i = i + 1;                
            }
        };                                        
    }

    entry fun trainer_exploration_2<CoinType>(receiver: &signer, 
        trainer_token_name:String, trainer_creator:address, property_version:u64, exporation_address:address, egg_contract:address, 
        trainer_contract:address) acquires Exploration {
        assert!(trainer_creator == @trainer_creator, error::permission_denied(ENOT_AUTHORIZED));        
        let token_id = token::create_token_id_raw(trainer_creator, string::utf8(TRAINER_COLLECTION_NAME), trainer_token_name, property_version);        
        let resource_signer = get_resource_account_cap(exporation_address);

        let pm = token::get_property_map(signer::address_of(receiver), token_id);
        
        let grade = property_map::read_u64(&pm, &string::utf8(PROPERTY_GRADE));
        let ex_time = property_map::read_u64(&pm, &string::utf8(PROPERTY_NEXT_EXPLORATION_TIME));
        assert!(ex_time < timestamp::now_seconds(), error::permission_denied(ENOT_AUTHORIZED));
        assert!(grade > 2 && grade < 6, error::permission_denied(ENOT_AUTHORIZED));
        let percentage = if(grade == 1) {
            65
        } else if (grade == 2) {
            70
        } else if (grade == 3) {
            75
        } else if (grade == 4) {
            80
        } else if (grade == 5) {
            85
        } else {
            30
        };
        let guid = account::create_guid(&resource_signer);        
        let uuid = guid::creation_num(&guid);        
        let random_idx = utils::random_with_nonce(signer::address_of(&resource_signer), 100, uuid) + 1;
        let random_exp = utils::random_with_nonce(signer::address_of(&resource_signer), 20, uuid + 1) + 1;
        trainer_generator::add_exp(receiver, &resource_signer, trainer_contract, token_id, random_exp);                          
        if(random_idx < percentage) {                        
            let random_eggcount = utils::random_with_nonce(signer::address_of(&resource_signer), 5, uuid + 2) + 1;
            let i = 0;
            while(i < random_eggcount) {                
                let random_rarity = utils::random_with_nonce(signer::address_of(receiver), 3, i + 1) + 1;
                egg_generator::mint_egg(receiver,&resource_signer, egg_contract, random_rarity); 
                i = i + 1;
            }
        };                                        
    }
}

```
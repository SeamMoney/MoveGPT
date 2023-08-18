```rust

module beast_collector::launchpad {
    
    use std::signer;    
    use std::error;
    use aptos_framework::timestamp;    
    use aptos_framework::coin::{Self};
    use aptos_framework::event::{Self, EventHandle};        
    use aptos_framework::account;    
    use aptos_framework::guid;
    use beast_collector::utils;
    use beast_collector::trainer_generator;    

    const MAX_AMOUNT:u64 = 1000;
    const APT_PRICE:u64 = 50000000;
    const WAR_PRICE:u64 = 50000000000;    

    const ENOT_AUTHORIZED:u64 = 0;
    const ENOT_OPENED: u64 = 1; 
    const EMAX_AMOUNT: u64 = 2;   
    const ENO_SUFFICIENT_FUND: u64 = 3;
    

    struct LaunchPad has store, key {          
        signer_cap: account::SignerCapability,
        launchpad_public_open:u64,        
        max_amount:u64,
        minted_count:u64,
        minted_events:EventHandle<MintedEvent>,                                           
    }
    
    struct MintedEvent has drop, store {        
        minted_count: u64
    }  

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires LaunchPad {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires LaunchPad {
        let launchpad = borrow_global<LaunchPad>(minter_address);
        account::create_signer_with_capability(&launchpad.signer_cap)
    }

    entry fun init<AptosCoin, WarCoinType>(sender: &signer, launchpad_public_open:u64) {
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"02");        
        if(!exists<LaunchPad>(sender_addr)){            
            move_to(sender, LaunchPad {                
                signer_cap,
                launchpad_public_open:launchpad_public_open,
                max_amount:MAX_AMOUNT,
                minted_count: 0,
                minted_events:account::new_event_handle<MintedEvent>(sender)                
            });
        };

        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };

        if(!coin::is_account_registered<AptosCoin>(signer::address_of(&resource_signer))){
            coin::register<AptosCoin>(&resource_signer);
        };
        
    }     

    entry fun mint_trainer<CoinType>(receiver: &signer, launchpad_address:address, trainer_generator:address) acquires LaunchPad {        
        let receiver_addr = signer::address_of(receiver);
        let resource_signer = get_resource_account_cap(launchpad_address);
        // check war coin or aptos        
        let coin_address = utils::coin_address<CoinType>();
        assert!(coin_address == @war_coin || coin_address == @aptos_coin, error::permission_denied(ENOT_AUTHORIZED));
        let is_war_coin = if(coin_address == @war_coin) { true } else { false };
        // check open time
        let launchpad = borrow_global_mut<LaunchPad>(launchpad_address);
        assert!(timestamp::now_seconds() > launchpad.launchpad_public_open, ENOT_OPENED);
        assert!(launchpad.minted_count <= launchpad.max_amount, EMAX_AMOUNT);
        // payment
        let price_to_pay = if(is_war_coin) { WAR_PRICE } else { APT_PRICE };
        assert!(coin::balance<CoinType>(receiver_addr) >= price_to_pay, error::invalid_argument(ENO_SUFFICIENT_FUND));
        let coins_to_pay = coin::withdraw<CoinType>(receiver, price_to_pay);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);
        // use resource account address for authentication                    
        let guid = account::create_guid(&resource_signer);
        let uuid = guid::creation_num(&guid);
        let random_idx = utils::random_with_nonce(receiver_addr, 1000, uuid) + 1;
        let grade = if(random_idx < 800) { // 80%
            1
        } else if (random_idx >= 800 && random_idx < 930) { // 13%
            2
        } else if (random_idx >= 930 && random_idx < 970) { // 5%
            3
        } else if (random_idx >= 970 && random_idx < 990) { // 2%
            4
        } else {  // 1%
            5
        };  
        trainer_generator::mint_trainer(receiver, &resource_signer, trainer_generator, grade);
        launchpad.minted_count = launchpad.minted_count + 1; 
        
        event::emit_event(&mut launchpad.minted_events, MintedEvent { 
            minted_count: launchpad.minted_count,            
        });               
    } 

    entry fun bulk_mint<CoinType>(receiver: &signer, launchpad_address:address,trainer_generator:address, amount: u64) acquires LaunchPad {
        let receiver_addr = signer::address_of(receiver);
        let resource_signer = get_resource_account_cap(launchpad_address);
        let coin_address = utils::coin_address<CoinType>();
        assert!(coin_address == @war_coin || coin_address == @aptos_coin, error::permission_denied(ENOT_AUTHORIZED));
        let is_war_coin = if(coin_address == @war_coin) { true } else { false };
        let ind = 1;
        assert!(amount > 1 && amount < 101, error::permission_denied(ENOT_AUTHORIZED));        
        let launchpad = borrow_global_mut<LaunchPad>(launchpad_address);
        assert!(timestamp::now_seconds() > launchpad.launchpad_public_open, ENOT_OPENED);
        assert!(launchpad.minted_count + amount <= launchpad.max_amount, EMAX_AMOUNT);
        let price_to_pay = if(is_war_coin) { WAR_PRICE } else { APT_PRICE };
        assert!(coin::balance<CoinType>(receiver_addr) >= price_to_pay * amount, error::invalid_argument(ENO_SUFFICIENT_FUND));
        let coins_to_pay = coin::withdraw<CoinType>(receiver, price_to_pay * amount);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);
        while (ind <= amount) {
            mint_trainer_native<CoinType>(receiver, launchpad_address, trainer_generator, ind);
            ind = ind + 1;
        };        
    }

    fun mint_trainer_native<CoinType>(receiver: &signer, launchpad_address:address, trainer_generator:address, index:u64) acquires LaunchPad {                                    
        let receiver_addr = signer::address_of(receiver);
        let resource_signer = get_resource_account_cap(launchpad_address);
        let guid = account::create_guid(&resource_signer);
        let uuid = guid::creation_num(&guid);
        let random_idx = utils::random_with_nonce(receiver_addr, 1000, uuid + index) + 1;
        let grade = if(random_idx < 800) { // 80%
            1
        } else if (random_idx >= 800 && random_idx < 930) { // 13%
            2
        } else if (random_idx >= 930 && random_idx < 970) { // 5%
            3
        } else if (random_idx >= 970 && random_idx < 990) { // 2%
            4
        } else {  // 1%
            5
        };  
        let launchpad = borrow_global_mut<LaunchPad>(launchpad_address);
        trainer_generator::mint_trainer(receiver, &resource_signer, trainer_generator, grade);
        launchpad.minted_count = launchpad.minted_count + 1;         
        event::emit_event(&mut launchpad.minted_events, MintedEvent { 
            minted_count: launchpad.minted_count,            
        });               
    }                     
}

```
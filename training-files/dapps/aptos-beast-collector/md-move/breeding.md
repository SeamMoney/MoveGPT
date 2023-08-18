```rust

module beast_collector::breeding {
    
    use std::signer;    
    use std::error;
    use std::string::{Self, String}; 
    use aptos_framework::timestamp;    
    use aptos_framework::coin::{Self};           
    use aptos_token::property_map::{Self};
    use aptos_token::token::{Self}; 
    use aptos_framework::account;
    use beast_collector::utils;        

    use beast_collector::beast_generator;       
    use beast_collector::egg_generator::{Self};    

    const ENOT_AUTHORIZED:u64 = 0;        

    const BEAST_COLLECTION_NAME:vector<u8> = b"W&W Beast";    

    const BEAST_BREEDING_TIME: vector<u8> = b"W_BREEDING";
    const BEAST_RARITY: vector<u8> = b"W_RARITY"; // very common(1),Common(2), Rare(3), Very Rare(4), Epic (5), Legendary(6), Mythic(7)

    struct Breeding has store, key {          
        signer_cap: account::SignerCapability,                
    }    

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires Breeding {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires Breeding {
        let launchpad = borrow_global<Breeding>(minter_address);
        account::create_signer_with_capability(&launchpad.signer_cap)
    }

    entry fun init<WarCoinType>(sender: &signer) {
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"07");        
        if(!exists<Breeding>(sender_addr)){            
            move_to(sender, Breeding {                
                signer_cap,                
            });
        };

        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };        
    } 
    
    entry fun breeding<WarCoinType>(
        holder: &signer, breed_address: address,
        token_name_1:String, property_version_1:u64,
        token_name_2:String, property_version_2:u64
    ) acquires Breeding {        
        let resource_signer = get_resource_account_cap(breed_address);                        
        let token_id_1 = token::create_token_id_raw(@beast_creator, string::utf8(BEAST_COLLECTION_NAME), token_name_1, property_version_1);        
        let token_id_2 = token::create_token_id_raw(@beast_creator, string::utf8(BEAST_COLLECTION_NAME), token_name_2, property_version_2);        
        let pm = token::get_property_map(signer::address_of(holder), token_id_1);        
        let pm2 = token::get_property_map(signer::address_of(holder), token_id_2);        
        let breed_expired_time_1 = property_map::read_u64(&pm, &string::utf8(BEAST_BREEDING_TIME));
        let breed_expired_time_2 = property_map::read_u64(&pm2, &string::utf8(BEAST_BREEDING_TIME));
        
        let coin_address = utils::coin_address<WarCoinType>();
        assert!(coin_address == @war_coin, error::permission_denied(ENOT_AUTHORIZED));
        let price_to_pay = 1000000000; // 10 WAR Coin
        let coins_to_pay = coin::withdraw<WarCoinType>(holder, price_to_pay);
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);

        let rarity_1 = property_map::read_u64(&pm, &string::utf8(BEAST_RARITY));
        let rarity_2 = property_map::read_u64(&pm2, &string::utf8(BEAST_RARITY));
        let small_rarity = if(rarity_1 > rarity_2) { rarity_2 } else { rarity_1 };
        if (small_rarity < 5) {
            egg_generator::mint_egg(holder, &resource_signer, @egg_gen_address, 1);
        } else {
            egg_generator::mint_egg(holder, &resource_signer, @egg_gen_address, 2);
        };
        let now_seconds = timestamp::now_seconds();
        assert!(breed_expired_time_1 < now_seconds, error::permission_denied(ENOT_AUTHORIZED));
        assert!(breed_expired_time_2 < now_seconds, error::permission_denied(ENOT_AUTHORIZED));                
        beast_generator::extend_breeding_time (holder, &resource_signer, @beast_gen_address, token_id_1);
        beast_generator::extend_breeding_time (holder, &resource_signer, @beast_gen_address, token_id_2);
    }


}

```
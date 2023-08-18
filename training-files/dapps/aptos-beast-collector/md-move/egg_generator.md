```rust

module beast_collector::egg_generator {    
    use std::bcs;
    use std::signer;    
    use std::string::{Self, String};    
    use aptos_framework::account;    
    use aptos_token::token::{Self};
    use beast_collector::acl::{Self};    
    use aptos_framework::coin;        
    use std::option::{Self};    
    use beast_collector::utils;
    use aptos_framework::event::{Self, EventHandle};    

    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";    
    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    const TOKEN_PROPERTY_MUTABLE: vector<u8> = b"TOKEN_PROPERTY_MUTATBLE";    

    const FEE_DENOMINATOR: u64 = 100000;    

    // collection name / info
    const EGG_COLLECTION_NAME:vector<u8> = b"W&W EGG";
    const COLLECTION_DESCRIPTION:vector<u8> = b"https://beast.werewolfandwitch.xyz/ / Eggs are the key to obtaining Beasts through hatching. There exists a diverse array of eggs, each representing a different species or variation. Rare eggs hold the promise of acquiring even rarer and more extraordinary Beasts. ";
    
    const PROPERTY_RARITY: vector<u8> = b"W_RARITY"; // (Common(1) / Rare(2) / Epic (3))

    struct EggManager has store, key {          
        signer_cap: account::SignerCapability,                 
        acl: acl::ACL,
        acl_events:EventHandle<AclAddEvent>,
    }

    struct AclAddEvent has drop, store {
        added: address,        
    }


    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires EggManager {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires EggManager {
        let minter = borrow_global<EggManager>(minter_address);
        account::create_signer_with_capability(&minter.signer_cap)
    }    

    entry fun add_acl(sender: &signer, address_to_add:address) acquires EggManager  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<EggManager>(sender_addr);        
        acl::add(&mut manager.acl, address_to_add);
        event::emit_event(&mut manager.acl_events, AclAddEvent { 
            added: address_to_add,            
        });        
    }

    entry fun remove_acl(sender: &signer, address_to_remove:address) acquires EggManager  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<EggManager>(sender_addr);        
        acl::remove(&mut manager.acl, address_to_remove);        
    }
    
    // resource cab required 
    entry fun init(sender: &signer) acquires EggManager {
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"04");    
        token::initialize_token_store(&resource_signer);
        if(!exists<EggManager>(sender_addr)){            
            move_to(sender, EggManager {                
                signer_cap,  
                acl: acl::empty(),
                acl_events:account::new_event_handle<AclAddEvent>(sender)
            });
        };                
        let mutate_setting = vector<bool>[ true, true, true ]; // TODO should check before deployment.
        // egg
        let collection_uri = string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/egg/egg_epic.png");
        token::create_collection(&resource_signer, 
            string::utf8(EGG_COLLECTION_NAME), 
            string::utf8(COLLECTION_DESCRIPTION), 
            collection_uri, 99999, mutate_setting);                
        let manager = borrow_global_mut<EggManager>(sender_addr);             
        acl::add(&mut manager.acl, sender_addr);
        event::emit_event(&mut manager.acl_events, AclAddEvent { 
            added: sender_addr,            
        });        
    }        

    public fun mint_egg (
        receiver: &signer, auth: &signer, egg_minter_address:address, egg_type: u64
    ) acquires EggManager {             
        let auth_address = signer::address_of(auth);
        let manager = borrow_global<EggManager>(egg_minter_address);
        acl::assert_contains(&manager.acl, auth_address);                           
        let resource_signer = get_resource_account_cap(egg_minter_address);                
        let resource_account_address = signer::address_of(&resource_signer);                            
        let mutability_config = &vector<bool>[ false, true, true, true, true ];                
        if(!token::check_collection_exists(resource_account_address, string::utf8(EGG_COLLECTION_NAME))) {
            let mutate_setting = vector<bool>[ true, true, true ]; 
            let collection_uri = string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/egg/egg_epic.png"); 
            token::create_collection(&resource_signer, 
                string::utf8(EGG_COLLECTION_NAME), 
                string::utf8(COLLECTION_DESCRIPTION), 
                collection_uri, 99999, mutate_setting);        
        };
        let uri = if (egg_type == 1) {
            string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/egg/egg_common.png")
        } else if (egg_type == 2) {
            string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/egg/egg_rare.png")
        } else {
            string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/egg/egg_epic.png")
        };        
        
        let supply_count = &mut token::get_collection_supply(resource_account_address, string::utf8(EGG_COLLECTION_NAME));        
        let new_supply = option::extract<u64>(supply_count);                        
        let i = 0;
        let token_name = string::utf8(EGG_COLLECTION_NAME);
        while (i <= new_supply) {
            let new_token_name = string::utf8(EGG_COLLECTION_NAME);
            string::append_utf8(&mut new_token_name, b" #");
            let count_string = utils::to_string((i as u128));
            string::append(&mut new_token_name, count_string);                                
            if(!token::check_tokendata_exists(resource_account_address, string::utf8(EGG_COLLECTION_NAME), new_token_name)) {
                token_name = new_token_name;                
                break
            };
            i = i + 1;
        };
        
        let token_data_id = token::create_tokendata(
            &resource_signer,
            string::utf8(EGG_COLLECTION_NAME),
            token_name,
            string::utf8(COLLECTION_DESCRIPTION),
            1, // 1 maximum for NFT 
            uri,
            egg_minter_address, // royalty fee to                
            FEE_DENOMINATOR,
            4000,
                // we don't allow any mutation to the token
            token::create_token_mutability_config(mutability_config),
                // type
            vector<String>[string::utf8(BURNABLE_BY_OWNER), string::utf8(BURNABLE_BY_CREATOR), string::utf8(TOKEN_PROPERTY_MUTABLE), 
                    string::utf8(PROPERTY_RARITY), 
                    ],  // property_keys                
            vector<vector<u8>>[bcs::to_bytes<bool>(&true), bcs::to_bytes<bool>(&true), bcs::to_bytes<bool>(&true),
                    bcs::to_bytes<u64>(&egg_type),                    
                    ],  // values 
            vector<String>[string::utf8(b"bool"),string::utf8(b"bool"), string::utf8(b"bool"),
                string::utf8(b"u64"),
            ],
        );                                    
        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::opt_in_direct_transfer(receiver, true);
        token::direct_transfer(&resource_signer, receiver, token_id, 1);
    }
    
}


```
```rust

module beast_collector::beast_generator {                
    use std::bcs;
    use std::signer;    
    use std::string::{Self, String};        
    use aptos_std::table::{Self, Table};  
    use aptos_token::property_map::{Self};
    use aptos_token::token::{Self, TokenId};     
    use aptos_framework::coin;    
    use aptos_framework::event::{Self, EventHandle};    
    use aptos_framework::timestamp;
    use aptos_framework::account;        
    use beast_collector::acl::{Self};       
    use beast_collector::utils; 
    use std::option::{Self};    

    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";    
    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    const TOKEN_PROPERTY_MUTABLE: vector<u8> = b"TOKEN_PROPERTY_MUTATBLE";    

    const FEE_DENOMINATOR: u64 = 100000;
    
    // collection name / info
    const BEAST_COLLECTION_NAME:vector<u8> = b"W&W Beast";    
    const COLLECTION_DESCRIPTION:vector<u8> = b"https://beast.werewolfandwitch.xyz/ | The Beasts inhabit pristine and crystalline forests, their home a sanctuary of tranquility. Within these ethereal woods, a myriad of species thrives, each possessing its own unique traits and abilities. As the Beasts grow and mature, they undergo magnificent evolutions, unlocking even greater power and the ability to wield formidable magic.";
    // item property
    const BEAST_NUMBER: vector<u8> = b"W_NUMBER";
    const BEAST_EXP: vector<u8> = b"W_EXP";
    const BEAST_LEVEL: vector<u8> = b"W_LEVEL";
    const BEAST_RARITY: vector<u8> = b"W_RARITY"; // very common(1),Common(2), Rare(3), Very Rare(4), Epic (5), Legendary(6), Mythic(7)
    const BEAST_EVO_STAGE: vector<u8> = b"W_EVO_STAGE"; // 1 , 2, 3
    const BEAST_DUNGEON_TIME: vector<u8> = b"W_DUNGEON_TIME";
    const BEAST_BREEDING_TIME: vector<u8> = b"W_BREEDING";
    const BEAST_EVOLUTION_TIME: vector<u8> = b"W_EVOLUTION";    
    

    struct BeastCollection has key {
        collections: Table<u64, Evolution>, // <Name of Item, Item Composition>        
    }

    struct Evolution has key, store, drop {
        stage_name_1: String,        
        stage_uri_1: String,
        stage_name_2: String,        
        stage_uri_2: String,
        stage_name_3: String,        
        stage_uri_3: String,
        rarity: u64,
        story: String
    }

    struct AclAddEvent has drop, store {
        added: address,        
    }

    struct LevelUpEvent has drop, store {
        owner: address,
        level: u64,
        beast: TokenId
    }

    struct CollectionAdded has drop, store {
        material_1: String,        
        material_2: String,
        item: String,
    }
    

    struct BeastManager has store, key {          
        signer_cap: account::SignerCapability,
        acl: acl::ACL,
        maximum_beast_count:u64,
        acl_events:EventHandle<AclAddEvent>,
        token_minting_events: EventHandle<MintedEvent>,
        collection_add_events:EventHandle<CollectionAdded>,
        level_up_events:EventHandle<LevelUpEvent>,
    } 


    struct MintedEvent has drop, store {
        minted_item: token::TokenId,
        owner: address,
        generated_time: u64
    }

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires BeastManager {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires BeastManager {
        let minter = borrow_global<BeastManager>(minter_address);
        account::create_signer_with_capability(&minter.signer_cap)
    }    

    entry fun add_acl(sender: &signer, address_to_add:address) acquires BeastManager  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<BeastManager>(sender_addr);        
        acl::add(&mut manager.acl, address_to_add);
        event::emit_event(&mut manager.acl_events, AclAddEvent { 
            added: address_to_add,            
        });        
    }

    entry fun remove_acl(sender: &signer, address_to_remove:address) acquires BeastManager  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<BeastManager>(sender_addr);        
        acl::remove(&mut manager.acl, address_to_remove);        
    }    
    // resource cab required 
    entry fun init<WarCoinType>(sender: &signer) acquires BeastManager {
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"05");    
        token::initialize_token_store(&resource_signer);
        if(!exists<BeastManager>(sender_addr)){            
            move_to(sender, BeastManager {                
                signer_cap,  
                acl: acl::empty(),
                maximum_beast_count: 0,
                acl_events:account::new_event_handle<AclAddEvent>(sender),
                token_minting_events: account::new_event_handle<MintedEvent>(sender),
                collection_add_events: account::new_event_handle<CollectionAdded>(sender),                                                  
                level_up_events:account::new_event_handle<LevelUpEvent>(sender)
            });
        };
        
        if(!exists<BeastCollection>(sender_addr)){
            move_to(sender, BeastCollection {
                collections: table::new(),                
            });
        };

        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };        

        let mutate_setting = vector<bool>[ true, true, true ]; // TODO should check before deployment.
        let collection_uri = string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/beast/1.png");
        token::create_collection(&resource_signer, string::utf8(BEAST_COLLECTION_NAME), 
            string::utf8(COLLECTION_DESCRIPTION), collection_uri, 999999, mutate_setting);                
        
        let manager = borrow_global_mut<BeastManager>(sender_addr);
        acl::add(&mut manager.acl, sender_addr);              
    }    

    entry fun add_collection (
        sender: &signer, beast_number: u64,
        stage_name_1: String, stage_uri_1: String, 
        stage_name_2: String, stage_uri_2: String, 
        stage_name_3: String, stage_uri_3: String, 
        rarity:u64, story: String,
        ) acquires BeastCollection, BeastManager {
        let creator_address = signer::address_of(sender);        
        let collections = borrow_global_mut<BeastCollection>(creator_address);
        let _beast_manager = borrow_global_mut<BeastManager>(creator_address);        
        table::add(&mut collections.collections, beast_number, Evolution {
            stage_name_1,            
            stage_uri_1,
            stage_name_2, 
            stage_uri_2,
            stage_name_3,
            stage_uri_3,
            rarity,
            story
        });
    }

     entry fun remove_collection (
        sender: &signer, beast_number: u64, 
        ) acquires BeastCollection {  
        let creator_address = signer::address_of(sender);
        let collection = borrow_global_mut<BeastCollection>(creator_address);
        table::remove(&mut collection.collections, beast_number); 
    }
    

    public fun mint_beast (
        sender: &signer, auth: &signer, beast_contract_address:address, beast_number:u64
    ) acquires BeastCollection, BeastManager {    
        let auth_address = signer::address_of(auth);
        let manager = borrow_global<BeastManager>(beast_contract_address);
        acl::assert_contains(&manager.acl, auth_address);                           
        let resource_signer = get_resource_account_cap(beast_contract_address);                
        let resource_account_address = signer::address_of(&resource_signer);    
        let mutability_config = &vector<bool>[ true, true, true, true, true ];
        if(!token::check_collection_exists(resource_account_address, string::utf8(BEAST_COLLECTION_NAME))) {
            let mutate_setting = vector<bool>[ true, true, true ]; // TODO should check before deployment.
            let collection_uri = string::utf8(b"https://werewolfandwitch-beast-collection.s3.ap-northeast-2.amazonaws.com/beast/1.png");
            token::create_collection(&resource_signer, 
                string::utf8(BEAST_COLLECTION_NAME), 
                string::utf8(COLLECTION_DESCRIPTION), 
                collection_uri, 999999, mutate_setting);        
        };
        let collection = borrow_global_mut<BeastCollection>(beast_contract_address);
        let evolution_struct = table::borrow(&collection.collections, beast_number);        

        let supply_count = &mut token::get_collection_supply(resource_account_address, string::utf8(BEAST_COLLECTION_NAME));        
        let new_supply = option::extract<u64>(supply_count);                        
        let i = 0;
        let token_name = evolution_struct.stage_name_1;
        while (i <= new_supply) {
            let new_token_name = token_name;
            string::append_utf8(&mut new_token_name, b" #");
            let count_string = utils::to_string((i as u128));
            string::append(&mut new_token_name, count_string);                                
            if(!token::check_tokendata_exists(resource_account_address, string::utf8(BEAST_COLLECTION_NAME), new_token_name)) {
                token_name = new_token_name;                
                break
            };
            i = i + 1;
        };
        let token_uri = evolution_struct.stage_uri_1;
        let rarity = evolution_struct.rarity;
        let story = evolution_struct.story;        
        let token_data_id;
        token_data_id = token::create_tokendata(
                &resource_signer,
                string::utf8(BEAST_COLLECTION_NAME),
                token_name,
                story,
                1, 
                token_uri,
                beast_contract_address, // royalty fee to                
                FEE_DENOMINATOR,
                4000,
                // we don't allow any mutation to the token
                token::create_token_mutability_config(mutability_config),
                // type
                vector<String>[string::utf8(BURNABLE_BY_OWNER), string::utf8(BURNABLE_BY_CREATOR), string::utf8(TOKEN_PROPERTY_MUTABLE), 
                    string::utf8(BEAST_NUMBER),
                    string::utf8(BEAST_EXP),
                    string::utf8(BEAST_LEVEL),
                    string::utf8(BEAST_RARITY),
                    string::utf8(BEAST_EVO_STAGE),
                    string::utf8(BEAST_DUNGEON_TIME),                    
                    string::utf8(BEAST_BREEDING_TIME),
                    string::utf8(BEAST_EVOLUTION_TIME)
                ],  // property_keys                
                vector<vector<u8>>[bcs::to_bytes<bool>(&true),bcs::to_bytes<bool>(&true),bcs::to_bytes<bool>(&true),
                    bcs::to_bytes<u64>(&beast_number),
                    bcs::to_bytes<u64>(&0),
                    bcs::to_bytes<u64>(&1),
                    bcs::to_bytes<u64>(&rarity),
                    bcs::to_bytes<u64>(&1),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                ],  // values 
                vector<String>[string::utf8(b"bool"),string::utf8(b"bool"),string::utf8(b"bool"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),                    
                ],
            );
        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::opt_in_direct_transfer(sender, true);
        token::direct_transfer(&resource_signer, sender, token_id, 1);        
        let game_events = borrow_global_mut<BeastManager>(beast_contract_address);               
        event::emit_event(&mut game_events.token_minting_events, MintedEvent {            
            minted_item: token_id,
            owner: signer::address_of(sender),
            generated_time: timestamp::now_seconds()
        });
    }

    public fun extend_breeding_time (
        receiver: &signer, auth: &signer, beast_contract_address:address, token_id: TokenId,
    ) acquires BeastManager {  
        let auth_address = signer::address_of(auth);
        let manager = borrow_global<BeastManager>(beast_contract_address);
        acl::assert_contains(&manager.acl, auth_address);                                   
        let resource_signer = get_resource_account_cap(beast_contract_address);                
        token::mutate_one_token(            
                &resource_signer,
                signer::address_of(receiver),
                token_id,            
                vector<String>[
                    string::utf8(BEAST_BREEDING_TIME),                    
                ],  // property_keys                
                vector<vector<u8>>[                    
                    bcs::to_bytes<u64>(&(timestamp::now_seconds() + (86400 * 7)))
                ],  // values 
                vector<String>[
                    string::utf8(b"u64"),                    
                ],      // type
            );             
    }

    public fun add_exp (
        receiver: &signer, auth: &signer, beast_contract_address:address, token_id: TokenId, add_exp:u64,
    ) acquires BeastManager {  
        let auth_address = signer::address_of(auth);
        let holder_addr = signer::address_of(receiver);
        let manager = borrow_global<BeastManager>(beast_contract_address);
        acl::assert_contains(&manager.acl, auth_address);                                   
        let resource_signer = get_resource_account_cap(beast_contract_address);                               
        let pm = token::get_property_map(holder_addr, token_id);
        let level = property_map::read_u64(&pm, &string::utf8(BEAST_LEVEL));
        let exp = property_map::read_u64(&pm, &string::utf8(BEAST_EXP));
        exp = exp + add_exp;        
        if(exp > 100) {
            exp = exp - 100;
            level = level + 1;
        };
        token::mutate_one_token(            
            &resource_signer,
            holder_addr,
            token_id,            
            vector<String>[                    
                string::utf8(BEAST_LEVEL),
                string::utf8(BEAST_EXP),
                string::utf8(BEAST_DUNGEON_TIME)
            ],  // property_keys                
            vector<vector<u8>>[
                bcs::to_bytes<u64>(&level),
                bcs::to_bytes<u64>(&exp),
                bcs::to_bytes<u64>(&(timestamp::now_seconds() + 86400))
            ],  // values 
            vector<String>[
                string::utf8(b"u64"),
                string::utf8(b"u64"),
                string::utf8(b"u64")
            ],      // type
        ); 
        let game_events = borrow_global_mut<BeastManager>(beast_contract_address);               
        event::emit_event(&mut game_events.level_up_events, LevelUpEvent {            
            owner: holder_addr,
            level: level,
            beast: token_id
        });    
    }

    public fun evolve (
        receiver: &signer, auth: &signer, beast_contract_address:address, token_id: TokenId,
    ) acquires BeastCollection, BeastManager {
        let auth_address = signer::address_of(auth);
        let manager = borrow_global<BeastManager>(beast_contract_address);
        acl::assert_contains(&manager.acl, auth_address);
        let collection = borrow_global_mut<BeastCollection>(beast_contract_address);        
        let resource_signer = get_resource_account_cap(beast_contract_address);                               
        let resource_account_address = signer::address_of(&resource_signer);    
        let pm = token::get_property_map(signer::address_of(receiver), token_id);        
        let evo_stage = property_map::read_u64(&pm, &string::utf8(BEAST_EVO_STAGE));                
        let beast_number = property_map::read_u64(&pm, &string::utf8(BEAST_NUMBER));
        let beast_rarity = property_map::read_u64(&pm, &string::utf8(BEAST_RARITY));        
        let evolution_struct = table::borrow(&collection.collections, beast_number);
        evo_stage = evo_stage + 1;
        let new_name = evolution_struct.stage_name_2;
        let new_uri = evolution_struct.stage_uri_2;
        let story = evolution_struct.story;        
        if(evo_stage == 2) {
            new_name = evolution_struct.stage_name_2;
            new_uri = evolution_struct.stage_uri_2;        
        } else if(evo_stage == 3) {
            new_name = evolution_struct.stage_name_3;
            new_uri = evolution_struct.stage_uri_3;        
        };   
        let supply_count = &mut token::get_collection_supply(resource_account_address, string::utf8(BEAST_COLLECTION_NAME));        
        let new_supply = option::extract<u64>(supply_count);                        
        let i = 0;
        let token_name = new_name;
        while (i <= new_supply) {
            let new_token_name = token_name;
            string::append_utf8(&mut new_token_name, b" #");
            let count_string = utils::to_string((i as u128));
            string::append(&mut new_token_name, count_string);                                
            if(!token::check_tokendata_exists(resource_account_address, string::utf8(BEAST_COLLECTION_NAME), new_token_name)) {
                token_name = new_token_name;                
                break
            };
            i = i + 1;
        };
        let mutability_config = &vector<bool>[ true, true, true, true, true ];
        let token_data_id = token::create_tokendata(
                &resource_signer,
                string::utf8(BEAST_COLLECTION_NAME),
                token_name,
                story,
                1, 
                new_uri,
                beast_contract_address, // royalty fee to                
                FEE_DENOMINATOR,
                4000,
                // we don't allow any mutation to the token
                token::create_token_mutability_config(mutability_config),
                // type
                vector<String>[string::utf8(BURNABLE_BY_OWNER), string::utf8(BURNABLE_BY_CREATOR), string::utf8(TOKEN_PROPERTY_MUTABLE), 
                    string::utf8(BEAST_NUMBER),
                    string::utf8(BEAST_EXP),
                    string::utf8(BEAST_LEVEL),
                    string::utf8(BEAST_RARITY),
                    string::utf8(BEAST_EVO_STAGE),
                    string::utf8(BEAST_DUNGEON_TIME),                    
                    string::utf8(BEAST_BREEDING_TIME),
                    string::utf8(BEAST_EVOLUTION_TIME)
                ],  // property_keys                
                vector<vector<u8>>[bcs::to_bytes<bool>(&true),bcs::to_bytes<bool>(&true),bcs::to_bytes<bool>(&true),
                    bcs::to_bytes<u64>(&beast_number),
                    bcs::to_bytes<u64>(&0),
                    bcs::to_bytes<u64>(&1),
                    bcs::to_bytes<u64>(&beast_rarity),
                    bcs::to_bytes<u64>(&evo_stage),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                    bcs::to_bytes<u64>(&timestamp::now_seconds()),
                ],  // values 
                vector<String>[string::utf8(b"bool"),string::utf8(b"bool"),string::utf8(b"bool"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),
                    string::utf8(b"u64"),                    
                ],
            );
        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::opt_in_direct_transfer(receiver, true);
        token::direct_transfer(&resource_signer, receiver, token_id, 1); 
        let game_events = borrow_global_mut<BeastManager>(beast_contract_address);               
        event::emit_event(&mut game_events.token_minting_events, MintedEvent {            
            minted_item: token_id,
            owner: signer::address_of(receiver),
            generated_time: timestamp::now_seconds()
        });

    }
              
}

```
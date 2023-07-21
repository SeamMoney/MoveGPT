
module item_gen::item_equip {           
    use std::signer;        
    use std::string::{String};
    use aptos_framework::account;    
    use aptos_token::token::{Self};    
    use aptos_std::table::{Self, Table};  
    use aptos_framework::event::{Self, EventHandle};    
    use aptos_framework::coin;

    use item_gen::acl;

    // collection name / info
    const ITEM_COLLECTION_NAME:vector<u8> = b"W&W ITEM";    
    
    
    const ECONTAIN:u64 = 1;
    const ENOT_CONTAIN:u64 = 2;
    const ENOT_IN_ACL: u64 = 3;
    const EIS_TOP_LEVEL: u64 = 4;
    const ENOT_CREATOR:u64 = 5;
    const ENOT_OWNER:u64 = 6;
    
    struct ItemHolder has store, key {          
        signer_cap: account::SignerCapability,
        acl: acl::ACL,
        holdings: Table<FighterId, ItemReciept>,
        item_equip_events:EventHandle<ItemEquipEvent>,
        item_unequip_events:EventHandle<ItemUnEquipEvent>,
        acl_events:EventHandle<AclAddEvent>,                                   
    }

    struct AclAddEvent has drop, store {
        added: address,        
    }

    struct FighterId has store, copy, drop {        
        fighter_token_name:String,
        fighter_collection_name: String,
        fighter_creator: address
    }    

    struct ItemReciept has store, copy, drop {
        owner: address,
        item_token_name:String,
        item_collection_name:String,
        item_creator:address
    }    

    struct ItemEquipEvent has drop, store {
        fighter_id: FighterId,
        item_reciept: ItemReciept,        
    }

    struct ItemUnEquipEvent has drop, store {
        fighter_id: FighterId,
        item_reciept: ItemReciept, 
    }

    fun create_fighter_id(
        fighter_token_name:String,
        fighter_collection_name: String,
        fighter_creator: address     
    ): FighterId {        
        FighterId { fighter_token_name, fighter_collection_name,fighter_creator }
    }

    fun create_item_reciept(
        owner: address,
        item_token_name:String,
        item_collection_name:String,
        item_creator:address  
    ): ItemReciept {        
        ItemReciept { owner, item_token_name, item_collection_name, item_creator}
    }    
    
    entry fun admin_withdraw_items(sender: &signer, creator:address, collection:String, name:String, property_version:u64, 
        amount: u64) acquires ItemHolder {     
        // war_coin::init_module(sender);
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);
        let token_id_1 = token::create_token_id_raw(creator, collection, name, property_version);                        
        let token = token::withdraw_token(&resource_signer, token_id_1, amount);
        token::deposit_token(sender, token);        
    }
    
    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires ItemHolder {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires ItemHolder {
        let minter = borrow_global<ItemHolder>(minter_address);
        account::create_signer_with_capability(&minter.signer_cap)
    }    

    entry fun add_acl(sender: &signer, address_to_add:address) acquires ItemHolder  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<ItemHolder>(sender_addr);        
        acl::add(&mut manager.acl, address_to_add);
        event::emit_event(&mut manager.acl_events, AclAddEvent { 
            added: address_to_add,            
        });        
    }

    fun is_in_acl(sender_addr:address) : bool acquires ItemHolder {
        let manager = borrow_global<ItemHolder>(sender_addr);
        let acl = manager.acl;        
        acl::contains(&acl, sender_addr)
    }

    entry fun init (sender: &signer) acquires ItemHolder {
        let sender_addr = signer::address_of(sender);
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"03");    
        token::initialize_token_store(&resource_signer);
        if(!exists<ItemHolder>(sender_addr)){            
            move_to(sender, ItemHolder {                
                signer_cap,
                acl: acl::empty(),
                holdings: table::new(),
                item_equip_events: account::new_event_handle<ItemEquipEvent>(sender),
                item_unequip_events:account::new_event_handle<ItemUnEquipEvent>(sender),
                acl_events:account::new_event_handle<AclAddEvent>(sender)
            });
        };                
        let manager = borrow_global_mut<ItemHolder>(sender_addr);
        acl::add(&mut manager.acl, sender_addr);
    }
    
    // keep item in resource account with claim receipt
    // sender address should be season contract address for authorization
    entry fun item_equip_entry (
        sender: &signer, contract_address:address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        owner: address, item_token_name:String, item_collection_name:String, item_creator:address, item_property_version:u64
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        assert!(is_in_acl(sender_address), ENOT_IN_ACL);
        assert!(item_creator == @item_creator, ENOT_CREATOR);
        let resource_signer = get_resource_account_cap(contract_address);                        

        let fighter_id = create_fighter_id(fighter_token_name,fighter_collection_name,fighter_creator);
        let reciept = create_item_reciept(owner, item_token_name,item_collection_name,item_creator);
        
        let manager = borrow_global_mut<ItemHolder>(contract_address);        
        table::add(&mut manager.holdings, fighter_id, reciept);

        let token_id = token::create_token_id_raw(item_creator, item_collection_name, item_token_name, item_property_version);        
        let token = token::withdraw_token(sender, token_id, 1);
        token::deposit_token(&resource_signer, token);

        event::emit_event(&mut manager.item_equip_events, ItemEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });        
    }

    entry fun item_unequip_entry (
        sender: &signer, contract_address:address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        owner: address, item_token_name:String, item_collection_name:String, item_creator:address, item_property_version:u64
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        assert!(is_in_acl(sender_address), ENOT_IN_ACL);        
        assert!(item_creator == @item_creator, ENOT_CREATOR);
        let resource_signer = get_resource_account_cap(contract_address);                        

        let fighter_id = create_fighter_id(fighter_token_name,fighter_collection_name,fighter_creator);
        let reciept = create_item_reciept(owner, item_token_name,item_collection_name,item_creator);
        
        let manager = borrow_global_mut<ItemHolder>(contract_address);        
        table::remove(&mut manager.holdings, fighter_id);
        let token_id = token::create_token_id_raw(item_creator, item_collection_name, item_token_name, item_property_version);        
        let token = token::withdraw_token(&resource_signer, token_id, 1);
        token::deposit_token(sender, token);
        
        event::emit_event(&mut manager.item_unequip_events, ItemUnEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });        
    }


        
    // admin only
    entry fun swap_owner_entry(
        sender: &signer, contract_address:address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        owner: address, item_token_name:String, item_collection_name:String, item_creator:address,
        new_fighter_token_name: String, new_fighter_collection_name:String, new_fighter_creator:address,
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        assert!(is_in_acl(sender_address), ENOT_IN_ACL);                                   
        assert!(item_creator == @item_creator, ENOT_CREATOR);
        let fighter_id = create_fighter_id(fighter_token_name, fighter_collection_name, fighter_creator);
        let reciept = create_item_reciept(owner, item_token_name,item_collection_name, item_creator);
                
        let manager = borrow_global_mut<ItemHolder>(contract_address);        
        table::remove(&mut manager.holdings, fighter_id);

        event::emit_event(&mut manager.item_unequip_events, ItemUnEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });

        let new_fighter_id = create_fighter_id(new_fighter_token_name,new_fighter_collection_name,new_fighter_creator);        
        table::add(&mut manager.holdings, fighter_id, reciept);
        event::emit_event(&mut manager.item_equip_events, ItemEquipEvent { 
            fighter_id: new_fighter_id,
            item_reciept: reciept,            
        });        
    }

    public fun item_equip (
        sender: &signer, auth: &signer, contract_address:address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        item_token_name:String, item_collection_name:String, item_creator:address, item_property_version:u64
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        let auth_address = signer::address_of(auth);     
        let manager = borrow_global<ItemHolder>(contract_address);             
        acl::assert_contains(&manager.acl, auth_address);
        assert!(item_creator == @item_creator, ENOT_CREATOR);
        let resource_signer = get_resource_account_cap(contract_address);                        

        let fighter_id = create_fighter_id(fighter_token_name,fighter_collection_name,fighter_creator);
        let reciept = create_item_reciept(sender_address, item_token_name,item_collection_name,item_creator);
        
        let manager = borrow_global_mut<ItemHolder>(contract_address);        
        table::add(&mut manager.holdings, fighter_id, reciept);

        let token_id = token::create_token_id_raw(item_creator, item_collection_name, item_token_name, item_property_version);        
        let token = token::withdraw_token(sender, token_id, 1);
        token::deposit_token(&resource_signer, token);

        event::emit_event(&mut manager.item_equip_events, ItemEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });        
    }

    public fun item_unequip (
        sender: &signer, auth: &signer, contract_address: address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        item_token_name:String, item_collection_name:String, item_creator:address, item_property_version:u64
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        let auth_address = signer::address_of(auth);
        let manager = borrow_global<ItemHolder>(contract_address);             
        acl::assert_contains(&manager.acl, auth_address);        
        assert!(item_creator == @item_creator, ENOT_CREATOR);
        let resource_signer = get_resource_account_cap(contract_address);                        

        let fighter_id = create_fighter_id(fighter_token_name,fighter_collection_name,fighter_creator);
        let reciept = create_item_reciept(sender_address, item_token_name,item_collection_name,item_creator);
        
        let manager = borrow_global_mut<ItemHolder>(contract_address);
        let item_reciept = table::borrow(&manager.holdings, fighter_id);
        assert!(sender_address == item_reciept.owner, ENOT_OWNER);
        table::remove(&mut manager.holdings, fighter_id);
        let token_id = token::create_token_id_raw(item_creator, item_collection_name, item_token_name, item_property_version);        
        let token = token::withdraw_token(&resource_signer, token_id, 1);
        token::deposit_token(sender, token);
        
        event::emit_event(&mut manager.item_unequip_events, ItemUnEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });        
    }

    public fun swap_owner(
        sender: &signer, auth: &signer, contract_address:address,
        fighter_token_name: String, fighter_collection_name:String, fighter_creator:address,
        item_token_name:String, item_collection_name:String, item_creator:address,
        new_fighter_token_name: String, new_fighter_collection_name:String, new_fighter_creator:address,
    ) acquires ItemHolder {
        let sender_address = signer::address_of(sender);     
        let auth_address = signer::address_of(auth);     
        assert!(is_in_acl(auth_address), ENOT_IN_ACL);                                   

        let fighter_id = create_fighter_id(fighter_token_name,fighter_collection_name,fighter_creator);
        let reciept = create_item_reciept(sender_address, item_token_name,item_collection_name, item_creator);
                
        let manager = borrow_global_mut<ItemHolder>(contract_address);        
        let item_reciept = table::borrow(&manager.holdings, fighter_id);
        assert!(sender_address == item_reciept.owner, ENOT_OWNER);
        table::remove(&mut manager.holdings, fighter_id);

        event::emit_event(&mut manager.item_unequip_events, ItemUnEquipEvent { 
            fighter_id: fighter_id,
            item_reciept: reciept,            
        });

        let new_fighter_id = create_fighter_id(new_fighter_token_name, new_fighter_collection_name, new_fighter_creator);        
        table::add(&mut manager.holdings, new_fighter_id, reciept);
        event::emit_event(&mut manager.item_equip_events, ItemEquipEvent { 
            fighter_id: new_fighter_id,
            item_reciept: reciept,            
        });        
    }   
}


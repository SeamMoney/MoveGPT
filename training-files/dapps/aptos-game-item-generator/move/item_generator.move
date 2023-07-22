
module item_gen::item_generator {        
    use std::error;
    use std::bcs;
    use std::signer;    
    use std::string::{Self, String};    
    use std::option::{Self};
    use aptos_std::table::{Self, Table};  
    use aptos_token::property_map::{Self};
    use aptos_token::token::{Self}; 
    use aptos_framework::coin;    
    use aptos_framework::event::{Self, EventHandle};
    use std::vector;
    use aptos_framework::account;    
    use item_gen::utils;
    use item_gen::acl::{Self};    

    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";    
    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    const TOKEN_PROPERTY_MUTABLE: vector<u8> = b"TOKEN_PROPERTY_MUTATBLE";    

    const FEE_DENOMINATOR: u64 = 100000;
    const WAR_COIN_DECIMAL:u64 = 100000000;   

    
    // collection name / info
    const ITEM_COLLECTION_NAME:vector<u8> = b"W&W ITEM";
    const ITEM_MATERIAL_COLLECTION_NAME:vector<u8> = b"W&W ITEM MATERIAL";
    const COLLECTION_DESCRIPTION:vector<u8> = b"these items can be equipped by characters in W&W";
    // item property
    const ITEM_LEVEL: vector<u8> = b"W_ITEM_LEVEL";
    const ITEM_DEFAULT_STR: vector<u8> = b"W_ITEM_DEFAULT_STRENGTH";

    const ENOT_CREATOR:u64 = 1;
    const ESAME_MATERIAL:u64 = 2;
    const ENOT_IN_RECIPE:u64 = 3;
    const ENOT_IN_ACL: u64 = 4;
    const EIS_TOP_LEVEL:u64 = 5;
    const ENOT_AUTHORIZED:u64 = 6;
    const ENO_SUFFICIENT_FUND:u64 = 7;

    // property for game

    // Glimmering Crystals + Ethereal Essence = Radiant Spiritstone
    // Effect: By combining the radiant crystals with the ethereal essence, you create a Spiritstone that harnesses the power of ethereal beings. This enchanted stone can be used to augment magical weapons or create ethereal armor.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/radiant_spiritstone.png

    // Glimmering Crystals + Celestial Dust = Radiant Celestite
    // Effect: By combining the radiant crystals with celestial dust, you create Radiant Celestite. This gemstone radiates celestial magic and can be used to imbue weapons with enhanced celestial properties or create powerful celestial-themed artifacts.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/radiant_celestite.png

    // Dragon Scale + Celestial Dust = Celestial Dragon Scale
    // Effect: By infusing the mighty dragon scales with celestial dust, you forge a Celestial Dragon Scale. This rare material possesses exceptional resistance to both physical and magical attacks, granting the wearer enhanced protection against elemental forces.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/celestial_dragon_scale.png

    // Dragon Scale + Elemental Essence (Fire) = Inferno Scale Armor
    // Effect: By infusing the mighty dragon scales with the fiery elemental essence, you forge Inferno Scale Armor. This legendary armor provides exceptional protection against fire-based attacks and grants the wearer the ability to unleash powerful flames in combat.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/inferno_scale_armor.png

    // Essence of the Ancients + Phoenix Feather = Phoenix's Elixir
    // Effect: By combining the ancient essence with the heat-resistant phoenix feathers, you create a potent elixir known as Phoenix's Elixir. This elixir grants temporary fire-based abilities to the user, enhancing their strength and resilience.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/phoenix_elixir.png

    // Moonstone Ore + Enchanted Wood = Lunar Enchanted Talisman
    // Effect: By combining the lunar-infused gemstone with enchanted wood, you craft a Lunar Enchanted Talisman. This mystical talisman enhances the wielder's magical abilities, granting them increased spellcasting prowess and the ability to channel lunar energy.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/lunar_enchanted_talisman.png

    // Kraken Ink + Elemental Essence (Water) = Ink of the Deep Seas
    // Effect: By blending the dark, iridescent kraken ink with water elemental essence, you create the Ink of the Deep Seas. This ink is used to inscribe protective runes or create powerful spell scrolls with water-based enchantments, providing the user with aquatic powers.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/ink_of_the_deep_seas.png

    // Ethereal Essence + Essence of the Ancients = Spectral Essence
    // Effect: By blending the ghostly ethereal essence with the potent Essence of the Ancients, you obtain Spectral Essence. This essence contains a combination of ethereal and ancient energies, making it a versatile substance for crafting artifacts that harness spectral powers or enhance magical abilities.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/spectral_essence.png

    // Phoenix Feather + Enchanted Wood = Flameheart Bow
    // Effect: By combining the heat-resistant phoenix feathers with enchanted wood, you create the Flameheart Bow. This enchanted bow channels the essence of fire, imbuing arrows with fiery properties and granting the archer enhanced precision and power in dealing with fire-aligned foes.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/flameheart_bow.png

    // Moonstone Ore + Kraken Ink = Tidecaller Pendant
    // Effect: By combining the lunar-infused moonstone ore with the dark, iridescent kraken ink, you craft the Tidecaller Pendant. This enchanted pendant allows the wearer to command the tides and manipulate water-based magic, granting them control over aquatic forces.
    // https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/tidecaller_pendent.png

    struct Recipes has key {
        recipes: Table<String, ItemComposition>, // <Name of Item, Item Composition>
        recipe_add_events:EventHandle<ItemRecipeAdded>,
        recipe_check_events:EventHandle<ItemRecipeCheck>,        
    }

    struct AclAddEvent has drop, store {
        added: address,        
    }

    struct ItemRecipeAdded has drop, store {
        material_1: String,        
        material_2: String,
        item: String,
    }

    struct ItemRecipeCheck has drop, store {
        material_1: bool,        
        material_2: bool,
        item: String,
    }

    struct ItemComposition has key, store, drop {
        composition: vector<String>
    }

    struct ItemManager has store, key {          
        signer_cap: account::SignerCapability,
        acl: acl::ACL,
        acl_events:EventHandle<AclAddEvent>,                                   
    } 

    struct ItemEvents has key {
        token_minting_events: EventHandle<ItemMintedEvent>,        
    }

    struct ItemMintedEvent has drop, store {
        minted_item: token::TokenId,
        generated_time: u64
    }

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires ItemManager {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires ItemManager {
        let minter = borrow_global<ItemManager>(minter_address);
        account::create_signer_with_capability(&minter.signer_cap)
    }    

    entry fun add_acl(sender: &signer, address_to_add:address) acquires ItemManager  {                    
        let sender_addr = signer::address_of(sender);                
        let manager = borrow_global_mut<ItemManager>(sender_addr);        
        acl::add(&mut manager.acl, address_to_add);
        event::emit_event(&mut manager.acl_events, AclAddEvent { 
            added: address_to_add,            
        });        
    }

    fun is_in_acl(sender_addr:address) : bool acquires ItemManager {
        let manager = borrow_global<ItemManager>(sender_addr);
        let acl = manager.acl;        
        acl::contains(&acl, sender_addr)
    }
    // resource cab required 
    entry fun init<WarCoinType>(sender: &signer,collection_uri:String,maximum_supply:u64) acquires ItemManager{
        let sender_addr = signer::address_of(sender);                
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"01");    
        token::initialize_token_store(&resource_signer);
        if(!exists<ItemManager>(sender_addr)){            
            move_to(sender, ItemManager {                
                signer_cap,  
                acl: acl::empty(),
                acl_events:account::new_event_handle<AclAddEvent>(sender)
            });
        };

        if(!exists<Recipes>(sender_addr)){
            move_to(sender, Recipes {
                recipes: table::new(),
                recipe_add_events: account::new_event_handle<ItemRecipeAdded>(sender),
                recipe_check_events: account::new_event_handle<ItemRecipeCheck>(sender)
            });
        };

        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };

        let mutate_setting = vector<bool>[ true, true, true ]; // TODO should check before deployment.
        token::create_collection(&resource_signer, string::utf8(ITEM_COLLECTION_NAME), string::utf8(COLLECTION_DESCRIPTION), collection_uri, maximum_supply, mutate_setting);
        
        let manager = borrow_global_mut<ItemManager>(sender_addr);
        acl::add(&mut manager.acl, sender_addr);              
    }    

    entry fun add_recipe (
        sender: &signer, item_token_name: String, material_token_name_1:String, material_token_name_2:String
        ) acquires Recipes {
        let creator_address = signer::address_of(sender);
        let recieps = borrow_global_mut<Recipes>(creator_address);
        let values = vector<String>[ material_token_name_1, material_token_name_2];
        table::add(&mut recieps.recipes, item_token_name, ItemComposition {
            composition: values
        });        
        event::emit_event(&mut recieps.recipe_add_events, ItemRecipeAdded { 
            material_1: material_token_name_1,        
            material_2: material_token_name_2,
            item: item_token_name,            
        });        
    }

    fun check_recipe(creator_address: address, item_token_name: String, material_token_name_1:String, material_token_name_2:String) : bool acquires Recipes {        
        let minter = borrow_global<Recipes>(creator_address);
        let recipe = table::borrow(&minter.recipes, item_token_name);
        let contain1 = vector::contains(&recipe.composition, &material_token_name_1);
        let contain2 = vector::contains(&recipe.composition, &material_token_name_2);
        contain1 && contain2        
    }

    // entry fun check_recipe_entry(creator_address: address, item_token_name: String, material_token_name_1:String, material_token_name_2:String) acquires Recipes {        
    //     let minter = borrow_global_mut<Recipes>(creator_address);
    //     let recipe = table::borrow(&minter.recipes, item_token_name);
    //     let contain1 = vector::contains(&recipe.composition, &material_token_name_1);
    //     let contain2 = vector::contains(&recipe.composition, &material_token_name_2);
    //     event::emit_event(&mut minter.recipe_check_events, ItemRecipeCheck { 
    //         material_1: contain1,        
    //         material_2: contain2,
    //         item: item_token_name,            
    //     });        
    // }

    entry fun remove_recipe(
        sender: &signer, item_token_name: String
        )acquires Recipes  {   
        let creator_address = signer::address_of(sender);
        let recipes = borrow_global_mut<Recipes>(creator_address);
        table::remove(&mut recipes.recipes, item_token_name);                                                 
    }
        
    fun mint_item (
        sender: &signer, minter_address:address, token_name: String, target_item_uri:String
    ) acquires ItemManager {    
        let sender_address = signer::address_of(sender);     
        assert!(is_in_acl(minter_address), ENOT_IN_ACL);                           
        let resource_signer = get_resource_account_cap(minter_address);                
        let resource_account_address = signer::address_of(&resource_signer);    
        let mutability_config = &vector<bool>[ false, true, true, true, true ];
        if(!token::check_collection_exists(resource_account_address, string::utf8(ITEM_COLLECTION_NAME))) {
            let mutate_setting = vector<bool>[ true, true, true ]; // TODO should check before deployment.
            let collection_uri = string::utf8(b"https://werewolfandwitch-mainnet.s3.ap-northeast-2.amazonaws.com/item-image/flameheart_bow.png");
            token::create_collection(&resource_signer, 
                string::utf8(ITEM_COLLECTION_NAME), 
                string::utf8(COLLECTION_DESCRIPTION), 
                collection_uri, 9999, mutate_setting);        
        };
        
        let supply_count = &mut token::get_collection_supply(resource_account_address, string::utf8(ITEM_COLLECTION_NAME));        
        let new_supply = option::extract<u64>(supply_count);                        
        let i = 0;
        while (i <= new_supply) {
            let new_token_name = token_name;                
            string::append_utf8(&mut new_token_name, b" #");
            let count_string = utils::to_string((i as u128));
            string::append(&mut new_token_name, count_string);                                
            if(!token::check_tokendata_exists(resource_account_address, string::utf8(ITEM_COLLECTION_NAME), new_token_name)) {
                token_name = new_token_name;                
                break
            };
            i = i + 1;
        };                          
        let default_str = utils::random_with_nonce(sender_address,5, 1) + 1;                     
        let token_data_id = token::create_tokendata(
                &resource_signer,
                string::utf8(ITEM_COLLECTION_NAME),
                token_name,
                string::utf8(COLLECTION_DESCRIPTION),
                1, // 1 maximum for NFT 
                target_item_uri, 
                minter_address, // royalty fee to                
                FEE_DENOMINATOR,
                4000, // TODO:: should be check later::royalty_points_numerator
                // we don't allow any mutation to the token
                token::create_token_mutability_config(mutability_config),
                // type
                vector<String>[string::utf8(BURNABLE_BY_OWNER), string::utf8(BURNABLE_BY_CREATOR), string::utf8(TOKEN_PROPERTY_MUTABLE), string::utf8(ITEM_LEVEL), string::utf8(ITEM_DEFAULT_STR)],  // property_keys                
                vector<vector<u8>>[bcs::to_bytes<bool>(&true), bcs::to_bytes<bool>(&true), bcs::to_bytes<bool>(&true),bcs::to_bytes<u64>(&16), bcs::to_bytes<u64>(&default_str)],  // values 
                vector<String>[string::utf8(b"bool"),string::utf8(b"bool"), string::utf8(b"bool"),string::utf8(b"u64"), string::utf8(b"u64")],
        );
        let token_id = token::mint_token(&resource_signer, token_data_id, 1);
        token::opt_in_direct_transfer(sender, true);
        token::direct_transfer(&resource_signer, sender, token_id, 1);        
    }
    // synthesis => item systhesys by item recicpe    
    entry fun synthesis_two_item<WarCoinType>(
        sender: &signer, minter_address:address, 
        item_material_creator:address, target_item:String, token_name_1: String, token_name_2: String, property_version:u64,
        target_item_uri:String,
    ) acquires Recipes, ItemManager {
        // check collection name and creator address
        assert!(item_material_creator == @item_material_creator, ENOT_CREATOR);
        assert!(token_name_1 != token_name_2, ESAME_MATERIAL);
                
        // check is in recipe
        // Glimmering Crystals + Ethereal Essence
        assert!(check_recipe(minter_address, target_item, token_name_1, token_name_2), ENOT_IN_RECIPE);
        token::burn(sender, item_material_creator, string::utf8(ITEM_MATERIAL_COLLECTION_NAME), token_name_1, property_version, 1);
        token::burn(sender, item_material_creator, string::utf8(ITEM_MATERIAL_COLLECTION_NAME), token_name_2, property_version, 1);
        
        mint_item(sender, minter_address, target_item, target_item_uri);        
    }

    entry fun item_enchant<WarCoinType> (
        sender: &signer, contract_address:address,        
        item_token_name:String, item_collection_name:String, item_creator:address, item_property_version:u64
    ) acquires ItemManager {    
        let coin_address = utils::coin_address<WarCoinType>();
        let sender_address = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(contract_address);
        assert!(coin_address == @war_coin, error::permission_denied(ENOT_AUTHORIZED));
        assert!(coin::balance<WarCoinType>(sender_address) >= WAR_COIN_DECIMAL, error::permission_denied(ENO_SUFFICIENT_FUND));
        let coins = coin::withdraw<WarCoinType>(sender, WAR_COIN_DECIMAL * 10);        
        coin::deposit(signer::address_of(&resource_signer), coins);                    
        assert!(item_creator == @item_creator, ENOT_CREATOR);        
        let random = utils::random_with_nonce(sender_address, 10, 1) + 1;                     
        let token_id = token::create_token_id_raw(item_creator, item_collection_name, item_token_name, item_property_version);        
        let pm = token::get_property_map(sender_address, token_id);
        let item_level = property_map::read_u64(&pm, &string::utf8(ITEM_LEVEL));
        assert!(item_level > 1 , EIS_TOP_LEVEL);
        if(random <= 2) {            
            let token = token::withdraw_token(sender, token_id, 1);
            token::deposit_token(&resource_signer, token);
            token::burn(&resource_signer, item_creator, item_collection_name, item_token_name, item_property_version, 1);                
        } else {
            token::mutate_one_token(            
                &resource_signer,
                sender_address,
                token_id,            
                vector<String>[string::utf8(ITEM_LEVEL)],  // property_keys                
                vector<vector<u8>>[bcs::to_bytes<u64>(&(item_level -1) )],  // values 
                vector<String>[string::utf8(b"u64")],      // type
            );        
        }        
    }        
}

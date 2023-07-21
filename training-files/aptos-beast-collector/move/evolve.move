
module beast_collector::evolve {
    
    use std::signer;    
    use std::error;
    use std::string::{Self, String};     
    use aptos_framework::coin::{Self};           
    use aptos_token::property_map::{Self};
    use aptos_token::token::{Self}; 
    use aptos_framework::account;

    use beast_collector::beast_generator;

    const ENOT_AUTHORIZED:u64 = 0;       
    const EREQUIRED_TOP_LEVEL:u64 = 1;         
    const EIS_FINAL_STAGE:u64 = 2;

    const BEAST_COLLECTION_NAME:vector<u8> = b"W&W Beast";  

    const BEAST_EXP: vector<u8> = b"W_EXP";
    const BEAST_LEVEL: vector<u8> = b"W_LEVEL";
    const BEAST_EVO_STAGE: vector<u8> = b"W_EVO_STAGE"; // 1 , 2, 3        
    const BEAST_EVOLUTION_TIME: vector<u8> = b"W_EVOLUTION";    

    struct Evolve has store, key {          
        signer_cap: account::SignerCapability,                                                        
    }
        

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires Evolve {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }

    fun get_resource_account_cap(minter_address : address) : signer acquires Evolve {
        let launchpad = borrow_global<Evolve>(minter_address);
        account::create_signer_with_capability(&launchpad.signer_cap)
    }

    entry fun init(sender: &signer) {
        let sender_addr = signer::address_of(sender);                
        let (_resource_signer, signer_cap) = account::create_resource_account(sender, x"08");        
        if(!exists<Evolve>(sender_addr)){            
            move_to(sender, Evolve {                
                signer_cap,                
            });
        };
        
    } 
            
    entry fun evolve(
        holder: &signer, breed_address: address,
        token_name:String, property_version:u64,        
    ) acquires Evolve {
        let resource_signer = get_resource_account_cap(breed_address);                        
        let token_id = token::create_token_id_raw(@beast_creator, string::utf8(BEAST_COLLECTION_NAME), token_name, property_version);                
        let pm = token::get_property_map(signer::address_of(holder), token_id);        
        let beast_level = property_map::read_u64(&pm, &string::utf8(BEAST_LEVEL));
        let beast_evo_stage = property_map::read_u64(&pm, &string::utf8(BEAST_EVO_STAGE));
        assert!(beast_level > 4,error::permission_denied(EREQUIRED_TOP_LEVEL));
        assert!(beast_evo_stage < 3, error::permission_denied(EIS_FINAL_STAGE));                                
        beast_generator::evolve(holder, &resource_signer, @beast_gen_address, token_id);        
        token::burn(holder, @beast_creator, string::utf8(BEAST_COLLECTION_NAME), token_name, property_version, 1);
    }
}

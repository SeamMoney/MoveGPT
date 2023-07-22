
module war_land::lands {                
    
    use aptos_framework::timestamp;
    use std::signer;    
    use std::error;    
    use aptos_framework::account;
    use aptos_framework::coin;    
    use aptos_framework::event::{Self, EventHandle};            


    use war_land::utils;

    use aptos_std::table::{Self, Table};  

    const X_MAX:u64 = 150;
    const Y_MAX:u64 = 150;

    const WAR_COIN_PRICE:u64 = 100000000; // 1 WAR
    const APT_COIN_PRICE:u64 = 1000000; // 0.01 APT    

    const ENOT_AUTHORIZED: u64 = 1;
    const ENO_SUFFICIENT_FUND:u64 = 2;
    const ENOT_OPENED:u64 = 3;
    const ENOT_EXPIRED:u64 = 4;
    const ENOT_OWNER:u64 = 5;
    const EOUT_RANGE:u64 = 6;

    const ONE_DAY:u64 = 86400;


    struct LaunchPad has store, key {          
        signer_cap: account::SignerCapability,        
        launchpad_public_open:u64,                             
        color_state_events: EventHandle<StateChangeEvent>,        
        rent_events: EventHandle<RentEvent>,        
    }

    struct Rent has drop, store {                                  
        owner: address,
        expired: u64        
    }
    
    struct RentInfo has key {
        rents: Table<Coord, Rent>
    }    

    struct Coord has store, copy, drop {
        x: u64,
        y: u64,
    }

    struct StateChangeEvent has drop, store {
        x: u64,
        y: u64,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
        changer: address,
        timestamp:u64
    }

    struct RentEvent has drop, store {
       owner: address,
       x: u64,
       y: u64,
       expired: u64           
    }            

    fun get_resource_account_cap(minter_address : address) : signer acquires LaunchPad {
        let minter = borrow_global<LaunchPad>(minter_address);
        account::create_signer_with_capability(&minter.signer_cap)
    }

    fun create_coord_id(
        x: u64,
        y: u64
    ): Coord {        
        Coord { x, y }
    }
    
    entry fun init<CoinType, WarCoinType>(sender:&signer, launchpad_public_open:u64) {
        let (resource_signer, signer_cap) = account::create_resource_account(sender, x"01");                    
        let sender_addr = signer::address_of(sender);
        if(!coin::is_account_registered<CoinType>(signer::address_of(&resource_signer))){
            coin::register<CoinType>(&resource_signer);
        };
        if(!coin::is_account_registered<WarCoinType>(signer::address_of(&resource_signer))){
            coin::register<WarCoinType>(&resource_signer);
        };
        if(!exists<LaunchPad>(sender_addr)){            
            move_to(sender, LaunchPad {                
                signer_cap,
                launchpad_public_open: launchpad_public_open,                
                color_state_events: account::new_event_handle<StateChangeEvent>(sender),
                rent_events: account::new_event_handle<RentEvent>(sender),
            });
        };

        if(!exists<RentInfo>(sender_addr)){
            move_to(sender, RentInfo{
                rents: table::new()
            });
        };
    }

    entry fun rent_pixel<CoinType>(sender:&signer, minter:address, x:u64, y:u64, r:u8, g:u8, b:u8, a:u8, days:u64) acquires LaunchPad, RentInfo {                        
        if(!coin::is_account_registered<CoinType>(signer::address_of(sender))){
            coin::register<CoinType>(sender);
        };
        let resource_signer = get_resource_account_cap(minter);
        // let resource_account_address = signer::address_of(&resource_signer);
        let rent_info = borrow_global_mut<RentInfo>(minter);
        let coord_id = create_coord_id(x,y);
        let minter = borrow_global_mut<LaunchPad>(minter); 
        
        assert!(minter.launchpad_public_open < timestamp::now_seconds(), error::permission_denied(ENOT_OPENED));
        assert!((x <= X_MAX && y <= Y_MAX), error::permission_denied(EOUT_RANGE));
        // pay coins
        let coin_address = utils::coin_address<CoinType>();
        let price_to_pay = WAR_COIN_PRICE;
        if(coin_address == @war_coin) {            
            price_to_pay = WAR_COIN_PRICE;
        } else if(coin_address == @apt_coin) {
            price_to_pay = APT_COIN_PRICE;
        } else {
            assert!((coin_address == @war_coin || coin_address == @apt_coin), error::permission_denied(ENOT_AUTHORIZED));
        };                                
        let coins_to_pay = coin::withdraw<CoinType>(sender, price_to_pay * days);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);
        
        if(table::contains(&mut rent_info.rents, coord_id)) {
            let rent = table::borrow(&rent_info.rents, coord_id);                        
            assert!(rent.expired < timestamp::now_seconds(), ENOT_EXPIRED);           
            table::upsert(&mut rent_info.rents, coord_id, Rent {  
                owner: signer::address_of(sender),              
                expired: timestamp::now_seconds() + ONE_DAY * days,            
            });
        } else {
            table::add(&mut rent_info.rents, coord_id, Rent {                
                owner:signer::address_of(sender),
                expired: timestamp::now_seconds() + ONE_DAY * days,            
            });
        };
        
        event::emit_event(&mut minter.rent_events, RentEvent {            
            owner: signer::address_of(sender),
            x: x,
            y: y,
            expired: timestamp::now_seconds() + ONE_DAY * days                      
        });

        event::emit_event(&mut minter.color_state_events, StateChangeEvent {            
            x: x,
            y: y,
            r: r,
            g: g,
            b: b,
            a: a,
            changer: signer::address_of(sender),          
            timestamp: timestamp::now_microseconds(),
        });        
    }

    entry fun change_color<CoinType>(sender:&signer, minter:address, x:u64, y:u64, r:u8, g:u8, b:u8, a:u8) acquires LaunchPad, RentInfo {
        let sender_addr = signer::address_of(sender);
        //check rent owner
        let rent_info = borrow_global_mut<RentInfo>(minter);
        let coord_id = create_coord_id(x,y);                                      
        let rent = table::borrow(&rent_info.rents, coord_id);
        assert!(rent.owner ==  signer::address_of(sender), ENOT_OWNER);
        // pay coins
        let coin_address = utils::coin_address<CoinType>();
        let price_to_pay = WAR_COIN_PRICE;
        if(coin_address == @war_coin) {
            price_to_pay = WAR_COIN_PRICE;
        } else if(coin_address == @apt_coin) {
            price_to_pay = APT_COIN_PRICE;
        } else {
            assert!((coin_address == @war_coin || coin_address == @apt_coin), error::permission_denied(ENOT_AUTHORIZED));
        };                
        let resource_signer = get_resource_account_cap(minter);
        // let resource_account_address = signer::address_of(&resource_signer);        
        let coins_to_pay = coin::withdraw<CoinType>(sender, price_to_pay);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);

        let minter = borrow_global_mut<LaunchPad>(minter);
        event::emit_event(&mut minter.color_state_events, StateChangeEvent {            
            x: x,
            y: y,
            r: r,
            g: g,
            b: b,
            a: a,
            changer: sender_addr,          
            timestamp: timestamp::now_microseconds(),
        });
    }

    entry fun extend_time<CoinType>(sender:&signer, minter:address, x:u64, y:u64, days:u64) acquires LaunchPad, RentInfo {
        let resource_signer = get_resource_account_cap(minter);
        // let resource_account_address = signer::address_of(&resource_signer);
         // pay coins
        let coin_address = utils::coin_address<CoinType>();
        let price_to_pay = WAR_COIN_PRICE;
        if(coin_address == @war_coin) {
            price_to_pay = WAR_COIN_PRICE;
        } else if(coin_address == @apt_coin) {
            price_to_pay = APT_COIN_PRICE;
        } else {
            assert!((coin_address == @war_coin || coin_address == @apt_coin), error::permission_denied(ENOT_AUTHORIZED));
        };                        
        
        let coins_to_pay = coin::withdraw<CoinType>(sender, price_to_pay * days);                
        coin::deposit(signer::address_of(&resource_signer), coins_to_pay);

        //check rent owner
        let rent_info = borrow_global_mut<RentInfo>(minter);
        let coord_id = create_coord_id(x,y);                                      
        let rent = table::borrow(&rent_info.rents, coord_id);
        assert!(rent.owner ==  signer::address_of(sender), ENOT_OWNER);
        assert!(days <= 365, ENOT_AUTHORIZED);
        table::upsert(&mut rent_info.rents, coord_id, Rent {  
            owner: signer::address_of(sender),              
            expired: timestamp::now_seconds() + ONE_DAY * days,
        });

        let minter = borrow_global_mut<LaunchPad>(minter);
        event::emit_event(&mut minter.rent_events, RentEvent {            
            owner: signer::address_of(sender),
            x: x,
            y: y,
            expired: timestamp::now_seconds() + ONE_DAY * days                       
        });        
    }

    entry fun release_pixel<CoinType>(sender:&signer, minter:address, x:u64, y:u64) acquires LaunchPad, RentInfo {                
        let rent_info = borrow_global_mut<RentInfo>(minter);
        let coord_id = create_coord_id(x,y);                                      
        let rent = table::borrow(&rent_info.rents, coord_id);
        assert!(rent.owner ==  signer::address_of(sender), ENOT_OWNER);
        table::upsert(&mut rent_info.rents, coord_id, Rent {  
            owner: signer::address_of(sender),              
            expired: timestamp::now_seconds() - ONE_DAY,
        });

        let minter = borrow_global_mut<LaunchPad>(minter);
        event::emit_event(&mut minter.rent_events, RentEvent {            
            owner: signer::address_of(sender),
            x: x,
            y: y,
            expired: timestamp::now_seconds() - ONE_DAY                       
        });
    }


    // only for bad pixels
    entry fun admin_bother<WarCoinType>(sender:&signer,x:u64,y:u64,r:u8, g:u8, b:u8, a:u8) acquires LaunchPad {                
        let sender_addr = signer::address_of(sender);                        
        let minter = borrow_global_mut<LaunchPad>(sender_addr);               
        event::emit_event(&mut minter.color_state_events, StateChangeEvent {            
            x: x,
            y: y,
            r: r,
            g: g,
            b: b,
            a: a,
            changer: sender_addr,          
            timestamp: timestamp::now_microseconds(),
        });
    }        

    entry fun admin_withdraw<CoinType>(sender: &signer, amount: u64) acquires LaunchPad {
        let sender_addr = signer::address_of(sender);
        let resource_signer = get_resource_account_cap(sender_addr);                                
        let coins = coin::withdraw<CoinType>(&resource_signer, amount);                
        coin::deposit(sender_addr, coins);
    }
       
}

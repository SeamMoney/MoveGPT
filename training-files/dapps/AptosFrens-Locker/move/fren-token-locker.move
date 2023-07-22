module FrensLocker::frens_locker {

    use std::signer;
    use std::error;
    use std::string;

    use aptos_std::event;

    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp; 

    struct LockerTimed<phantom CoinType> has key {
         locker_store: coin::Coin<CoinType>,
         unlock_time: u64,
     }

    struct LockerState has key{
        locker_live: bool,
        locker_cap: account::SignerCapability,
        deposit_fee: u64
    }

    struct LockerEventHolder has key {
        lock_events: event::EventHandle<LockerEvent>
    }

    struct LockerEvent has drop, store { 
        new_locked_amount: u64,
        coin_type: string::String,
        coin_name: string::String,
        decimals: u8,
        locker_address: address,
    } 

    const ENOT_UNLOCKED: u64 = 1;
    const ENOT_TIME_EXTENSION: u64 = 2;

    const ENOT_ENOUGH_APTOS: u64 = 11;
    const ENOT_ENOUGH_COINS: u64 = 12;

    const OWNER_RESTRICTED: u64 = 21;
    const ENOT_LOCKER_LIVE: u64 = 22;

    const HARD_DEPOSIT_FEE_LIMIT: u64 = 500000000; // 5 APTOS

    public entry fun depositLockTimed<CoinType>(newAccount: &signer, lockAmount: u64, unlock_time: u64) acquires LockerState, LockerTimed, LockerEventHolder {
        let account_address = signer::address_of(newAccount);

        let locker_state = borrow_global<LockerState>(@FrensLocker);
        let locker_signer = account::create_signer_with_capability(&locker_state.locker_cap);
        let locker_address = signer::address_of(&locker_signer);

        let account_coin_balance = coin::balance<CoinType>(account_address);
        let account_aptos_balance = coin::balance<aptos_framework::aptos_coin::AptosCoin>(account_address);
        
        assert!(
            account_coin_balance >= lockAmount,
            error::permission_denied(ENOT_ENOUGH_COINS)
        );

        assert!(
            account_aptos_balance >= locker_state.deposit_fee,
            error::permission_denied(ENOT_ENOUGH_APTOS)
        );

        assert!(
            (locker_state.locker_live == true || account_address == @FrensLocker),
            error::permission_denied(ENOT_LOCKER_LIVE)
        );
        
        let time_now = timestamp::now_seconds();
        assert!(
            unlock_time > time_now,
            error::permission_denied(ENOT_TIME_EXTENSION),
        );

        if(!exists<LockerEventHolder>(locker_address)){
            move_to(&locker_signer, LockerEventHolder{
                lock_events: account::new_event_handle<LockerEvent>(&locker_signer),
            });
        };

        aptos_framework::aptos_account::transfer(newAccount, @FrensLocker, locker_state.deposit_fee);
        let coin_name = coin::name<CoinType>();
        let decimals:u8 = coin::decimals<CoinType>();
        let coin_type = aptos_std::type_info::type_name<CoinType>();
        let tempHolder = borrow_global_mut<LockerEventHolder>(locker_address);
        event::emit_event(&mut tempHolder.lock_events, LockerEvent{new_locked_amount: lockAmount, coin_type, coin_name, decimals, locker_address: account_address});    

        let the_deposit = aptos_framework::coin::withdraw<CoinType>(newAccount, lockAmount);
        if(exists<LockerTimed<CoinType>>(account_address)){
            let tempHolder = borrow_global_mut<LockerTimed<CoinType>>(account_address);
            coin::merge<CoinType>(&mut tempHolder.locker_store, the_deposit);
        }
        else{
            move_to<LockerTimed<CoinType>>(newAccount, LockerTimed { locker_store: the_deposit, unlock_time: unlock_time}); 
        };
    }

    public entry fun withdrawLockTimed<CoinType>(newAccount: &signer) acquires LockerTimed, LockerState, LockerEventHolder {
        let account_addr = signer::address_of(newAccount);
        let LockerTimed {  locker_store: the_depositz, unlock_time: _unlock_time} = move_from<LockerTimed<CoinType>>(account_addr); 
        let time_now = timestamp::now_seconds();
        assert!(
            time_now > _unlock_time,
            error::permission_denied(ENOT_UNLOCKED),
        );
        coin::deposit<CoinType>(account_addr, the_depositz);

        let locker_state = borrow_global<LockerState>(@FrensLocker); 
        let locker_signer = account::create_signer_with_capability(&locker_state.locker_cap);
        let locker_address = signer::address_of(&locker_signer);

        if(!exists<LockerEventHolder>(locker_address)){
            move_to(&locker_signer, LockerEventHolder{
                lock_events: account::new_event_handle<LockerEvent>(&locker_signer),
            });
        };
        
        let coin_name = coin::name<CoinType>();
        let decimals: u8 = coin::decimals<CoinType>();
        let coin_type = aptos_std::type_info::type_name<CoinType>();
        let tempHolder = borrow_global_mut<LockerEventHolder>(locker_address);
        event::emit_event(&mut tempHolder.lock_events, LockerEvent{new_locked_amount: 0, coin_type, coin_name, decimals, locker_address: account_addr});  
    }

    public entry fun extendLockTimed<CoinType>(newAccount: &signer, newUnlockTime: u64) acquires LockerTimed {
        let account_addr = signer::address_of(newAccount);
        let locker = borrow_global_mut<LockerTimed<CoinType>>(account_addr); 
        assert!(
            newUnlockTime > locker.unlock_time,
            error::permission_denied(ENOT_TIME_EXTENSION),
        );
        locker.unlock_time = newUnlockTime;
    }

    //Disables new locks (withdraws/extensions/increases remain unchanged) 
    // For ease of V2 migration
    public entry fun toggleLockerState(deployerSigner: &signer) acquires LockerState{
        let account_addr = signer::address_of(deployerSigner);
        assert!(
            account_addr == @FrensLocker,
            error::permission_denied(OWNER_RESTRICTED),
        );
        let state = borrow_global_mut<LockerState>(account_addr);
        if(state.locker_live == true){
            state.locker_live = false;    
        }
        else{
            state.locker_live = true;
        }
    }

    public entry fun modifyDepositFee(deployerSigner: &signer, newDepositFee: u64) acquires LockerState {
        let account_addr = signer::address_of(deployerSigner);
        assert!(
            account_addr == @FrensLocker,
            error::permission_denied(OWNER_RESTRICTED),
        );
        assert!(
            newDepositFee <= HARD_DEPOSIT_FEE_LIMIT,
            error::permission_denied(OWNER_RESTRICTED),
        );
        let locker_state = borrow_global_mut<LockerState>(@FrensLocker); 
        locker_state.deposit_fee = newDepositFee;
    }

    fun init_module(deployerSigner: &signer) {
        let seeds = vector<u8>[11,11,11,11,11];
        let (_locker_signer, locker_cap) = account::create_resource_account(deployerSigner, seeds); 
        move_to(deployerSigner, LockerState{locker_live: true, locker_cap: locker_cap, deposit_fee: 500000000u64});
    }
}

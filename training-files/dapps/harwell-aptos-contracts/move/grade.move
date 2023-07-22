module harwell::grade_008 {
    use std::vector;
    use std::signer;
    use std::option;
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};

    struct Level has store,copy,drop{
        name: vector<u8>,
        weight: u64,
    }

    struct Deposition has store, drop {
        sequence: u64,
        amount: u64,
        lock_units: u64,
        deposit_time: u64,
    }

    struct DepositEvent has drop, store {
        user: address,
        deposit_sequence: u64,
        deposit_amount: u64,
        lock_units: u64,
        level: Level,
    }

    struct WithdrawEvent has drop, store {
        user: address,
        deposit_sequence: u64,
        deposit_amount: u64,
    }

    struct UserStore<phantom CoinType> has key{
        depositions: vector<Deposition>,
        level: option::Option<Level>,
    }

    struct ModuleStore<phantom CoinType> has store,key {
        signer_capability: account::SignerCapability,
        levels: vector<Level>,
        next_deposit_sequence: u64,
        lock_unit_span: u64,
        total_depositions: u64,
        total_depositors: u64,
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    const INDEX_NOT_FOUND                 :u64 = 0xffffffff;

    const ENOT_DEPLOYER                   :u64 = 0x1001;
    const EALREADY_INITIALIZED            :u64 = 0x1002;
    const ENOT_INITIALIZED                :u64 = 0x1003;
    const ELEVEL_NOT_FOUND                :u64 = 0x1004;
    const EUSER_SOTRE_NOT_FOUND           :u64 = 0x1005;
    const EDEPOSIT_SEQUENCE_NOT_FOUND     :u64 = 0x1006;
    const EWITHDRAW_BEFORE_UNLOCK_TIME    :u64 = 0x1007;

    public entry fun initialize<CoinType>(deployer:&signer,level_names: vector<vector<u8>>, level_weights: vector<u64>, lock_unit_span: u64, seed: vector<u8>) {
        let addr = signer::address_of(deployer);
        assert!(addr==@harwell,ENOT_DEPLOYER);
        assert!(!exists<ModuleStore<CoinType>>(@harwell),EALREADY_INITIALIZED);
        let (resource_signer,signer_capability) = account::create_resource_account(deployer,seed);
        move_to(deployer,ModuleStore<CoinType>{
            signer_capability,
            levels: parse_levels(&level_names,&level_weights),
            next_deposit_sequence: 0,
            lock_unit_span,
            total_depositions: 0,
            total_depositors: 0,
            deposit_events: account::new_event_handle<DepositEvent>(deployer),
            withdraw_events:account::new_event_handle<WithdrawEvent>(deployer),
        });
        managed_coin::register<CoinType>(&resource_signer);
    }

    fun parse_levels(names: &vector<vector<u8>>, weights: &vector<u64>): vector<Level> {
        let levels = vector::empty<Level>();
        let (i,length) = (0,vector::length(names));
        while(i < length) {
            vector::push_back(&mut levels, Level {name: *vector::borrow(names,i),weight: *vector::borrow(weights,i)});
            i = i + 1;
        };
        levels
    }

    public entry fun emergency_withdraw<CoinType>(sender: &signer,to: address, amount: u64) acquires ModuleStore{
        assert!(signer::address_of(sender)==@harwell,ENOT_DEPLOYER);
        let swap_info = borrow_global_mut<ModuleStore<CoinType>>(@harwell);
        let resource_signer = account::create_signer_with_capability(&swap_info.signer_capability);
        coin::transfer<CoinType>(&resource_signer,to,amount);
    }

    public entry fun deposit<CoinType>(user:&signer,amount:u64,lock_units:u64) acquires ModuleStore,UserStore {
        let addr = signer::address_of(user);
        assert!(exists<ModuleStore<CoinType>>(@harwell),ENOT_INITIALIZED);
        if(!exists<UserStore<CoinType>>(addr)){
            move_to(user,UserStore<CoinType>{
                depositions: vector::empty(),
                level: option::none<Level>(),
            });
        };

        let module_store= borrow_global_mut<ModuleStore<CoinType>>(@harwell); 
        let user_store= borrow_global_mut<UserStore<CoinType>>(addr);

        let is_new_user = option::is_none(&user_store.level) ;

        let level = match_level(&module_store.levels,amount*lock_units);
        assert!(option::is_some(&level),ELEVEL_NOT_FOUND);
        let level = option::extract(&mut level);

        if(is_new_user || level.weight > option::borrow(&user_store.level).weight) {
            *&mut user_store.level = option::some(level);
        };
        let resource_signer = account::create_signer_with_capability(&module_store.signer_capability);
        coin::transfer<CoinType>(user,signer::address_of(&resource_signer),amount);

        let deposit_sequence = module_store.next_deposit_sequence;
        number_add(&mut module_store.next_deposit_sequence,1);
        number_add(&mut module_store.total_depositions,amount);
        if(is_new_user) {
            number_add(&mut module_store.total_depositors,1);
        };

        vector::push_back(&mut user_store.depositions,Deposition{
            sequence: module_store.next_deposit_sequence,
            amount,
            lock_units,
            deposit_time: timestamp::now_seconds(),
        });

        event::emit_event<DepositEvent>(&mut module_store.deposit_events,DepositEvent {
            user: addr,
            deposit_sequence,
            deposit_amount:amount,
            lock_units,
            level,
        });
    }


    public entry fun withdraw<CoinType>(user: &signer, deposit_sequence: u64) acquires ModuleStore,UserStore {
        let addr = signer::address_of(user);
        assert!(exists<ModuleStore<CoinType>>(@harwell),ENOT_INITIALIZED);
        assert!(exists<UserStore<CoinType>>(addr),EUSER_SOTRE_NOT_FOUND);
        let module_store= borrow_global_mut<ModuleStore<CoinType>>(@harwell);
        let user_store= borrow_global_mut<UserStore<CoinType>>(addr);
        let index = depostion_index_of(&user_store.depositions,deposit_sequence);
        assert!(index!=INDEX_NOT_FOUND, EDEPOSIT_SEQUENCE_NOT_FOUND);
        let deposition = vector::swap_remove(&mut user_store.depositions,index);

        assert!(
            deposition.deposit_time + deposition.lock_units * module_store.lock_unit_span < timestamp::now_seconds(),
            EWITHDRAW_BEFORE_UNLOCK_TIME,
        );

        let resource_signer = account::create_signer_with_capability(&module_store.signer_capability);
        coin::transfer<CoinType>(&resource_signer,addr,deposition.amount);

        *&mut user_store.level = match_level(&module_store.levels,get_weight(&user_store.depositions));

        number_sub(&mut module_store.total_depositions,deposition.amount);
        if(vector::is_empty(&user_store.depositions)) {
            number_sub(&mut module_store.total_depositors,1);
        };

        event::emit_event<WithdrawEvent>(&mut module_store.withdraw_events,WithdrawEvent {
            user: addr,
            deposit_sequence: deposition.sequence,
            deposit_amount: deposition.amount,
        });
   }

    fun get_weight(depositions: &vector<Deposition>): u64 {
        let (max_value,i,length) = (0,0,vector::length(depositions));
        while(i < length) {
            let deposit = vector::borrow(depositions,i);
            let value = deposit.amount * deposit.lock_units;
            if(value > max_value ) {
                max_value = value;
            };
            i = i + 1;
        };
        max_value
    }

    fun depostion_index_of(depositions: &vector<Deposition>, sequence: u64): u64{
        let (i,length) = (0, vector::length(depositions));
        while(i < length) {
            if(sequence == vector::borrow(depositions,i).sequence) {
                return i
            };
            i = i + 1;
        };
        INDEX_NOT_FOUND
    }

    fun number_add(n: &mut u64, value: u64) {
        *n = *n + value;
    }

    fun number_sub(n: &mut u64, value: u64) {
        *n = *n - value;
    }


    fun match_level(levels: &vector<Level>, weight: u64) : option::Option<Level>{
        let i = 0;
        let length = vector::length(levels);
        if(weight > 0 && length > 0) {
            while(i < length) {
                let item = vector::borrow(levels,length-i-1);
                if(item.weight <= weight) {
                    return option::some(*item)
                };
                i = i +1 ;
            };
        };
        option::none<Level>()
    }
}






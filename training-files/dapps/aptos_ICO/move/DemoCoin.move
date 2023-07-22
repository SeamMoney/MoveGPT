module publisher::DemoCoin{
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::resource_account;
    use aptos_std::type_info;
    use std::string::{utf8, String};
    use std::signer;


    struct DemoCoin{}
    
    struct CapStore has key{
        signer_cap: account::SignerCapability,
        mint_cap: coin::MintCapability<DemoCoin>,
        freeze_cap: coin::FreezeCapability<DemoCoin>,
        burn_cap: coin::BurnCapability<DemoCoin>
    }

    struct DCEventStore has key{
        event_handle: event::EventHandle<String>,
    }

    fun init_module(account: &signer){
        let signer_capabilty = resource_account::retrieve_resource_account_cap(account, @source_addr);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DemoCoin>(account, utf8(b"DCoin"), utf8(b"DC"), 8, true);
        move_to(account, CapStore{signer_cap: signer_capabilty ,mint_cap: mint_cap, freeze_cap: freeze_cap, burn_cap: burn_cap});
    }

    public entry fun register(account: &signer){
        let addr = signer::address_of(account);
        if(!coin::is_account_registered<DemoCoin>(addr)){
            coin::register<DemoCoin>(account);
        };
        if(!exists<DCEventStore>(addr)){
            move_to(account, DCEventStore{event_handle: account::new_event_handle(account)});
        };
    }

    fun emit(account: address, msg: String) acquires DCEventStore{
        event::emit_event<String>(&mut borrow_global_mut<DCEventStore>(account).event_handle, msg);
    }

    public entry fun mint_coin(to_addr: address, amount: u64) acquires CapStore, DCEventStore{
        let mint_cap = &borrow_global<CapStore>(@publisher).mint_cap;
        let mint_coin = coin::mint<DemoCoin>(amount, mint_cap);
        coin::deposit<DemoCoin>(to_addr, mint_coin);
        emit(to_addr, utf8(b"DCoin minted."));
    }

    public entry fun transfer_coin(from: &signer, to: address, amount: u64) {
        aptos_account::transfer_coins<DemoCoin>(from, to, amount);
    } 

    public entry fun burn_coin(account: &signer, amount: u64) acquires CapStore, DCEventStore{
        let owner_address = type_info::account_address(&type_info::type_of<DemoCoin>());
        let burn_cap = &borrow_global<CapStore>(owner_address).burn_cap;
        let burn_coin = coin::withdraw<DemoCoin>(account, amount);
        coin::burn(burn_coin, burn_cap);
        emit(signer::address_of(account), utf8(b"DCoin burned."));
    }

    public entry fun self_freeze(account: &signer) acquires CapStore, DCEventStore{
        let owner_address = type_info::account_address(&type_info::type_of<DemoCoin>());
        let freeze_cap = &borrow_global<CapStore>(owner_address).freeze_cap;
        let freeze_addr = signer::address_of(account);
        coin::freeze_coin_store<DemoCoin>(freeze_addr, freeze_cap);
        emit(freeze_addr, utf8(b"Freezed self."));
    }

    public entry fun unfreeze(cap_owner: &signer, uf_account: address) acquires CapStore, DCEventStore{
        let owner_address = signer::address_of(cap_owner);
        let freeze_cap = &borrow_global<CapStore>(owner_address).freeze_cap;
        coin::unfreeze_coin_store<DemoCoin>(uf_account, freeze_cap);
        emit(uf_account, utf8(b"Unfreezed."));
    }

    public entry fun emergency_freeze(cap_owner: &signer, fr_account: address) acquires CapStore, DCEventStore{
        let owner_address = signer::address_of(cap_owner);
        let freeze_cap = &borrow_global<CapStore>(owner_address).freeze_cap;
        coin::freeze_coin_store<DemoCoin>(fr_account, freeze_cap);
        emit(fr_account, utf8(b"Emergency freezed."));
    }
}
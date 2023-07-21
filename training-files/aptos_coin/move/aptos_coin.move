module aptos_coin_addr::aptos_coin{
    use aptos_framework::coin;
    use aptos_framework::event;
    //defalut
    // use aptos_framework::account;
    // use std::signer;
    use std::string::{utf8,String};
    //AptToken:Erc20
    struct APT{}
   //entry:ction. Unlike the usual function which can be called only by other modules, entry functions can be c
  
   struct CapStore has key{
    //MintCapability:Capability required to mint coins.
    mint_cap:coin::MintCapability<APT>,
    //FreezeCapability:Capability required to freeze a coin store.
    freeze_cap: coin::FreezeCapability<APT>,
    //burn:Capability required to burn coins.
    burn_cap:coin::BurnCapability<APT>
   }

   /*
   EventHandle
   Other modules can emit events to this handle.
   Storage can use this handle to prove the total number of events that happened in the past.
   */
   struct APT_EVENT_STORE has key{
       event_handle:event::EventHandle<String>,
   }
   //init module:
   fun init_module(account:&signer){
    let (burn_cap,freeze_cap,mint_cap)= coin::initialize<APT>(account, utf8(b"APT"), utf8(b"APT"),6,true);
    move_to(account, CapStore{mint_cap:mint_cap,freeze_cap:freeze_cap,burn_cap:burn_cap});
   }

   public entry fun register(){}
   //
   fun emit_event(){}
   //coin mint
   public entry fun mint_coin(){}
   /*
   burn coin:coin delete
   */
   public entry fun burn_coin(){}
   //freeze_coin:coin freeze
   public entry fun freeze_coin(){}
   //emergency_freeze
   public entry fun emergency_freeze(){}
   //unfreeze
   public entry fun unfreeze(){}
}
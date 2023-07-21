module Vault::SimpleVault {
    use std::signer;

    // use aptos_framework::account;
    use aptos_framework::coin;

    // use aptos_std::type_info;
    
    //Errors
    const EINVALID_SIGNER: u64 = 0;
    const EADMIN_ALREADY_EXISTS: u64 = 1;
    const EADMIN_NOT_CREATED: u64 = 3;
    const EINVALID_ADMIN_ACCOUNT: u64 = 4;
    const EDEPOSIT_IS_PAUSED: u64 = 5;
    const EINVALID_AMOUNT: u64 = 6;
    const EVAULT_NOT_CREATED: u64 = 7;
    const ELOW_BALANCE: u64 = 8;
    const EALREADY_PAUSED: u64 = 9;
    const EALREADY_UNPAUSED: u64 = 10;
    const EWITHDRAWAL_IS_PAUSED: u64 = 11;

    // Resources
    struct Admin<phantom CoinType> has key {
        pause: bool,
        coin_store: coin::Coin<CoinType>,
    }
    
    public entry fun create_admin<CoinType>(admin: &signer, amount: u64) {
        let admin_addr = signer::address_of(admin);
        // The @Vault is the address of the account publishing the module. So this can be called only once
        assert!(admin_addr == @Vault, EINVALID_SIGNER);
        assert!(!exists<Admin<CoinType>>(admin_addr), EADMIN_ALREADY_EXISTS);
        assert!(coin::balance<CoinType>(admin_addr) >= amount, ELOW_BALANCE);
        let deposit_amount = coin::withdraw<CoinType>(admin, amount);
        move_to<Admin<CoinType>>(admin, Admin{pause: false, coin_store:deposit_amount});
    }

    public entry fun deposit<CoinType>(depositor: &signer, vault_admin: address, amount: u64) acquires Admin{
        assert!(exists<Admin<CoinType>>(vault_admin), EINVALID_ADMIN_ACCOUNT); 
        let vault_info = borrow_global<Admin<CoinType>>(vault_admin);
        assert!(vault_info.pause == false, EDEPOSIT_IS_PAUSED);

        let depositor_addr = signer::address_of(depositor);
        assert!(coin::balance<CoinType>(depositor_addr) >= amount, ELOW_BALANCE);

        let deposit_amount = coin::withdraw<CoinType>(depositor, amount);
        let vault = borrow_global_mut<Admin<CoinType>>(vault_admin);
        coin::merge<CoinType>(&mut vault.coin_store, deposit_amount);

    }

    public entry fun withdraw_admin<CoinType>(admin: &signer, user: address, amount: u64) acquires Admin {
       let admin_addr = signer::address_of(admin);
       assert!(admin_addr == @Vault, EINVALID_SIGNER);
       assert!(exists<Admin<CoinType>>(admin_addr), EINVALID_ADMIN_ACCOUNT); 
       let vault_info = borrow_global<Admin<CoinType>>(admin_addr);
       assert!(vault_info.pause == false, EWITHDRAWAL_IS_PAUSED);

       let vault = borrow_global_mut<Admin<CoinType>>(admin_addr);
       let coin_to_withdraw = coin::extract(&mut vault.coin_store, amount);

       coin::deposit<CoinType>(user, coin_to_withdraw);
    }

    public entry fun pause<CoinType>(admin: &signer) acquires Admin {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Admin<CoinType>>(admin_addr), EINVALID_ADMIN_ACCOUNT);  
        let vault_info = borrow_global_mut<Admin<CoinType>>(admin_addr);
        assert!(!vault_info.pause, EALREADY_PAUSED);

        vault_info.pause = true;
    }

    public entry fun unpause<CoinType>(admin: &signer) acquires Admin {
        let admin_addr = signer::address_of(admin);
        assert!(exists<Admin<CoinType>>(admin_addr), EINVALID_ADMIN_ACCOUNT);  
        let vault_info = borrow_global_mut<Admin<CoinType>>(admin_addr);
        assert!(vault_info.pause, EALREADY_UNPAUSED);

        vault_info.pause = false;
    }

}
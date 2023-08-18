```rust
module admin::aptopadtoken {
    use std::signer;
    use std::string;
    use aptos_framework::coin;

    const ENOT_ADMIN: u64 = 0;
    const E_ALREADY_HAS_CAPABILITY: u64 = 1;
    const E_DONT_HAVE_CAPABILITY: u64 = 2;
    const SUPPLY: u64 = 10000000;

    struct DogeCoin has key {}

    struct CoinCapabilities has key {
        burn_cap: coin::BurnCapability<DogeCoin>,
        freeze_cap: coin::FreezeCapability<DogeCoin>
    }

    public fun is_admin(addr: address) {
        assert!(addr == @admin, ENOT_ADMIN);
    }

    public fun have_coin_capabilities(addr: address) {
        assert!(exists<CoinCapabilities>(addr), E_DONT_HAVE_CAPABILITY);
    }
    public fun not_have_coin_capabilities(addr: address) {
        assert!(!exists<CoinCapabilities>(addr), E_ALREADY_HAS_CAPABILITY);
    }

    fun init_module(account: &signer) {
        let account_addr = signer::address_of(account);
        is_admin(account_addr);
        not_have_coin_capabilities(account_addr);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<DogeCoin>(
            account,
            string::utf8(b"Doge Coin"),
            string::utf8(b"DOGE"),
            8,
            true
        );

        coin::register<DogeCoin>(account);

        let coins = coin::mint<DogeCoin>(SUPPLY, &mint_cap);
        coin::deposit<DogeCoin>(account_addr, coins);
        coin::destroy_mint_cap<DogeCoin>(mint_cap);
        move_to(account, CoinCapabilities {burn_cap, freeze_cap});
    }

    // public entry fun mint(account: &signer, user: address, amount: u64) acquires CoinCapabilities {
    //     let account_addr = signer::address_of(account);

    //     is_admin(account_addr);
    //     have_coin_capabilities(account_addr);

    //     let mint_cap = &borrow_global<CoinCapabilities>(account_addr).mint_cap;
    //     let coins = coin::mint<DogeCoin>(amount, mint_cap);
    //     coin::deposit<DogeCoin>(user, coins);
    // }

    public entry fun register(account: &signer) {
        coin::register<DogeCoin>(account);
    }

    public entry fun burn(account: &signer, amount: u64) acquires CoinCapabilities {
        // Withdraw from the user.
        let coins = coin::withdraw<DogeCoin>(account, amount);
        let burn_cap = &borrow_global<CoinCapabilities>(@admin).burn_cap; 
        coin::burn<DogeCoin>(coins, burn_cap);
    }

    public entry fun freeze_user(account: &signer, user: address) acquires CoinCapabilities {
        let account_addr = signer::address_of(account);
        is_admin(account_addr);
        have_coin_capabilities(account_addr);

        let freeze_cap = &borrow_global<CoinCapabilities>(@admin).freeze_cap; 
        coin::freeze_coin_store<DogeCoin>(user, freeze_cap);
    }

    public entry fun unfreeze_user(account: &signer, user: address) acquires CoinCapabilities {
        let account_addr = signer::address_of(account);
        is_admin(account_addr);
        have_coin_capabilities(account_addr);

        let freeze_cap = &borrow_global<CoinCapabilities>(@admin).freeze_cap; 
        coin::unfreeze_coin_store<DogeCoin>(user, freeze_cap);
    }
}

```
module simple_aptos_coin::coin_coin {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::coin;


    // Errors
    const ENOT_ADMIN: u64 = 0;
    const ENO_COIN_CAP: u64 = 1;
    const EALREADY_COIN_CAP: u64 = 2;

    // Resources
    struct CoinCoin has key {}
    struct Capabilities has key {
        mint_cap: coin::MintCapability<CoinCoin>,
        burn_cap: coin::BurnCapability<CoinCoin>,
    }


    fun init_module(_: &signer) {}

    public entry fun issue(account: &signer) {
        let account_addr = signer::address_of(account);
        // we verify that we didn't already issued the Coin
        assert!(
            !exists<Capabilities>(account_addr), 
            error::already_exists(EALREADY_COIN_CAP)
        );

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinCoin>(
            account,
            string::utf8(b"Coin Coin"),
            string::utf8(b"COINCOIN"),
            18,
            true
        );
        move_to(account, Capabilities {mint_cap, burn_cap});
        // we don't ever want to be able to freeze coins in users' wallet 
        // so we have to destroy it because this Resource doesn't have drop ability
        coin::destroy_freeze_cap(freeze_cap);
    }


    public entry fun mint(user: &signer, amount: u64) acquires Capabilities {
        let user_addr = signer::address_of(user);
        // we check if the user already issued the Coin
        assert!(exists<Capabilities>(user_addr), error::permission_denied(ENO_COIN_CAP));

        // we need to get the mint_cap from the user account
        let mint_cap = &borrow_global<Capabilities>(user_addr).mint_cap;
        let coins = coin::mint<CoinCoin>(amount, mint_cap);
        coin::register<CoinCoin>(user);
        coin::deposit<CoinCoin>(signer::address_of(user), coins);
    }

    public entry fun burn(user: &signer, amount: u64) acquires Capabilities {
        let user_addr = signer::address_of(user);
        assert!(exists<Capabilities>(user_addr), error::permission_denied(ENO_COIN_CAP));

        let burn_cap = &borrow_global<Capabilities>(user_addr).burn_cap;
        let coins = coin::withdraw<CoinCoin>(user, amount);
        coin::burn<CoinCoin>(coins, burn_cap);
    }
}
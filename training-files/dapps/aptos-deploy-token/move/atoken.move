address admin {

module atoken2 {
    use aptos_framework::coin;
    use std::signer;
    use std::string;

    struct ATN2{}

    struct CoinCapabilities<phantom ATN2> has key {
        mint_capability: coin::MintCapability<ATN2>,
        burn_capability: coin::BurnCapability<ATN2>,
        freeze_capability: coin::FreezeCapability<ATN2>,
    }

    const E_NO_ADMIN: u64 = 0;
    const E_NO_CAPABILITIES: u64 = 1;
    const E_HAS_CAPABILITIES: u64 = 2;

    public entry fun init_atn2(account: &signer) {
        let (burn_capability, freeze_capability,  mint_capability) = coin::initialize<ATN2>(
            account,
            string::utf8(b"A-Token2"),
            string::utf8(b"ATN2"),
            18,
            true,
        );

        assert!(signer::address_of(account) == @admin, E_NO_ADMIN);
        assert!(!exists<CoinCapabilities<ATN2>>(@admin), E_HAS_CAPABILITIES);

        move_to<CoinCapabilities<ATN2>>(account, CoinCapabilities<ATN2>{mint_capability, burn_capability, freeze_capability});
    }

    public entry fun mint<ATN2>(account:&signer, user:address, amount:u64) acquires CoinCapabilities {
        let account_address = signer::address_of(account);
        assert!(account_address == @admin, E_NO_ADMIN);
        assert!(exists<CoinCapabilities<ATN2>>(account_address), E_NO_CAPABILITIES);
        let mint_capability = &borrow_global<CoinCapabilities<ATN2>>(account_address).mint_capability;
        let coins = coin::mint<ATN2>(amount, mint_capability);
        coin::deposit(user, coins)
    }

    public fun burn<ATN2>(coins: coin::Coin<ATN2>) acquires CoinCapabilities {
        let burn_capability = &borrow_global<CoinCapabilities<ATN2>>(@admin).burn_capability;
        coin::burn<ATN2>(coins, burn_capability);
    }
}
}
address admin {

module TestToken {
    use aptos_framework::coin;
    use std::signer;
    use std::string;

    struct TEST1{}

    struct CoinCapabilities<phantom TEST1> has key {
        mint_capability: coin::MintCapability<TEST1>,
        burn_capability: coin::BurnCapability<TEST1>,
        freeze_capability: coin::FreezeCapability<TEST1>,
    }

    const E_NO_ADMIN: u64 = 0;
    const E_NO_CAPABILITIES: u64 = 1;
    const E_HAS_CAPABILITIES: u64 = 2;

    public entry fun init_TEST1(account: &signer) {
        let (burn_capability, freeze_capability, mint_capability) = coin::initialize<TEST1>(
            account,
            string::utf8(b"Test Token"),
            string::utf8(b"TEST1"),
            18,
            true,
        );

        assert!(signer::address_of(account) == @admin, E_NO_ADMIN);
        assert!(!exists<CoinCapabilities<TEST1>>(@admin), E_HAS_CAPABILITIES);
        move_to<CoinCapabilities<TEST1>>(account, CoinCapabilities<TEST1>{mint_capability, burn_capability, freeze_capability});
    }

    public entry fun mint<TEST1>(account: &signer, user: address, amount: u64) acquires CoinCapabilities {
        let account_address = signer::address_of(account);
        assert!(account_address == @admin, E_NO_ADMIN);
        assert!(exists<CoinCapabilities<TEST1>>(account_address), E_NO_CAPABILITIES);
        let mint_capability = &borrow_global<CoinCapabilities<TEST1>>(account_address).mint_capability;
        let coins = coin::mint<TEST1>(amount, mint_capability);
        coin::deposit(user, coins)
    }

    public entry fun burn<TEST1>(coins: coin::Coin<TEST1>) acquires CoinCapabilities {
        let burn_capability = &borrow_global<CoinCapabilities<TEST1>>(@admin).burn_capability;
        coin::burn<TEST1>(coins, burn_capability);
    }
  }
}



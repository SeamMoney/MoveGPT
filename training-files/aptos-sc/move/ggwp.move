module coin::ggwp {
     use aptos_framework::coin::{Self,
        MintCapability, BurnCapability, FreezeCapability
    };
    use std::option::{Self, Option};
    use std::signer::{address_of};
    use std::string;

    struct GGWPCoin has key {}

    struct CapStore has key, store {
        mint: Option<MintCapability<GGWPCoin>>,
        burn: Option<BurnCapability<GGWPCoin>>,
        freeze: Option<FreezeCapability<GGWPCoin>>
    }

    /// Initialize GGWP coin.
    /// Will be called automatically as part of publishing the package.
    fun init_module(account: &signer) {
        if (exists<CapStore>(address_of(account))) {
            return
        };

        let (cap_burn, cap_freeze, cap_mint) = coin::initialize<GGWPCoin>(
            account,
            string::utf8(b"Global Games World Passion"),
            string::utf8(b"GGWP"),
            8,
            true
        );

        let caps = CapStore {
            mint: option::some(cap_mint),
            burn: option::some(cap_burn),
            freeze: option::some(cap_freeze)
        };
        move_to(account, caps);
    }

    /// Register CoinStore for account.
    public entry fun register(account: &signer) {
        coin::register<GGWPCoin>(account);
    }

    /// Mint GGWP tokens by coin owner.
    public entry fun mint_to(account: &signer, amount: u64, to: address) acquires CapStore {
        let caps = borrow_global<CapStore>(address_of(account));
        let minted = coin::mint(amount, option::borrow(&caps.mint));
        coin::deposit(to, minted);
    }

    #[test_only]
    public fun set_up_test(resource_account: &signer) {
        use std::signer;
        use aptos_framework::account;

        account::create_account_for_test(signer::address_of(resource_account));
        init_module(resource_account);
    }
}

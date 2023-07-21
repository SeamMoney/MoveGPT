module coin_mint::coin_coin {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::resource_account;


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

    struct CoinMintingEvent has drop, store {
        receiver_addr: address,
        amount: u64,
    }
    struct ModuleData has key {
        admin_addr: address,
        signer_cap: account::SignerCapability,
        minting_enabled: bool,
        coin_minting_event: event::EventHandle<CoinMintingEvent>,
    }


    // Admin-only functions
    fun assert_is_admin(addr: address) acquires ModuleData {
        let admin = borrow_global<ModuleData>(@coin_mint).admin_addr;
        assert!(addr == admin, error::permission_denied(ENOT_ADMIN));
    }

    fun init_module(resource_acc: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(resource_acc, @source);

        move_to(resource_acc, ModuleData {
            admin_addr: @admin,
            signer_cap,
            minting_enabled: false,
            coin_minting_event: account::new_event_handle<CoinMintingEvent>(resource_acc),
        });
    }

    public entry fun issue(admin: &signer) acquires ModuleData {
        assert!(!exists<Capabilities>(@coin_mint), error::already_exists(EALREADY_COIN_CAP));
        let addr = signer::address_of(admin);
        assert_is_admin(addr);

        let data = borrow_global<ModuleData>(@coin_mint);
        let resource_signer = &account::create_signer_with_capability(&data.signer_cap);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinCoin>(
            resource_signer,
            string::utf8(b"Coin Coin"),
            string::utf8(b"Coin2"),
            18,
            true,
        );
        move_to(resource_signer, Capabilities {mint_cap, burn_cap});
        coin::destroy_freeze_cap(freeze_cap);
    }

    public entry fun enable_minting(admin: &signer, status: bool) acquires ModuleData {
        let addr = signer::address_of(admin);
        assert_is_admin(addr);
        borrow_global_mut<ModuleData>(@coin_mint).minting_enabled = status;
    }

    public entry fun set_admin(admin: &signer, admin_addr: address) acquires ModuleData {
        let addr = signer::address_of(admin);
        assert_is_admin(addr);
        borrow_global_mut<ModuleData>(@coin_mint).admin_addr = admin_addr;
    }


    // public functions
    public entry fun mint(user: &signer, amount: u64) acquires Capabilities {
        assert!(exists<Capabilities>(@coin_mint), error::permission_denied(ENO_COIN_CAP));

        let mint_cap = &borrow_global<Capabilities>(@coin_mint).mint_cap;
        let coins = coin::mint<CoinCoin>(amount, mint_cap);
        coin::register<CoinCoin>(user);
        coin::deposit<CoinCoin>(signer::address_of(user), coins);
    }

    public entry fun burn(user: &signer, amount: u64) acquires Capabilities {
        assert!(exists<Capabilities>(@coin_mint), error::permission_denied(ENO_COIN_CAP));

        let burn_cap = &borrow_global<Capabilities>(@coin_mint).burn_cap;
        let coins = coin::withdraw<CoinCoin>(user, amount);
        coin::burn<CoinCoin>(coins, burn_cap);
    }
}
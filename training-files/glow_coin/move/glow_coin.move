module glow_address::glow_coin {
    use std::signer;
    use std::string::utf8;

    use aptos_std::table::{Self, Table};
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    const ERR_NOT_ADMIN: u64 = 1;
    const ERR_COIN_INITIALIZED: u64 = 2;
    const ERR_COIN_NOT_INITIALZED: u64 = 3;

    struct GlowCoin{}

    struct Config has key {
        white_list: Table<address, bool>,
        tax_buy: u64,
        tax_sell: u64,
    }

    struct Capabilities has key {
        mint_cap: MintCapability<GlowCoin>,
        burn_cap: BurnCapability<GlowCoin>
    }

    public entry fun initialize(admin: &signer) {
        assert!(signer::address_of(admin) == @glow_address, ERR_NOT_ADMIN);
        assert!(!coin::is_coin_initialized<GlowCoin>(), ERR_COIN_INITIALIZED);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<GlowCoin>(admin, utf8(b"GlowCoin"), utf8(b"GLC"), 6, true);
        coin::destroy_freeze_cap(freeze_cap);

        let caps = Capabilities {
            mint_cap,
            burn_cap
        };

        move_to(admin, caps);
        move_to(admin, Config {
            white_list: table::new<address, bool>(),
            tax_buy: 0,
            tax_sell: 0,
        })              
    }

    public entry fun mint(admin: &signer, to_addr: address, amount: u64) acquires Capabilities {
        assert!(signer::address_of(admin) == @glow_address, ERR_NOT_ADMIN);
        assert!(coin::is_coin_initialized<GlowCoin>(), ERR_COIN_INITIALIZED);

        let caps = borrow_global<Capabilities>(@glow_address);
        let coins = coin::mint(amount, &caps.mint_cap);
        
        coin::deposit(to_addr, coins);
    }

    public entry fun burn(user: &signer, amount: u64) acquires Capabilities {
        assert!(coin::is_coin_initialized<GlowCoin>(), ERR_COIN_INITIALIZED);

        let coin = coin::withdraw<GlowCoin>(user, amount);

        let caps = borrow_global<Capabilities>(@glow_address);

        coin::burn(coin, &caps.burn_cap);
    }

    public entry fun whitelist(sender: &signer, addr: address, enable: bool) acquires Config {
        assert!(signer::address_of(sender) == @glow_address, ERR_NOT_ADMIN);

        let white_list = &mut borrow_global_mut<Config>(@glow_address).white_list;
        let exist = table::contains<address, bool>(white_list, addr);

        if (exist && !enable) {
            table::remove<address, bool>(white_list, addr);
        } else if (!exist && enable) {
            table::add<address, bool>(white_list, addr, true);
        } else {
            return
        }
    }

    public entry fun set_tax_buy(sender: &signer, val: u64) acquires Config {
        assert!(signer::address_of(sender) == @glow_address, ERR_NOT_ADMIN);

        let tax_buy = &mut borrow_global_mut<Config>(@glow_address).tax_buy;
        *tax_buy = val;
    }

    public entry fun get_tax_buy(): u64 acquires Config {
        let cfg = borrow_global<Config>(@glow_address);
        let tax_buy = cfg.tax_buy;

        tax_buy
    }

    public entry fun get_tax_sell(): u64 acquires Config {
        let cfg = borrow_global<Config>(@glow_address);
        let tax_sell = cfg.tax_sell;

        tax_sell
    }

    public entry fun set_tax_sell(sender: &signer, val: u64) acquires Config {
        assert!(signer::address_of(sender) == @glow_address, ERR_NOT_ADMIN);

        let tax_sell = &mut borrow_global_mut<Config>(@glow_address).tax_sell;
        *tax_sell = val;
    }

}
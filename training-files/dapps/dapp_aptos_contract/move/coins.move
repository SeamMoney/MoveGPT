module qve_protocol::coins {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    struct QVE {}
    struct MQVE {}
    struct AQVE {}
    struct USDC {}
    struct USDT {}

    struct Caps<phantom CoinType> has key {
        mint: MintCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }

    const MODULE_OWNER: address = @qve_protocol;
    const ERR_NOT_MODULE_OWNER: u64 = 0;

    public entry fun register_coins(token_admin: &signer) {
        let (usdt_b, usdt_f, usdt_m) =
            coin::initialize<USDT>(token_admin,
                utf8(b"Tether"), utf8(b"USDT"), 8, true);
        let (usdc_b, usdc_f, usdc_m) =
            coin::initialize<USDC>(token_admin,
                utf8(b"USD Coin"), utf8(b"USDC"), 8, true);
        let (qve_b, qve_f, qve_m) =
            coin::initialize<QVE>(token_admin,
                utf8(b"QVE Protocol"), utf8(b"QVE"), 8, true);
        let (mqve_b, mqve_f, mqve_m) =
            coin::initialize<MQVE>(token_admin,
                utf8(b"Market Making QVE"), utf8(b"MQVE"), 8, true);
        let (aqve_b, aqve_f, aqve_m) =
            coin::initialize<AQVE>(token_admin,
                utf8(b"Arbitrage QVE"), utf8(b"AQVE"), 8, true);

        coin::destroy_freeze_cap(usdc_f);
        coin::destroy_freeze_cap(usdt_f);
        coin::destroy_freeze_cap(qve_f);
        coin::destroy_freeze_cap(mqve_f);
        coin::destroy_freeze_cap(aqve_f);

        move_to(token_admin, Caps<USDT> { mint: usdt_m, burn: usdt_b });
        move_to(token_admin, Caps<USDC> { mint: usdc_m, burn: usdc_b });
        move_to(token_admin, Caps<QVE> { mint: qve_m, burn: qve_b });
        move_to(token_admin, Caps<MQVE> { mint: mqve_m, burn: mqve_b });
        move_to(token_admin, Caps<AQVE> { mint: aqve_m, burn: aqve_b });
    }

    public fun mint_coin<CoinType>(dest: &signer, amount: u64) acquires Caps {
        if (!coin::is_account_registered<CoinType>(signer::address_of(dest))) {
            coin::register<CoinType>(dest);
        };
        let caps = borrow_global_mut<Caps<CoinType>>(@qve_protocol);
        let coins = coin::mint<CoinType>(amount, &caps.mint);
        coin::deposit(signer::address_of(dest), coins);
    }

    public entry fun mint_coin_entry<CoinType>(owner: &signer, to: address, amount: u64) acquires Caps {
        assert!(signer::address_of(owner) == MODULE_OWNER, ERR_NOT_MODULE_OWNER);
        
        let caps = borrow_global_mut<Caps<CoinType>>(signer::address_of(owner));
        let coins = coin::mint<CoinType>(amount, &caps.mint);
        coin::deposit(to, coins);
    }

    public entry fun deposit_coin_entry<CoinType>(
        from: &signer,
        amount: u64,
    ) {
        if (amount > 0) {
            let coins = coin::withdraw<CoinType>(from, amount);
            coin::deposit<CoinType>(@qve_protocol, coins);
        };
    }
}

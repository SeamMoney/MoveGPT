address Quantum {
// module for Quantum USD the stable coin of the Quantum Ecosystem
module QUSD {

    use std::error;
    use std::string;
    use std::signer;
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_framework::type_info;
    
    // QUSD Token marker
    struct QUSD has copy, drop, store {}

    struct Minting has key, store {
        time: u64,
        amount: u64,
    }

    struct Capabilities<phantom CoinType> has key {
        burn_cap: coin::BurnCapability<CoinType>,
        freeze_cap: coin::FreezeCapability<CoinType>,
        mint_cap: coin::MintCapability<CoinType>,
    }

    const BASE_COIN_NAME: vector<u8> = b"Quantum USD";

    const BASE_COIN_SYMBOL: vector<u8> = b"QUSD";

    const BASE_COIN_DECIMALS: u8 = 9;

    const MINTING_PERIOD: u64 = 24 * 3600; // 24 hours
    const MINTING_INCREASE: u64 = 15000;
    const MINTING_PRECISION: u64 = 100000;

    const ENO_CAPABILITIES: u64 = 1;
    const ERR_MINT_EXCEED: u64 = 401;
    const EDEPRECATED_FUNCTION: u64 = 404;
    
    /// Initialize new coin `CoinType` in Aptos Blockchain.
    /// Mint and Burn Capabilities will be stored under `account` in `Capabilities` resource.
    fun init_coin<CoinType>(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinType>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        move_to(account, Capabilities<CoinType>{
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    public entry fun initialize(account: &signer) {
        init_coin<QUSD>(account, BASE_COIN_NAME, BASE_COIN_SYMBOL,
            BASE_COIN_DECIMALS, true);
        coin::register<QUSD>(account);
        initialize_minting(account);
    }

    public fun initialize_minting(account: &signer) {
        move_to(account, Minting {time: timestamp::now_seconds(), amount: 0});
    }

    fun coin_address<QUSD>(): address {
        let type_info = type_info::type_of<QUSD>();
        type_info::account_address(&type_info)
    }

    public entry fun mint<QUSD>(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires Capabilities {
        let account_addr = signer::address_of(account);

        assert!(
            exists<Capabilities<QUSD>>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capabilities = borrow_global<Capabilities<QUSD>>(account_addr);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(dst_addr, coins_minted);
    }

    public fun supply(): u64 {
        let coin_supply = coin::supply<QUSD>();
        (option::destroy_some(coin_supply) as u64)
    }

    public fun mint_to(account: &signer, to: address, amount: u64) acquires Minting, Capabilities {
        let minting = borrow_global_mut<Minting>(coin_address<QUSD>());
        let total_supply = supply();
        let now = timestamp::now_seconds();
        let total_minted_amount;
        if (now - minting.time > MINTING_PERIOD) {
            total_minted_amount = amount;
        } else {
            total_minted_amount = minting.amount + amount;
        };
        let max_mint_amount = total_supply * MINTING_INCREASE / MINTING_PRECISION;
        assert!(total_supply == 0 || max_mint_amount >= total_minted_amount, ERR_MINT_EXCEED);

        minting.time = now;
        minting.amount = total_minted_amount;
        mint<QUSD>(account, to, amount);
    }
}
}

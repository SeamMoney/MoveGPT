address Quantum {

module QBITS {

    use std::string;
    use std::option;
    use std::error;
    use std::signer;

    use aptos_framework::coin;
    // use aptos_framework::account;

    use Quantum::MathU64;

    const MAX_SUPPLY: u64 = 1 * 1000 * 1000 * 1000; // 1b
    const ENO_CAPABILITIES: u64 = 1;
    const ERR_TOO_BIG_AMOUNT: u64 = 100;

    struct QBITS has copy, drop, store {}

    struct Capabilities<phantom CoinType> has key {
        burn_cap: coin::BurnCapability<CoinType>,
        freeze_cap: coin::FreezeCapability<CoinType>,
        mint_cap: coin::MintCapability<CoinType>,
    }

    const BASE_COIN_NAME: vector<u8> = b"Quantum Bits";

    const BASE_COIN_SYMBOL: vector<u8> = b"QBITS";

    const BASE_COIN_DECIMALS: u8 = 9;

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
        init_coin<QBITS>(account, BASE_COIN_NAME, BASE_COIN_SYMBOL,
            BASE_COIN_DECIMALS, true);
        coin::register<QBITS>(account);
    }

    /// Create new coins `CoinType` and deposit them into dst_addr's account.
    public fun mint_internal<CoinType>(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires Capabilities {
        let account_addr = signer::address_of(account);

        assert!(
            exists<Capabilities<CoinType>>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capabilities = borrow_global<Capabilities<CoinType>>(account_addr);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(dst_addr, coins_minted);
    }

    public fun mint<QBITS>(account: &signer, to: address, amount: u64) acquires Capabilities {
        assert!(get_max_supply() >= ((option::destroy_some(coin::supply<QBITS>()) as u64) + amount), ERR_TOO_BIG_AMOUNT);
        mint_internal<QBITS>(account, to, amount);
    }

    public fun scaling_factor(): u64 {
        MathU64::exp(10, (coin::decimals<QBITS>() as u64))
    }

    public fun get_max_supply(): u64 {
        scaling_factor() * MAX_SUPPLY
    }
}
}

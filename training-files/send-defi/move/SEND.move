address admin {
/// SEND is a governance token of Sendswap DAPP.
/// It uses apis defined in the `Coin` module.
module SEND {

    use std::signer;
    use std::error;
    use std::string;

    use aptos_framework::coin;
    use aptos_framework::type_info;

    /// SEND token marker.
    struct SEND has copy, drop, store {}

    struct Capabilities<phantom SEND> has key {
        burn_cap: coin::BurnCapability<SEND>,
        freeze_cap: coin::FreezeCapability<SEND>,
        mint_cap: coin::MintCapability<SEND>,
    }

    const BASE_COIN_NAME: vector<u8> = b"Send Token";

    const BASE_COIN_SYMBOL: vector<u8> = b"SEND";

    const BASE_COIN_DECIMALS: u8 = 9;

    const ENO_CAPABILITIES: u64 = 1;
    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

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

    /// SEND initialization.
    public entry fun init(account: &signer) {
        init_coin<SEND>(account, BASE_COIN_NAME, BASE_COIN_SYMBOL,
            BASE_COIN_DECIMALS, true);
        coin::register<SEND>(account);
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

    public fun mint<SEND>(account: &signer, to: address, amount: u64) acquires Capabilities {
        mint_internal<SEND>(account, to, amount);
    }

    /// Return true if the type `CoinType1` is same with `CoinType2`
    public fun is_same_token<CoinType1: store, CoinType2: store>(): bool {
        return type_info::type_of<CoinType1>() == type_info::type_of<CoinType2>()
    }

    /// Returns true if `TokenType` is `SEND::SEND`
    public fun is_send<CoinType: store>(): bool {
       is_same_token<SEND, CoinType>()
    }

    public fun assert_genesis_address(account : &signer) {
        assert!(signer::address_of(account) == coin_address<SEND>(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return SEND token address.
    public fun coin_address<SEND>(): address {
        let type_info = type_info::type_of<SEND>();
        type_info::account_address(&type_info)
    }


    /// Return SEND precision.
    public fun precision(): u8 {
        BASE_COIN_DECIMALS
    }
}
}
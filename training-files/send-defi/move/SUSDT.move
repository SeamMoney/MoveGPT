address admin {
module SUSDT {
    use std::string;
    use std::error;
    use std::signer;
    use aptos_framework::coin;

    /// SUSDT token marker.
    struct SUSDT has copy, drop, store {}

    struct Capabilities<phantom SUSDT> has key {
        burn_cap: coin::BurnCapability<SUSDT>,
        freeze_cap: coin::FreezeCapability<SUSDT>,
        mint_cap: coin::MintCapability<SUSDT>,
    }

    /// Account has no capabilities (burn/mint).
    const ENO_CAPABILITIES: u64 = 1;

    const BASE_COIN_NAME: vector<u8> = b"Aptos Pegged USDT";

    const BASE_COIN_SYMBOL: vector<u8> = b"USDT";

    const BASE_COIN_DECIMALS: u8 = 6;

    /// Initialize new coin `CoinType` in Aptos Blockchain.
    /// Mint and Burn Capabilities will be stored under `account` in `Capabilities` resource.
    fun initialize<CoinType>(
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

    public entry fun init_coin(account: &signer) {
        initialize<SUSDT>(account, BASE_COIN_NAME, BASE_COIN_SYMBOL,
            BASE_COIN_DECIMALS, true);
    }

    public entry fun mint<SUSDT>(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires Capabilities {
        let account_addr = signer::address_of(account);

        assert!(
            exists<Capabilities<SUSDT>>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capabilities = borrow_global<Capabilities<SUSDT>>(account_addr);
        let coins_minted = coin::mint(amount, &capabilities.mint_cap);
        coin::deposit(dst_addr, coins_minted);
    }

    
    public entry fun register<SUSDT>(account: &signer) {
        coin::register<SUSDT>(account);
    }
}
}
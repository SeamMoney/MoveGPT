module testcoin::testcoin {
    use std::signer;
    use std::string;
    use std::error;

    use aptos_framework::coin;

    struct CoinCapabilities<phantom CoinType> has key {
        burn_capability: coin::BurnCapability<CoinType>,
    }

    struct TESTCOIN { }

    const ERR_CAPS_NOT_FOUND: u64 = 0;

    public entry fun mint_testcoin<CoinType>(
        issuer: &signer,
        name: string::String,
        symbol: string::String,
        decimals: u8,
        amount: u64
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize(issuer, name, symbol, decimals, true);
        let coins_minted = coin::mint<CoinType>(amount, &mint_cap);
        coin::deposit(signer::address_of(issuer), coins_minted);

        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_mint_cap(mint_cap);

        move_to<CoinCapabilities<CoinType>>(issuer,
            CoinCapabilities<CoinType>{
                burn_capability: burn_cap,
        });
    }

    public entry fun burn<CoinType>(
        account: &signer,
        amount: u64
    ) acquires CoinCapabilities {
        let account_addr = signer::address_of(account);

        assert!(exists<CoinCapabilities<CoinType>>(account_addr), error::not_found(ERR_CAPS_NOT_FOUND));

        let caps = borrow_global<CoinCapabilities<CoinType>>(account_addr);

        let to_burn = coin::withdraw<CoinType>(account, amount);
        coin::burn(to_burn, &caps.burn_capability)
    }
}
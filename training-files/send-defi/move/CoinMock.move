address admin {

module CoinMock {

    use std::string;

    use aptos_framework::coin;
    use aptos_framework::type_info;

    struct CoinSharedCapability<phantom CoinType> has key, store {
        mint_cap: coin::MintCapability<CoinType>,
        burn_cap: coin::BurnCapability<CoinType>,
        freeze_cap: coin::FreezeCapability<CoinType>,
    }

    // mock ETH token
    struct WETH has copy, drop, store {}

    // mock USDT token
    struct WUSDT has copy, drop, store {}

    // mock DAI token
    struct WDAI has copy, drop, store {}

    // mock BTC token
    struct WBTC has copy, drop, store {}

    // mock DOT token
    struct WDOT has copy, drop, store {}

    const WETH_NAME: vector<u8> = b"Mock WETH";

    const WUSDT_NAME: vector<u8> = b"Mock WUSDT";

    const WDAI_NAME: vector<u8> = b"Mock WDAI";

    const WBTC_NAME: vector<u8> = b"Mock WBTC";

    const WDOT_NAME: vector<u8> = b"Mock WDOT";

    const WETH_SYMBOL: vector<u8> = b"WETH";

    const WUSDT_SYMBOL: vector<u8> = b"WUSDT";

    const WDAI_SYMBOL: vector<u8> = b"WDAI";

    const WBTC_SYMBOL: vector<u8> = b"WBTC";

    const WDOT_SYMBOL: vector<u8> = b"WDOT";

    const BASE_COIN_DECIMALS: u8 = 9;

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

        move_to(account, CoinSharedCapability<CoinType>{
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }


    public fun register_coin<CoinType: store>(account: &signer){
        initialize<WETH>(account, WETH_NAME, WETH_SYMBOL, BASE_COIN_DECIMALS, true);
        initialize<WUSDT>(account, WUSDT_NAME, WUSDT_SYMBOL, BASE_COIN_DECIMALS, true);
        initialize<WDAI>(account, WDAI_NAME, WDAI_SYMBOL, BASE_COIN_DECIMALS, true);
        initialize<WBTC>(account, WBTC_NAME, WBTC_SYMBOL, BASE_COIN_DECIMALS, true);
        initialize<WDOT>(account, WDOT_NAME, WDOT_SYMBOL, BASE_COIN_DECIMALS, true);
        coin::register<WETH>(account);
        coin::register<WUSDT>(account);
        coin::register<WDAI>(account);
        coin::register<WBTC>(account);
        coin::register<WDOT>(account);
    }

    /// Return SEND token address.
    public fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    public fun mint_token<CoinType: store>(amount: u64): coin::Coin<CoinType> acquires CoinSharedCapability{
        //token holder address
        let cap = borrow_global<CoinSharedCapability<CoinType>>(coin_address<CoinType>());
        coin::mint<CoinType>(amount, &cap.mint_cap)
    }

    public fun burn_token<CoinType: store>(tokens: coin::Coin<CoinType>) acquires CoinSharedCapability{
        //token holder address
        let cap = borrow_global<CoinSharedCapability<CoinType>>(coin_address<CoinType>());
        coin::burn<CoinType>(tokens, &cap.burn_cap);
    }
}

}


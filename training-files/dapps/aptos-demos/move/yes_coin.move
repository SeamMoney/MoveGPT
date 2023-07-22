module private_coin::yes_coin {
    use std::string;
    use std::error;
    use std::signer;

    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};

    //
    // Errors
    //

    /// Account has no capabilities (burn/mint).
    const ENO_CAPABILITIES: u64 = 1;

    struct Capabilities<phantom CoinType> has key {
        burn_cap: BurnCapability<CoinType>,
        freeze_cap: FreezeCapability<CoinType>,
        mint_cap: MintCapability<CoinType>,
    }

    struct YesCoin {}

    fun init_module(sender: &signer, name: vector<u8>) {
        // aptos_framework::managed_coin::initialize<YesCoin>(
        //     sender,
        //     b"Moon Coin",
        //     b"MOON",
        //     6,
        //     false,
        // );
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<YesCoin>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        move_to(account, Capabilities<YesCoin> {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }


}
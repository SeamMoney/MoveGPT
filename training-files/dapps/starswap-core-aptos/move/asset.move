
module bridge::asset {
    use aptos_framework::coin::{Self};
    use aptos_framework::managed_coin;
    use std::signer;

    /// USDT token marker.
    struct USDT has copy, drop, store {}

    /// USDC token marker.
    struct USDC has copy, drop, store {}

    /// precision of USDT token.
    const PRECISION: u8 = 6;

    /// USDT initialization.
    public entry fun init(account: &signer) {
        managed_coin::initialize<USDT>(
            account,
            b"USDT Coin",
            b"USDT",
            PRECISION,
            true,
        );
        coin::register<USDT>(account);
    }

    public entry fun mint(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<USDT>(account, dst_addr, (amount as u64))
    }

    /// USDC initialization.
    public entry fun init_usdc(account: &signer) {
        managed_coin::initialize<USDC>(
            account,
            b"USDC Coin",
            b"USDC",
            PRECISION,
            true,
        );
        coin::register<USDC>(account);
    }

    public entry fun mint_usdc(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<USDC>(account, dst_addr, (amount as u64))
    }

}

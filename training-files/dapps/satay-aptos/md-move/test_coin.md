```rust
#[test_only]
module satay::test_coin {
    use std::signer;
    use std::string::utf8;

    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};

    /// Represents test USDC coin.
    struct USDC {}

    /// Storing mint/burn capabilities for `USDT` and `BTC` coins under user account.
    struct Caps<phantom CoinType> has key {
        mint: MintCapability<CoinType>,
        burn: BurnCapability<CoinType>,
    }

    public fun register_coin<CoinType>(token_admin: &signer) {
        let (
            burn,
            freeze,
            mint
        ) = coin::initialize<CoinType>(
            token_admin,
            utf8(b"USDC"),
            utf8(b"USDC"),
            8,
            true
        );
        coin::destroy_freeze_cap(freeze);
        move_to(token_admin, Caps<CoinType> { mint, burn });
    }

    /// Mints new coin `CoinType` on account `acc_addr`.
    public fun mint_coin<CoinType>(token_admin: &signer, acc_addr: address, amount: u64) acquires Caps {
        let token_admin_addr = signer::address_of(token_admin);
        let caps = borrow_global<Caps<CoinType>>(token_admin_addr);
        let coins = coin::mint<CoinType>(amount, &caps.mint);
        coin::deposit(acc_addr, coins);
    }

    public fun mint<CoinType>(token_admin: &signer, amount: u64): Coin<CoinType> acquires Caps {
        let token_admin_addr = signer::address_of(token_admin);
        let caps = borrow_global<Caps<CoinType>>(token_admin_addr);
        coin::mint<CoinType>(amount, &caps.mint)
    }
}
```
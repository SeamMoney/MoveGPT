```rust
/// Holds the struct used for VaultCoin in the satay package
/// Deployed by the resource account created in satay::vault_coin_account
module satay_coins::vault_coin {
    /// the VaultCoin generic struct
    struct VaultCoin<phantom BaseCoin> {}
}

```
```rust
module publisher::MyCoinMyRules {
    use std::signer;
    use publisher::AptosCoinGeneric;

    struct MyCoinMyRules has key,drop {}

    public fun setup_and_mint(account: &signer, amount: u64) {
        AptosCoinGeneric::publish_balance<MyCoinMyRules>(account);
        AptosCoinGeneric::mint<MyCoinMyRules>(signer::address_of(account), amount, MyCoinMyRules {});
    }

    public fun transfer(from: &signer, to: address, amount: u64) {
        // amount must be odd.
        assert!(amount % 2 == 1, ENOT_ODD);
        AptosCoinGeneric::transfer<MyCoinMyRules>(from, to, amount, MyCoinMyRules {});
    }
}
```
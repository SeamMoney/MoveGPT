```rust
//:!:>moon
module MoonCoin::moon_coin {
    struct MoonCoin {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<MoonCoin>(
            sender,
            b"Moon Coin",
            b"MOON",
            6,
            false,
        );
    }

    fun mint(sender: &signer, dst_addr:address, amount: u64) {
        aptos_framework::managed_coin::mint<MoonCoin>(
            sender,
            dst_addr,
            amount,
        );
    }
}
//<:!:moon

```
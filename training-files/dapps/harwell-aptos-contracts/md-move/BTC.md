```rust
module coin::BTC {

    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"BTC", b"BTC", 8, false);
    }
}
```
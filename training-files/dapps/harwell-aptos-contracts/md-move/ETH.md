```rust
module coin::ETH {

    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"ETH", b"ETH", 8, false);
    }
}
```
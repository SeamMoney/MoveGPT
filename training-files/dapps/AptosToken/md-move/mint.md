```rust
script {
    fun mint(account: &signer, dst_addr: address, amount: u64) {
        aptos_framework::managed_coin::mint<MoonCoin::moon_coin::MoonCoin>(account, dst_addr, amount)
    }
}



```
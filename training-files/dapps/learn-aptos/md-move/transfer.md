```rust
script {
    use aptos_framework::coin;

    fun transfer(account: &signer, dest: address) {
        coin::transfer<testcoin::testcoin::TESTCOIN>(account, dest, 100);
    }
}
```
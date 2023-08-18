```rust
module aptos_launch_token::aptos_launch_token {

    struct AptosLaunchToken {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<AptosLaunchToken>(
            sender,
            b"Aptos Launch Token",
            b"ALT",
            8,
            false,
        );
    }
}
```
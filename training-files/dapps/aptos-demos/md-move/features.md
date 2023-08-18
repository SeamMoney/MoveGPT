```rust
script {
    use std::features;
    use std::debug;
    use 0x1::vector;

    fun main(account: &signer) {
        let enable = vector::empty<u64>();
        vector::push_back(&mut enable, 1);
        vector::push_back(&mut enable, 3);
        vector::push_back(&mut enable, 5);
        let disable = vector::empty<u64>();

        debug::print(&features::bulletproofs_enabled());

        features::change_feature_flags(account, enable, disable);
        
        debug::print(&features::bulletproofs_enabled());
    }
}
```
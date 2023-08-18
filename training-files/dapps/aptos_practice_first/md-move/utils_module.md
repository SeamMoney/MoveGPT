```rust
module use_oracle::utils_module {
    use std::error;
    use std::string::{String};
    use aptos_framework::type_info;

    const ENOT_OWNER: u64 = 1;

    // coin_key
    public fun key<C>(): String {
        type_info::type_name<C>()
    }

    // permission
    public fun owner_address(): address {
        @use_oracle
    }
    public fun is_owner(account: address): bool {
        account == owner_address()
    }
    public fun assert_owner(account: address) {
        assert!(is_owner(account),error::invalid_argument(ENOT_OWNER));
    }

    #[test_only]
    struct USDC {}
    #[test_only]
    struct WETH {}
}

```
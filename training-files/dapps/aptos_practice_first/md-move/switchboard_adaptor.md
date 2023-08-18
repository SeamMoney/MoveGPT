```rust
module use_oracle::switchboard_adaptor {
    use std::error;
    use std::signer;
    use std::string::String;
    use aptos_std::simple_map;
    use switchboard::aggregator;
    use switchboard::math;
    use use_oracle::utils_module::{Self, key};

    const ENOT_INITIALIZED: u64 = 1;
    const EALREADY_INITIALIZED: u64 = 2;
    const ENOT_REGISTERED: u64 = 3;
    const EALREADY_REGISTERED: u64 = 4;

    struct Storage has key {
        aggregators: simple_map::SimpleMap<String, address>
    }

    ////////////////////////////////////////////////////
    /// Manage module
    ////////////////////////////////////////////////////
    public entry fun initialize(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        utils_module::assert_owner(signer::address_of(owner));
        assert!(!exists<Storage>(owner_addr), error::invalid_argument(EALREADY_INITIALIZED));
        move_to(owner, Storage { aggregators: simple_map::create<String, address>() })
    }

    public entry fun add_aggregator<C>(owner: &signer, aggregator: address) acquires Storage {
        let owner_addr = signer::address_of(owner);
        utils_module::assert_owner(owner_addr);
        let key = key<C>();
        assert!(exists<Storage>(owner_addr), error::invalid_argument(ENOT_INITIALIZED));
        assert!(!is_registered(key), error::invalid_argument(EALREADY_REGISTERED));
        let aggrs = &mut borrow_global_mut<Storage>(owner_addr).aggregators;
        simple_map::add<String, address>(aggrs, key, aggregator);
    }
    fun is_registered(key: String): bool acquires Storage {
        let storage_ref = borrow_global<Storage>(utils_module::owner_address());
        is_registered_internal(key, storage_ref)
    }
    fun is_registered_internal(key: String, storage: &Storage): bool {
        simple_map::contains_key(&storage.aggregators, &key)
    }

    ////////////////////////////////////////////////////
    /// Feed
    ////////////////////////////////////////////////////
    fun price_from_aggregator(aggregator_addr: address): (u128, u8) {
        let latest_value = aggregator::latest_value(aggregator_addr);
        let (value, dec, _) = math::unpack(latest_value);
        (value, dec) // TODO: use neg in struct SwitchboardDecimal
    }
    fun price_internal(key: String): (u128, u8) acquires Storage {
        let owner_addr = utils_module::owner_address();
        assert!(exists<Storage>(owner_addr), error::invalid_argument(ENOT_INITIALIZED));
        assert!(is_registered(key), error::invalid_argument(ENOT_REGISTERED));
        let aggrs = &borrow_global<Storage>(owner_addr).aggregators;
        let aggregator_addr = simple_map::borrow<String, address>(aggrs, &key);
        price_from_aggregator(*aggregator_addr)
    }
    public fun price<C>(): (u128, u8) acquires Storage {
        let (value, dec) = price_internal(key<C>());
        (value, dec)
    }
    public fun price_of(name: &String): (u128, u8) acquires Storage {
        let (value, dec) = price_internal(*name);
        (value, dec)
    }
    // public fun volume<C>(amount: u128): u128
    // public fun volume_of(name: &String, amount: u128): u128

    #[test_only]
    use std::vector;
    #[test_only]
    use std::unit_test;
    #[test_only]
    use use_oracle::utils_module::{WETH, USDC};
    #[test(owner = @use_oracle)]
    fun test_initialize(owner: &signer) {
        initialize(owner);
        assert!(exists<Storage>(signer::address_of(owner)), 0);
    }
    #[test(account = @0x111)]
    #[expected_failure(abort_code = 65537)]
    fun test_initialize_with_not_owner(account: &signer) {
        initialize(account);
    }
    #[test(owner = @use_oracle)]
    #[expected_failure(abort_code = 65538)]
    fun test_initialize_twice(owner: &signer) {
        initialize(owner);
        initialize(owner);
    }
    #[test(owner = @use_oracle)]
    fun test_add_aggregator(owner: &signer) acquires Storage {
        initialize(owner);
        add_aggregator<WETH>(owner, @0xAAA);
        let aggregator = simple_map::borrow(&borrow_global<Storage>(signer::address_of(owner)).aggregators, &key<WETH>());
        assert!(aggregator == &@0xAAA, 0);
    }
    #[test(account = @0x111)]
    #[expected_failure(abort_code = 65537)]
    fun test_add_aggregator_with_not_owner(account: &signer) acquires Storage {
        add_aggregator<WETH>(account, @0xAAA);
    }
    #[test(owner = @use_oracle)]
    #[expected_failure(abort_code = 65537)]
    fun test_add_aggregator_before_initialize(owner: &signer) acquires Storage {
        add_aggregator<WETH>(owner, @0xAAA);
    }
    #[test(owner = @use_oracle)]
    #[expected_failure(abort_code = 65540)]
    fun test_add_aggregator_twice(owner: &signer) acquires Storage {
        initialize(owner);
        add_aggregator<WETH>(owner, @0xAAA);
        add_aggregator<WETH>(owner, @0xAAA);
    }
    #[test(owner = @use_oracle, usdc_aggr = @0x111AAA, weth_aggr = @0x222AAA)]
    fun test_end_to_end(owner: &signer, usdc_aggr: &signer, weth_aggr: &signer) acquires Storage {
        aggregator::new_test(usdc_aggr, 2, 0, false);
        aggregator::new_test(weth_aggr, 3, 0, false);

        initialize(owner);
        add_aggregator<USDC>(owner, signer::address_of(usdc_aggr));
        add_aggregator<WETH>(owner, signer::address_of(weth_aggr));

        let (usdc_value, usdc_dec) = price_from_aggregator(signer::address_of(usdc_aggr));
        assert!(usdc_value == 2 * math::pow_10(9), 0);
        assert!(usdc_dec == 9, 0);
        let (weth_value, weth_dec) = price_from_aggregator(signer::address_of(weth_aggr));
        assert!(weth_value == 3 * math::pow_10(9), 0);
        assert!(weth_dec == 9, 0);
        let (usdc_value, usdc_dec) = price<USDC>();
        assert!(usdc_value / math::pow_10(usdc_dec) == 2, 0);
        let (weth_value, weth_dec) = price<WETH>();
        assert!(weth_value / math::pow_10(weth_dec) == 3, 0);
        let (usdc_value, usdc_dec) = price_of(&key<USDC>());
        assert!(usdc_value / math::pow_10(usdc_dec) == 2, 0);
        let (weth_value, weth_dec) = price_of(&key<WETH>());
        assert!(weth_value / math::pow_10(weth_dec) == 3, 0);
    }
    #[test]
    fun test_aggregator() {
        let signers = unit_test::create_signers_for_testing(1);

        let acc1 = vector::borrow(&signers, 0);
        aggregator::new_test(acc1, 100, 0, false);
        let (val, dec, is_neg) = math::unpack(aggregator::latest_value(signer::address_of(acc1)));
        assert!(val == 100 * math::pow_10(dec), 0);
        assert!(dec == 9, 0);
        assert!(is_neg == false, 0);        
    }
}

```
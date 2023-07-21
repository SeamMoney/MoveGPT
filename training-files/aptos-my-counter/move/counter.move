module publisher::counter {
    use std::signer;

    struct CounterHolder has key {
        count: u64
    }

    public fun get_count(addr: address): u64 acquires CounterHolder {
        assert!(exists<CounterHolder>(addr), 0);
        *&borrow_global<CounterHolder>(addr).count
    }

    public entry fun bump(account: signer) acquires CounterHolder {
        let addr = signer::address_of(&account);
        if (!exists<CounterHolder>(addr)) {
            move_to(&account, CounterHolder {
                count: 0
            })
        } else {
            let old_count = borrow_global_mut<CounterHolder>(addr);
            old_count.count = old_count.count + 1;
        }
    }
}
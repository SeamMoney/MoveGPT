module hello_aptos::counter {
    use std::signer::address_of;

    struct Counter has key {
        value: u8,
    }

    public fun increment(signer: &signer) acquires Counter {
        let addr = address_of(signer);
        if (!exists<Counter>(addr)) {
            move_to(signer, Counter { value: 0 });
        };

        let r = borrow_global_mut<Counter>(addr);
        r.value = r.value + 1;
    }

    public fun increment2(addr: address) acquires Counter {
        let r = borrow_global_mut<Counter>(addr);
        r.value = r.value + 1;
    }

    spec increment2 {
        let conter = global<Counter>(addr).value;


        let post conter_post = global<Counter>(addr).value;
        ensures conter_post == conter + 1;
    }


    public fun counter(addr: address): u8 acquires Counter {
        borrow_global<Counter>(addr).value
    }


    #[test(signer = @hello_aptos)]
    public fun test_increment(signer: &signer) acquires Counter {
        increment(signer);
        let counter_log_1 = counter(address_of(signer));
        increment(signer);
        let counter_log_2 = counter(address_of(signer));
        assert!(counter_log_1 + 1 == counter_log_2, 1);
    }
}

module AptosCounter::Counter {

    use std::error;
    use std::signer;

    struct CounterHolder has key {
        counter: u8
    }

    public entry fun init_counter(account: signer)
    acquires CounterHolder {
        let counter: u8 = 0;
        let account_addr = signer::address_of(&account);
        if (!exists<CounterHolder>(account_addr)) {
            move_to(&account, CounterHolder {
                counter,
            })
        } else {
            let old_counter_holder = borrow_global_mut<CounterHolder>(account_addr);
            old_counter_holder.counter = 0;
        }
    }

    const ENOT_INIT: u64 = 0;

    public fun get_counter(account: signer): u8 acquires CounterHolder {
        let account_addr = signer::address_of(&account);
        let counter = borrow_global_mut<CounterHolder>(account_addr);
        counter.counter
    }

    public entry fun inc_counter(account: signer)
    acquires CounterHolder {
        let account_addr = signer::address_of(&account);
        let counter = borrow_global_mut<CounterHolder>(account_addr);
        counter.counter = counter.counter + 1
    }

}
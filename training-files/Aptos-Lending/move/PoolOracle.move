address Quantum {
module PoolOracle {
    use std::event;
    use std::signer;

    use aptos_framework::timestamp;
    use aptos_framework::account;

    use Quantum::SafeMathU64;
    use Quantum::AptPoolOracle;

    struct UpdateEvent has drop, store {}

    struct Price<phantom PoolType> has key, store {
        oracle_name: vector<u8>,
        exchange_rate: u64,
        scaling_factor: u64,
        last_updated: u64,
        events: event::EventHandle<UpdateEvent>,
    }
    // 1e12
    const PRECISION: u64 = 1000000 * 1000000;

    // error code
    const ERR_NOT_REGISTER: u64 = 201;
    const ERR_NOT_AUTHORIZED: u64 = 202;
    const ERR_NOT_EXIST : u64 = 203;

    public fun admin_address(): address {
        @Quantum
    }

    // get T issuer
    fun t_address<T: store>(): address { admin_address() }

    fun assert_is_register<PoolType: store>(): address {
        let owner = t_address<PoolType>();
        assert!(exists<Price<PoolType>>(owner), ERR_NOT_REGISTER);
        owner
    }

    // only PoolType's issuer can register
    public fun register<PoolType: store>(account: &signer, oracle_name: vector<u8>) {
        assert!(signer::address_of(account) == t_address<PoolType>(), ERR_NOT_AUTHORIZED);
        move_to(
            account,
            Price<PoolType> {
                oracle_name: oracle_name,
                exchange_rate: 0,
                scaling_factor: 0,
                last_updated: timestamp::now_seconds(),
                events: account::new_event_handle<UpdateEvent>(account),
            },
        );
    }

    public fun get<PoolType: store>(): (u64, u64, u64) acquires Price {
        let owner = assert_is_register<PoolType>();
        let price = borrow_global<Price<PoolType>>(owner);
        (price.exchange_rate, price.scaling_factor, price.last_updated)
    }

    public fun latest_price<PoolType: store>(): (u64, u64) acquires Price {
        let owner = assert_is_register<PoolType>();
        let name = *&borrow_global<Price<PoolType>>(owner).oracle_name;
        if (name == b"APT_POOL") {
            AptPoolOracle::get()
        } else {
            (0, 0)
        }
    }

    public fun latest_exchange_rate<PoolType: store>(): (u64, u64) acquires Price {
        let (e, s) = latest_price<PoolType>();
        if (e > 0) {
            (SafeMathU64::safe_mul_div(s, PRECISION, e), PRECISION)
        } else {
            (0, 0)
        }
    }

    public fun update<PoolType: store>(): (u64, u64) acquires Price {
        let (e, s) = latest_price<PoolType>();
        if (e > 0) {
            do_update<PoolType>(e, s)
        } else {
            (0, 0)
        }
    }

    // how much collateral to buy 1 QUSD
    fun do_update<PoolType: store>(exchange_rate: u64, scaling_factor: u64): (u64, u64) acquires Price {
        let price = borrow_global_mut<Price<PoolType>>(t_address<PoolType>());
        let new_exchange_rate = SafeMathU64::safe_mul_div(scaling_factor, PRECISION, exchange_rate);
        price.exchange_rate = new_exchange_rate;
        price.scaling_factor = PRECISION;
        price.last_updated = timestamp::now_seconds();
        event::emit_event(&mut price.events, UpdateEvent {});
        (new_exchange_rate, PRECISION)
    }
}
}

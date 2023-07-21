/// Price data is committed to a Safe to allow price data modularity. Safes are stored on addresses
/// called namespaces. Upon Safe creation, a SafeWriteCapability is returned. SafeWriteCapability
/// is required to write to the Safe.
module argo_safe::safe {
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use std::error;
    use std::signer::{address_of};

    //
    // ERRORS
    //

    const ESAFE_ALREADY_EXISTS: u64 = 0;

    //
    // CORE STRUCTS
    //

    /// Safe stores price information.
    struct Safe has key {
        // Up to the application to decide the units and denomination.
        // CONVENTION: Use 6 decimals with respect to the denominating currency.  E.g. 1.15 EUR/USD
        // would be represented as 1_150000.
        price: u64,
        // Time of last update in seconds. This value is always clamped to a minimum between
        // current_time and fresh_time at the time of write
        fresh_time: u64,
        /// WritePriceEvent storage.
        write_price_events: EventHandle<WritePriceEvent>,
    }

    /// Capability required to write price to a Safe.
    struct SafeWriteCapability has drop, store {
        safe_addr: address
    }

    //
    // EVENTS
    //

    /// Event emitted whenever a Safe's price has been updated.
    struct WritePriceEvent has drop, store {
        price: u64,
        fresh_time: u64,
    }

    //
    // WRITE
    //

    /// Creates a new Safe stored at `namespace`.
    public fun new_safe(namespace: &signer): SafeWriteCapability {
        let namespace_addr = address_of(namespace);
        assert!(!exists<Safe>(namespace_addr), error::invalid_argument(ESAFE_ALREADY_EXISTS));
        move_to(namespace, Safe {
            price: 0,
            fresh_time: 0,
            write_price_events: account::new_event_handle<WritePriceEvent>(namespace),
        });
        return SafeWriteCapability {
            safe_addr: namespace_addr,
        }
    }

    /// Writes a new `price` and `fresh_time`.
    public fun write_price(
        price: u64,
        fresh_time: u64,
        cap: &SafeWriteCapability,
    ) acquires Safe {
        let safe = borrow_global_mut<Safe>(cap.safe_addr);
        let next_fresh_time = min(timestamp::now_seconds(), fresh_time);
        if (next_fresh_time <= safe.fresh_time) {
            // Return early as we only allow price updates in the future.
            return
        };
        safe.price = price;
        safe.fresh_time = next_fresh_time;
        event::emit_event(&mut safe.write_price_events, WritePriceEvent { price, fresh_time });
    }

    //
    // VIEW
    //

    /// Returns the smaller of two values.
    fun min(a: u64, b: u64): u64 {
        if (a <= b) return a;
        return b
    }

    /// Returns the price field of a Safe.
    public fun price(safe_addr: address): u64 acquires Safe {
        return borrow_global<Safe>(safe_addr).price
    }

    /// Returns the fresh_time field of a Safe.
    public fun fresh_time(safe_addr: address): u64 acquires Safe {
        return borrow_global<Safe>(safe_addr).fresh_time
    }
}
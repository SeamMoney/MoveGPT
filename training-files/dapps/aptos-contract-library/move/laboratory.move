/// laboratory is an immutable manager for USDA.
module argo_core::laboratory {
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use std::error;
    use std::signer::{address_of};
    use std::string;
    use std::vector;
    use usda::usda::{USDA};

    //
    // ERRORS
    //

    const EALREADY_EXISTS: u64 = 0;
    const ENOT_USDA: u64 = 1;
    const ENO_MANAGEMENT_CAPABILITY: u64 = 2;
    const EPAUSED: u64 = 3;
    const EMAX_SUPPLY_EXCEEDED: u64 = 4;
    const EMETER_LIMIT_EXCEEDED: u64 = 5;
    const ETIMED_LIMIT_EXCEEDED: u64 = 6;

    //
    // CORE STRUCTS
    //

    /// Capability for managing the Laboratory.
    struct LabAdminCapability has store, drop { }

    /// Capability for to minting and burning USDA.
    struct USDASupplyCapability has store, drop {
        /// References an index in Laboratory.usda_meters.
        id: u64,
    }

    /// Stores a MeterCap's limit and usage.
    struct USDAMeter has store {
        /// Max amount of USDA that can be minted from this meter.
        limit: u64,
        /// Amount of USDA that has been minted from this meter.
        usage: u64,
    }

    /// Stores global capabilities and protocol interest.
    struct Laboratory has key {
        // USDA management
        /// Capability required to burn USDA.
        burn_cap: BurnCapability<USDA>,
        /// Capability required to freeze USDA. It is unused, but we store it because it cannot be
        /// dropped.
        freeze_cap: FreezeCapability<USDA>,
        /// Capability required to mint USDA.
        mint_cap: MintCapability<USDA>,
        /// List of USDAMeter.
        usda_meters: vector<USDAMeter>,
        /// Max supply for USDA.
        usda_max_supply: u64,
        /// Current supply for USDA.
        usda_supply: u64,
        /// Whether USDA is paused.
        usda_pause: bool,
        /// Max amount of USDA that can be minted in a given usda_timed_duration period.
        usda_timed_limit: u64,
        /// Current usage of USDA in the current usda_timed_duration period.
        usda_timed_usage: u64,
        /// Time in seconds required before a usda_timed_duration period is reset.
        usda_timed_duration: u64,
        /// Time when `timed_usage` was reset to 0. Also marks the start of a usda_timed_duration
        /// period.
        usda_timed_last_reset: u64,

        // Interest
        /// Current USDA interest collected.
        interest: Coin<USDA>,
        /// Lifetime counter for USDA interest collected.
        lifetime_interest: u64,

        // Liquidation tax
        /// Current USDA liquidation tax collected.
        liquidation_tax: Coin<USDA>,
        /// Lifetime counter for USDA liquidation tax collected.
        lifetime_liquidation_tax: u64,

        // Events
        /// LabAdminCapabilityAcquired storage.
        lab_admin_capability_acquired_events: EventHandle<LabAdminCapabilityAcquired>,
        /// USDAConstraintChangedEvent storage.
        usda_constraint_changed_events: EventHandle<USDAConstraintChangedEvent>,
        /// USDASupplyChangedEvent storage.
        usda_supply_changed_events: EventHandle<USDASupplyChangedEvent>,
        /// USDAMeterLimitChangedEvent storage.
        usda_meter_limit_changed_events: EventHandle<USDAMeterLimitChangedEvent>,
        /// USDAMeterUsageChangedEvent storage.
        usda_meter_usage_changed_events: EventHandle<USDAMeterUsageChangedEvent>,
    }

    //
    // EVENTS
    //

    /// Event emitted when a LabAdminCapability is acquired.
    struct LabAdminCapabilityAcquired has drop, store {
        acquirer_addr: address,
    }

    /// Event emitted when a USDA constraint change.
    struct USDAConstraintChangedEvent has drop, store {
        usda_max_supply: u64,
        usda_timed_limit: u64,
        usda_timed_duration: u64,
        usda_pause: bool,
    }

    /// Event emitted when usda_supply changes.
    struct USDASupplyChangedEvent has drop, store {
        usda_supply: u64
    }

    /// Event emitted when a USDAMeter changes.
    struct USDAMeterLimitChangedEvent has drop, store {
        id: u64,
        limit: u64,
    }

    /// Event emitted when a USDAMeter changes.
    struct USDAMeterUsageChangedEvent has drop, store {
        id: u64,
        usage: u64,
    }

    //
    // WRITE
    //

    /// Creates the Laboratory. Must be @usda to call this function. Returns an enabled
    /// LabAdminCapability.
    public fun initialize(
        creator: &signer,
        usda_max_supply: u64,
        usda_timed_limit: u64,
        usda_timed_duration: u64,
    ): LabAdminCapability acquires Laboratory {
        let creator_addr = address_of(creator);
        assert!(creator_addr == @usda, error::invalid_argument(ENOT_USDA));
        assert!(!exists<Laboratory>(creator_addr), error::invalid_argument(EALREADY_EXISTS));
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<USDA>(
            creator,
            string::utf8(b"Argo USD"),
            string::utf8(b"USDA"),
            6,
            true,
        );

        move_to(creator, Laboratory {
            burn_cap,
            freeze_cap,
            mint_cap,
            usda_meters: vector::empty<USDAMeter>(),
            usda_max_supply,
            usda_supply: 0,
            usda_pause: false,
            usda_timed_limit,
            usda_timed_usage: 0,
            usda_timed_duration,
            usda_timed_last_reset: timestamp::now_seconds(),

            interest: coin::zero(),
            lifetime_interest: 0,

            liquidation_tax: coin::zero(),
            lifetime_liquidation_tax: 0,

            usda_constraint_changed_events:
                account::new_event_handle<USDAConstraintChangedEvent>(creator),
            usda_supply_changed_events:
                account::new_event_handle<USDASupplyChangedEvent>(creator),
            usda_meter_limit_changed_events:
                account::new_event_handle<USDAMeterLimitChangedEvent>(creator),
            usda_meter_usage_changed_events:
                account::new_event_handle<USDAMeterUsageChangedEvent>(creator),
            lab_admin_capability_acquired_events:
                account::new_event_handle<LabAdminCapabilityAcquired>(creator),
        });

        let laboratory = borrow_global_mut<Laboratory>(@usda);
        emit_usda_constraint_changed_event(laboratory);
        event::emit_event(
            &mut laboratory.lab_admin_capability_acquired_events,
            LabAdminCapabilityAcquired {
                acquirer_addr: creator_addr,
            },
        );

        return LabAdminCapability { }
    }

    /// Admin-only. Return a LabAdminCapability.
    public fun acquire_admin_cap(
        acquirer: &signer,
        _cap: &LabAdminCapability,
    ): LabAdminCapability acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        event::emit_event(
            &mut laboratory.lab_admin_capability_acquired_events,
            LabAdminCapabilityAcquired {
                acquirer_addr: address_of(acquirer),
            },
        );
        return LabAdminCapability { }
    }

    /// Permissionless. Returns a USDASupplyCapability with limit default to 0.
    public fun acquire_usda_supply_cap(): USDASupplyCapability acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        vector::push_back(&mut laboratory.usda_meters, USDAMeter { limit: 0, usage: 0 });
        return USDASupplyCapability { id: vector::length(&laboratory.usda_meters) - 1 }
    }

    /// Admin-only. Updates the usda_max_supply.
    public fun set_usda_max_supply(
        usda_max_supply: u64,
        _cap: &LabAdminCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        laboratory.usda_max_supply = usda_max_supply;
        emit_usda_constraint_changed_event(laboratory);
    }

    /// Admin-only. Updates the limit of a USDAMeter.
    public fun set_usda_meter_limit(
        id: u64,
        limit: u64,
        _cap: &LabAdminCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        let meter = vector::borrow_mut(&mut laboratory.usda_meters, id);
        meter.limit = limit;
        event::emit_event(
            &mut laboratory.usda_meter_limit_changed_events,
            USDAMeterLimitChangedEvent { id, limit },
        );
    }

    /// Admin-only. Updates the usda_timed_limit.
    public fun set_usda_timed_limit(
        usda_timed_limit: u64,
        _cap: &LabAdminCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        laboratory.usda_timed_limit = usda_timed_limit;
        emit_usda_constraint_changed_event(laboratory);
    }

    /// Admin-only. Updates the usda_timed_duration.
    public fun set_usda_timed_duration(
        usda_timed_duration: u64,
        _cap: &LabAdminCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        laboratory.usda_timed_duration = usda_timed_duration;
        emit_usda_constraint_changed_event(laboratory);
    }

    /// Admin-only. Pauses mint/burn USDA.
    public fun pause_usda(_cap: &LabAdminCapability) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        laboratory.usda_pause = true;
        emit_usda_constraint_changed_event(laboratory);
    }

    /// Admin-only. Unpauses mint/burn USDA.
    public fun unpause_usda(_cap: &LabAdminCapability) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        laboratory.usda_pause = false;
        emit_usda_constraint_changed_event(laboratory);
    }

    /// Mints `mint_amount` USDA.
    public fun mint(
        mint_amount: u64,
        cap: &USDASupplyCapability,
    ): Coin<USDA> acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        assert!(!laboratory.usda_pause, error::invalid_argument(EPAUSED));
        update_timed_period(laboratory);

        laboratory.usda_supply = laboratory.usda_supply + mint_amount;
        laboratory.usda_timed_usage = laboratory.usda_timed_usage + mint_amount;
        let usda_meter = vector::borrow_mut(&mut laboratory.usda_meters, cap.id);
        usda_meter.usage = usda_meter.usage + mint_amount;

        assert!(
            laboratory.usda_supply <= laboratory.usda_max_supply,
            error::invalid_argument(EMAX_SUPPLY_EXCEEDED)
        );
        assert!(
            usda_meter.usage <= usda_meter.limit,
            error::invalid_argument(EMETER_LIMIT_EXCEEDED)
        );
        assert!(
            laboratory.usda_timed_usage <= laboratory.usda_timed_limit,
            error::invalid_argument(ETIMED_LIMIT_EXCEEDED)
        );

        emit_usda_supply_changed_event(laboratory);
        emit_usda_meter_usage_changed_event(laboratory, cap);

        return coin::mint<USDA>(mint_amount, &laboratory.mint_cap)
    }

    /// Burns `to_burn`.
    public fun burn(
        to_burn: Coin<USDA>,
        cap: &USDASupplyCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        assert!(!laboratory.usda_pause, error::invalid_argument(EPAUSED));
        update_timed_period(laboratory);

        let burn_amount = coin::value(&to_burn);
        laboratory.usda_supply = laboratory.usda_supply - burn_amount;
        let meter = vector::borrow_mut(&mut laboratory.usda_meters, cap.id);
        meter.usage = meter.usage - burn_amount;
        laboratory.usda_timed_usage =
            laboratory.usda_timed_usage - min(laboratory.usda_timed_usage, burn_amount);

        emit_usda_supply_changed_event(laboratory);
        emit_usda_meter_usage_changed_event(laboratory, cap);

        coin::burn<USDA>(to_burn, &laboratory.burn_cap)
    }

    /// Pays interest to Laboratory.interest.
    public fun pay_interest(
        to_pay: Coin<USDA>,
        cap: &USDASupplyCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        let interest_amount = coin::value(&to_pay);
        let meter = vector::borrow_mut(&mut laboratory.usda_meters, cap.id);
        meter.usage = meter.usage - interest_amount;
        laboratory.lifetime_interest = laboratory.lifetime_interest + interest_amount;

        emit_usda_meter_usage_changed_event(laboratory, cap);

        coin::merge(&mut laboratory.interest, to_pay);
    }

    /// Pays liquidation_tax to Laboratory.liquidation_tax.
    public fun pay_liquidation_tax(
        to_pay: Coin<USDA>,
        cap: &USDASupplyCapability,
    ) acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        let tax_amount = coin::value(&to_pay);
        let meter = vector::borrow_mut(&mut laboratory.usda_meters, cap.id);
        meter.usage = meter.usage - tax_amount;
        laboratory.lifetime_liquidation_tax = laboratory.lifetime_liquidation_tax + tax_amount;

        emit_usda_meter_usage_changed_event(laboratory, cap);

        coin::merge(&mut laboratory.liquidation_tax, to_pay);
    }

    /// Admin-only. Extracts all USDA from Laboratory.interest.
    public fun collect_interest(_cap: &LabAdminCapability): Coin<USDA> acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        return coin::extract_all(&mut laboratory.interest)
    }

    /// Admin-only. Extracts all USDAs from Laboratory.liquidation_tax.
    public fun collect_liquidation_tax(_cap: &LabAdminCapability): Coin<USDA> acquires Laboratory {
        let laboratory = borrow_global_mut<Laboratory>(@usda);
        return coin::extract_all(&mut laboratory.liquidation_tax)
    }

    /// Emits the latest USDA constraints.
    fun emit_usda_constraint_changed_event(laboratory: &mut Laboratory) {
        let usda_max_supply = laboratory.usda_max_supply;
        let usda_timed_limit = laboratory.usda_timed_limit;
        let usda_timed_duration = laboratory.usda_timed_duration;
        let usda_pause = laboratory.usda_pause;
        event::emit_event(
            &mut laboratory.usda_constraint_changed_events,
            USDAConstraintChangedEvent {
                usda_max_supply,
                usda_timed_limit,
                usda_timed_duration,
                usda_pause,
            },
        );
    }

    /// Emits the latest USDA supply.
    fun emit_usda_supply_changed_event(laboratory: &mut Laboratory) {
        event::emit_event(
            &mut laboratory.usda_supply_changed_events,
            USDASupplyChangedEvent { usda_supply: laboratory.usda_supply },
        );
    }

    /// Emits the latest meter usage.
    fun emit_usda_meter_usage_changed_event(
        laboratory: &mut Laboratory,
        cap: &USDASupplyCapability,
    ) {
        let meter = vector::borrow(&laboratory.usda_meters, cap.id);
        event::emit_event(
            &mut laboratory.usda_meter_usage_changed_events,
            USDAMeterUsageChangedEvent { id: cap.id, usage: meter.usage },
        );
    }

    /// Checks if the current usda_timed_period should be reset. If it should be reset, we zero
    /// `usda_timed_usage` and set the `usda_timed_last_reset` to now.
    fun update_timed_period(laboratory: &mut Laboratory) {
        let now = timestamp::now_seconds();
        let time_elapsed = now - laboratory.usda_timed_last_reset;
        if (time_elapsed > laboratory.usda_timed_duration) {
            laboratory.usda_timed_last_reset = now;
            laboratory.usda_timed_usage = 0;
        };
    }

    //
    // VIEW
    //

    /// Returns the smaller of two values.
    fun min(a: u64, b: u64): u64 {
        if (a <= b) return a;
        return b
    }

    /// Returns the number of USDASupplyCapability.
    public fun usda_supply_cap_length(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return vector::length(&laboratory.usda_meters)
    }

    /// Returns the usda_max_supply.
    public fun usda_max_supply(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_max_supply
    }

    /// Returns the usda_supply.
    public fun usda_supply(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_supply
    }

    /// Returns a Meter's limit.
    public fun usda_meter_limit(id: u64): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        let meter = vector::borrow(&laboratory.usda_meters, id);
        return meter.limit
    }

    /// Returns a Meter's usage.
    public fun usda_meter_usage(id: u64): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        let meter = vector::borrow(&laboratory.usda_meters, id);
        return meter.usage
    }

    /// Returns the usda_timed_limit.
    public fun usda_timed_limit(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_timed_limit
    }

    /// Returns the usda_timed_usage.
    public fun usda_timed_usage(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_timed_usage
    }

    /// Returns the usda_timed_duration.
    public fun usda_timed_duration(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_timed_duration
    }

    /// Returns the usda_timed_last_reset.
    public fun usda_timed_last_reset(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_timed_last_reset
    }

    /// Returns the usda_pause.
    public fun usda_pause(): bool acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return laboratory.usda_pause
    }

    /// Returns the amount of interest that can be collected from the Laboratory.
    public fun collectable_interest(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return coin::value(&laboratory.interest)
    }

    /// Returns the amount of liquidation tax that can be collected from the Laboratory.
    public fun collectable_liquidation_tax(): u64 acquires Laboratory {
        let laboratory = borrow_global<Laboratory>(@usda);
        return coin::value(&laboratory.liquidation_tax)
    }
}

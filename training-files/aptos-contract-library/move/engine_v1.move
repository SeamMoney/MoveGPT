// engine_v1 is the first version of the Argo engine. Each engine has a single collateral type
// stored at a namespace. Users can create up to one Vault per Engine.
module argo_engine::engine_v1 {
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::type_info;
    use argo_core::laboratory::{Self, USDASupplyCapability};
    use argo_safe::safe;
    use std::error;
    use std::signer::{address_of};
    use usda::usda::{USDA};

    //
    // ERRORS
    //

    // Engine errors
    const EENGINE_ALREADY_EXISTS: u64 = 0x00;
    const ENAMESPACE_MISMATCH: u64 = 0x01;
    const EENGINE_DNE: u64 = 0x02;
    const EADMIN_CAP_DISABLED: u64 = 0x03;
    const EPAUSE_CAP_DISABLED: u64 = 0x04;
    const EINVALID_COLLATERAL_RATIO_PARAMETERIZATION: u64 = 0x05;

    // Vault errors
    const EVAULT_ALREADY_EXISTS: u64 = 0x10;
    const EBELOW_MINIMUM_DEBT: u64 = 0x11;
    const ECOLLATERAL_RATIO_TOO_LOW: u64 = 0x12;
    const EINVALID_MINT_AMOUNT: u64 = 0x13;
    const EINVALID_REPAY_AMOUNT: u64 = 0x14;
    const EINVALID_WITHDRAW_AMOUNT: u64 = 0x15;
    const EINVALID_LIQUIDATE_AMOUNT: u64 = 0x16;
    const ESAFE_NOT_FRESH: u64 = 0x17;
    const ELIQUIDATE_TOO_MUCH: u64 = 0x18;
    const EPAUSED: u64 = 0x19;
    const ENOT_MARKED: u64 = 0x1A;
    const ENO_DEBT: u64 = 0x1B;
    const ECANNOT_MARK: u64 = 0x19;
    const EALREADY_MARKED: u64 = 0x1a;

    //
    // CONSTANTS
    //

    const BPS_PRECISION: u64 = 10000;
    const CR_PRECISION: u64 = 100;
    const MAX_U64: u64 = 18446744073709551615;
    const PRICE_DECIMALS: u8 = 6;
    const PRICE_PRECISION: u64 = 1000000;
    const SCALING_FACTOR_PRECISION: u64 = 1000000000000000;
    /// 100 in SCALING_FACTOR_PRECISION
    const SCALING_FACTOR_PRECISION_100: u64 = 100000000000000000;

    const CREATE_ACTION: u8 = 1;
    const DEPOSIT_ACTION: u8 = 2;
    const WITHDRAW_ACTION: u8 = 3;
    const MINT_ACTION: u8 = 4;
    const REPAY_ACTION: u8 = 5;
    const LIQUIDATE_ACTION: u8 = 6;

    //
    // CORE STRUCTS
    //

    /// Capability required to edit an Engine's parameters.
    struct EngineAdminCapability<phantom NamespaceType, phantom CoinType> has store, drop { }

    /// Capability required to pause/unpause
    struct EnginePauseCapability<phantom NamespaceType, phantom CoinType> has store, drop { }

    /// Parameterization and storage for a USDA collateral in Argo. We use a NamespaceType so that
    /// users can have multiple Vaults of the same collateral type if there are multiple Engines of
    /// the same collateral type.
    struct Engine<phantom NamespaceType, phantom CoinType> has key {
        // Capabilities
        /// Capability required to mint USDA via the Laboratory.
        usda_supply_cap: USDASupplyCapability,

        // Statistics
        /// Total amount of collateral observed across all Vaults.
        total_observed_collateral: u64,
        /// Total net amount of USDA minted by this engine. Exactly equal to `vault_supply` summed
        /// over all the underlying Vaults.
        engine_supply: u64,

        // CRs
        /// Minimum collateral ratio users are allowed to mint to.
        initial_collateral_ratio: u64,
        /// Maximum collateral ratio at the end of a liquidation call.
        liquidation_collateral_ratio: u64,
        /// Minimum collateral ratio before a Vault becomes marked.
        maintenance_collateral_ratio: u64,

        // Debt
        /// Minimum debt that all underlying Vaults must have. This is checked in mint and repay.
        minimum_debt: u64,
        /// Total interest paid per second on the debt. This is denominated in
        /// SCALING_FACTOR_PRECISION, e.g. 100% APR would be represented as 100 *
        /// SCALING_FACTOR_PRECISION.
        interest_rate_per_second: u64,
        /// A monotonically increasing scaling factor that is applied to every Vault's unscaled_debt
        /// to derive debt after applying the interest rate.
        debt_scaling_factor: u64,
        /// The last time touch_engine was called.
        last_touch_time: u64,

        // Liquidation
        /// Time in seconds before auction can begin.
        liquidate_delay: u64,
        /// The initial multiplier on the mark price after the delay passes. Denominated in
        /// PRICE_PRECISION.
        liquidate_initial_multiplier: u64,
        /// How fast the multiplier falls per second. Denominated in PRICE_PRECISION.
        liquidate_multiplier_decay: u64,
        /// The lowest the multiplier is allowed to go. Denominated in PRICE_PRECISION.
        liquidate_minimum_multiplier: u64,
        /// A liquidation tax that is applied during liquidate_repay. Disincentivizes vault owners
        /// from liquidating their own vaults. Denominated in BPS_PRECISION.
        liquidate_tax: u64,
        /// Advantage in seconds during an auction when the liquidator is the marker.
        marker_advantage: u64,


        // Safe
        /// The maximum number in seconds a Safe's fresh_time can be in the past.
        safe_freshness: u64,
        /// Address where the Safe is stored.
        safe_addr: address,

        // Pauses
        /// Emergency pause disables withdraw, mint, and liquidate.
        emergency_pause: bool,
        /// Withdraw pause disables withdraw.
        withdraw_pause: bool,
        /// Mint pause disables mint.
        mint_pause: bool,
        /// Liquidate pause disables liquidate.
        liquidate_pause: bool,

        // Events
        /// EngineAdminCapabilityAcquiredEvent storage.
        engine_admin_capability_acquired_events: EventHandle<EngineAdminCapabilityAcquiredEvent>,
        /// EnginePauseCapabilityAcquiredEvent storage.
        engine_pause_capability_acquired_events: EventHandle<EnginePauseCapabilityAcquiredEvent>,
        /// NewVaultEvent storage.
        new_vault_events: EventHandle<NewVaultEvent>,
        /// EngineAccountingChangedEvent storage.
        engine_accounting_changed_events: EventHandle<EngineAccountingChangedEvent>,
        /// EngineParamChangedEvent storage.
        param_changed_events: EventHandle<EngineParamChangedEvent>,
    }

    /// Storage for a Vault mark.
    struct MarkInfo has store {
        /// Address of account that created the mark. @0 if the vault is not market.
        marker_addr: address,
        /// Time that the mark was created.
        timestamp: u64,
        /// Oracle-free-price of collateral at time of mark creation.
        mark_price: u64,
    }

    /// Storage for a user's collateral and debt on an engine.
    struct Vault<phantom NamespaceType, phantom CoinType> has key {
        /// Vault ID
        id: u64,
        /// Collateral Coins.
        collateral: Coin<CoinType>,
        /// USDA debt. To get scaled debt, multiply by the engine.debt_scaling_factor.
        unscaled_debt: u64,
        /// The net amount of USDA minted by this vault.
        vault_supply: u64,
        /// Mark information.
        mark_info: MarkInfo,
        /// VaultAccountChangeEvent storage.
        accounting_events: EventHandle<VaultAccountingChangeEvent>,
    }

    /// Enables flash liquidations. A liquidator receives a LiquidateIOU after calling
    /// liquidate_withdraw and must return it by calling liquidate_repay.
    struct LiquidateIOU<phantom NamespaceType, phantom CoinType> {
        /// The owner of the Vault being liquidated.
        owner_addr: address,
        /// The amount that was seized from liquidate_withdraw.
        liquidate_amount: u64,
    }

    //
    // ENGINE EVENTS
    //

    /// Event emitted whenever an EngineAdminCapability has been acquired.
    struct EngineAdminCapabilityAcquiredEvent has drop, store {
        acquirer_addr: address,
    }

    /// Event emitted whenever an EnginePauseCapability has been acquired.
    struct EnginePauseCapabilityAcquiredEvent has drop, store {
        acquirer_addr: address,
    }

    /// Event emitted whenever a new vault has been created.
    struct NewVaultEvent has drop, store {
        owner_addr: address,
    }

    /// Event emitted whenever an Engine's total_observed_collateral or engine_supply has changed.
    struct EngineAccountingChangedEvent has drop, store {
        total_observed_collateral: u64,
        engine_supply: u64,
    }

    /// Event emitted whenever Engine parameterization changes.
    struct EngineParamChangedEvent has drop, store {
        initial_collateral_ratio: u64,
        liquidation_collateral_ratio: u64,
        maintenance_collateral_ratio: u64,
        minimum_debt: u64,
        interest_rate_per_second: u64,
        safe_freshness: u64,
        safe_addr: address,
        liquidate_delay: u64,
        liquidate_initial_multiplier: u64,
        liquidate_multiplier_decay: u64,
        liquidate_minimum_multiplier: u64,
        liquidate_tax: u64,
        marker_advantage: u64,
        emergency_pause: bool,
        withdraw_pause: bool,
        mint_pause: bool,
        liquidate_pause: bool,
    }

    //
    // VAULT EVENTS
    //

    /// Event emitted whenever a vault's accounting changes.
    struct VaultAccountingChangeEvent has drop, store {
        observed_collateral: u64,
        unscaled_debt: u64,
        debt_scaling_factor: u64,
        safe_price: u64,
        safe_fresh_time: u64,
        action_type: u8,
        timestamp: u64,
    }

    //
    // ENGINE WRITE
    //

    /// Creates a new engine. `NamespaceType` must reside at `creator`
    public fun new_engine<NamespaceType, CoinType>(
        creator: &signer,
        initial_collateral_ratio: u64,
        liquidation_collateral_ratio: u64,
        maintenance_collateral_ratio: u64,
        minimum_debt: u64,
        interest_rate_per_second: u64,
        safe_addr: address,
        safe_freshness: u64,
        liquidate_delay: u64,
        liquidate_initial_multiplier: u64,
        liquidate_multiplier_decay: u64,
        liquidate_minimum_multiplier: u64,
        liquidate_tax: u64,
        marker_advantage: u64,
    ): (
        EngineAdminCapability<NamespaceType, CoinType>,
        EnginePauseCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        assert!(
            !engine_exists<NamespaceType, CoinType>(),
            error::invalid_argument(EENGINE_ALREADY_EXISTS),
        );

        // Check that NamespaceType is defined at `creator`
        let namespace_addr = namespace_addr<NamespaceType>();
        let creator_addr = address_of(creator);
        assert!(
            namespace_addr == creator_addr,
            error::invalid_argument(ENAMESPACE_MISMATCH),
        );

        move_to(creator, Engine<NamespaceType, CoinType> {
            usda_supply_cap: laboratory::acquire_usda_supply_cap(),

            total_observed_collateral: 0,
            engine_supply: 0,

            initial_collateral_ratio,
            liquidation_collateral_ratio,
            maintenance_collateral_ratio,

            minimum_debt,
            interest_rate_per_second,
            debt_scaling_factor: SCALING_FACTOR_PRECISION,
            last_touch_time: timestamp::now_seconds(),

            safe_addr,
            safe_freshness,

            liquidate_delay,
            liquidate_initial_multiplier,
            liquidate_multiplier_decay,
            liquidate_minimum_multiplier,
            liquidate_tax,
            marker_advantage,

            emergency_pause: false,
            withdraw_pause: false,
            mint_pause: false,
            liquidate_pause: false,

            engine_admin_capability_acquired_events:
                account::new_event_handle<EngineAdminCapabilityAcquiredEvent>(creator),
            engine_pause_capability_acquired_events:
                account::new_event_handle<EnginePauseCapabilityAcquiredEvent>(creator),
            new_vault_events: account::new_event_handle<NewVaultEvent>(creator),
            engine_accounting_changed_events:
                account::new_event_handle<EngineAccountingChangedEvent>(creator),
            param_changed_events: account::new_event_handle<EngineParamChangedEvent>(creator),
        });

        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(namespace_addr);
        emit_engine_param_changed_event(engine);
        event::emit_event(
            &mut engine.engine_admin_capability_acquired_events,
            EngineAdminCapabilityAcquiredEvent {
                acquirer_addr: creator_addr,
            }
        );
        event::emit_event(
            &mut engine.engine_pause_capability_acquired_events,
            EnginePauseCapabilityAcquiredEvent {
                acquirer_addr: creator_addr,
            }
        );
        emit_engine_accounting_changed_event(engine);

        return (
            EngineAdminCapability { },
            EnginePauseCapability { },
        )
    }

    /// Admin-only. Return a EngineAdminCapability.
    public fun acquire_admin_cap<NamespaceType, CoinType>(
        acquirer: &signer,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ): EngineAdminCapability<NamespaceType, CoinType> acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        event::emit_event(
            &mut engine.engine_admin_capability_acquired_events,
            EngineAdminCapabilityAcquiredEvent {
                acquirer_addr: address_of(acquirer),
            }
        );
        return EngineAdminCapability { }
    }

    /// Admin-only. Return a EnginePauseCapability.
    public fun acquire_pause_cap<NamespaceType, CoinType>(
        acquirer: &signer,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ): EnginePauseCapability<NamespaceType, CoinType> acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        event::emit_event(
            &mut engine.engine_pause_capability_acquired_events,
            EnginePauseCapabilityAcquiredEvent {
                acquirer_addr: address_of(acquirer),
            }
        );
        return EnginePauseCapability { }
    }

    /// Admin-only. Updates an Engine's initial_collateral_ratio.
    public fun set_initial_collateral_ratio<NamespaceType, CoinType>(
        initial_collateral_ratio: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.initial_collateral_ratio = initial_collateral_ratio;
        check_collateral_ratio_parameterization(engine);
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Updates an Engine's liquidation_collateral_ratio.
    public fun set_liquidation_collateral_ratio<NamespaceType, CoinType>(
        liquidation_collateral_ratio: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidation_collateral_ratio = liquidation_collateral_ratio;
        check_collateral_ratio_parameterization(engine);
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Updates an Engine's maintenance_collateral_ratio.
    public fun set_maintenance_collateral_ratio<NamespaceType, CoinType>(
        maintenance_collateral_ratio: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.maintenance_collateral_ratio = maintenance_collateral_ratio;
        check_collateral_ratio_parameterization(engine);
        emit_engine_param_changed_event(engine);
    }

    /// Checks that the initial >= liquidation >= maintenance.
    fun check_collateral_ratio_parameterization<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
    ) {
        assert!(
            engine.initial_collateral_ratio >= engine.liquidation_collateral_ratio &&
                engine.liquidation_collateral_ratio >= engine.maintenance_collateral_ratio,
            error::invalid_argument(EINVALID_COLLATERAL_RATIO_PARAMETERIZATION),
        )
    }

    /// Admin-only. Updates an Engine's minimum_debt.
    public fun set_minimum_debt<NamespaceType, CoinType>(
        minimum_debt: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.minimum_debt = minimum_debt;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Updates an Engine's interest_rate_per_second.
    public fun set_interest_rate_per_second<NamespaceType, CoinType>(
        interest_rate_per_second: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.interest_rate_per_second = interest_rate_per_second;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Updates an Engine's safe_freshness.
    public fun set_safe_freshness<NamespaceType, CoinType>(
        safe_freshness: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.safe_freshness = safe_freshness;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Updates an Engine's safe_addr.
    public fun set_safe_addr<NamespaceType, CoinType>(
        safe_addr: address,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.safe_addr = safe_addr;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets the liquidate_delay.
    public fun set_liquidate_delay<NamespaceType, CoinType>(
        liquidate_delay: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_delay = liquidate_delay;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets liquidate_initial_multiplier.
    public fun set_liquidate_initial_multiplier<NamespaceType, CoinType>(
        liquidate_initial_multiplier: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_initial_multiplier = liquidate_initial_multiplier;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets liquidate_multiplier_decay.
    public fun set_liquidate_multiplier_decay<NamespaceType, CoinType>(
        liquidate_multiplier_decay: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_multiplier_decay = liquidate_multiplier_decay;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets liquidate_minimum_multiplier.
    public fun set_liquidate_minimum_multiplier<NamespaceType, CoinType>(
        liquidate_minimum_multiplier: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_minimum_multiplier = liquidate_minimum_multiplier;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets liquidate_tax.
    public fun set_liquidate_tax<NamespaceType, CoinType>(
        liquidate_tax: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_tax = liquidate_tax;
        emit_engine_param_changed_event(engine);
    }

    /// Admin-only. Sets marker_advantage.
    public fun set_marker_advantage<NamespaceType, CoinType>(
        marker_advantage: u64,
        _cap: &EngineAdminCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.marker_advantage = marker_advantage;
        emit_engine_param_changed_event(engine);
    }

    /// Pauser-only. Sets emergency_pause.
    public fun set_emergency_pause<NamespaceType, CoinType>(
        emergency_pause: bool,
        _cap: &EnginePauseCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.emergency_pause = emergency_pause;
        emit_engine_param_changed_event(engine);
    }

    /// Pauser-only. Sets withdraw_pause.
    public fun set_withdraw_pause<NamespaceType, CoinType>(
        withdraw_pause: bool,
        _cap: &EnginePauseCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.withdraw_pause = withdraw_pause;
        emit_engine_param_changed_event(engine);
    }

    /// Pauser-only. Sets mint_pause.
    public fun set_mint_pause<NamespaceType, CoinType>(
        mint_pause: bool,
        _cap: &EnginePauseCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.mint_pause = mint_pause;
        emit_engine_param_changed_event(engine);
    }

    /// Pauser-only. Sets liquidate_pause.
    public fun set_liquidate_pause<NamespaceType, CoinType>(
        liquidate_pause: bool,
        _cap: &EnginePauseCapability<NamespaceType, CoinType>,
    ) acquires Engine {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.liquidate_pause = liquidate_pause;
        emit_engine_param_changed_event(engine);
    }

    /// Updates an Engine's debt_scaling_factor and last_touch_time.
    fun touch_engine<NamespaceType, CoinType>(
        engine: &mut Engine<NamespaceType, CoinType>,
    ) {
        engine.debt_scaling_factor = debt_scaling_factor_current_internal(engine);
        engine.last_touch_time = timestamp::now_seconds();
    }

    /// Emits the latest engine for an Engine.
    fun emit_engine_param_changed_event<NamespaceType, CoinType>(
        engine: &mut Engine<NamespaceType, CoinType>,
    ) {
        // Store these variables because engine will get borrowed by emit_event
        let initial_collateral_ratio = engine.initial_collateral_ratio;
        let liquidation_collateral_ratio = engine.liquidation_collateral_ratio;
        let maintenance_collateral_ratio = engine.maintenance_collateral_ratio;
        let minimum_debt = engine.minimum_debt;
        let interest_rate_per_second = engine.interest_rate_per_second;
        let safe_freshness = engine.safe_freshness;
        let safe_addr = engine.safe_addr;
        let liquidate_delay = engine.liquidate_delay;
        let liquidate_initial_multiplier = engine.liquidate_initial_multiplier;
        let liquidate_multiplier_decay = engine.liquidate_multiplier_decay;
        let liquidate_minimum_multiplier = engine.liquidate_minimum_multiplier;
        let liquidate_tax = engine.liquidate_tax;
        let marker_advantage = engine.marker_advantage;
        let emergency_pause = engine.emergency_pause;
        let withdraw_pause = engine.withdraw_pause;
        let mint_pause = engine.mint_pause;
        let liquidate_pause = engine.liquidate_pause;

        event::emit_event(
            &mut engine.param_changed_events,
            EngineParamChangedEvent {
                initial_collateral_ratio,
                liquidation_collateral_ratio,
                maintenance_collateral_ratio,
                minimum_debt,
                interest_rate_per_second,
                safe_freshness,
                safe_addr,
                liquidate_delay,
                liquidate_initial_multiplier,
                liquidate_multiplier_decay,
                liquidate_minimum_multiplier,
                liquidate_tax,
                marker_advantage,
                emergency_pause,
                withdraw_pause,
                mint_pause,
                liquidate_pause,
            },
        );
    }

    /// Emits the latest accounting for an Engine.
    fun emit_engine_accounting_changed_event<NamespaceType, CoinType>(
        engine: &mut Engine<NamespaceType, CoinType>,
    ) {
        // Store these variables because engine will get borrowed by emit_event
        let total_observed_collateral = engine.total_observed_collateral;
        let engine_supply = engine.engine_supply;

        event::emit_event(
            &mut engine.engine_accounting_changed_events,
            EngineAccountingChangedEvent {
                total_observed_collateral,
                engine_supply,
            },
        );
    }

    //
    // ENGINE VIEW
    //

    /// Returns whether an engine of (Namespace, CoinType) already exists.
    fun engine_exists<NamespaceType, CoinType>(): bool {
        return exists<Engine<NamespaceType, CoinType>>(namespace_addr<NamespaceType>())
    }

    /// Returns the address where NamespaceType is stored.
    fun namespace_addr<NamespaceType>(): address {
        return type_info::account_address(&type_info::type_of<NamespaceType>())
    }

    /// Returns the current debt_scaling_factor for an Engine by applying the current timestamp.
    public fun debt_scaling_factor_current<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return debt_scaling_factor_current_internal(engine)
    }

    /// Gas-efficient return for debt_scaling_factor_current.
    fun debt_scaling_factor_current_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>
    ): u64 {
        let now = timestamp::now_seconds();
        let time_elapsed = now - engine.last_touch_time;
        if (time_elapsed == 0) return engine.debt_scaling_factor;
        let interest_percent =
            engine.interest_rate_per_second * time_elapsed +  SCALING_FACTOR_PRECISION_100;
        return scale_floor(
            engine.debt_scaling_factor,
            interest_percent,
            SCALING_FACTOR_PRECISION_100,
        )
    }

    /// Returns the safe_addr field for an Engine.
    public fun safe_addr<NamespaceType, CoinType>(): address acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).safe_addr
    }

    /// Returns the total_observed_collateral field for an Engine.
    public fun total_observed_collateral<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).total_observed_collateral
    }

    /// Returns the engine_supply field for an Engine.
    public fun engine_supply<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).engine_supply
    }

    /// Returns the minimum_debt field for an Engine.
    public fun minimum_debt<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).minimum_debt
    }

    /// Returns the interest_rate_per_second field for an Engine.
    public fun interest_rate_per_second<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).interest_rate_per_second
    }

    /// Returns the debt_scaling_factor field for an Engine.
    public fun debt_scaling_factor<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).debt_scaling_factor
    }

    /// Returns the last_touch_time field for an Engine.
    public fun last_touch_time<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).last_touch_time
    }

    /// Returns the initial_collateral_ratio field for an Engine.
    public fun initial_collateral_ratio<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).initial_collateral_ratio
    }

    /// Returns the liquidation_collateral_ratio field for an Engine.
    public fun liquidation_collateral_ratio<NamespaceType, CoinType>(): u64 acquires Engine {
        borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).liquidation_collateral_ratio
    }

    /// Returns the maintenance_collateral_ratio field for an Engine.
    public fun maintenance_collateral_ratio<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).maintenance_collateral_ratio
    }

    /// Returns the safe_freshness field for an Engine.
    public fun safe_freshness<NamespaceType, CoinType>(): u64 acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).safe_freshness
    }

    /// Returns whether the pointed Safe's fresh_time falls within the Engine safe_freshness.
    public fun safe_is_fresh<NamespaceType, CoinType>(): bool acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return safe_is_fresh_internal(engine)
    }

    /// Gas-efficient check for a Safe's freshness that does not borrow.
    fun safe_is_fresh_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
    ): bool {
        let fresh_time = safe::fresh_time(engine.safe_addr);
        let expiration = fresh_time + engine.safe_freshness;
        return timestamp::now_seconds() < expiration
    }

    /// Returns the number of Vaults for an Engine.
    public fun vault_count<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return event::counter(&engine.new_vault_events)
    }

    /// Calculates the required repayment for a liquidation
    public fun required_repay_amount<NamespaceType, CoinType>(
        liquidator_addr: address,
        owner_addr: address,
        liquidate_amount: u64,
    ): u64 acquires Engine, Vault {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return required_repay_amount_internal(engine, liquidator_addr, owner_addr, liquidate_amount)
    }

    /// Gas-efficient calculation of required_repay_amount
    fun required_repay_amount_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        liquidator_addr: address,
        owner_addr: address,
        liquidate_amount: u64,
    ): u64 acquires Vault {
        return scale_ceil(
            liquidate_amount,
            auction_price_internal(engine, liquidator_addr, owner_addr),
            PRICE_PRECISION
        )
    }

    /// Gives a price in PRICE_PRECISION
    public fun auction_price<NamespaceType, CoinType>(
        liquidator_addr: address,
        owner_addr: address,
    ): u64 acquires Engine, Vault {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return auction_price_internal(engine, liquidator_addr, owner_addr)
    }

    /// Gas-efficient calculation of auction_price
    fun auction_price_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        liquidator_addr: address,
        owner_addr: address,
    ): u64 acquires Vault {
        let auction_time = timestamp::now_seconds();
        let (
            marker_addr,
            mark_timestamp,
            mark_price,
        ) = vault_mark_info<NamespaceType, CoinType>(owner_addr);
        if (marker_addr == liquidator_addr) {
            auction_time = auction_time + engine.marker_advantage;
        };
        if (auction_time < mark_timestamp + engine.liquidate_delay) {
            return MAX_U64
        } else {
            let auction_time_passed = auction_time - mark_timestamp - engine.liquidate_delay;
            let delta = auction_time_passed * engine.liquidate_multiplier_decay;
            let multiplier = if (delta < engine.liquidate_initial_multiplier) {
                engine.liquidate_initial_multiplier - delta
            } else {
                0
            };
            multiplier = max(multiplier, engine.liquidate_minimum_multiplier);
            return scale_floor(
                mark_price,
                multiplier,
                PRICE_PRECISION,
            )
        }
    }

    /// Returns the liquidate_delay field of Engine
    public fun liquidate_delay<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.liquidate_delay
    }

    /// Returns the liquidate_initial_multiplier field of Engine
    public fun liquidate_initial_multiplier<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.liquidate_initial_multiplier
    }

    /// Returns the liquidate_multiplier_decay field of Engine
    public fun liquidate_multiplier_decay<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.liquidate_multiplier_decay
    }

    /// Returns the liquidate_minimum_multiplier field of Engine
    public fun liquidate_minimum_multiplier<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.liquidate_minimum_multiplier
    }

    /// Returns the liquidate_tax field of Engine
    public fun liquidate_tax<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.liquidate_tax
    }

    /// Returns the marker_advantage field of Engine
    public fun marker_advantage<NamespaceType, CoinType>(): u64 acquires Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        return engine.marker_advantage
    }

    /// Returns the emergency_pause field for an Engine.
    public fun emergency_pause<NamespaceType, CoinType>(): bool acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).emergency_pause
    }

    /// Returns the withdraw_pause field for an Engine.
    public fun withdraw_pause<NamespaceType, CoinType>(): bool acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).withdraw_pause
    }

    /// Returns the mint_pause field for an Engine.
    public fun mint_pause<NamespaceType, CoinType>(): bool acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).mint_pause
    }

    /// Returns the liquidate_pause field for an Engine.
    public fun liquidate_pause<NamespaceType, CoinType>(): bool acquires Engine {
        return borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        ).liquidate_pause
    }

    //
    // VAULT WRITE
    //

    /// Create a new Vault and store it at the `owner` address.
    public fun new_vault<NamespaceType, CoinType>(owner: &signer) acquires Engine, Vault {
        assert!(engine_exists<NamespaceType, CoinType>(), error::not_found(EENGINE_DNE));
        let owner_addr = address_of(owner);
        assert!(
            !exists<Vault<NamespaceType, CoinType>>(owner_addr),
            error::invalid_argument(EVAULT_ALREADY_EXISTS),
        );
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault_id = event::counter(&engine.new_vault_events);
        move_to(owner, Vault<NamespaceType, CoinType> {
            id: vault_id,
            collateral: coin::zero(),
            unscaled_debt: 0,
            vault_supply: 0,
            mark_info: MarkInfo {
                marker_addr: @0,
                timestamp: 0,
                mark_price: MAX_U64,
            },
            accounting_events: account::new_event_handle<VaultAccountingChangeEvent>(owner),
        });
        event::emit_event(&mut engine.new_vault_events, NewVaultEvent { owner_addr });
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr);
        emit_vault_accounting_changed_event(engine, vault, CREATE_ACTION);
    }

    /// Deposit collateral into the vault.
    public fun deposit<NamespaceType, CoinType>(
        owner: &signer,
        to_deposit: Coin<CoinType>,
    ) acquires Engine, Vault {
        // Update collateral counter
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        engine.total_observed_collateral =
            engine.total_observed_collateral + coin::value(&to_deposit);

        // Deposit collateral
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(address_of(owner));
        coin::merge<CoinType>(&mut vault.collateral, to_deposit);

        // Record accounting change
        emit_vault_accounting_changed_event(engine, vault, DEPOSIT_ACTION);
        emit_engine_accounting_changed_event(engine);
    }

    /// Mint against the vault.
    public fun mint<NamespaceType, CoinType>(
        owner: &signer,
        amount: u64
    ): Coin<USDA> acquires Engine, Vault {
        // Update engine debt_scaling_factor
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        touch_engine(engine);

        // Check that the mint is valid
        let owner_addr = address_of(owner);
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr);
        assert!(amount > 0, error::invalid_argument(EINVALID_MINT_AMOUNT));
        assert!(!engine.emergency_pause && !engine.mint_pause, error::invalid_state(EPAUSED));

        // Calculate and update debt counters
        let new_scaled_debt = scaled_debt_internal(engine, vault) + amount;
        let debt_scaling_factor = engine.debt_scaling_factor;
        vault.unscaled_debt = unscale_debt(new_scaled_debt, debt_scaling_factor);
        vault.vault_supply = vault.vault_supply + amount;
        engine.engine_supply = engine.engine_supply + amount;

        // Check resulting debt is greater than the minimum debt and resulting collateral ratio is
        // above the initial collateral ratio
        assert!(
            scaled_debt_internal(engine, vault) >= engine.minimum_debt,
            error::invalid_argument(EBELOW_MINIMUM_DEBT),
        );
        assert!(
            collateral_ratio_internal(engine, vault) >= engine.initial_collateral_ratio,
            error::invalid_argument(ECOLLATERAL_RATIO_TOO_LOW),
        );

        // Record accounting change
        emit_vault_accounting_changed_event(engine, vault, MINT_ACTION);
        emit_engine_accounting_changed_event(engine);

        return laboratory::mint(amount, &engine.usda_supply_cap)
    }

    /// Repay USDA back to the vault. Returns any remaining USDA back to the caller.
    fun repay_internal<NamespaceType, CoinType>(
        max_to_repay: Coin<USDA>,
        engine: &mut Engine<NamespaceType, CoinType>,
        vault: &mut Vault<NamespaceType, CoinType>,
    ): Coin<USDA> {
        // Update engine debt_scaling_factor
        touch_engine(engine);

        // Check that the repay is valid.
        let max_repay_amount = coin::value(&max_to_repay);
        assert!(max_repay_amount > 0, error::invalid_argument(EINVALID_REPAY_AMOUNT));
        let scaled_debt = scaled_debt_internal(engine, vault);
        assert!(scaled_debt > 0, error::invalid_state(ENO_DEBT));

        // Calculate interest and principal
        let pending_interest = scaled_debt - vault.vault_supply;
        let interest_amount = min(pending_interest, max_repay_amount);
        let principal_amount = min(vault.vault_supply, max_repay_amount - interest_amount);

        // Update debt counters
        let debt_scaling_factor = engine.debt_scaling_factor;
        vault.unscaled_debt =
            unscale_debt(
                scaled_debt - interest_amount - principal_amount,
                debt_scaling_factor,
            );
        engine.engine_supply = engine.engine_supply - principal_amount;
        vault.vault_supply = vault.vault_supply - principal_amount;

        // Repay interest
        if (interest_amount > 0) {
            let interest_payment = coin::extract(&mut max_to_repay, interest_amount);
            laboratory::pay_interest(interest_payment, &engine.usda_supply_cap);
        };

        // Repay principal
        if (principal_amount > 0) {
            let principal_payment = coin::extract(&mut max_to_repay, principal_amount);
            laboratory::burn(principal_payment, &engine.usda_supply_cap);
        };

        // Check resulting debt is 0 or greater than the minimum debt
        let resulting_scaled_debt = scaled_debt_internal(engine, vault);
        assert!(
            resulting_scaled_debt == 0 || resulting_scaled_debt >= engine.minimum_debt,
            error::invalid_argument(EBELOW_MINIMUM_DEBT),
        );

        // Record accounting change
        emit_vault_accounting_changed_event(engine, vault, REPAY_ACTION);
        emit_engine_accounting_changed_event(engine);

        // Return any remaining repay amount back to the caller
        return max_to_repay
    }

    /// Repay USDA back to the vault. Returns any remaining USDA back to the caller.
    public fun repay<NamespaceType, CoinType>(
        owner_addr: address,
        max_to_repay: Coin<USDA>
    ): Coin<USDA> acquires Engine, Vault {
        return repay_internal<NamespaceType, CoinType>(
            max_to_repay,
            borrow_global_mut<Engine<NamespaceType, CoinType>>(
                namespace_addr<NamespaceType>(),
            ),
            borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr),
        )
    }

    /// Withdraw collateral from vault. NOTE: This function is internal and there are **0**
    /// invariant checks. Use with extreme caution.
    fun withdraw_internal<NamespaceType, CoinType>(
        engine: &mut Engine<NamespaceType, CoinType>,
        vault: &mut Vault<NamespaceType, CoinType>,
        amount: u64,
    ): Coin<CoinType> {
        // Update accounting
        engine.total_observed_collateral = engine.total_observed_collateral - amount;

        // Withdraw collateral
        return coin::extract(&mut vault.collateral, amount)
    }

    /// Withdraw collateral from the vault.
    public fun withdraw<NamespaceType, CoinType>(
        owner: &signer,
        amount: u64
    ): Coin<CoinType> acquires Engine, Vault {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        touch_engine(engine);

        // Check that the withdraw is valid
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(address_of(owner));
        assert!(amount > 0, error::invalid_argument(EINVALID_WITHDRAW_AMOUNT));
        assert!(!engine.emergency_pause && !engine.withdraw_pause, error::invalid_state(EPAUSED));

        // Withdraw
        let to_withdraw = withdraw_internal(engine, vault, amount);

        // Check debt is 0 OR resulting collateral ratio is above the ICR
        assert!(
            scaled_debt_internal(engine, vault) == 0 ||
                collateral_ratio_internal(engine, vault) >= engine.initial_collateral_ratio,
            error::invalid_argument(ECOLLATERAL_RATIO_TOO_LOW),
        );

        // Record accounting change
        emit_vault_accounting_changed_event(engine, vault, WITHDRAW_ACTION);
        emit_engine_accounting_changed_event(engine);

        return to_withdraw
    }

    /// Mark a Vault for liquidation. A Vault can only be marked if it is below the
    /// maintenance_collateral_ratio and the Safe is fresh.
    public fun mark_vault<NamespaceType, CoinType>(
        marker: &signer,
        owner_addr: address,
    ) acquires Engine, Vault {
        let marker_addr = address_of(marker);
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr);
        assert!(
            collateral_ratio_internal(engine, vault) < engine.maintenance_collateral_ratio,
            error::invalid_state(ECANNOT_MARK),
        );
        assert!(vault.mark_info.marker_addr == @0, error::invalid_state(EALREADY_MARKED));
        vault.mark_info.marker_addr = marker_addr;
        vault.mark_info.timestamp = timestamp::now_seconds();
        vault.mark_info.mark_price = oracle_free_price_internal(engine, vault);
    }

    /// Unmark a vault from liquidation. A Vault can only be unmarked if it is above the
    /// maintenance_collateral_ratio. We allow the Safe to stay marked if the Safe is not fresh
    /// because we will check the Safe freshness before the liquidation.
    public fun unmark_vault<NamespaceType, CoinType>(owner_addr: address) acquires Engine, Vault {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr);
        unmark_vault_internal(engine, vault);
    }

    /// Gas-efficient vault unmarking.
    fun unmark_vault_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        vault: &mut Vault<NamespaceType, CoinType>,
    ) {
        if (collateral_ratio_internal(engine, vault) >= engine.maintenance_collateral_ratio) {
            vault.mark_info.marker_addr = @0;
        }
    }

    /// Withdraw collateral for a liquidation. Safe must be fresh. Since we export liqudation
    /// collateral pricing on an external liquidation module, we require that the caller MUST
    /// provide an enabled Cap<LiquidateFeature> and finish the call with liquidate_repay.
    public fun liquidate_withdraw<NamespaceType, CoinType>(
        owner_addr: address,
        liquidate_amount: u64,
    ): (Coin<CoinType>, LiquidateIOU<NamespaceType, CoinType>) acquires Engine, Vault {
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        touch_engine(engine);

        // Check invariants
        assert!(liquidate_amount > 0, error::invalid_argument(EINVALID_LIQUIDATE_AMOUNT));
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(owner_addr);
        assert!(vault.mark_info.marker_addr != @0, error::invalid_state(ENOT_MARKED));
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        assert!(!engine.emergency_pause && !engine.liquidate_pause, error::invalid_state(EPAUSED));

        // Skip events emission. Defer it to liquidate_repay to emit events.

        // Withdraw + return an IOU
        return (
            withdraw_internal(engine, vault, liquidate_amount),
            LiquidateIOU<NamespaceType, CoinType> {
                owner_addr,
                liquidate_amount: liquidate_amount,
            },
        )
    }

    /// Required call after calling liquidate_withdraw that repays the user's debt. Checks that a
    /// Vault is below the liquidation_collateral_ratio.
    public fun liquidate_repay<NamespaceType, CoinType>(
        liquidator: &signer,
        max_to_repay: Coin<USDA>,
        iou: LiquidateIOU<NamespaceType, CoinType>,
    ): Coin<USDA> acquires Engine, Vault {
        // Based on the liquidate_amount, calculate and check the required repayment + tax
        let engine = borrow_global_mut<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let required_repay_amount = required_repay_amount_internal(
            engine,
            address_of(liquidator),
            iou.owner_addr,
            iou.liquidate_amount,
        );
        let tax_amount = scale_floor(
            required_repay_amount,
            engine.liquidate_tax,
            BPS_PRECISION,
        );

        // Pay for the liquidated collateral + tax
        let required_to_repay = coin::extract(&mut max_to_repay, required_repay_amount);
        let to_tax = coin::extract(&mut required_to_repay, tax_amount);

        // Repay.
        let vault = borrow_global_mut<Vault<NamespaceType, CoinType>>(iou.owner_addr);
        let remaining = repay_internal<NamespaceType, CoinType>(
            required_to_repay,
            engine,
            vault,
        );

        // Remaining should be zero because the Vault cannot have 0 debt. If the vault has 0 debt,
        // the collateral ratio would be above the liquidation ratio.
        coin::destroy_zero(remaining);

        // Pay the liquidation tax.
        laboratory::pay_liquidation_tax(to_tax, &engine.usda_supply_cap);

        // Check that the Vault is below the liquidation_collateral_ratio. If the scaled_debt is
        // less than minimum_debt, use the minimum_debt to calculate the collateral ratio. If we are
        // below the liquidation_collateral_ratio with the minimum debt, we should allow liquidation
        // of the entire vault.
        assert!(safe_is_fresh_internal(engine), error::invalid_state(ESAFE_NOT_FRESH));
        let collateral_ratio = collateral_ratio(
            coin::value(&vault.collateral),
            max(scaled_debt_internal(engine, vault), engine.minimum_debt),
            safe::price(engine.safe_addr),
            coin::decimals<CoinType>(),
        );
        assert!(
            collateral_ratio < engine.liquidation_collateral_ratio,
            error::invalid_argument(ELIQUIDATE_TOO_MUCH),
        );

        // Try to unmark the vault
        unmark_vault_internal(engine, vault);

        // Drop the IOU
        let LiquidateIOU { owner_addr: _, liquidate_amount: _ } = iou;

        // Record accounting change
        emit_vault_accounting_changed_event(engine, vault, LIQUIDATE_ACTION);
        emit_engine_accounting_changed_event(engine);

        return max_to_repay
    }

    /// Emits the latest accounting for a Vault.
    fun emit_vault_accounting_changed_event<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        vault: &mut Vault<NamespaceType, CoinType>,
        action_type: u8,
    ) {
        // Store these variables because vault will get borrowed by emit_event
        let observed_collateral = coin::value(&vault.collateral);
        let unscaled_debt = vault.unscaled_debt;

        event::emit_event(
            &mut vault.accounting_events,
            VaultAccountingChangeEvent {
                observed_collateral,
                unscaled_debt,
                debt_scaling_factor: debt_scaling_factor_current_internal(engine),
                safe_price: safe::price(engine.safe_addr),
                safe_fresh_time: safe::fresh_time(engine.safe_addr),
                action_type,
                timestamp: timestamp::now_seconds(),
            },
        );
    }

    //
    // VAULT VIEW
    //

    /// Returns the id field for a Vault.
    public fun vault_id<NamespaceType, CoinType>(owner_addr: address): u64 acquires Vault {
        borrow_global<Vault<NamespaceType, CoinType>>(owner_addr).id
    }

    /// Returns the unscaled_debt field for a Vault.
    public fun vault_unscaled_debt<NamespaceType, CoinType>(
        owner_addr: address,
    ): u64 acquires Vault {
        return borrow_global<Vault<NamespaceType, CoinType>>(owner_addr).unscaled_debt
    }

    /// Returns the current scaled_debt for a Vault using debt_scaling_factor_current.
    public fun vault_scaled_debt<NamespaceType, CoinType>(
        owner_addr: address,
    ): u64 acquires Engine, Vault {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault = borrow_global<Vault<NamespaceType, CoinType>>(owner_addr);
        return scaled_debt_internal(engine, vault)
    }

    /// Gas-efficient return for scaled_debt that does not borrow.
    fun scaled_debt_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        vault: &Vault<NamespaceType, CoinType>,
    ): u64 {
        return scale_debt(vault.unscaled_debt, debt_scaling_factor_current_internal(engine))
    }

    /// Returns the collateral amount for a Vault.
    public fun vault_observed_collateral<NamespaceType, CoinType>(
        owner_addr: address
    ): u64 acquires Vault {
        let vault = borrow_global<Vault<NamespaceType, CoinType>>(owner_addr);
        return coin::value(&vault.collateral)
    }

    /// Estimates the oracle price based off of the maintenance collateral ratio. The closer a
    /// vault's collateral ratio to the maintenance CR, the more accurate the estimate. If the
    /// actual collateral ratio is below the maintenance collateral ratio, the estimated price
    /// will be higher. A higher price is generally more friendly for the vault owner during
    /// liquidations.
    public fun vault_oracle_free_price<NamespaceType, CoinType>(
        owner_addr: address,
    ): u64 acquires Engine, Vault {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault = borrow_global<Vault<NamespaceType, CoinType>>(owner_addr);
        return oracle_free_price_internal(engine, vault)
    }

    /// Gas-efficient return for oracle_free_price that does not borrow.
    fun oracle_free_price_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        vault: &Vault<NamespaceType, CoinType>,
    ): u64 {
        return scale_floor(
            scaled_debt_internal(engine, vault),
            engine.maintenance_collateral_ratio * PRICE_PRECISION,
            coin::value(&vault.collateral) * CR_PRECISION,
        )
    }

    /// Returns the collateral ratio for a Vault.
    public fun vault_collateral_ratio<NamespaceType, CoinType>(
        owner_addr: address,
    ): u64 acquires Vault, Engine {
        let engine = borrow_global<Engine<NamespaceType, CoinType>>(
            namespace_addr<NamespaceType>(),
        );
        let vault = borrow_global<Vault<NamespaceType, CoinType>>(owner_addr);
        return collateral_ratio_internal(engine, vault)
    }

    /// Gas-efficient return for collateral_ratio that does not borrow.
    fun collateral_ratio_internal<NamespaceType, CoinType>(
        engine: &Engine<NamespaceType, CoinType>,
        vault: &Vault<NamespaceType, CoinType>,
    ): u64 {
        assert!(safe_is_fresh_internal(engine), error::invalid_state(ESAFE_NOT_FRESH));
        return collateral_ratio(
            coin::value(&vault.collateral),
            scaled_debt_internal(engine, vault),
            safe::price(engine.safe_addr),
            coin::decimals<CoinType>(),
        )
    }

    /// Returns whether the Vault is marked for liquidation.
    public fun vault_is_marked<NamespaceType, CoinType>(owner_addr: address): bool acquires Vault {
        return borrow_global<Vault<NamespaceType, CoinType>>(owner_addr).mark_info.marker_addr != @0
    }

    /// Returns the mark_info for a Vault.
    public fun vault_mark_info<NamespaceType, CoinType>(
        owner_addr: address,
    ): (address, u64, u64) acquires Vault {
        let mark_info = &borrow_global<Vault<NamespaceType, CoinType>>( owner_addr).mark_info;
        return (mark_info.marker_addr, mark_info.timestamp, mark_info.mark_price)
    }

    //
    // HELPERS
    //

    /// Returns the collateral ratio in %. e.g. 100 = 100%
    fun collateral_ratio(
        collateral_amount: u64,
        debt_amount: u64,
        collateral_price: u64,
        collateral_decimals: u8,
    ): u64 {
        if (debt_amount == 0) return MAX_U64;
        let collateral_value =
            collateral_value(collateral_amount, collateral_price, collateral_decimals);
        return scale_floor(collateral_value, CR_PRECISION, debt_amount)
    }

    /// Returns the collateral value
    fun collateral_value(
        collateral_amount: u64,
        collateral_price: u64,
        collateral_decimals: u8,
    ): u64 {
        let collateral_value = scale_floor(collateral_amount, collateral_price, PRICE_PRECISION);
        if (collateral_decimals > PRICE_DECIMALS) {
            let delta = collateral_decimals - PRICE_DECIMALS;
            while (delta > 0) {
                collateral_value = collateral_value / 10;
                delta = delta - 1;
            }
        } else if (collateral_decimals < PRICE_DECIMALS) {
            let delta = PRICE_DECIMALS - collateral_decimals;
            while (delta > 0) {
                collateral_value = collateral_value * 10;
                delta = delta - 1;
            }
        };
        return collateral_value
    }

    /// Returns debt scaled by the debt_scaling_factor. Since this value is used to calculate the
    /// collateral ratio, we use ceiling division to avoid rounding errors
    fun scale_debt(unscaled_debt: u64, debt_scaling_factor: u64): u64 {
        return scale_ceil(unscaled_debt, debt_scaling_factor, SCALING_FACTOR_PRECISION)
    }

    /// Returns debt unscaled by the debt_scaling_factor.
    fun unscale_debt(scaled_debt: u64, debt_scaling_factor: u64): u64 {
        return scale_ceil(scaled_debt, SCALING_FACTOR_PRECISION, debt_scaling_factor)
    }

    /// Scales a number by a numerator/denominator. Applies floor division.
    fun scale_floor(n: u64, numerator: u64, denominator: u64): u64 {
        return ((n as u128) * (numerator as u128) / (denominator as u128) as u64)
    }

    /// Scales a number by a numerator/denominator. Applies ceiling division.
    fun scale_ceil(n: u64, numerator: u64, denominator: u64): u64 {
        let top = (n as u128) * (numerator as u128);
        let bottom = (denominator as u128);
        let quotient = top / bottom;
        let remainer = top % bottom;
        if (remainer > 0) {
            return (quotient + 1 as u64)
        } else {
            return (quotient as u64)
        }
    }

    /// Returns the larger of two values.
    fun max(a: u64, b: u64): u64 {
        if (a >= b) return a;
        return b
    }

    /// Returns the smaller of two values.
    fun min(a: u64, b: u64): u64 {
        if (a <= b) return a;
        return b
    }
}
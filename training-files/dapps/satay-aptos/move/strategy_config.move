/// establishes access control for the strategy keeper role of strategies approved on a vault
module satay::strategy_config {
    use std::signer;

    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    friend satay::strategy_coin;

    // error codes

    /// when the strategy coin config does not exist
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 1;

    /// when the account calling accept_strategy_manager is not the new strategy coin manager
    const ERR_NOT_NEW_MANAGER: u64 = 2;

    /// when the signer is not the strategy coin manager
    const ERR_NOT_MANAGER: u64 = 3;

    /// holds the strategy manager information for each (BaseCoin, StrategyType), stored in strategy account
    /// * strategy_manager_address: address - the address of the account that has the strategy manager role
    /// * new_strategy_manager_addressL address - the address of the account that can accept the strategy manager role
    /// * strategy_manager_change_events: EventHandle<StrategyManagerChangeEvent>
    struct StrategyConfig<phantom BaseCoin, phantom StrategyType: drop> has key {
        strategy_manager_address: address,
        new_strategy_manager_address: address,
        strategy_manager_change_events: EventHandle<StrategyManagerChangeEvent>,
    }

    /// emitted when a new strategy manager accepts the role
    /// * new_strategy_manager_address: address - the address of the account that accepted the strategy manager role
    struct StrategyManagerChangeEvent has drop, store {
        new_strategy_manager_address: address,
    }

    /// initializes a StrategyConfig resource in the strategy account, called by strategy_coin::initialize
    /// * strategy_account: &signer - the strategy resource account
    /// * strategy_manager_address: address - the address of the account to grant the strategy manager role to
    /// * _witness: &StrategyType - witness pattern
    public(friend) fun initialize<BaseCoin, StrategyType: drop>(
        strategy_account: &signer,
        strategy_manager_address: address,
        _witness: &StrategyType
    ) {
        move_to(strategy_account, StrategyConfig<BaseCoin, StrategyType> {
            strategy_manager_address,
            new_strategy_manager_address: @0x0,
            strategy_manager_change_events: account::new_event_handle<StrategyManagerChangeEvent>(strategy_account)
        });
    }

    /// sets the new strategy coin manager address
    /// * strategy_manager: &signer - must have the strategy manager role
    /// * strategy_address: address - the address of the strategy resource account
    /// * new_strategy_manager_address: address - the address of the account to grant the strategy manager role to
    public entry fun set_strategy_manager<BaseCoin, StrategyType: drop>(
        strategy_manager: &signer,
        strategy_address: address,
        new_strategy_manager_address: address
    )
    acquires StrategyConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(strategy_address);
        assert_strategy_manager<BaseCoin, StrategyType>(strategy_manager, strategy_address);
        let strategy_config = borrow_global_mut<StrategyConfig<BaseCoin, StrategyType>>(strategy_address);
        strategy_config.new_strategy_manager_address = new_strategy_manager_address;
    }

    /// accept the strategy manager role
    /// * new_strategy_manager: &signer - must have the address set on StrategyConfig.new_strategy_manager_address
    /// * strategy_address: address - the address of the strategy resource account
    public entry fun accept_strategy_manager<BaseCoin, StrategyType: drop>(
        new_strategy_manager: &signer,
        strategy_address: address
    )
    acquires StrategyConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(strategy_address);
        let strategy_config = borrow_global_mut<StrategyConfig<BaseCoin, StrategyType>>(strategy_address);
        let new_strategy_manager_address = signer::address_of(new_strategy_manager);
        assert!(new_strategy_manager_address == strategy_config.new_strategy_manager_address, ERR_NOT_MANAGER);
        event::emit_event(&mut strategy_config.strategy_manager_change_events, StrategyManagerChangeEvent {
            new_strategy_manager_address
        });
        strategy_config.strategy_manager_address = strategy_config.new_strategy_manager_address;
        strategy_config.new_strategy_manager_address = @0x0;
    }

    #[view]
    /// returns the strategy manager address for the strategy
    /// * strategy_address: address - the address of the strategy resource account
    public fun get_strategy_manager_address<BaseCoin, StrategyType: drop>(strategy_address: address): address
    acquires StrategyConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(strategy_address);
        let config = borrow_global<StrategyConfig<BaseCoin, StrategyType>>(strategy_address);
        config.strategy_manager_address
    }

    /// asserts that the signer has the strategy manager role for the strategy
    /// * strategy_manager: &signer - must have the strategy manager role
    /// * strategy_address: address - the address of the strategy resource account
    public fun assert_strategy_manager<BaseCoin, StrategyType: drop>(
        strategy_manager: &signer,
        strategy_address: address
    )
    acquires StrategyConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(strategy_address);
        let config = borrow_global<StrategyConfig<BaseCoin, StrategyType>>(strategy_address);
        assert!(signer::address_of(strategy_manager) == config.strategy_manager_address, ERR_NOT_MANAGER);
    }

    /// asserts that StrategyConfig<BaseCoin, StrategyType> exists on strategy_address
    /// * strategy_address: address - the address of the strategy resource account
    fun assert_strategy_config_exists<BaseCoin, StrategyType: drop>(strategy_address: address) {
        assert!(exists<StrategyConfig<BaseCoin, StrategyType>>(strategy_address), ERR_CONFIG_DOES_NOT_EXIST);
    }
}

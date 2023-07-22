/// establishes access control for the strategy keeper role of strategies approved on a vault
module satay::keeper_config {
    use std::signer;

    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;

    use satay::vault_config;

    friend satay::vault;

    // error codes

    /// when the keeper config does not exist
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 1;

    /// when the account calling accept_keeper is not the new keeper
    const ERR_NOT_NEW_KEEPER: u64 = 2;

    /// when the signer is not the keeper
    const ERR_NOT_KEEPER: u64 = 3;

    /// holds the keeper information for each StrategyType, stored in Vault<BaseCoin> account
    /// * keeper_address: address - the address of the current keeper
    /// * new_keeper_address: address - the address of the account that can accept the keeper role
    /// * keeper_change_events: EventHandle<KeeperChangeEvent>
    struct KeeperConfig<phantom BaseCoin, phantom StrategyType: drop> has key {
        keeper_address: address,
        new_keeper_address: address,
        keeper_change_events: EventHandle<KeeperChangeEvent>,
    }

    /// emitted when a new keeper accepts the role
    /// * new_keeper_address: address - the address of the account that accepted the keeper role
    struct KeeperChangeEvent has drop, store {
        new_keeper_address: address,
    }

    /// initializes a KeeperConfig resource in vault_account, called by vault::approve_strategy
    /// * vault_account: &signer - the resource account of Vault<BaseCoin>
    /// * _witness: &StrategyType - witness pattern
    public(friend) fun initialize<BaseCoin, StrategyType: drop>(vault_account: &signer, _witness: &StrategyType) {
        move_to(vault_account, KeeperConfig<BaseCoin, StrategyType> {
            keeper_address: vault_config::get_vault_manager_address(signer::address_of(vault_account)),
            new_keeper_address: @0x0,
            keeper_change_events: account::new_event_handle<KeeperChangeEvent>(vault_account),
        });
    }

    /// set new_keeper_address on the KeeperConfig resource
    /// * vault_manager: &signer - must have the vault manager role for Vault<BaseCoin>
    /// * vault_address: address - the address of the resource account for Vault<BaseCoin>
    /// * new_keeper_address: address - the address of the account that can accept the keeper role
    public entry fun set_keeper<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        vault_address: address,
        new_keeper_address: address
    )
    acquires KeeperConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(vault_address);
        vault_config::assert_vault_manager(vault_manager, vault_address);
        let strategy_config = borrow_global_mut<KeeperConfig<BaseCoin, StrategyType>>(vault_address);
        strategy_config.new_keeper_address = new_keeper_address;
    }

    /// accept the keeper role
    /// * new_keeper: &signer - must have the address set on KeeperConfig.new_keeper_address
    /// * vault_address: address - the address of the resource account for Vault<BaseCoin>
    public entry fun accept_keeper<BaseCoin, StrategyType: drop>(new_keeper: &signer, vault_address: address)
    acquires KeeperConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(vault_address);
        let vault_config = borrow_global_mut<KeeperConfig<BaseCoin, StrategyType>>(vault_address);
        assert!(signer::address_of(new_keeper) == vault_config.new_keeper_address, ERR_NOT_NEW_KEEPER);
        event::emit_event(&mut vault_config.keeper_change_events, KeeperChangeEvent {
            new_keeper_address: vault_config.new_keeper_address,
        });
        vault_config.keeper_address = vault_config.new_keeper_address;
        vault_config.new_keeper_address = @0x0;
    }

    /// returns the keeper address for StrategyType on Vault<BaseCoin>
    /// * vault_address: address - the address of the resource account for Vault<BaseCoin>
    public fun get_keeper_address<BaseCoin, StrategyType: drop>(vault_address: address): address
    acquires KeeperConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(vault_address);
        let config = borrow_global<KeeperConfig<BaseCoin, StrategyType>>(vault_address);
        config.keeper_address
    }

    /// asserts that the signer has the keeper role for StrategyType on Vault<BaseCoin>
    /// * keeper: &signer - must have the keeper role for StrategyType on Vault<BaseCoin>
    /// * vault_address: address - the address of the resource account for Vault<BaseCoin>
    public fun assert_keeper<BaseCoin, StrategyType: drop>(keeper: &signer, vault_address: address)
    acquires KeeperConfig {
        assert_strategy_config_exists<BaseCoin, StrategyType>(vault_address);
        let config = borrow_global<KeeperConfig<BaseCoin, StrategyType>>(vault_address);
        assert!(signer::address_of(keeper) == config.keeper_address, ERR_NOT_KEEPER);
    }

    /// asserts that KeeperConfig<BaseCoin, StrategyType> exists on vault_address
    /// * vault_address: address - the address of the resource account for Vault<BaseCoin>
    fun assert_strategy_config_exists<BaseCoin, StrategyType: drop>(vault_address: address) {
        assert!(exists<KeeperConfig<BaseCoin, StrategyType>>(vault_address), ERR_CONFIG_DOES_NOT_EXIST);
    }
}

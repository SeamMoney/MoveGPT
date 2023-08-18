```rust
/// establishes access control for the global roles Governance and DAO Admin
module satay::global_config {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::event::{Self, EventHandle};

    friend satay::satay;

    // Error codes

    /// when config doesn't exist
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 400;

    /// when non-satay account calls initialize
    const ERR_NOT_SATAY: u64 = 401;

    /// When user is not admin
    const ERR_NOT_DAO_ADMIN: u64 = 402;

    /// When user is not governance
    const ERR_NOT_GOVERNANCE: u64 = 403;

    /// when unathorized call to accept_governance
    const ERR_NOT_NEW_GOVERNANCE: u64 = 404;

    /// when unathorized call to accept_dao_admin
    const ERR_NOT_NEW_DAO_ADMIN: u64 = 405;

    /// holds signer cap for resource account that holds GlobalConfig
    /// * signer_cap: SignerCapability
    struct GlobalConfigResourceAccount has key {
        signer_cap: SignerCapability
    }

    /// the global configuation resource
    /// * dao_admin_address: address - the address of the account that has the DAO admin role
    /// * governance_address: address - the address of the account that has the governance role
    /// * new_dao_admin_address: address - the address of the account that can accept the DAO admin role
    /// * new_governance_address: address - the address of the account that can accept the governance role
    /// * dao_admin_change_events: EventHandle<DaoAdminChangeEvent>
    /// * governance_change_events: EventHandle<GovernanceChangeEvent>
    struct GlobalConfig has key {
        dao_admin_address: address,
        governance_address: address,
        new_dao_admin_address: address,
        new_governance_address: address,
        dao_admin_change_events: EventHandle<DaoAdminChangeEvent>,
        governance_change_events: EventHandle<GovernanceChangeEvent>,
    }

    // events

    /// emitted when an acocunt accepts the dao_admin role
    /// * new_dao_admin_address - the address of the account that accepted the DAO admin role
    struct DaoAdminChangeEvent has drop, store {
        new_dao_admin_address: address,
    }

    /// emitted when an account accpets the governance role
    /// * new_governance_address - the address of the account that accepted the governance role
    struct GovernanceChangeEvent has drop, store {
        new_governance_address: address,
    }

    /// initialize resource account and GlobalConfig resource, called by satay::initialize
    /// * satay_admin: &signer - must be the satay deployer account
    public(friend) fun initialize(satay_admin: &signer)
    acquires GlobalConfig {
        assert!(signer::address_of(satay_admin) == @satay, ERR_NOT_SATAY);

        let (global_config_signer, signer_cap) = account::create_resource_account(
            satay_admin,
            b"global config resource account",
        );

        move_to(satay_admin, GlobalConfigResourceAccount {signer_cap});

        move_to(&global_config_signer, GlobalConfig {
            dao_admin_address: @satay,
            governance_address: @satay,
            new_dao_admin_address: @0x0,
            new_governance_address: @0x0,
            dao_admin_change_events: account::new_event_handle<DaoAdminChangeEvent>(&global_config_signer),
            governance_change_events: account::new_event_handle<GovernanceChangeEvent>(&global_config_signer),
        });

        let global_config_account_address = signer::address_of(&global_config_signer);
        let global_config = borrow_global_mut<GlobalConfig>(global_config_account_address);
        event::emit_event(&mut global_config.dao_admin_change_events, DaoAdminChangeEvent {
            new_dao_admin_address: @satay
        });
        event::emit_event(&mut global_config.governance_change_events, GovernanceChangeEvent {
            new_governance_address: @satay
        });
    }

    // getter functions

    #[view]
    /// returns the address of the account that holds the GlobalConfig resource
    public fun get_global_config_account_address(): address
    acquires GlobalConfigResourceAccount {
        assert!(exists<GlobalConfigResourceAccount>(@satay), ERR_CONFIG_DOES_NOT_EXIST);

        let global_config_account = borrow_global<GlobalConfigResourceAccount>(@satay);
        let global_config_account_address = account::get_signer_capability_address(
            &global_config_account.signer_cap
        );

        assert!(exists<GlobalConfig>(global_config_account_address), ERR_CONFIG_DOES_NOT_EXIST);

        global_config_account_address
    }

    #[view]
    /// returns the address of the DAO admin account
    public fun get_dao_admin(): address
    acquires GlobalConfig, GlobalConfigResourceAccount {
        let global_config_account_address = get_global_config_account_address();
        let config = borrow_global<GlobalConfig>(global_config_account_address);
        config.dao_admin_address
    }

    #[view]
    /// returns the address of the governance account
    public fun get_governance_address(): address
    acquires GlobalConfig, GlobalConfigResourceAccount {
        let global_config_account_address = get_global_config_account_address();
        let config = borrow_global<GlobalConfig>(global_config_account_address);
        config.governance_address
    }

    // assert statements

    /// asserts that the transaction signer has the DAO admin role
    /// * dao_admin: &signer - must have the DAO admin role on GlobalConfig
    public fun assert_dao_admin(dao_admin: &signer)
    acquires GlobalConfig, GlobalConfigResourceAccount {
        assert!(get_dao_admin() == signer::address_of(dao_admin), ERR_NOT_DAO_ADMIN);
    }

    /// asserts that the transaction signer has the governance role
    /// * governance: &signer - must have the governance role on GlobalConfig
    public fun assert_governance(governance: &signer)
    acquires GlobalConfig, GlobalConfigResourceAccount {
        assert!(get_governance_address() == signer::address_of(governance), ERR_NOT_GOVERNANCE);
    }

    /// set new_dao_admin_address on GlobalConfig
    /// * dao_admin: &signer - must have the DAO admin role on GlobalConfig
    /// * new_dao_admin_address: address - the address of the account that can accept the DAO admin role
    public entry fun set_dao_admin(dao_admin: &signer, new_dao_admin_address: address)
    acquires GlobalConfigResourceAccount, GlobalConfig {
        assert_dao_admin(dao_admin);
        let global_config_account_address = get_global_config_account_address();
        let config = borrow_global_mut<GlobalConfig>(global_config_account_address);
        config.new_dao_admin_address = new_dao_admin_address;
    }

    /// accept the dao admin role
    /// * new_dao_admin: &signer - must have the address set on GlobalConfig.new_dao_admin_address
    public entry fun accept_dao_admin(new_dao_admin: &signer)
    acquires GlobalConfigResourceAccount, GlobalConfig {
        let global_config_account_address = get_global_config_account_address();

        let new_dao_admin_address = signer::address_of(new_dao_admin);
        let config = borrow_global_mut<GlobalConfig>(global_config_account_address);

        assert!(config.new_dao_admin_address == new_dao_admin_address, ERR_NOT_NEW_DAO_ADMIN);

        config.dao_admin_address = new_dao_admin_address;
        config.new_dao_admin_address = @0x0;

        event::emit_event(&mut config.dao_admin_change_events, DaoAdminChangeEvent {
            new_dao_admin_address
        });
    }

    /// set new_governance_address on GlobalConfig
    /// * governance: &signer - must have the governance role on GlobalConfig
    /// * new_governance_address: address - the address of the account that can accept the governance role
    public entry fun set_governance(governance: &signer, new_governance_address: address)
    acquires GlobalConfigResourceAccount, GlobalConfig {
        assert_governance(governance);
        let global_config_account_address = get_global_config_account_address();
        let config = borrow_global_mut<GlobalConfig>(global_config_account_address);
        config.new_governance_address = new_governance_address;
    }

    /// accept the governance role for new_governance_address
    /// * new_governance: &signer - must have the address set on GlobalConfig.new_governance_address
    public entry fun accept_governance(new_governance: &signer)
    acquires GlobalConfigResourceAccount, GlobalConfig {
        let global_config_account_address = get_global_config_account_address();

        let new_governance_address = signer::address_of(new_governance);
        let config = borrow_global_mut<GlobalConfig>(global_config_account_address);

        assert!(config.new_governance_address == new_governance_address, ERR_NOT_NEW_GOVERNANCE);

        config.governance_address = new_governance_address;
        config.new_governance_address = @0x0;

        event::emit_event(&mut config.governance_change_events, GovernanceChangeEvent {
            new_governance_address
        });
    }
}
```
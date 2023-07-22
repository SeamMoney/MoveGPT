module hamsterpocket::platform {
    use aptos_framework::account;
    use aptos_std::table_with_length;
    use aptos_framework::account::SignerCapability;

    use std::error;
    use std::signer::address_of;
    use std::string::String;

    friend hamsterpocket::chef;
    friend hamsterpocket::pocket;

    // Binding deployer
    const HAMSTERPOCKET: address = @hamsterpocket;
    const DEPLOYER: address = @deployer;

    const INVALID_ADMIN: u64 = 0x0;
    const INVALID_OPERATOR: u64 = 0x1;
    const INVALID_TARGET: u64 = 0x2;

    // here we define the platform config
    struct PlatformConfig has key {
        deployer_capibility: account::SignerCapability,
        allowed_interactive_targets: table_with_length::TableWithLength<String, bool>,
        allowed_operators: table_with_length::TableWithLength<address, bool>,
        allowed_admins: table_with_length::TableWithLength<address, bool>,
    }

    // init module will be called automatically whenever the module is published
    public(friend) fun initialize(
        hamsterpocket_signer: &signer,
        signer_cap: SignerCapability
    ) acquires PlatformConfig {
        move_to(hamsterpocket_signer, PlatformConfig {
            deployer_capibility: signer_cap,
            allowed_operators: table_with_length::new<address, bool>(),
            allowed_interactive_targets: table_with_length::new<String, bool>(),
            allowed_admins: table_with_length::new<address, bool>(),
        });

        let config = borrow_global_mut<PlatformConfig>(HAMSTERPOCKET);
        table_with_length::add(&mut config.allowed_admins, DEPLOYER, true);

        assert!(
            table_with_length::contains(
                &config.allowed_admins,
                DEPLOYER
            ),
            error::invalid_state(INVALID_ADMIN)
        );
        is_admin(DEPLOYER, true);
        assert!(address_of(&get_resource_signer()) == HAMSTERPOCKET, error::invalid_state(INVALID_ADMIN));
    }

    // get resource signer
    public(friend) fun get_resource_signer(): signer acquires PlatformConfig {
        let config = borrow_global<PlatformConfig>(HAMSTERPOCKET);
        let resource_signer = account::create_signer_with_capability(
            &config.deployer_capibility
        );
        return resource_signer
    }

    // enable interactive target
    public(friend) fun set_interactive_target(target: String, enabled: bool) acquires PlatformConfig {
        let config = borrow_global_mut<PlatformConfig>(HAMSTERPOCKET);
        let allowed_interactive_targets = &mut config.allowed_interactive_targets;

        table_with_length::upsert<String, bool>(allowed_interactive_targets, target, enabled);
    }

    // enable operators
    public(friend) fun set_operator(operator: address, enabled: bool) acquires PlatformConfig {
        let config = borrow_global_mut<PlatformConfig>(HAMSTERPOCKET);
        let allowed_operators = &mut config.allowed_operators;

        table_with_length::upsert<address, bool>(allowed_operators, operator, enabled);
    }

    // enable operators
    public(friend) fun set_admin(admin: address, enabled: bool) acquires PlatformConfig {
        let config = borrow_global_mut<PlatformConfig>(HAMSTERPOCKET);
        let allowed_admins = &mut config.allowed_admins;

        table_with_length::upsert<address, bool>(allowed_admins, admin, enabled);
    }

    // check whether the signer is admin
    public(friend) fun is_admin(signer: address, raise_error: bool): bool acquires PlatformConfig {
        let config = borrow_global<PlatformConfig>(HAMSTERPOCKET);

        let result = false;

        if (table_with_length::contains(&config.allowed_admins, signer)) {
            result = *table_with_length::borrow(
                &config.allowed_admins,
                signer
            );
        };

        if (raise_error) {
            assert!(result, error::permission_denied(INVALID_ADMIN));
        };

        return result
    }

    // check whether an address is operator
    public(friend) fun is_operator(operator: address, raise_error: bool): bool acquires PlatformConfig {
        let config = borrow_global<PlatformConfig>(HAMSTERPOCKET);

        let result = false;

        if (table_with_length::contains(&config.allowed_operators, operator)) {
            result = *table_with_length::borrow<address, bool>(&config.allowed_operators, operator);
        };

        if (raise_error) {
            assert!(result, error::permission_denied(INVALID_OPERATOR));
        };

        return result
    }

    // check whether an address is allowed to be interacted
    public(friend) fun is_allowed_target(target: String, raise_error: bool): bool acquires PlatformConfig {
        let config = borrow_global<PlatformConfig>(HAMSTERPOCKET);

        let result = false;

        if (table_with_length::contains(&config.allowed_interactive_targets, target)) {
            result = *table_with_length::borrow<String, bool>(&config.allowed_interactive_targets, target);
        };

        if (raise_error) {
            assert!(result, error::permission_denied(INVALID_TARGET));
        };

        return result
    }
}
address Quantum {
module Permission {
    use std::event;
    use std::signer;
    use std::vector;
    use aptos_std::type_info;
    use aptos_framework::account;
    

    struct Permission<phantom PermType> has key, store {
        addresses: vector<address>,
        events: event::EventHandle<UpdateEvent>,
    }

    struct UpdateEvent has drop, store {
        action: u8,     // 0 for remove, 1 for add
        addr: address,
    }

    const PERMISSION_CAN_NOT_REGISTER: u64 = 101;
    const PERMISSION_NOT_EXISTS: u64 = 102;

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    fun owner_address<PermType: store>(): address {
        // get the T-type address
        coin_address<PermType>()
    }

    // only permType owner can register
    public fun register_permission<PermType: store>(account: &signer) {
        let owner = owner_address<PermType>();
        assert!(signer::address_of(account) == owner, PERMISSION_CAN_NOT_REGISTER);
        move_to(
            account,
            Permission<PermType> {
                addresses: vector::empty<address>(),
                events: account::new_event_handle<UpdateEvent>(account),
            },
        );
    }

    public fun add<PermType: store>(account: &signer, to: address) acquires Permission {
        let account_addr = signer::address_of(account);
        assert!(exists<Permission<PermType>>(account_addr), PERMISSION_NOT_EXISTS);
        let perm = borrow_global_mut<Permission<PermType>>(account_addr);
        vector::push_back<address>(&mut perm.addresses, to);
        event::emit_event(
            &mut perm.events,
            UpdateEvent { addr: to, action: 1 },
        );
    }

    public fun remove<PermType: store>(account: &signer, to: address) acquires Permission {
        let account_addr = signer::address_of(account);
        assert!(exists<Permission<PermType>>(account_addr), PERMISSION_NOT_EXISTS);
        let perm = borrow_global_mut<Permission<PermType>>(account_addr);
        let addresses = &mut perm.addresses;
        let (is_exists, index) = vector::index_of<address>(addresses, &to);
        if (is_exists) {
            vector::remove<address>(addresses, index);
            event::emit_event(
                &mut perm.events,
                UpdateEvent { addr: to, action: 0 },
            );
        };
    }

    public fun can<PermType: store>(addr: address): bool acquires Permission {
        let owner = owner_address<PermType>();
        if (owner == addr) {
            return true
        };
        let perm = borrow_global<Permission<PermType>>(owner);
        vector::contains<address>(&perm.addresses, &addr)
    }

    public fun total<PermType: store>(owner: address): u64 acquires Permission {
        assert!(exists<Permission<PermType>>(owner), PERMISSION_NOT_EXISTS);
        let perm = borrow_global<Permission<PermType>>(owner);
        vector::length<address>(&perm.addresses)
    }

    public fun is_owner<PermType: store>(addr: address): bool {
        owner_address<PermType>() == addr
    }
}
}

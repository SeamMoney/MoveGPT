```rust
/// This module demonstrates a basic user profile management
/// users can
///     (1) register for the profile board
///     (2) update a profile
///
/// The module also emits events for subscribers
///     (1) profile change event
module userinfo_addr::userinfo {
    use std::acl::Self;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // Error map
    const EACCOUNT_NOT_IN_ACL: u64 = 1;
    const ECANNOT_REMOVE_ADMIN_FROM_ACL: u64 = 2;

    struct ProfileChangeEventHandle has key {
        change_events: EventHandle<ProfileChangeEvent>
    }

    /// emit an event from participant account showing the board and the new post
    struct ProfileChangeEvent has store, drop {
        name: vector<u8>,
        image: vector<u8>,
        user: address
    }

    /// an account can make or update profile
    public entry fun update_profile(
        account: signer, _address: address, name: vector<u8>, image: vector<u8>,
    ) acquires ProfileChangeEventHandle {
        let event_handle = borrow_global_mut<ProfileChangeEventHandle>(_address);
        event::emit_event<ProfileChangeEvent>(
            &mut event_handle.change_events,
            ProfileChangeEvent{
                name,
                image,
                user: signer::address_of(&account)
            }
        );
    }
}

```
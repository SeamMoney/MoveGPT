/**
Trying to write fundraiser contract in move lang.
**/


module raise_money::Fundraiser {
    use std::signer;
    use std::debug;
    use std::simple_map;
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::aptos_account;
    use aptos_framework::account;
    use aptos_framework::system_addresses;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::coin::{Self, MintCapability};

    // Error codes
    const ERROR_ALREADY_STORAGE_RESOURCE: u64 = 0;

    // Storage
    struct Storage has key, store {
        value: u64,
        ledger: simple_map::SimpleMap<address, u64>,
        donate_events: EventHandle<DonateEvent>
    }

    // Events
    struct DonateEvent has drop, store {
        value: u64,
        to: address,
        from: address
    }

    /// Publish `Storage` to `sender`.
    public fun publish_storage(sender: &signer) {
        // Make sure the `sender` already doesn't have the `Storage` resource.
        assert!(!exists<Storage>(signer::address_of(sender)), ERROR_ALREADY_STORAGE_RESOURCE);

        move_to(sender, Storage {
            value: 0, 
            ledger: simple_map::create<address,u64>(),
            donate_events: account::new_event_handle<DonateEvent>(sender)
        });
    }

    public fun donate(sender: &signer, to: address, amount: u64) acquires Storage{
        // `to` should have the `Storage` resource.
        assert!(exists<Storage>(to), ERROR_ALREADY_STORAGE_RESOURCE);

        // Transfer `amount` Octa to `to` from `sender`
        coin::transfer<AptosCoin>(sender, to, amount);

        // Increment the state.
        let to_storage = borrow_global_mut<Storage>(to);
        to_storage.value = to_storage.value + amount;

        event::emit_event(&mut to_storage.donate_events, DonateEvent {
            value: amount,
            to: to,
            from: signer::address_of(sender),
        });

        if (simple_map::contains_key<address, u64>(&to_storage.ledger, &signer::address_of(sender)) ){
            // Get the value.
            let val = simple_map::borrow_mut(&mut to_storage.ledger, &signer::address_of(sender));

            // Increment the value.
            *val = amount + *val;
        } else {
            simple_map::add(&mut to_storage.ledger, signer::address_of(sender), amount);
        }
    }

    public fun get_raised_amount(addr: address): u64 acquires Storage {
        borrow_global<Storage>(addr).value
    }

    public fun get_donation_by_to(by: address, to: address): u64 acquires Storage {
        // Make sure the `to` has `Storage` resource.
        assert!(exists<Storage>(to), ERROR_ALREADY_STORAGE_RESOURCE);

        // Get the storage.
        let to_storage = borrow_global_mut<Storage>(to); 

        if (simple_map::contains_key<address, u64>(&to_storage.ledger, &by) ){
            let val = simple_map::borrow(&to_storage.ledger, &by);
            *val
        } else {
            0
        }
    }

    #[test_only]
    struct AptosCoinCapabilities has key {
        mint_cap: MintCapability<AptosCoin>,
    }

    #[test_only]
    public(friend) fun store_aptos_coin_mint_cap(aptos_framework: &signer, mint_cap: MintCapability<AptosCoin>) {
        system_addresses::assert_aptos_framework(aptos_framework);
        move_to(aptos_framework, AptosCoinCapabilities { mint_cap })
    }


    #[test_only]
    public fun test_aptos_coin(
        aptos_framework: &signer
    ) {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        store_aptos_coin_mint_cap(aptos_framework, mint_cap);
        coin::destroy_burn_cap<AptosCoin>(burn_cap);
    }

    #[test(aptos_framework = @aptos_framework, a = @0xAAAA, person = @0xBBBB)]
    public fun test_fund_address(aptos_framework: signer, a: signer, person: signer) acquires Storage {
        let donate_amount = 100;
        let a_address = signer::address_of(&a);
        let person_address = signer::address_of(&person);

        // Register accounts.
        aptos_account::create_account(signer::address_of(&a));
        aptos_account::create_account(signer::address_of(&person));

        // Setup AptosCoin for testing.
        test_aptos_coin(&aptos_framework);

        // Allocate Storage.
        publish_storage(&person);

        // Give some test AptosCoin to `a`.
        aptos_coin::mint(&aptos_framework, signer::address_of(&a), donate_amount);

        debug::print(&coin::balance<AptosCoin>(signer::address_of(&a)));

        // Things got minted
        assert!(coin::balance<AptosCoin>(signer::address_of(&a)) > 0, 10);

        // a will give some funds.
        donate(&a, signer::address_of(&person), donate_amount);
        
        debug::print(&get_donation_by_to(a_address, person_address));
        assert!(get_donation_by_to(a_address, person_address) == donate_amount, 100);
    }
}


module AptosFundraiser::Fundraiser {
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

    struct DonateVault has key, store {
        value: u64,
        ledger: simple_map::SimpleMap<address, u64>,
    }

    // Initing the storage
    public fun init(sender: &signer) {
        // assert the existence of signer's DonateVault
        assert!(!exists<DonateVault>(signer::address_of(sender)), ERROR_ALREADY_STORAGE_RESOURCE);

        move_to(sender, DonateVault {
            value: 0, 
            ledger: simple_map::create<address,u64>(),
        });
    }

    // Donate handler
    public fun donate(sender: &signer, to: address, amount: u64) acquires DonateVault{
        assert!(exists<DonateVault>(to), ERROR_ALREADY_STORAGE_RESOURCE);

        coin::transfer<AptosCoin>(sender, to, amount);

        // Add balance in vault
        let donate_vault = borrow_global_mut<DonateVault>(to);
        donate_vault.value = donate_vault.value + amount;

        if (simple_map::contains_key<address, u64>(&donate_vault.ledger, &signer::address_of(sender)) ){
            let val = simple_map::borrow_mut(&mut donate_vault.ledger, &signer::address_of(sender));
            *val = amount + *val;
        } else {
            simple_map::add(&mut donate_vault.ledger, signer::address_of(sender), amount);
        }
    }

    public fun get_raised(addr: address): u64 acquires DonateVault {
        borrow_global<DonateVault>(addr).value
    }

    public fun get_donation(by: address, to: address): u64 acquires DonateVault {
        // assert the existence of signer's DonateVault
        assert!(exists<DonateVault>(to), ERROR_ALREADY_STORAGE_RESOURCE);

        // Get the donate vault.
        let donate_vault = borrow_global_mut<DonateVault>(to); 

        if (simple_map::contains_key<address, u64>(&donate_vault.ledger, &by) ){
            let val = simple_map::borrow(&donate_vault.ledger, &by);
            *val
        } else {
            0
        }
    }

    // Test casae
    #[test_only]
    struct AptosCoinCapabilities has key {
        mint_cap: MintCapability<AptosCoin>,
    }

    #[test_only]
    public(friend) fun test_aptos_metadata(aptos_framework: &signer, mint_cap: MintCapability<AptosCoin>) {
        system_addresses::assert_aptos_framework(aptos_framework);
        move_to(aptos_framework, AptosCoinCapabilities { mint_cap })
    }


    #[test_only]
    public fun test_coin(
        aptos_framework: &signer
    ) {
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        aptos_metadata(aptos_framework, mint_cap);
        coin::destroy_burn_cap<AptosCoin>(burn_cap);
    }

    #[test(aptos_framework = @aptos_framework, a = @0xAAAA, person = @0xBBBB)]
    public fun test_fund(aptos_framework: signer, a: signer, person: signer) acquires DonateVault {
        let donate_amount = 100;
        let a_address = signer::address_of(&a);
        let person_address = signer::address_of(&person);

        // Register accounts.
        aptos_account::create_account(signer::address_of(&a));
        aptos_account::create_account(signer::address_of(&person));

        // Setup AptosCoin for testing.
        test_aptos_coin(&aptos_framework);

        // Allocate DonateVault.
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

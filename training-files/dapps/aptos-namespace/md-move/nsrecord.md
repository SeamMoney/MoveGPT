```rust

module nsrecord_addr::nsrecord {

    use aptos_framework::event;
    use std::string::String;
    use std::signer;
    use aptos_std::table::{Self, Table};
    use aptos_framework::account;

    #[test_only]
    use std::string;

    const E_NOT_INITIALIZED: u64 = 1;
    const ERECORD_DOESNT_EXIST: u64 = 2;
    const ERECORD_IS_PUBLIC: u64 = 3;

    struct NamespaceRecord has key {
        records: Table<u64, Record>,
        set_record_event: event::EventHandle<Record>,
        record_counter: u64
    }

    struct Record has store, drop, copy {
        record_id: u64,
        address:address,
        content: String,
        shared_publicly: bool,
    }

    public entry fun create_record(account: &signer){
        let records_holder = NamespaceRecord {
            records: table::new(),
            set_record_event: account::new_event_handle<Record>(account),
            record_counter: 0
        };
        move_to(account, records_holder);
    }

    public entry fun record_hash(account: &signer, content: String) acquires NamespaceRecord {
        let signer_address = signer::address_of(account);
        assert!(exists<NamespaceRecord>(signer_address), E_NOT_INITIALIZED);
        let ns_record = borrow_global_mut<NamespaceRecord>(signer_address);
        let counter = ns_record.record_counter + 1;
        let new_record = Record {
            record_id: counter,
            address: signer_address,
            content,
            shared_publicly: false
        };
        table::upsert(&mut ns_record.records, counter, new_record);
        ns_record.record_counter = counter;
        event::emit_event<Record>(
            &mut borrow_global_mut<NamespaceRecord>(signer_address).set_record_event,
            new_record,
        );
    }

    public entry fun share_publicly(account: &signer, record_id: u64) acquires NamespaceRecord {
        let signer_address = signer::address_of(account);
        assert!(exists<NamespaceRecord>(signer_address), E_NOT_INITIALIZED);
        let ns_record = borrow_global_mut<NamespaceRecord>(signer_address);
        assert!(table::contains(&ns_record.records, record_id), ERECORD_DOESNT_EXIST);
        let this_record = table::borrow_mut(&mut ns_record.records, record_id);
        assert!(this_record.shared_publicly == false, ERECORD_IS_PUBLIC);
        this_record.shared_publicly = true;
    }

    #[test(admin = @0x123)]
    public entry fun test_flow(admin: signer) acquires NamespaceRecord {
        account::create_account_for_test(signer::address_of(&admin));
        create_record(&admin);

        record_hash(&admin, string::utf8(b"New Record"));
        let record_count = event::counter(&borrow_global<NamespaceRecord>(signer::address_of(&admin)).set_record_event);
        assert!(record_count == 1, 4);
        let ns_record = borrow_global<NamespaceRecord>(signer::address_of(&admin));
        assert!(ns_record.record_counter == 1, 5);
        let this_record = table::borrow(&ns_record.records, ns_record.record_counter);
        assert!(this_record.record_id == 1, 6);
        assert!(this_record.shared_publicly == false, 7);
        assert!(this_record.content == string::utf8(b"New Record"), 8);
        assert!(this_record.address == signer::address_of(&admin), 9);

        share_publicly(&admin, 1);
        let ns_record = borrow_global<NamespaceRecord>(signer::address_of(&admin));
        let this_record = table::borrow(&ns_record.records, 1);
        assert!(this_record.record_id == 1, 10);
        assert!(this_record.shared_publicly == true, 11);
        assert!(this_record.content == string::utf8(b"New Record"), 12);
        assert!(this_record.address == signer::address_of(&admin), 13);
    }

    #[test(admin = @0x123)]
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    public entry fun account_can_not_update_record(admin: signer) acquires NamespaceRecord {
        account::create_account_for_test(signer::address_of(&admin));
        share_publicly(&admin, 2);
    }

}

  
```
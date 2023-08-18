```rust
module realm::Realm{

    use std::string::{String,utf8};
    use aptos_std::table::{Self,Table};
    use aptos_std::simple_map::{Self,SimpleMap};
    use std::account::{SignerCapability,create_resource_account,create_signer_with_capability};
    use std::signer;
    use std::vector;
    friend realm::Members;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

     struct Realms has key{
        accounts:Table<String,address>,
    }

    struct Realm has key,drop{
        name:String,
        realm_authority:address,
        active_proposal_count:u64,
        signer_capability:SignerCapability,
        realm_address:address,
        role_config:RoleConfig
    }

    struct RoleConfig has store,copy,drop{
        role_config:SimpleMap<String,vector<u8>>,

    }

    public fun init_module(resource_account:signer){
        move_to(&resource_account,Realms{
            accounts:table::new(),
        })
    }

    const EREALM_NAME_TAKEN:u64=0;


    public fun create_realm(creator:&signer,name:vector<u8>,realm_account:&signer,role_config:&RoleConfig)acquires Realms{
        let (account_signer,signer_capability)=create_resource_account(realm_account,name);
        let creator_address=signer::address_of(creator);
         let created_realms=borrow_global_mut<Realms>(@resource_account);
         let account_address=signer::address_of(&account_signer);
         assert!(!table::contains(&created_realms.accounts,utf8(name)),EREALM_NAME_TAKEN);
         table::add(&mut created_realms.accounts,utf8(name),account_address);
         move_to(&account_signer,Realm{
            name:utf8(name),
            realm_authority:creator_address,
            active_proposal_count:0,
            signer_capability,
            realm_address:signer::address_of(&account_signer),
            role_config:*role_config
         });
        }
    public(friend) fun get_realm_by_address(realm_address:address):signer acquires Realm{
        let realm=borrow_global<Realm>(realm_address);
        create_signer_with_capability(&realm.signer_capability)
    }

    public(friend) fun get_realm_address_by_name(realm_name:String):address acquires Realms{
        let realms=borrow_global<Realms>(@resource_account);
        *table::borrow(&realms.accounts,realm_name)
       
    }

    public(friend) fun is_valid_role_for_action(member:String,action:u8,realm_address:&address):bool acquires Realm{
        let realm=borrow_global<Realm>(*realm_address);
        let member_actions=simple_map::borrow(&realm.role_config.role_config,&member);
        let actions_len=vector::length(member_actions);
        let i=0;
        let has=false;
        while (i < actions_len){
            let added_action=vector::borrow(member_actions,i);
            if(action==*added_action){
                has=true;
                break
            }
        };
        has
    }

    public (friend) fun get_founder_address(realm_address:address):address acquires Realm{
        borrow_global<Realm>(realm_address).realm_authority
    }
 
    #[test_only]
    public fun setup_test(creator:signer){
        init_module(creator);
    }
    #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15)]
    public (friend)  fun test_create_realm(creator:signer,account_creator:&signer,resource_account:signer,realm_account:&signer) acquires Realms,Realm{
        create_account_for_test(signer::address_of(&creator));
        let name=b"Genesis Realm";
        setup_test(resource_account);
        let map=simple_map::create<String,vector<u8>>();
        let actions_vector=vector::empty<u8>();
        vector::push_back(&mut actions_vector,0);
        vector::push_back(&mut actions_vector,1);
        simple_map::add(&mut map,utf8(b"Founder"),actions_vector);
        let role_config_data=RoleConfig{
            role_config:map
        };
        create_realm(account_creator,name,realm_account,&role_config_data);
        let account_table=borrow_global<Realms>(@resource_account);
        assert!(table::contains(&account_table.accounts,utf8(name)),0);
        let account=table::borrow(&account_table.accounts,utf8(name));
        let realm_data=borrow_global<Realm>(*account);
        assert!(realm_data.name==utf8(name),1);
        assert!(realm_data.realm_authority==signer::address_of(account_creator),2);

    }
     #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15,second_realm=@0x16)]
     #[expected_failure(abort_code = 0)]
    public entry fun test_create_realm_with_taken_name(creator:signer,account_creator:signer,resource_account:signer,realm_account:signer,second_realm:signer) acquires Realms,Realm{
        create_account_for_test(signer::address_of(&creator));
        let name=b"Genesis Realm";
        setup_test(resource_account);
         let role_config_data=RoleConfig{
            role_config:simple_map::create()
        };
        create_realm(&account_creator,name,&realm_account,&role_config_data);
        let account_table=borrow_global<Realms>(@resource_account);
        assert!(table::contains(&account_table.accounts,utf8(name)),0);
        let account=table::borrow(&account_table.accounts,utf8(name));
        let realm_data=borrow_global<Realm>(*account);
        assert!(realm_data.name==utf8(name),1);
        assert!(realm_data.realm_authority==signer::address_of(&account_creator),2);
        create_realm(&creator,name,&second_realm,&role_config_data);

    }
    

}
```
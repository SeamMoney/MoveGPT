```rust
module realm::Members{
    use std::table::Table;
    use realm::Realm;
    use std::string::{String,utf8};
    use std::signer;
    use std::table;
 
    struct MemberRecord has store,key,copy,drop{
        realm_address:address,
        status:u8,
        user_address:address,
        role:String
    }

    struct RealmMemberships has key{
        realms:Table<address,MemberRecord>,
    }

    const EMEMBER_RECORD_ALREDY_EXIST:u64=0;
    const ENOT_VALID_ACTION_FOR_ROLE:u64=1;
    const EINVALID_INVITATION_STATUS:u64=2;
    const EINVALID_REALM_AUTHORITY:u64=3;

    const ADD_MEMBER_ACTION:u8=0;
    const DECLINE_MEMBER_ACTION:u8=1;

    const INVITED:u8=0;
    const ACCEPTED:u8=1;
    const REJECTED:u8=2;
    const DECLINED:u8=3;

    public fun  add_founder_role(founder:&signer,realm_address:address)acquires RealmMemberships{
        let founder_addres=signer::address_of(founder);
        let realm=Realm::get_realm_by_address(realm_address);
        let realm_authority_address=Realm::get_founder_address(realm_address);
        assert!(realm_authority_address==founder_addres,EINVALID_REALM_AUTHORITY);
        move_to(&realm,RealmMemberships{
            realms:table::new()
        });
        table::add(&mut borrow_global_mut<RealmMemberships>(realm_address).realms,founder_addres,MemberRecord{
            realm_address,
            status:0,
            user_address:founder_addres,
            role:utf8(b"Founder")
        });
    }

    public entry fun invite_member(inviter:&signer,member_address:address,realm_address:address,role:String) acquires RealmMemberships{
        let signer_address=signer::address_of(inviter);
        let member_datas=borrow_global_mut<RealmMemberships>(realm_address);
        let member_data=table::borrow_mut(&mut member_datas.realms,signer_address);

         assert!(Realm::is_valid_role_for_action(member_data.role,ADD_MEMBER_ACTION,&realm_address),ENOT_VALID_ACTION_FOR_ROLE);

        table::add(&mut member_datas.realms,member_address,MemberRecord{
            role,
            status:0,
            realm_address,
            user_address:member_address
        });
    }

    public entry fun accept_or_reject_membership(invited_member:&signer,realm_address:address,status:u8) acquires RealmMemberships{
        let realm_invitation=borrow_global_mut<RealmMemberships>(realm_address);
        let member_address=signer::address_of(invited_member);
        let invitation=table::borrow_mut(&mut realm_invitation.realms,member_address);
        assert!(invitation.status==INVITED,EINVALID_INVITATION_STATUS);
        if(status==ACCEPTED){
            invitation.status=status;
            move_to(invited_member,MemberRecord{
                realm_address,
                user_address:member_address,
                status:1,
                role:invitation.role
            });
        }else{
            table::remove(&mut realm_invitation.realms,member_address);
        }

    }

    public entry fun delete_invitation(realm_authority:signer,member_address:address,realm_address:address)acquires RealmMemberships{
        let member_data=get_member_data_role(signer::address_of(&realm_authority),realm_address);
        assert!(Realm::is_valid_role_for_action(member_data,DECLINE_MEMBER_ACTION,&realm_address),ENOT_VALID_ACTION_FOR_ROLE);
        let member_datas=borrow_global_mut<RealmMemberships>(realm_address);
        table::remove(&mut member_datas.realms,member_address);

    }

    fun get_member_data_role(member_address:address,realm_address:address):String acquires RealmMemberships{
        let member_datas=borrow_global<RealmMemberships>(realm_address);
        table::borrow(&member_datas.realms,member_address).role
    }

    #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15)]
    public fun test_add_founder(creator:signer,account_creator:&signer,resource_account:signer,realm_account:&signer) acquires RealmMemberships{
        Realm::test_create_realm(creator,account_creator,resource_account,realm_account);
        let realm_address=Realm::get_realm_address_by_name(utf8(b"Genesis Realm"));
        let founder_address=signer::address_of(account_creator);
        add_founder_role(account_creator,realm_address);
        let member_role=get_member_data_role(founder_address,realm_address);
        assert!(member_role==utf8(b"Founder"),0);
    }

    #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15,member_to_invite=@0x16)]
    public fun test_add_member(creator:signer,account_creator:&signer,resource_account:signer,realm_account:&signer,member_to_invite:&signer)acquires RealmMemberships{
        test_add_founder(creator,account_creator,resource_account,realm_account);
        let member_address=signer::address_of(member_to_invite);
        let realm_address=Realm::get_realm_address_by_name(utf8(b"Genesis Realm"));
        invite_member(account_creator,member_address,realm_address,utf8(b"Member"));
        let added_invitation=borrow_global<RealmMemberships>(realm_address);
        let invited_member_data=table::borrow(&added_invitation.realms,member_address);
        assert!(invited_member_data.user_address==member_address,1);
        assert!(invited_member_data.role==utf8(b"Member"),1);
        assert!(invited_member_data.status==0,1);
        assert!(invited_member_data.realm_address==realm_address,1);
    }

    #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15,member_to_invite=@0x16)]
    public fun test_accept_membership(creator:signer,account_creator:signer,resource_account:signer,realm_account:signer,member_to_invite:signer)acquires RealmMemberships,MemberRecord{
        test_add_member(creator,&account_creator,resource_account,&realm_account,&member_to_invite);
        let realm_address=Realm::get_realm_address_by_name(utf8(b"Genesis Realm"));
        let member_address=signer::address_of(&member_to_invite);
        accept_or_reject_membership(&member_to_invite,realm_address,1);
        let member_datas=borrow_global<RealmMemberships>(realm_address);
        let member_record=table::borrow(&member_datas.realms,member_address);
        assert!(member_record.role==utf8(b"Member"),1);
        assert!(member_record.status==1,1);
        let membersip=borrow_global<MemberRecord>(member_address);
        assert!(membersip.user_address==member_address,1);
        assert!(membersip.role==utf8(b"Member"),1);
    }

    // #[test(creator=@0xcaffe,account_creator=@0x99,resource_account=@0x14,realm_account=@0x15,member_to_invite=@0x16)]
    public fun test_delete_invitation(creator:signer,account_creator:signer,resource_account:signer,realm_account:signer,member_to_invite:signer)acquires RealmMemberships{
        test_add_member(creator,&account_creator,resource_account,&realm_account,&member_to_invite);
        let realm_address=Realm::get_realm_address_by_name(utf8(b"Genesis Realm"));
        let member_address=signer::address_of(&member_to_invite);
        delete_invitation(account_creator,member_address,realm_address);
    }


}
```
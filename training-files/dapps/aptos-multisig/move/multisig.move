module multisig::acl_based_mb {
    use std::signer;    
    use std::vector;
    use std::error;
    use aptos_std::type_info;
    use aptos_framework::coin::{Self};
    use aptos_framework::account;


    const INVALID_SIGNER: u64 = 0;
    const OWNER_MISMATCHED: u64 = 1;
    const AlreadySigned:u64 =2;
    const NotEnoughSigners:u64 =3;
    const COIN_MISMATCHED:u64 =4;
    const ALREADY_EXECUTED:u64 =5;

    struct Multisig has key,store {
        owners: vector<address>,
        threshold: u64,
    }
    struct ResourceInfo has key {
        source: address,
        resource_cap: account::SignerCapability
    }
    struct Transaction has key {
        did_execute: bool,
        coin_address: address,
        amount: u64,
        signers: vector<bool>,
        multisig: address,
        receiver: address,
        resource_cap: account::SignerCapability
    }
    public entry fun create_multisig(
        account: &signer,
        owners: vector<address>,
        threshold: u64,
        seeds: vector<u8>
    ){
        let (_multisig, multisig_cap) = account::create_resource_account(account, seeds);
        let multisig_signer_from_cap = account::create_signer_with_capability(&multisig_cap);
        let multisig_data = Multisig{
                    owners,
                    threshold
        };
        move_to<ResourceInfo>(&multisig_signer_from_cap, ResourceInfo{resource_cap: multisig_cap, source: signer::address_of(account)});
        move_to(&multisig_signer_from_cap, multisig_data);
    }
    public entry fun create_transaction<CoinType>(
        account: &signer,
        receiver: address,
        amount: u64,
        seeds: vector<u8>,
        multisig: address
    )acquires Multisig,ResourceInfo{
        let account_addr = signer::address_of(account);
        let (_transaction, transaction_cap) = account::create_resource_account(account, seeds);
        let transaction_signer_from_cap = account::create_signer_with_capability(&transaction_cap);
        let multisig_data = borrow_global_mut<Multisig>(multisig);
        let owners_length = vector::length(&multisig_data.owners);
        let signers = vector::empty<bool>();
        let (is_owner,index) = vector::index_of(&multisig_data.owners,&account_addr);
        assert!(is_owner==true,OWNER_MISMATCHED);
        let i = 0;
        while (i < owners_length) {
            if (i==index){
                vector::push_back(&mut signers, true);
            }
            else{
                vector::push_back(&mut signers, false);
            };
            i = i + 1;
        };
        let multisig_vault_data = borrow_global<ResourceInfo>(multisig);
        let multisig_signer_from_cap = account::create_signer_with_capability(&multisig_vault_data.resource_cap);
        coin::register<CoinType>(&multisig_signer_from_cap);
        let coin_address=coin_address<CoinType>();
        move_to<Transaction>(&transaction_signer_from_cap, Transaction{did_execute:false,coin_address,receiver,amount,signers,multisig,resource_cap:transaction_cap});
    }
    public entry fun approve_transaction(
        account: &signer,
        multisig: address,
        transaction: address,
    )acquires Multisig,Transaction{
        let account_addr = signer::address_of(account);
        let multisig_data = borrow_global_mut<Multisig>(multisig);
        let transaction_data = borrow_global_mut<Transaction>(transaction);
        let owners = multisig_data.owners;
        let signers = transaction_data.signers;
        let (is_owner,index) = vector::index_of(&owners,&account_addr);
        assert!(is_owner==true,OWNER_MISMATCHED);
        assert!(*vector::borrow(&signers,index)==false,AlreadySigned);
        let owners_length = vector::length(&multisig_data.owners);
        let i = 0;
        while (i < owners_length) {
            if (i==index){
                vector::push_back(&mut signers, true);
            };
            i = i + 1;
        };
    }
    public entry fun execute_transaction<CoinType>(
        account: &signer,
        multisig: address,
        transaction: address,
    )acquires Multisig,Transaction,ResourceInfo{
        let account_addr = signer::address_of(account);
        let multisig_data = borrow_global_mut<Multisig>(multisig);
        let transaction_data = borrow_global_mut<Transaction>(transaction);
        assert!(transaction_data.did_execute==false,ALREADY_EXECUTED);
        let owners = multisig_data.owners;
        let signers = transaction_data.signers;
        let (is_owner,_index) = vector::index_of(&owners,&account_addr);
        assert!(is_owner==true,OWNER_MISMATCHED);
        let owners_length = vector::length(&multisig_data.owners);
        let i = 0;
        let total_signers = 0;
        while (i < owners_length) {
            let (havs_signed,_index) = vector::index_of(&signers,&true);
            if (havs_signed==true){
                total_signers=total_signers+1
            };
            i = i + 1;
        };
        if(total_signers >= multisig_data.threshold){
            let multisig_vault_data = borrow_global<ResourceInfo>(multisig);
            let multisig_signer_from_cap = account::create_signer_with_capability(&multisig_vault_data.resource_cap);
            let coin_address=coin_address<CoinType>();
            assert!(coin_address==transaction_data.coin_address,COIN_MISMATCHED);
            coin::transfer<CoinType>(&multisig_signer_from_cap, transaction_data.receiver, transaction_data.amount);
            transaction_data.did_execute =true
        }
        else{
                abort error::invalid_argument(NotEnoughSigners)
        }
    }
    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    #[test_only] 
    struct MokshyaMoney { }
    #[test(ownerA = @0xa11ce, ownerB = @0xb0b,receiver = @0xc0b,multisig_vault=@multisig)]
    fun create_multisig_test(
        ownerA: signer,
        ownerB: signer,
        receiver: signer,
        multisig_vault: signer
    )acquires Multisig,Transaction,ResourceInfo{
        let ownerA_addr = signer::address_of(&ownerA);
        let ownerB_addr = signer::address_of(&ownerB);
        let receiver_addr = signer::address_of(&receiver);
        // let multisig_vault_addr = signer::address_of(&multisig_vault);
        aptos_framework::account::create_account_for_test(ownerA_addr);
        aptos_framework::account::create_account_for_test(ownerB_addr);
        aptos_framework::account::create_account_for_test(receiver_addr);
        aptos_framework::managed_coin::initialize<MokshyaMoney>(
            &multisig_vault,
            b"Mokshya Money",
            b"MOK",
            8,
            true
        );
        let owners = vector<address>[ownerA_addr,ownerB_addr];
        let threshold=2;

        create_multisig(&ownerA,owners,threshold,b"1bc");

        let multisig_data = account::create_resource_address(&ownerA_addr, b"1bc");
        let amount= 10;

        create_transaction<MokshyaMoney>(&ownerA,receiver_addr,amount,b"1bd",multisig_data);

        let transaction_data = account::create_resource_address(&ownerA_addr, b"1bd");

        approve_transaction(&ownerB,multisig_data,transaction_data);

        aptos_framework::managed_coin::mint<MokshyaMoney>(&multisig_vault,multisig_data,100);
        aptos_framework::managed_coin::register<MokshyaMoney>(&receiver);
        
        execute_transaction<MokshyaMoney>(&ownerB,multisig_data,transaction_data);
    }
}
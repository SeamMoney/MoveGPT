module mokshya::merkle_distributor{
    use std::signer;
    use aptos_std::aptos_hash;
    use mokshya::merkle_proof::{Self};
    use aptos_framework::coin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use aptos_std::type_info;
    use aptos_std::table::{Self, Table};
    use std::bcs;
    use std::vector;

    struct DistributionDetails has key {
        merkle_root: vector<u8>,
        coin_type:address, 
        distribution_event: EventHandle<CreateDistributionEvent>,
    }
    struct ClaimDistribution has key {
        claimers: Table<address,u64>,
        paused: bool,
        claim_event: EventHandle<ClaimDistributionEvent>,
    }
    struct ResourceInfo has key {
            source: address,
            resource_cap: account::SignerCapability
    }
    struct CreateDistributionEvent has drop, store {
        distributor: address,
        coin_type: address,
        merkle_root: vector<u8>
    }
    struct ClaimDistributionEvent has drop, store {
        claimer: address,
        amount: u64,
        coin_type: address,
    }
    const COINTYPE_MISMATCH:u64=0;
    const DISTRIBUTION_EXISTS:u64=1;
    const INVALID_PROOF:u64=2;
    const AlREADY_CLAIMED:u64=2;
    const INVALID_SIGNER:u64=3;
    const PAUSED:u64=4;

    public entry fun init_distribution<CoinType>(distributor: &signer,merkle_root: vector<u8>,seeds: vector<u8>)acquires DistributionDetails {
        let (resource, resource_cap) = account::create_resource_account(distributor, seeds);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);
        let resource_address = signer::address_of(&resource);
        assert!(!exists<DistributionDetails>(resource_address),DISTRIBUTION_EXISTS);
        move_to<ResourceInfo>(&resource_signer_from_cap, ResourceInfo{resource_cap: resource_cap, source: signer::address_of(distributor)});
        move_to<DistributionDetails>(&resource_signer_from_cap, DistributionDetails{
            merkle_root,
            coin_type:coin_address<CoinType>(), 
            distribution_event: account::new_event_handle<CreateDistributionEvent>(&resource_signer_from_cap),
        });
        move_to<ClaimDistribution>(&resource_signer_from_cap, ClaimDistribution{
            claimers: table::new<address,u64>(),
            paused: false,
            claim_event: account::new_event_handle<ClaimDistributionEvent>(&resource_signer_from_cap),
        });
        managed_coin::register<CoinType>(&resource_signer_from_cap); 
        let records = borrow_global_mut<DistributionDetails>(resource_address);
        event::emit_event(&mut records.distribution_event,CreateDistributionEvent {
                distributor:signer::address_of(distributor),
                coin_type:coin_address<CoinType>(),
                merkle_root
            },
        );
    }
    public entry fun claim_distribution<CoinType>(claimer: &signer,resource_account:address,proof: vector<vector<u8>>,amount:u64)acquires DistributionDetails,ResourceInfo,ClaimDistribution {
        let claimer_addr = signer::address_of(claimer);
        let resource_data = borrow_global<ResourceInfo>(resource_account);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        let distributor_details = borrow_global<DistributionDetails>(resource_account);
        let claim_details = borrow_global_mut<ClaimDistribution>(resource_account);
        assert!(!table::contains(&claim_details.claimers, claimer_addr),AlREADY_CLAIMED);
        assert!(claim_details.paused == false, PAUSED);
        let leafvec = bcs::to_bytes(&claimer_addr);
        vector::append(&mut leafvec,bcs::to_bytes(&amount));
        assert!(merkle_proof::verify(proof,distributor_details.merkle_root,aptos_hash::keccak256(leafvec)),INVALID_PROOF);
        assert!(coin_address<CoinType>()==distributor_details.coin_type,COINTYPE_MISMATCH);
        if (!coin::is_account_registered<CoinType>(claimer_addr)){
            managed_coin::register<CoinType>(claimer); 
        };
        coin::transfer<CoinType>(&resource_signer_from_cap,claimer_addr,amount);
        table::add(&mut claim_details.claimers,claimer_addr,amount);
        event::emit_event(&mut claim_details.claim_event,ClaimDistributionEvent {
                claimer: claimer_addr,
                amount: amount,
                coin_type: coin_address<CoinType>(),
            }
        );
    }
    public entry fun withdraw_funds<CoinType>(distributor: &signer,resource_account:address)acquires ResourceInfo {
        let resource_data = borrow_global<ResourceInfo>(resource_account);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        assert!(resource_data.source == signer::address_of(distributor), INVALID_SIGNER);
        coin::transfer<CoinType>(&resource_signer_from_cap,signer::address_of(distributor),coin::balance<CoinType>(signer::address_of(&resource_signer_from_cap)));
    }
    public entry fun update_root(distributor: &signer,resource_account:address,merkle_root:vector<u8>)acquires ResourceInfo,DistributionDetails {
        let resource_data = borrow_global<ResourceInfo>(resource_account);
        assert!(resource_data.source == signer::address_of(distributor), INVALID_SIGNER);
        let distribution_data = borrow_global_mut<DistributionDetails>(resource_account);
        distribution_data.merkle_root = merkle_root;
    }
    public entry fun pause_distribution(distributor: &signer,resource_account:address)acquires ResourceInfo,ClaimDistribution {
        let resource_data = borrow_global<ResourceInfo>(resource_account);
        assert!(resource_data.source == signer::address_of(distributor), INVALID_SIGNER);
        let claim_data = borrow_global_mut<ClaimDistribution>(resource_account);
        claim_data.paused = true;
    }
    public entry fun resume_distribution(distributor: &signer,resource_account:address)acquires ResourceInfo,ClaimDistribution {
        let resource_data = borrow_global<ResourceInfo>(resource_account);
        assert!(resource_data.source == signer::address_of(distributor), INVALID_SIGNER);
        let claim_data = borrow_global_mut<ClaimDistribution>(resource_account);
        claim_data.paused = false;
    }
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
    #[test_only] 
    public fun set_up_test(distributor:&signer,claimer:&signer,mokshya:&signer){
        let distributor_addr = signer::address_of(distributor);
        let claimer_addr = signer::address_of(claimer);
        aptos_framework::account::create_account_for_test(distributor_addr);
        aptos_framework::account::create_account_for_test(claimer_addr);
        aptos_framework::managed_coin::initialize<MokshyaMoney>(
            mokshya,
            b"Mokshya Money",
            b"MOK",
            10,
            true
        );
        aptos_framework::managed_coin::register<MokshyaMoney>(distributor);
        aptos_framework::managed_coin::mint<MokshyaMoney>(mokshya,distributor_addr,500000000000); 
    }
    struct MokshyaMoney { }
    #[test(distributor = @0xa11ce, claimer = @0xd4dee0beab2d53f2cc83e567171bd2820e49898130a22622b10ead383e90bd77,mokshya=@mokshya)]
    fun test_distribute(distributor: &signer,claimer: &signer, mokshya:&signer)acquires DistributionDetails,ResourceInfo,ClaimDistribution{
        let claimer_addr = signer::address_of(claimer);
        let add1=  x"d4dee0beab2d53f2cc83e567171bd2820e49898130a22622b10ead383e90bd77";
        let add2 = x"5f16f4c7f149ac4f9510d9cf8cf384038ad348b3bcdc01915f95de12df9d1b02";
        let amount:u64 = 500000000;
        vector::append(&mut add1,bcs::to_bytes(&amount));
        vector::append(&mut add2,bcs::to_bytes(&amount));
        let leaf1 = aptos_hash::keccak256(add1);
        let leaf2 = aptos_hash::keccak256(add2);
        let merkle_root = merkle_proof::find_root(leaf1,leaf2);
        set_up_test(distributor,claimer,mokshya);
        init_distribution<MokshyaMoney>(distributor,merkle_root,b"merkle_distributor");
        let resource_addr = account::create_resource_address(&signer::address_of(distributor), b"merkle_distributor");
        coin::transfer<MokshyaMoney>(distributor,resource_addr, 500000000);
        claim_distribution<MokshyaMoney>(claimer,resource_addr,vector[leaf2],500000000);
        assert!(coin::balance<MokshyaMoney>(claimer_addr) == 500000000, 1);
        pause_distribution(distributor,resource_addr);
        resume_distribution(distributor,resource_addr);
        withdraw_funds<MokshyaMoney>(distributor,resource_addr);
    }
}
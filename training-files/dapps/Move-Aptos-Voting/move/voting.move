module hakan::voting{
    use std::vector;
    use std::signer;
    use std::simple_map::{Self, SimpleMap};
    //use std::account;

    struct CandidateList has key{
        candidate_list: SimpleMap<address, u64>,
        candidate_addresses : vector<address>,
        winner: address
    }

    struct VotersList has key{
        //TO kepp record who votes for who
        voters: SimpleMap<address, address>
    }

    public entry fun init(owner: &signer, candidate_address: address) acquires CandidateList{

        let addr = signer::address_of(owner);
        assert_is_owner(owner);

        let candidate = CandidateList{
            candidate_list: simple_map::new(),
            candidate_addresses: vector::empty<address>(),
            winner: @0x0
        };

        let voting = VotersList{
            voters: simple_map::new(),
        };

        move_to(owner, candidate);
        move_to(owner, voting);

        let c_store = borrow_global_mut<CandidateList>(addr);
        simple_map::add(&mut c_store.candidate_list, candidate_address, 0);
        vector::push_back(&mut c_store.candidate_addresses, candidate_address);

    }

    public fun add_candidate(owner: &signer, c_address: address) acquires CandidateList{
        let addr = signer::address_of(owner);
        assert_is_owner(owner);

        let c_store = borrow_global_mut<CandidateList>(addr);
        //assert_not_contains_candidate
        assert_not_contains_candidate(&c_store.candidate_list, c_address);

        simple_map::add(&mut c_store.candidate_list, c_address, 0);
        vector::push_back(&mut c_store.candidate_addresses, c_address);

    }

    public fun vote(voter: &signer, c_addr: address, store_addr: address) acquires CandidateList, VotersList{
        let addr = signer::address_of(voter);
        //assert_is_init
        assert_is_initialized(addr);

        let c_store = borrow_global_mut<CandidateList>(store_addr);
        let v_store = borrow_global_mut<VotersList>(store_addr);

        assert_contains_candidate(&c_store.candidate_list, c_addr);
        assert!(c_store.winner == @0x0, 1);

        let vote = simple_map::borrow_mut(&mut c_store.candidate_list, &c_addr);

        *vote = *vote + 1;

        simple_map::add(&mut v_store.voters, addr ,c_addr);
    }


    //
    //-------------ASSERTS-------------
    //
    fun assert_is_initialized(addr: address){
        assert!(exists<CandidateList>(addr), 0);
        assert!(exists<VotersList>(addr), 0);
    }

    fun assert_is_owner(acc:&signer){
        assert!(signer::address_of(acc) == @hakan, 0);
    }

    fun assert_not_contains_candidate(c_list: &SimpleMap<address, u64>, addr: address){
        assert!(!simple_map::contains_key(c_list, &addr), 0);
    }

    fun assert_contains_candidate(c_list: &SimpleMap<address, u64>, addr: address){
        assert!(simple_map::contains_key(c_list, &addr), 0);
    }

}
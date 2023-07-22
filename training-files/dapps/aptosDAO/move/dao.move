module 0x5665ff6558066d4243686b6be23E57DCE118CE4006E062882AE35448D3CF320A::dao { 
    
    use std::signer;
    use std::vector;
    use aptos_token::token::{Self, TokenId};
    use aptos_framework::bls12381::{verify_normal_signature, signature_from_bytes, public_key_from_bytes};
    use std::string::{Self, String};
    // use aptos_framework::resource_account::{Self};
    
    // use AptosFramework::Token::{Self};
    use std::option::{Self};
    use std::simple_map::{Self, SimpleMap};
    use aptos_framework::account::{Self, SignerCapability, create_signer_with_capability};
    use std::bcs;
    use aptos_std::debug;


    //Errors

    const ENO_VOTING: u64 = 0;
    const EINC_SIG: u64 = 1;
    const EFULL_DAO: u64 = 2;
    const ETOKEN_EXIST: u64 = 3;

    const SIGNER_ADDRESS: address = @0x5665ff6558066d4243686b6be23E57DCE118CE4006E062882AE35448D3CF320A;



    struct DAOInfo has key{
        dao_owner: address,
        name: String,
        description: String,
        uri: String,
        max_participant: u64,
        votings: SimpleMap<address, Voting>,
        signer_cap: SignerCapability
    }
    
    struct NFTProperty has key{
      rarity: u8
    }

    struct Voting has key, store {
        voting_owner: address,
        positive_vote: vector<Vote>,
        negative_vote: vector<Vote>,
        status: bool 
    }

    struct Vote has store, copy, drop{
        voter: address,
        count_vote: u64
    }


    public entry fun create_dao(dao_owner: &signer, uri: String, name: String, description: String, count: u64): address{
             
        
                
        let (resource_signer, signer_cap) = account::create_resource_account(dao_owner, b"INIT_DAO");

        token::create_collection(&resource_signer, name, description, uri, count, vector[false, false, false]);
        
        let dao_address = signer::address_of(&resource_signer);

        move_to<DAOInfo>(&resource_signer, DAOInfo {
          dao_owner: signer::address_of(dao_owner),
          name,
          description,
          uri,
          max_participant: count,
          votings: simple_map::create(),
          signer_cap
          }
            );

          dao_address
          
    }
    
    public entry fun join_dao(joiner: &signer, dao_address: address, signature: vector<u8>, rarity: u8) acquires DAOInfo{

        let dao_info = borrow_global_mut<DAOInfo>(dao_address);
        let joiner_addr = signer::address_of(joiner);

        let message: vector<u8> = get_address_bytes(joiner_addr);

        vector::push_back(&mut message, rarity);
        
        debug::print<vector<u8>>(&message);

        let isVerified = verify_normal_signature(
            &signature_from_bytes(signature),
            &option::extract(&mut public_key_from_bytes(get_address_bytes(SIGNER_ADDRESS))),
            message,
        );

        assert!(isVerified, EINC_SIG);
        
        
        let default_keys = vector<String>[string::utf8(b"rarity")];
        let default_vals = vector<vector<u8>>[vector[rarity]];
        let default_types = vector<String>[string::utf8(b"u8")];
        let mutate_setting = vector<bool>[false, false, false, false, true];

        let dao_signer: signer = create_signer_with_capability(&dao_info.signer_cap);

        let token_id: TokenId = token::create_token_id_raw(signer::address_of(&dao_signer), dao_info.name, dao_info.name, 0);

        assert!(token::balance_of(joiner_addr, token_id) == 0, ETOKEN_EXIST);

        token::create_token_script(
            &dao_signer,
            dao_info.name,
            dao_info.name,
            dao_info.description,
            1u64,
            dao_info.max_participant,
            dao_info.uri,
            signer::address_of(&dao_signer),
            100,
            0,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );

        // let token_id: TokenId = token::create_token_id_raw(signer::address_of(&dao_signer), dao_info.name, dao_info.name, 0);

        move_to<NFTProperty>(joiner, NFTProperty {rarity: *vector::borrow(&vector[rarity], 0)});
    }

    // fun _concatParams(sender: address, rarity: vector<u8>): vector<u8>{
    //     let addr_bytes = bcs::to_bytes(&sender);
    //     let rarity_copy = copy rarity;
    //     vector::push_back(&mut rarity_copy, addr_bytes)
    // }

    public entry fun init_voting(voting_owner: &signer) {

        let voting_owner_addr = signer::address_of(voting_owner);
        let positive_vote = vector::empty<Vote>();
        let negative_vote = vector::empty<Vote>(); 
		    move_to<Voting>(voting_owner, Voting {voting_owner: voting_owner_addr, positive_vote, negative_vote, status: true});

	}

    public entry fun vote(voter: &signer, voting_owner: address, vote_type:bool) acquires Voting, NFTProperty{
        let voter_addr = signer::address_of(voter);

        let voting = borrow_global_mut<Voting>(voting_owner);

        assert!(voting.status, ENO_VOTING);

        let property = borrow_global<NFTProperty>(voter_addr);

        let vote = Vote {voter: voter_addr, count_vote: (property.rarity as u64)};

        if(vote_type){
            vector::push_back<Vote>(&mut voting.positive_vote, vote);
        }else{
            vector::push_back<Vote>(&mut voting.negative_vote, vote);
        }
       
    }

    public entry fun close_voting(voting_owner: &signer) acquires Voting{
        let voting_owner_addr = signer::address_of(voting_owner);

        let voting = borrow_global_mut<Voting>(voting_owner_addr);

        voting.status = false;
    }

    public fun get_voting_info(voting_owner: address):(bool, vector<Vote>, vector<Vote>, address) acquires Voting{
        let voting = borrow_global<Voting>(voting_owner);
        return (voting.status, voting.positive_vote, voting.negative_vote, voting.voting_owner)
    }

    public fun get_dao_info(dao_owner: address):(String, String, String, u64) acquires DAOInfo{
      let dao_info = borrow_global<DAOInfo>(dao_owner);
      return (dao_info.name, dao_info.description, dao_info.uri, dao_info.max_participant)
    }

    // public entry fun get_voting_info(dao_owner: address):(String, String, String, u64) acquires DAOInfo{
    //   let dao_info = borrow_global<DAOInfo>(dao_owner);
    //   return (dao_info.name, dao_info.description, dao_info.uri, dao_info.max_participant)
    // }

    fun get_address_bytes(account: address): vector<u8>{
       
        bcs::to_bytes(&account)

    }
    
    #[test(testAcc=@0x5665ff6558066d4243686b6be23e57dce118ce4006e062882ae35448d3cf320a)]
    public entry fun sender_can_create_dao(testAcc: signer)acquires DAOInfo{

      let account_address = signer::address_of(&testAcc);
      
      let test_acc = account::create_account_for_test(account_address);

      let dao_address = create_dao(&test_acc, string::utf8(b"asas"), string::utf8(b"asda"), string::utf8(b"asdas"), 10u64);  

      let dao_info = borrow_global<DAOInfo>(dao_address);
      
      debug::print<address>(&dao_address);
      debug::print<address>(&dao_info.dao_owner);


      assert!(dao_info.dao_owner == account_address, 0);
      assert!(exists<DAOInfo>(dao_address), 1);
       

    }
    
    #[test(voter = @0xe8a48efd830360df0236679d4e7cf9a35c3042e6e98a9fae92a87e55ba1e3ade, contract_owner = @0x5665ff6558066d4243686b6be23e57dce118ce4006e062882ae35448d3cf320a)]
    public entry fun sender_can_join_dao(voter: signer, contract_owner: signer)acquires DAOInfo{

      let voter_signer = account::create_account_for_test(signer::address_of(&voter));
      let contract_owner_signer = account::create_account_for_test(signer::address_of(&contract_owner));

      let dao_address = create_dao(&contract_owner_signer, string::utf8(b"asas"), string::utf8(b"asda"), string::utf8(b"asdas"), 10u64);

      join_dao(&voter_signer, dao_address, vector[12, 23, 13, 43], 3u8);

    }

    // #[test(venue_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    // public entry fun sender_can_vote(voting_owner: signer, voter: signer, type: bool) acquires Voting{

    //     let voting_owner_addr = signer::address_of(&voting_owner);

    //     get_voting_info(voting_owner_addr);

    //     vote(&voter, voting_owner_addr, type, 4);


    //     get_voting_info(voting_owner_addr);

    //     close_voting(&voting_owner);

    // }

    // #[test(venue_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    // public entry fun sender_can_close_voting(voting_owner: signer, voter: signer) acquires Voting{

    //     close_voting(&voting_owner);

    // }

    // #[test(venue_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    // public entry fun sender_can_clsdose_voting(voting_owner: signer, voter: signer) acquires Voting{

    //     close_voting(&voting_owner);

    // }

    // #[test(voting_owner = @0x3, buyer = @0x2, faucet = @0x1)]
    // public entry fun sender_can_init_dao(voting_owner: signer){

    //     init_dao(&voting_owner, vector[67,21], vector[67,21], vector[67,21]);
    //     //borrow_global<Token::Collections>(Signer::address_of(&voting_owner))
    // }

    // #[test(account=@0x5665ff6558066d4243686b6be23e57dce118ce4006e062882ae35448d3cf320a)]
    // public entry fun get_signer_bytes_test(account: signer){
        
          
    //   assert!(get_signer_bytes(signer::address_of(&account)) == vector[32, 86, 101, 255, 101, 88, 6, 109, 66, 67, 104, 107, 107, 226, 62, 87, 220, 225, 24, 206, 64, 6, 224, 98, 136, 42, 227, 84, 72, 211, 207, 50, 10], 0);
      

    // }
}
module rarewave::whitelist{
    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_token::token::{Self};
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::timestamp;
    use aptos_std::event::{Self, EventHandle};
    use aptos_framework::timestamp::now_seconds;

    const INVALID_SIGNER: u64 = 0;
    const INVALID_AMOUNT: u64 = 1;
    const CANNOT_ZERO: u64 = 2;
    const WHITELIST_EXIST: u64 = 3;
    const WHITELIST_NOT_EXIST: u64 = 4;
    const WHIELIST_PAUSED: u64 = 5;
    const NOT_WINNER: u64 = 6;
    const NOT_SAME_WHITELIST_PHASE: u64 = 7;
    const ALREADY_CLAIMED: u64 = 8;
    const INVALID_PHASE: u64 = 9;
    const INVALID_CLAIM_APTOS_BACK: u64 = 10;
    const INVALID_LIST_WINNER: u64 = 11;
    const WHIELIST_STILL_ACTIVE: u64 = 12;
    const WHIELIST_NOT_PAUSED: u64 = 13;

    struct WhitelistPhase has key {
        current_phase: u64,
        whitelist: vector<Whitelist>,
    }

    struct Whitelist has store, copy {
        phase: u64,
        royalty_payee_address: address,
        paused: bool,
        price: u64,
        end_time: u64,
        whitelist: vector<Winner>,
    }

    struct Winner has store, drop, copy{
        resource: address,
        num_nft: u64,
        claimed: bool,
    }   

    struct WhitelistEnvelope has key {
        phase: u64,
        total_amount: u64
    }

    struct RareWave has key {
        collection_name: String,
        collection_description: String,
        baseuri: String,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        minted: u64,
        token_mutate_setting:vector<bool>,
    }

    struct ResourceInfo has key {
      source: address,
      resource_cap: account::SignerCapability
    }

    struct WhitelistEvent has key {
        claim_nft_event: EventHandle<ClaimNftEvent>,
        join_whitelist_event: EventHandle<JoinWhitelistEvent>,
    }

    struct ClaimNftEvent has store, drop {
        claimer: address,
        token_id: token::TokenDataId,
        timestamp: u64,
    }

    struct JoinWhitelistEvent has store, drop {
        joiner: address,
        timestamp: u64,
        phase: u64,
    }

    public entry fun init_rarewave(
        account:&signer,
        collection_name: String,
        collection_description: String,
        baseuri: String,
    )  {
        let royalty_payee_address = signer::address_of(account);
        let royalty_points_denominator: u64 = 5;
        let royalty_points_numerator: u64 = 100;
        let token_mutate_setting=vector<bool>[false, false, false, false, true];
        let collection_mutate_setting=vector<bool>[false, false, false];

        let (_resource, resource_cap) = account::create_resource_account(account, vector::empty<u8>());
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_cap);

        move_to<ResourceInfo>(
            &resource_signer_from_cap,
            ResourceInfo{
                resource_cap,
                source: signer::address_of(account)
            }
        );

        coin::register<0x1::aptos_coin::AptosCoin>(&resource_signer_from_cap);

        let whitelist = vector::empty<Whitelist>();

        // create whitelist phase wrapper
        move_to<WhitelistPhase>(&resource_signer_from_cap, WhitelistPhase{
            current_phase: 0,
            whitelist
        });

        // create rare wave resource
        move_to<RareWave>(&resource_signer_from_cap, RareWave{
            collection_name,
            collection_description,
            baseuri,
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            minted:0,
            token_mutate_setting
        });

        // create collection
        token::create_collection(
            &resource_signer_from_cap, 
            collection_name, 
            collection_description, 
            baseuri, 
            0,
            collection_mutate_setting
        );

        move_to(&resource_signer_from_cap, WhitelistEvent{
            claim_nft_event: account::new_event_handle<ClaimNftEvent>(&resource_signer_from_cap),
            join_whitelist_event: account::new_event_handle<JoinWhitelistEvent>(&resource_signer_from_cap)
        });
    }

    // get whitelist info
    public entry fun get_whitelist_info(
        resource_addr: address,
        phase: u64
    ) : (bool, u64, bool, u64, u64, vector<Winner>) acquires WhitelistPhase {
        // get whitelist pharse from resource address
        let whitelist_pharse = borrow_global_mut<WhitelistPhase>(resource_addr);
        let i = 0;
        let len = vector::length<Whitelist>(&whitelist_pharse.whitelist);

        // loop over whitelist and get the whitelist info by pharse
        while (i < len) {
            let whitelist = vector::borrow<Whitelist>(&whitelist_pharse.whitelist, i);
            if (whitelist.phase == phase) {
                return (
                    true,
                    whitelist.phase,
                    whitelist.paused,
                    whitelist.price,
                    whitelist.end_time,
                    whitelist.whitelist
                )
            };
            i = i + 1;
        };

        return (false, 0, false, 0, 0, vector::empty<Winner>())
    }

    // create whitelist
    public entry fun create_whitelist(
        account: &signer,
        resource_addr:address,
        royalty_payee_address: address,
        paused: bool,
        price: u64,
        end_time: u64,
    ) acquires ResourceInfo, WhitelistPhase {
        // get signer address
        let account_addr = signer::address_of(account);

        // check signer is admin
        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);

        // get whitelist pharse
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);
        whitelist_phase.current_phase = whitelist_phase.current_phase + 1;

        let whitelist = vector::empty<Winner>();

        // push back new whitelist to whitelist wrapper
        vector::push_back(&mut whitelist_phase.whitelist, Whitelist {
            phase: whitelist_phase.current_phase,
            royalty_payee_address,
            paused,
            price,
            end_time,
            whitelist,
        });
    }

    public entry fun join_whitelist(
        joiner: &signer,
        resource_addr: address,
    ) acquires WhitelistPhase, WhitelistEnvelope, ResourceInfo, WhitelistEvent {
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);
        let whitelist = vector::borrow_mut<Whitelist>(&mut whitelist_phase.whitelist, whitelist_phase.current_phase - 1);
        assert!(whitelist.paused == false, WHIELIST_PAUSED);
        let now = timestamp::now_seconds();
        assert!(now < whitelist.end_time, WHIELIST_PAUSED);

        let joiner_addr = signer::address_of(joiner);

        // create whitelist envelope for user when user join whitelist in first time
        if (!exists<WhitelistEnvelope>(joiner_addr)) {
            let whitelist_envelope = WhitelistEnvelope {
                phase: whitelist_phase.current_phase,
                total_amount: 1
            };
            move_to(joiner, whitelist_envelope);
        } else {
            let whitelist_envelope = borrow_global_mut<WhitelistEnvelope>(joiner_addr);
            if (whitelist_envelope.phase == whitelist_phase.current_phase) {
                whitelist_envelope.total_amount = whitelist_envelope.total_amount + 1;
            } else {
                whitelist_envelope.phase = whitelist_phase.current_phase;
                whitelist_envelope.total_amount = 1;
            };
        };

        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);

        if(!coin::is_account_registered<0x1::aptos_coin::AptosCoin>(signer::address_of(&resource_signer_from_cap))){
            coin::register<0x1::aptos_coin::AptosCoin>(&resource_signer_from_cap);
        };

        coin::transfer<0x1::aptos_coin::AptosCoin>(joiner, resource_addr, whitelist.price);

        let event_handler = borrow_global_mut<WhitelistEvent>(resource_addr);
        event::emit_event(&mut event_handler.join_whitelist_event, JoinWhitelistEvent{
            joiner: joiner_addr,
            phase: whitelist_phase.current_phase,
            timestamp: now_seconds()
        });
    }

    public entry fun claim_nft(
        joiner: &signer,
        resource_addr: address,
    ) acquires WhitelistPhase, ResourceInfo, RareWave, WhitelistEvent {
        let joiner_addr = signer::address_of(joiner);

        // check joiner is winner in whitelist
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);

        // get winner whitelist resource
        let whitelist = vector::borrow_mut<Whitelist>(&mut whitelist_phase.whitelist, whitelist_phase.current_phase - 1);
        let i = 0;
        let len = vector::length<Winner>(&whitelist.whitelist);
        let event_handler = borrow_global_mut<WhitelistEvent>(resource_addr);
        while (i < len) {
            let winner = vector::borrow_mut<Winner>(&mut whitelist.whitelist, i);
            if (winner.resource == joiner_addr) {
                assert!(winner.claimed == false, ALREADY_CLAIMED);

                winner.claimed = true;

                // get resource signer
                let resource_data = borrow_global<ResourceInfo>(resource_addr);
                let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);

                // get collection data
                let collection_data = borrow_global_mut<RareWave>(resource_addr);
                let baseuri = collection_data.baseuri;
                let properties = vector::empty<String>();

                let j = 0;
                while (j < winner.num_nft) {
                    let owl = collection_data.minted;
                    let token_name = collection_data.collection_name;
                    string::append(&mut token_name,string::utf8(b" #"));
                    string::append(&mut token_name,num_str(owl));
                    string::append(&mut baseuri,string::utf8(b".json"));

                    token::create_token_script(
                        &resource_signer_from_cap,
                        collection_data.collection_name,
                        token_name,
                        collection_data.collection_description,
                        1,
                        0,
                        baseuri,
                        collection_data.royalty_payee_address,
                        collection_data.royalty_points_denominator,
                        collection_data.royalty_points_numerator,
                        collection_data.token_mutate_setting,
                        properties,
                        vector<vector<u8>>[],
                        properties
                    );

                    let token_data_id = token::create_token_data_id(resource_addr,collection_data.collection_name,token_name);
                    token::opt_in_direct_transfer(joiner,true);

                    token::mint_token_to(&resource_signer_from_cap, joiner_addr , token_data_id,1);

                    // update minted nft collection
                    collection_data.minted = collection_data.minted + 1;

                    // emit event
                    event::emit_event(&mut event_handler.claim_nft_event, ClaimNftEvent{
                        claimer: joiner_addr,
                        token_id: token_data_id,
                        timestamp: now_seconds(),
                    });
                    j = j + 1;
                };

                return
            };
            i = i + 1;
        };
    }

    public entry fun claim_back_aptos(joiner: &signer, resource_addr: address) acquires WhitelistPhase, WhitelistEnvelope, ResourceInfo {
        let joiner_addr = signer::address_of(joiner);

        // check joiner is winner in whitelist
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);

        // check whitelist is paused
        let whitelist = vector::borrow_mut<Whitelist>(&mut whitelist_phase.whitelist, whitelist_phase.current_phase - 1);
        if (whitelist.paused == false) {
            let now = timestamp::now_seconds();
            assert!(now > whitelist.end_time, WHIELIST_PAUSED);
        } else {
            assert!(whitelist.paused == true, WHIELIST_NOT_PAUSED);
        };

        let i = 0;
        let len = vector::length<Winner>(&whitelist.whitelist);
        while (i < len) {
            let winner = vector::borrow<Winner>(&whitelist.whitelist, i);
            assert!(winner.resource != joiner_addr, INVALID_CLAIM_APTOS_BACK);
            i = i + 1;
        };

        let account_addr = signer::address_of(joiner);
        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);
        let whitelist_envelope = borrow_global<WhitelistEnvelope>(joiner_addr);

        coin::transfer<0x1::aptos_coin::AptosCoin>(&resource_signer_from_cap, account_addr, whitelist.price * whitelist_envelope.total_amount);
    }

    public entry fun withdraw_aptos(account: &signer, resource_addr: address, amount: u64) acquires ResourceInfo {
        let account_addr = signer::address_of(account);
        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);
        let resource_signer_from_cap = account::create_signer_with_capability(&resource_data.resource_cap);

        coin::transfer<0x1::aptos_coin::AptosCoin>(&resource_signer_from_cap, account_addr, amount);
    }

    public entry fun update_winner(
        account: &signer,
        resource_addr: address,
        pharse: u64,
        winner_addr: vector<address>,
        winner_num_nft: vector<u64>
    ) acquires ResourceInfo, WhitelistPhase {
        // get signer address
        let account_addr = signer::address_of(account);

        // check signer is admin
        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);

        // get whitelist pharse
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);
        assert!(whitelist_phase.current_phase == pharse, INVALID_PHASE);

        let whitelist = vector::borrow_mut<Whitelist>(&mut whitelist_phase.whitelist, pharse - 1);

        let i = 0;
        let len_addr = vector::length<address>(&winner_addr);
        let len_num_nft = vector::length<u64>(&winner_num_nft);
        assert!(len_addr == len_num_nft, INVALID_LIST_WINNER);

        while (i < len_addr) {
            let addr = vector::borrow<address>(&winner_addr, i);
            let num_nft = vector::borrow<u64>(&winner_num_nft, i);

            vector::push_back(&mut whitelist.whitelist, Winner{
                resource: *addr,
                num_nft: *num_nft,
                claimed: false,
            });

            i = i + 1;
        }
    }

    public entry fun update_whitelist_info(
        account: &signer,
        resource_addr: address,
        phase: u64,
        royalty_payee_address: address,
        paused: bool,
        price: u64,
        end_time: u64,
    ) acquires ResourceInfo, WhitelistPhase {
        // get signer address
        let account_addr = signer::address_of(account);

        // check signer is admin
        let resource_data = borrow_global<ResourceInfo>(resource_addr);
        assert!(resource_data.source == account_addr, INVALID_SIGNER);

        // get whitelist pharse
        let whitelist_phase = borrow_global_mut<WhitelistPhase>(resource_addr);
        assert!(whitelist_phase.current_phase == phase, INVALID_PHASE);

        let whitelist = vector::borrow_mut<Whitelist>(&mut whitelist_phase.whitelist, phase - 1);

        if (end_time != whitelist.end_time) {
            whitelist.end_time = end_time;
        };

        if (paused != whitelist.paused) {
            whitelist.paused = paused;
        };

        if (price != whitelist.price) {
            whitelist.price = price;
        };

        if (royalty_payee_address != whitelist.royalty_payee_address) {
            whitelist.royalty_payee_address = royalty_payee_address;
        };
    }
    fun num_str(num: u64): String{
        let v1 = vector::empty();
        while (num/10 > 0){
            let rem = num%10;
            vector::push_back(&mut v1, (rem+48 as u8));
            num = num/10;
        };
        vector::push_back(&mut v1, (num+48 as u8));
        vector::reverse(&mut v1);
        string::utf8(v1)
    }
    //
    // #[test(account = @0xAF, royalty_payee =@0xAF12, joinner=@0x11235, framework=@0x1)]
    // public entry fun end_to_end(
    //     account : signer,
    //     royalty_payee: signer,
    //     joinner:signer,
    //     framework: signer
    // ) acquires ResourceInfo, WhitelistPhase {
    //
    //     let joiner_addr = signer::address_of(&joinner);
    //     // account::create_account_for_test(signer::address_of(&account));
    //     // account::create_account_for_test(signer::address_of(&joinner));
    //     // aptos_framework::managed_coin::register<0x1::aptos_coin::AptosCoin>(&joinner);
    //     // set up global time for testing purpose
    //     timestamp::set_time_has_started_for_testing(&framework);
    //     let royalty_payee_addr = signer::address_of(&royalty_payee);
    //
    //     // init module
    //     let resource = init_rarewave(&account);
    //     let resource_addr = signer::address_of(&resource);
    //     //
    //     // // check if resource is exist
    //     // assert!(exists<WhitelistPhase>(resource_addr), 1);
    //     // assert!(exists<RareWave>(resource_addr), 1);
    //     // assert!(exists<ResourceInfo>(resource_addr), 1);
    //
    //     create_whitelist(
    //         &account,
    //         resource_addr,
    //         royalty_payee_addr,
    //         false,
    //         1,
    //         1123124125,
    //     );
    //
    //     // let whitelist_pharse = borrow_global<WhitelistPhase>(resource_addr);
    //     // assert!(whitelist_pharse.current_phase == 1, 1);
    //
    //     let winner_addr = vector::empty<address>();
    //     let winner_num_nft = vector::empty<u64>();
    //
    //     // append winner
    //     vector::push_back(&mut winner_addr, joiner_addr);
    //
    //     // append num nft
    //     vector::push_back(&mut winner_num_nft, 1);
    //
    //     update_winner(
    //         &account,
    //         resource_addr,
    //         1,
    //         winner_addr,
    //         winner_num_nft
    //     )
    // }
}
module BlueMoveLaunchpad::factory {
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self};
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_token::token;
    use std::string::{String, utf8};
    use std::vector;
    use std::string;
    use aptos_framework::account::SignerCapability;
    use aptos_token::token::TokenId;
    use aptos_framework::event::EventHandle;
    use aptos_framework::event;
    // use transfertoken::transfer_token::transfer_token;


    struct TokenCap has key {
        cap: SignerCapability,
    }

    struct MintData has key {
        current_token: u64,
        current_token_wl:u64,
        members:vector<address>,
        start_time:u64, // miliseconds
        expired_time:u64, // miliseconds
        nft_per_user:u64,
        start_time_wl:u64, // miliseconds
        expired_time_wl:u64, // miliseconds
        nft_per_user_wl:u64,
        total_nfts:u64,
        total_nfts_wl:u64,
        price_per_item:u64,
        price_per_item_wl:u64,
        lauchpad_fee:u64,
        minting_event:EventHandle<MintEvent>,
        minting_event_wl:EventHandle<MintEvent>
    }

    struct BaseNft has key{
        base_uri:String,

        collection_name:String,
        base_token_name:String,
        token_description:String,
    }

    struct MintEvent has drop, store {
        id:TokenId,
        minter_address:address,
    }

    struct MintedByUser has key {
        minted:u64,
        minted_wl:u64
    }

    const THIS_ACCONT: address = @0x8eafc4721064e0d0a20da5c696f8874a3c38967936f0f96b418e13f2a31dcf4c;

    const FUND_FEE_ADDRESS:address = @0x745b3caa9f369fa7acfef361b2e0f3208f36a334a25b7af0564ed64709608d1a;
    const ROYALTY_ADDRESS:address = @0x745b3caa9f369fa7acfef361b2e0f3208f36a334a25b7af0564ed64709608d1a;
    const FUND_CREATOR_ADDRESS:address = @0x745b3caa9f369fa7acfef361b2e0f3208f36a334a25b7af0564ed64709608d1a;

    const NUMERATOR_ROYALTY:u64 = 600;
    const DENOMINATOR_ROYALTY:u64 = 10000;

    const NUMBER_MINT_PER_ACCOUNT: u64 = 5;
    const MAX_NUMBER: u64 = 18446744073709551615;
    const MAX_TOTAL_MINTED:u64 = 2222;
    const ENO_ACCOUNT_MINTED: u64 = 0;
    const OUT_OF_NUMBER_MINT: u64 = 1;
    const INVALID_OWNER: u64 = 2;
    const OVER_MINTED:u64 = 3;
    const NOT_IN_WHILELIST:u64 = 4;
    const NOT_TIME_TO_MINT:u64 = 6;

   fun init_module(owner: &signer,
    ) {
        let owner_addr = signer::address_of(owner);
        let (collection_signer, collection_cap) = account::create_resource_account(owner, x"01");
        let creator_addr = signer::address_of(&collection_signer);

       assert!(owner_addr == THIS_ACCONT,INVALID_OWNER);

        if (!exists<TokenCap>(owner_addr)) {
            move_to(owner, TokenCap {
                cap: collection_cap,
            });
        };

       let collection_name = utf8(b"Aptos Wizards");
       let collection_description = utf8(b"AptosWizards early NFT Collection on Aptos Ecosystem. Do magic with your Wizard, meet people, staking, Early DAO on Aptos.");
       let collection_uri = utf8(b"https://ipfs.bluemove.io/uploads/AptosWizards/logo.png");

       let start_time = 1666540800000;
       let expired_time = 1666627200000;
       let nft_per_user = 1;
       let price_per_item = 300000000;
       let total_nfts:u64 = 5000; // total = public + wl


       let start_time_wl = 1666533600000;
       let expired_time_wl = 1666620000000;
       let nft_per_user_wl = 1;
       let price_per_item_wl = 300000000;
       let total_nfts_wl:u64 = 2000; // number of wl


       let base_uri = utf8(b"https://ipfs.bluemove.io/uploads/AptosWizards/metadata/");
       let base_token_name = utf8(b"Aptos Wizards #");
       let token_description = utf8(b"AptosWizards early NFT Collection on Aptos Ecosystem. Do magic with your Wizard, meet people, staking, Early DAO on Aptos.");

       //fee launchpad
       let lauchpad_fee:u64 = 1800;

        let mutate_setting = vector<bool>[false, false, false];
        token::create_collection_script(
            &collection_signer,
            collection_name,
            collection_description,
            collection_uri,
            MAX_NUMBER,
            mutate_setting
        );

       if (!exists<MintData>(creator_addr)) {
           move_to(&collection_signer, MintData {
               current_token: 0,
               current_token_wl:0,
               members:vector::empty(),
               start_time, // miliseconds
               expired_time, // miliseconds
               nft_per_user,
               total_nfts,
               start_time_wl,
               expired_time_wl,
               nft_per_user_wl,
               total_nfts_wl,
               price_per_item,
               price_per_item_wl,
               lauchpad_fee,
               minting_event:account::new_event_handle(&collection_signer),
               minting_event_wl:account::new_event_handle(&collection_signer)
           });
       };

       if (!exists<BaseNft>(creator_addr)) {
           move_to(&collection_signer, BaseNft {
               base_uri,
               collection_name,
               base_token_name,
               token_description,
           });
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

        utf8(v1)
    }

    public entry fun mint_nft_public(sender: &signer) acquires TokenCap, MintData, MintedByUser, BaseNft {
        let sender_addrr = signer::address_of(sender);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);

        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];
        let default_keys = vector<String>[];
        let default_vals = vector<vector<u8>>[];
        let default_types = vector<String>[];

        if(!exists<MintedByUser>(sender_addrr)){
            move_to(sender,MintedByUser{
                minted:0,
                minted_wl:0
            })
        };

        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let base_nft = borrow_global_mut<BaseNft>(collection_addr);
        // let is_whilelist = vector::contains(&mint_data.members,&sender_addrr);
        let minted_data = borrow_global_mut<MintedByUser>(sender_addrr);
        let minted_token_by_user = minted_data.minted;

        // assert!(!is_whilelist,NOT_IN_WHILELIST);
        assert!(mint_data.current_token + mint_data.total_nfts_wl < mint_data.total_nfts, MAX_TOTAL_MINTED);
        assert!(minted_token_by_user < mint_data.nft_per_user, OVER_MINTED);
        let time_now_seconds = timestamp::now_seconds()*1000;
        assert!(mint_data.start_time <= time_now_seconds && time_now_seconds <= mint_data.expired_time, NOT_TIME_TO_MINT);

        let fee = mint_data.price_per_item * mint_data.lauchpad_fee/10000;
        let sub_amount = mint_data.price_per_item - fee;

        // transfer fee lauchpad to owner contract and fee mint to creator
        if (fee > 0){
            coin::transfer<AptosCoin>(sender, FUND_FEE_ADDRESS, fee );
        };
        coin::transfer<AptosCoin>(sender, FUND_CREATOR_ADDRESS, sub_amount );

        let collection_name = base_nft.collection_name;
        let token_name = base_nft.base_token_name;
        let token_description = base_nft.token_description;


        let current_token = mint_data.current_token + mint_data.total_nfts_wl;
        let current_token_string = num_str(current_token);
        string::append(&mut token_name, current_token_string);

        let uri:String = base_nft.base_uri;

        string::append(&mut uri,num_str(current_token));
        string::append(&mut uri,utf8(b".json"));


        token::create_token_script(
            &collection_signer,
            collection_name,
            token_name,
            token_description,
            1,
            1,
            uri,
            ROYALTY_ADDRESS,
            DENOMINATOR_ROYALTY,
            NUMERATOR_ROYALTY,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let token_id = token::create_token_id_raw(collection_addr,collection_name,token_name,0 );

        token::direct_transfer(&collection_signer,sender,token_id,1);
        minted_data.minted = minted_data.minted + 1;
        mint_data.current_token = mint_data.current_token + 1;

        event::emit_event(&mut mint_data.minting_event, MintEvent{
            id:token_id,
            minter_address:sender_addrr
        })
    }

    public entry fun mint_nft_wl(sender: &signer) acquires TokenCap, MintData, MintedByUser, BaseNft {
        let sender_addrr = signer::address_of(sender);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);

        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];
        let default_keys = vector<String>[];
        let default_vals = vector<vector<u8>>[];
        let default_types = vector<String>[];

        if(!exists<MintedByUser>(sender_addrr)){
            move_to(sender,MintedByUser{
                minted:0,
                minted_wl:0
            })
        };

        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let base_nft = borrow_global_mut<BaseNft>(collection_addr);
        let is_whilelist = vector::contains(&mint_data.members,&sender_addrr);
        let minted_data = borrow_global_mut<MintedByUser>(sender_addrr);
        let minted_token_by_user = minted_data.minted_wl;

        assert!(is_whilelist,NOT_IN_WHILELIST);
        assert!(mint_data.current_token_wl < mint_data.total_nfts_wl, MAX_TOTAL_MINTED);
        assert!(minted_token_by_user < mint_data.nft_per_user_wl, OVER_MINTED);
        let time_now_seconds = timestamp::now_seconds()*1000;
        assert!(mint_data.start_time_wl <= time_now_seconds && time_now_seconds <= mint_data.expired_time_wl, NOT_TIME_TO_MINT);

        let fee = mint_data.price_per_item_wl * mint_data.lauchpad_fee/10000;
        let sub_amount = mint_data.price_per_item_wl - fee;

        // transfer fee lauchpad to owner contract and fee mint to creator
        if (fee > 0){
            coin::transfer<AptosCoin>(sender, FUND_FEE_ADDRESS, fee );
        };
        coin::transfer<AptosCoin>(sender, FUND_CREATOR_ADDRESS, sub_amount );

        let collection_name = base_nft.collection_name;
        let token_name = base_nft.base_token_name;
        let token_description = base_nft.token_description;


        let current_token = mint_data.current_token_wl;
        let current_token_string = num_str(current_token);
        string::append(&mut token_name, current_token_string);

        let uri:String = base_nft.base_uri;

        string::append(&mut uri,num_str(current_token));
        string::append(&mut uri,utf8(b".json"));


        token::create_token_script(
            &collection_signer,
            collection_name,
            token_name,
            token_description,
            1,
            1,
            uri,
            ROYALTY_ADDRESS,
            DENOMINATOR_ROYALTY,
            NUMERATOR_ROYALTY,
            mutate_setting,
            default_keys,
            default_vals,
            default_types,
        );
        let token_id = token::create_token_id_raw(collection_addr,collection_name,token_name,0 );

        token::direct_transfer(&collection_signer,sender,token_id,1);
        minted_data.minted_wl = minted_data.minted_wl + 1;
        mint_data.current_token_wl = mint_data.current_token_wl + 1;

        event::emit_event(&mut mint_data.minting_event_wl, MintEvent{
            id:token_id,
            minter_address:sender_addrr
        })
    }

    public entry fun add_whilelist_member(sender:&signer, members:vector<address>)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        vector::append(&mut mint_data.members,members);
    }

    public entry fun remove_all_whitelist_member(sender:&signer)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let members = &mut mint_data.members;
        while (!vector::is_empty(members)){
            vector::pop_back(members);
        }
    }

    public entry fun mint_with_quantity(sender:&signer, quantity:u64)acquires TokenCap, MintData, MintedByUser, BaseNft {
        let sender_addr = signer::address_of(sender);

        if(!exists<MintedByUser>(sender_addr)){
            move_to(sender,MintedByUser{
                minted:0,
                minted_wl:0
            })
        };

        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let minted_data = borrow_global_mut<MintedByUser>(sender_addr);

        assert!(quantity <= mint_data.total_nfts, OUT_OF_NUMBER_MINT);
        let i = quantity;
        let remain_can_mint = mint_data.nft_per_user - minted_data.minted;
        assert!(remain_can_mint >= quantity, OVER_MINTED);

        while (i > 0){
            mint_nft_public(sender);
            i = i - 1;
        }
    }

    public entry fun mint_with_quantity_whitelist(sender:&signer, quantity:u64)acquires TokenCap, MintData, MintedByUser, BaseNft {
        let sender_addr = signer::address_of(sender);

        if(!exists<MintedByUser>(sender_addr)){
            move_to(sender,MintedByUser{
                minted:0,
                minted_wl:0
            })
        };

        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let minted_data = borrow_global_mut<MintedByUser>(sender_addr);
        let remain_can_mint = mint_data.nft_per_user_wl - minted_data.minted_wl;
        assert!(remain_can_mint >= quantity, OVER_MINTED);

        assert!(quantity <= mint_data.total_nfts, OUT_OF_NUMBER_MINT);
        let is_whitelist = vector::contains(&mint_data.members,&sender_addr);
        assert!(is_whitelist,NOT_IN_WHILELIST);
        let i = quantity;

        while (i > 0){
            mint_nft_wl(sender);
            i = i - 1;
        }
    }

    public entry fun mint_with_owner(sender:&signer, quantity:u64) acquires TokenCap, MintData, BaseNft {
        let sender_address = signer::address_of(sender);
        assert!(sender_address == THIS_ACCONT, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);

        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];
        let default_keys = vector<String>[];
        let default_vals = vector<vector<u8>>[];
        let default_types = vector<String>[];

        let mint_data = borrow_global_mut<MintData>(collection_addr);
        let base_nft = borrow_global_mut<BaseNft>(collection_addr);
        assert!(mint_data.current_token < mint_data.total_nfts, MAX_TOTAL_MINTED);

        let _quantity = quantity;
        while (_quantity > 0 ){

            // let wl_address = vector::pop_back(&mut mint_data.members);

            let collection_name = base_nft.collection_name;
            let token_name = base_nft.base_token_name;
            let token_description = base_nft.token_description;


            let current_token = mint_data.current_token;
            let current_token_string = num_str(current_token);
            string::append(&mut token_name, current_token_string);

            let uri:String = base_nft.base_uri;


            string::append(&mut uri,num_str(current_token));
            string::append(&mut uri,utf8(b".json"));


            token::create_token_script(
                &collection_signer,
                collection_name,
                token_name,
                token_description,
                1,
                1,
                uri,
                ROYALTY_ADDRESS,
                DENOMINATOR_ROYALTY,
                NUMERATOR_ROYALTY,
                mutate_setting,
                default_keys,
                default_vals,
                default_types,
            );
            let token_id = token::create_token_id_raw(collection_addr,collection_name,token_name,0 );
            // let token = token::withdraw_token(&collection_signer, token_id, 1);
            // token::deposit_token(sender, token);
            token::direct_transfer(&collection_signer,sender,token_id,1);
            // transfer_token(&collection_signer,collection_addr,collection_name,token_name,0,wl_address);
            mint_data.current_token = current_token;
            _quantity = _quantity - 1;
        }
    }

    public entry fun update_time_to_mint (sender:&signer, start_time:u64, expited_time:u64)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        mint_data.start_time = start_time;
        mint_data.expired_time = expited_time;
    }

    public entry fun update_total_and_nft_per_user(sender:&signer, total_nfts:u64, nft_per_user:u64)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        mint_data.total_nfts = total_nfts;
        mint_data.nft_per_user = nft_per_user;
    }

    public entry fun update_price_mint(sender:&signer, _price_public:u64, _price_mint_wl:u64)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        mint_data.price_per_item = _price_public;
        mint_data.price_per_item_wl = _price_mint_wl;
    }

    public entry fun update_total_and_nft_per_user_wl(sender:&signer, total_nfts_wl:u64, nft_per_user_wl:u64)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        mint_data.total_nfts_wl = total_nfts_wl;
        mint_data.nft_per_user_wl = nft_per_user_wl;
    }

    public entry fun update_time_to_mint_wl (sender:&signer, start_time_wl:u64, expited_time_wl:u64)acquires TokenCap, MintData {
        let sender_addr = signer::address_of(sender);
        assert!(THIS_ACCONT == sender_addr, INVALID_OWNER);
        let token_cap = borrow_global<TokenCap>(THIS_ACCONT);
        let collection_cap = &token_cap.cap;
        let collection_signer = account::create_signer_with_capability(collection_cap);
        let collection_addr = signer::address_of(&collection_signer);
        let mint_data = borrow_global_mut<MintData>(collection_addr);
        mint_data.start_time_wl = start_time_wl;
        mint_data.expired_time_wl = expited_time_wl;
    }

}

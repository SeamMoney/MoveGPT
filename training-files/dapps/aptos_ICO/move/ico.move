module ico_mod::ico{
    use std::vector;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_account;
    use aptos_std::math64;

    use publisher::DemoCoin::{ DemoCoin as DC };
    const EC_ICO_ENDED: u64 = 1;
    const EC_INSUFFICIENT_TOKEN: u64 = 2;
    const EC_ICO_NOT_STARTED: u64 = 3;
    const EC_MAX_LIMIT: u64 = 4;
    const EC_NOT_ADMIN: u64 = 5;
    const EC_ZERO_ACCOUNT: u64 = 6;
    const EC_ZERO_TOKEN: u64 = 7;
    const EC_INVALID_TIMESTAMP: u64 = 8;
    const EC_ICO_RESTRICTED: u64 = 9;
    const EC_SOMETHING_WENT_WRONG: u64 = 10;
    const EC_EMPTY_WHITELIST: u64 = 11;
    const EC_ADMIN_NOT_ALLOWED: u64 = 12;
    const EC_ICO_RUNNING: u64 = 13;
    const EC_ICO_NOT_CREATED: u64 = 14;

    struct ICO has key{
        ico_creator: address,
        rate: u64,
        start_time: u64,
        end_time: u64,
        available_tokens: u64,
        max_limit_pp: u64,
        tokens_sold: u64,
        whitelist: vector<address>,
        token_amount: vector<u64>,
        closed: bool,
    }

    struct ResourceInfo has key{
        source_addr: address,
        signer_cap: account::SignerCapability,
    }


    fun init_module(account: &signer){
        let creator_addr = signer::address_of(account);
        if (!coin::is_account_registered<0x1::aptos_coin::AptosCoin>(creator_addr)) {
            coin::register<0x1::aptos_coin::AptosCoin>(account);
        };
        if (!coin::is_account_registered<DC>(creator_addr)) {
            coin::register<DC>(account);
        };
        let signer_capabilty = resource_account::retrieve_resource_account_cap(account, @source_address);
        move_to(account, ICO{ 
            ico_creator: @0x1,
            start_time: 0,
            rate: 0,
            end_time: 0,
            available_tokens: 0,
            max_limit_pp: 0,
            tokens_sold: 0,
            whitelist: vector::empty<address>(),
            token_amount: vector::empty<u64>(),
            closed: false,
        });
        move_to(account, ResourceInfo{
            source_addr: @source_address,
            signer_cap: signer_capabilty,
        });
    }

    public entry fun setup_ico(
        _creator: &signer, 
        _tokens: u64, 
        _start_time: u64, 
        _rate: u64, 
        _end_time: u64, 
        max_pp: u64
        ) acquires ICO, ResourceInfo{
        let curr_addr = signer::address_of(_creator);
        let current_timestamp = timestamp::now_seconds();
        let is_admin = borrow_global<ResourceInfo>(@ico_mod);
        assert!(is_admin.source_addr == curr_addr ,EC_NOT_ADMIN);
        assert!(_tokens != 0 ,EC_ZERO_TOKEN);
        assert!(max_pp != 0 , EC_ZERO_TOKEN);
        assert!(_rate != 0 ,EC_ZERO_TOKEN);
        let creator_addr = signer::address_of(_creator);
        if (!coin::is_account_registered<DC>(creator_addr)) {
            coin::register<DC>(_creator);
        };
        let bal = coin::balance<DC>(creator_addr);
        // let bal = coin::balance<DC>(@ico_mod);
        assert!(bal > 0, EC_INSUFFICIENT_TOKEN);
        assert!(_start_time >= current_timestamp ,EC_INVALID_TIMESTAMP); 
        assert!(_end_time > _start_time ,EC_INVALID_TIMESTAMP);  
        aptos_account::transfer_coins<DC>(_creator, @ico_mod, _tokens);
        // 3600 hrs
        let ico_ref = borrow_global_mut<ICO>(@ico_mod);
        ico_ref.ico_creator = creator_addr;
        ico_ref.available_tokens = _tokens;
        ico_ref.start_time = _start_time;
        ico_ref.rate = _rate;
        ico_ref.end_time = _end_time;
        ico_ref.tokens_sold = 0;
        ico_ref.max_limit_pp = max_pp;
        ico_ref.whitelist = vector::empty<address>();
        ico_ref.token_amount = vector::empty<u64>();
    }

    public entry fun register_tokens(
        buyer: &signer, 
        tokens: u64
        ) acquires ICO, ResourceInfo{
        let user = signer::address_of(buyer);
        let res_inf = borrow_global<ResourceInfo>(@ico_mod);
        let i_ref = borrow_global<ICO>(@ico_mod);
        assert!(res_inf.source_addr != user ,EC_ADMIN_NOT_ALLOWED);
        assert!(!i_ref.closed, EC_ICO_RESTRICTED);
        // if (!coin::is_account_registered<DC>(addre)) {
        //     coin::register<DC>(buyer);
        // };
        let current_timestamp = timestamp::now_seconds();
        assert!(current_timestamp >= borrow_global<ICO>(@ico_mod).start_time, EC_ICO_NOT_STARTED);
        assert!(borrow_global<ICO>(@ico_mod).available_tokens > 0, EC_INSUFFICIENT_TOKEN);
        assert!(tokens <= borrow_global<ICO>(@ico_mod).max_limit_pp , EC_MAX_LIMIT);
        assert!(borrow_global<ICO>(@ico_mod).available_tokens != 0, EC_ICO_ENDED);
        assert!(current_timestamp <= borrow_global<ICO>(@ico_mod).end_time, EC_ICO_ENDED);
        let i_ref = borrow_global<ICO>(@ico_mod);
        let tok_bal = tokens / math64::pow(10, 8);
        let total_cost = i_ref.rate * tok_bal;
        let ico_ref = borrow_global_mut<ICO>(@ico_mod);
        ico_ref.available_tokens = ico_ref.available_tokens - tokens;
        ico_ref.tokens_sold = ico_ref.tokens_sold + tokens;
        aptos_account::transfer_coins<0x1::aptos_coin::AptosCoin>(buyer, @ico_mod, total_cost);

        let _whitelist = borrow_global_mut<ICO>(@ico_mod);
        vector::push_back(&mut _whitelist.whitelist, user);
        vector::push_back(&mut _whitelist.token_amount, tokens);
    }

    public entry fun distribute_tokens(
        ) acquires ICO, ResourceInfo{
        let current_timestamp = timestamp::now_seconds();
        let is_admin = borrow_global<ResourceInfo>(@ico_mod);
        let _whitelist = borrow_global_mut<ICO>(@ico_mod);
        let addr_len = vector::length(&_whitelist.whitelist);
        let amt_len = vector::length(&_whitelist.token_amount);
        assert!(_whitelist.end_time != 0, EC_ICO_NOT_CREATED);
        assert!(current_timestamp > _whitelist.end_time, EC_ICO_RUNNING);
        assert!(addr_len != 0, EC_EMPTY_WHITELIST);
        assert!(addr_len == amt_len, EC_SOMETHING_WENT_WRONG);
        let recipients = _whitelist.whitelist;
        let amounts = _whitelist.token_amount;
        let resource_signer = account::create_signer_with_capability(&is_admin.signer_cap);
        aptos_account::batch_transfer_coins<DC>(&resource_signer, recipients, amounts);
        let send_amt = coin::balance<0x1::aptos_coin::AptosCoin>(@ico_mod);
        aptos_account::transfer_coins<0x1::aptos_coin::AptosCoin>(&resource_signer, is_admin.source_addr, send_amt);
        _whitelist.closed = true;
    }

    public entry fun modify_rate(
        from: &signer,
        _rate: u64
        ) acquires ICO, ResourceInfo{
        let curr_addr = signer::address_of(from);
        let current_timestamp = timestamp::now_seconds();
        let is_admin = borrow_global<ResourceInfo>(@ico_mod);
        let ico_ref = borrow_global<ICO>(@ico_mod);
        assert!(is_admin.source_addr == curr_addr ,EC_NOT_ADMIN); 
        assert!(ico_ref.rate != 0 ,EC_ICO_NOT_CREATED);
        assert!(current_timestamp <= ico_ref.end_time ,EC_ICO_ENDED);
        let _whitelist = borrow_global_mut<ICO>(@ico_mod);
        _whitelist.rate = _rate;
    }

    public entry fun set_admin(
        sender: &signer,
        new_admin: address
        ) acquires ResourceInfo {
        let curr_addr = signer::address_of(sender);
        let _inf = borrow_global<ResourceInfo>(@ico_mod);
        let res_inf = borrow_global_mut<ResourceInfo>(@ico_mod);
        assert!(res_inf.source_addr == curr_addr ,EC_NOT_ADMIN);
        assert!(new_admin != @0x0, EC_ZERO_ACCOUNT);
        res_inf.source_addr = new_admin;
    }

    public entry fun freeze_ico(
        admin: &signer,
        ) acquires ICO, ResourceInfo{
        let curr_addr = signer::address_of(admin);
        let current_timestamp = timestamp::now_seconds();
        let is_admin = borrow_global<ResourceInfo>(@ico_mod);
        let ico_ref = borrow_global<ICO>(@ico_mod);
        assert!(is_admin.source_addr == curr_addr ,EC_NOT_ADMIN);
        assert!(current_timestamp >= ico_ref.start_time ,EC_ICO_NOT_STARTED); 
        assert!(current_timestamp <= ico_ref.end_time ,EC_ICO_ENDED);
        let i_ref = borrow_global_mut<ICO>(@ico_mod);
        i_ref.closed = true; 
    }

    public entry fun unfreeze_ico(
        admin: &signer,
        ) acquires ICO, ResourceInfo{
        let curr_addr = signer::address_of(admin);
        let current_timestamp = timestamp::now_seconds();
        let is_admin = borrow_global<ResourceInfo>(@ico_mod);
        let ico_ref = borrow_global<ICO>(@ico_mod);
        assert!(is_admin.source_addr == curr_addr ,EC_NOT_ADMIN); 
        assert!(current_timestamp >= ico_ref.start_time ,EC_ICO_NOT_STARTED); 
        assert!(current_timestamp <= ico_ref.end_time ,EC_ICO_ENDED);
        let i_ref = borrow_global_mut<ICO>(@ico_mod);
        i_ref.closed = false; 
    } 
}
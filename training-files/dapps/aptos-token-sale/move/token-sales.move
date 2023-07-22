module token_sale::TokenSale {
    use std::signer;
    use aptos_framework::coin;
    use aptos_std::table_with_length;
    use aptos_framework::aptos_coin;

    const MODULE_OWNER: address = @token_sale;
    const COLLECT_ADDRESS: address = @collect_address;

    const ENOT_MODULE_OWNER: u64 = 0;
    const EALREADY_HAS_TOTALPURCHASED: u64 = 1;
    const EALREADY_HAS_RECORD: u64 = 2;
    const ENO_USER_RECORD: u64 = 3;
    const EINSUFFCIENT_BALANCE: u64 = 4;
    const ENOT_YET_PUBLISH_LAUCHPAD: u64 = 5;
    const EPURCHASE_DISABLED: u64 = 6;    
    const EEXCEED_ALLOCATION: u64 = 7;    
    const EEXCEED_insurance_ALLOWANCE: u64 = 8;    
    const EALREADY_HAS_INVESTOR_TABLE: u64 = 9;    
    const ELESS_THAN_INVESTED_AMOUNT: u64 = 10;    

    struct TotalPurchased has store, key {
        investment: u64,
        insurance: u64,
        status: bool
    }

    struct Investors<phantom K: copy + drop, phantom V: drop> has store, key{
        t: table_with_length::TableWithLength<K, V>,
    }

    struct UserRecord has store, key {
        allocation: u64,
        invested_amount: u64,
        insurance: u64
    }

    public entry fun publish_launchpad_total(module_owner: &signer) {
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        assert!(!exists<TotalPurchased>(signer::address_of(module_owner)), EALREADY_HAS_TOTALPURCHASED);
        move_to(module_owner, TotalPurchased { investment : 0, insurance : 0, status : true });
        create_investor_table(module_owner)
    }

    public entry fun create_investor_table(module_owner: &signer){
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        assert!(!exists<Investors<u64, address>>(MODULE_OWNER), EALREADY_HAS_INVESTOR_TABLE);
        let t = table_with_length::new<u64, address>();
        move_to(module_owner, Investors { t });      
    }

    public entry fun add_to_whitelist(new_investor: &signer) acquires Investors{
        let new_investor_addr = signer::address_of(new_investor);
        assert!(!exists<UserRecord>(signer::address_of(new_investor)), EALREADY_HAS_RECORD);
        let t = borrow_global_mut<Investors<u64, address>>(MODULE_OWNER);
        let key = table_with_length::length(&t.t);
        table_with_length::add(&mut t.t, key, new_investor_addr);
        move_to(new_investor, UserRecord { allocation : 100000000000000, invested_amount : 0, insurance : 0});
    }

    fun get_status(): bool acquires TotalPurchased {
        borrow_global<TotalPurchased>(MODULE_OWNER).status
    }

    public entry fun update_status(module_owner: &signer, status: bool) acquires TotalPurchased{
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        let status_ref = &mut borrow_global_mut<TotalPurchased>(MODULE_OWNER).status;
        *status_ref = status;
    }

    fun get_total_investment(): u64 acquires TotalPurchased {
        borrow_global<TotalPurchased>(MODULE_OWNER).investment
    }

    fun get_total_insurance(): u64 acquires TotalPurchased {
        borrow_global<TotalPurchased>(MODULE_OWNER).insurance
    }

    fun get_user_allocation(owner: address): u64 acquires UserRecord {
        borrow_global<UserRecord>(owner).allocation
    }

    fun get_user_invested_amount(owner: address): u64 acquires UserRecord {
        borrow_global<UserRecord>(owner).invested_amount
    }

    fun get_user_allocation_remaining(owner: address): u64 acquires UserRecord {
        let max_allocation = get_user_allocation(owner);
        let current_invesment = get_user_invested_amount(owner);
        max_allocation - current_invesment
    }

    fun get_user_insurance(owner: address): u64 acquires UserRecord {
        borrow_global<UserRecord>(owner).insurance
    }

    fun get_user_insurance_remaining(owner: address): u64 acquires UserRecord {
        let current_insurance = get_user_insurance(owner);
        let current_invesment = get_user_invested_amount(owner);
        (current_invesment * 8 / 10) - current_insurance
    }

    fun update_user_invested_amount(owner: address, amount: u64) acquires UserRecord{
        let current_invested_amount = get_user_invested_amount(owner);
        let invested_amount_ref = &mut borrow_global_mut<UserRecord>(owner).invested_amount;
        *invested_amount_ref = current_invested_amount + amount;
    }

    fun update_user_insurance(owner: address, amount: u64) acquires UserRecord{
        let current_insurance = get_user_insurance(owner);
        let insurance_ref = &mut borrow_global_mut<UserRecord>(owner).insurance;
        *insurance_ref = current_insurance + amount;
    }

    public entry fun update_user_allocation(module_owner: &signer, investor: address, new_allocation: u64) acquires UserRecord{
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);
        assert!(exists<UserRecord>(investor), ENO_USER_RECORD);
        let current_invested_amount = get_user_invested_amount(investor);
        assert!(new_allocation >= current_invested_amount, ELESS_THAN_INVESTED_AMOUNT);
        let allocation_ref = &mut borrow_global_mut<UserRecord>(investor).allocation;
        *allocation_ref = new_allocation;
    }

    fun update_total_investment(amount: u64) acquires TotalPurchased{
        let current_invesment = get_total_investment();
        let total_invesment_ref = &mut borrow_global_mut<TotalPurchased>(MODULE_OWNER).investment;
        *total_invesment_ref = current_invesment + amount;
    }

    fun update_total_insurance(amount: u64) acquires TotalPurchased{
        let current_insurance = get_total_insurance();
        let total_insurance_ref = &mut borrow_global_mut<TotalPurchased>(MODULE_OWNER).insurance;
        *total_insurance_ref = current_insurance + amount;
    }


    public entry fun invest(from: &signer, invest: u64) acquires UserRecord,  TotalPurchased, Investors{
        assert!(exists<TotalPurchased>(MODULE_OWNER), ENOT_YET_PUBLISH_LAUCHPAD);
        let current_status = get_status();
        assert!(current_status == true, EPURCHASE_DISABLED);
        
        let from_addr = signer::address_of(from);
        if(!exists<UserRecord>(signer::address_of(from))){
        let t = borrow_global_mut<Investors<u64, address>>(MODULE_OWNER);
        let key = table_with_length::length(&t.t);
        table_with_length::add(&mut t.t, key, from_addr);
        move_to(from, UserRecord { allocation : 100000000000000, invested_amount : 0, insurance : 0});      
        };

        assert!(exists<UserRecord>(from_addr), ENO_USER_RECORD);
        assert!(coin::balance<aptos_coin::AptosCoin>(from_addr) >= invest, EINSUFFCIENT_BALANCE);

        let user_allocation_ramining = get_user_allocation_remaining(from_addr);
        assert!(invest <= user_allocation_ramining, EEXCEED_ALLOCATION);

        coin::transfer<aptos_coin::AptosCoin>(from, COLLECT_ADDRESS, invest);
        update_user_invested_amount(from_addr, invest);
        update_total_investment(invest);
    }

    public entry fun buy_insurance(from: &signer, insurance: u64) acquires UserRecord,  TotalPurchased, Investors{
        assert!(exists<TotalPurchased>(MODULE_OWNER), ENOT_YET_PUBLISH_LAUCHPAD);
        let current_status = get_status();
        assert!(current_status == true, EPURCHASE_DISABLED);
        
        let from_addr = signer::address_of(from);
        if(!exists<UserRecord>(signer::address_of(from))){
        let t = borrow_global_mut<Investors<u64, address>>(MODULE_OWNER);
        let key = table_with_length::length(&t.t);
        table_with_length::add(&mut t.t, key, from_addr);
        move_to(from, UserRecord { allocation : 100000000000000, invested_amount : 0, insurance : 0});      
        };

        assert!(exists<UserRecord>(from_addr), ENO_USER_RECORD);
        assert!(coin::balance<aptos_coin::AptosCoin>(from_addr) >= insurance, EINSUFFCIENT_BALANCE);
        let insurance_remaining = get_user_insurance_remaining(from_addr);
        assert!(insurance <= insurance_remaining, EEXCEED_insurance_ALLOWANCE);

        coin::transfer<aptos_coin::AptosCoin>(from, COLLECT_ADDRESS, insurance);
        update_user_insurance(from_addr, insurance);
        update_total_insurance(insurance);
    }

    public entry fun invest_with_insurance(from: &signer, invest: u64, insurance: u64) acquires UserRecord,  TotalPurchased, Investors{
        assert!(exists<TotalPurchased>(MODULE_OWNER), ENOT_YET_PUBLISH_LAUCHPAD);
        let current_status = get_status();
        assert!(current_status == true, EPURCHASE_DISABLED);
        
        let from_addr = signer::address_of(from);
        if(!exists<UserRecord>(signer::address_of(from))){
        let t = borrow_global_mut<Investors<u64, address>>(MODULE_OWNER);
        let key = table_with_length::length(&t.t);
        table_with_length::add(&mut t.t, key, from_addr);
        move_to(from, UserRecord { allocation : 100000000000000, invested_amount : 0, insurance : 0});
        };

        assert!(exists<UserRecord>(from_addr), ENO_USER_RECORD);
        assert!(coin::balance<aptos_coin::AptosCoin>(from_addr) >= invest + insurance, EINSUFFCIENT_BALANCE);

        let user_allocation_ramining = get_user_allocation_remaining(from_addr);
        assert!(invest <= user_allocation_ramining, EEXCEED_ALLOCATION);

        let insurance_remaining = get_user_insurance_remaining(from_addr);
        let insurance_allowed = insurance_remaining + (invest * 8 / 10);
        assert!(insurance <= insurance_allowed, EEXCEED_insurance_ALLOWANCE);

        coin::transfer<aptos_coin::AptosCoin>(from, COLLECT_ADDRESS, invest);
        update_user_invested_amount(from_addr, invest);
        update_total_investment(invest);
        coin::transfer<aptos_coin::AptosCoin>(from, COLLECT_ADDRESS, insurance);
        update_user_insurance(from_addr, insurance);
        update_total_insurance(insurance);
    }  

    public entry fun get_investor_address_by_key(key: u64):address acquires Investors{
        let t = borrow_global<Investors<u64, address>>(MODULE_OWNER);
        *table_with_length::borrow(&t.t, key)
    }

    
    public entry fun get_total_investor_number():u64 acquires Investors{
        let t = borrow_global<Investors<u64, address>>(MODULE_OWNER);
        table_with_length::length(&t.t)
    }
}



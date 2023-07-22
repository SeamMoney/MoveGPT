module MasterChefDepolyer::AutoAni {
    use std::signer;
    use aptos_std::event;
    use aptos_framework::coin::{Self};
    use aptos_framework::timestamp;
    use aptos_framework::account::{Self, SignerCapability};
    use MasterChefDepolyer::BubbleMasterChefV1::{Self, ANI};
    // use aptos_std::debug;    // For debug

    const AMOUNT_ERROR: u64 = 101;
    const FORBIDDEN: u64 = 103;
    const WITHDRAW_ERROR: u64 = 104;
    const PAUSABLE_ERROR: u64 = 105;

    const ANI_PRECISION: u128 = 1000000000000;  // 1e12
    const DEPLOYER: address = @MasterChefDepolyer;

    // info of each user, store at user's address
    struct UserInfo has key, store {
        shares: u128,    // number of shares for a user
        last_deposited_time: u64,   // keeps track of deposited time for potential penalty
        last_user_action_ANI: u64,   // keeps track of ANI deposited at the last user action
        last_user_action_time: u64,  // keeps track of the last user action time
    }

    struct AutoANIData has drop, key {
        signer_cap: SignerCapability,
        total_shares: u128,
        admin_address: address,
        treasury: address,  // collect fees
        performance_fee: u64,
        call_fee: u64,
        withdraw_fee: u64,
        withdraw_fee_period: u64,
        last_harvested_time: u64,
        is_pause: bool,
    }

    struct Events has key {
        deposit_event: event::EventHandle<DepositEvent>,
        withdraw_event: event::EventHandle<WithdrawEvent>,
        harvest_event: event::EventHandle<HarvestEvent>,
    }

    struct DepositEvent has drop, store {
        sender_address: address,
        amount: u64,
        shares: u128,
        last_deposited_time: u64,
    }

    struct WithdrawEvent has drop, store {
        sender_address: address,
        amount: u64,
        shares: u128,
    }

    struct HarvestEvent has drop, store {
        sender_address: address,
        performance_fee: u64,
        call_fee: u64,
    }

    // resource account signer
    fun get_resource_account(): signer acquires AutoANIData {
        let signer_cap = &borrow_global<AutoANIData>(DEPLOYER).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    // return pair admin account address
    fun get_resource_account_address(): address acquires AutoANIData {
        signer::address_of(&get_resource_account())
    }

    fun register_coin<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
    }

    // initialize
    fun init_module(admin: &signer) {
        // create resource account
        let (resource_account, capability) = account::create_resource_account(admin, x"A0");
        register_coin<ANI>(&resource_account);
        // AutoANIData
        move_to(admin, AutoANIData {
            signer_cap: capability,
            total_shares: 0,
            admin_address: signer::address_of(admin),
            treasury: signer::address_of(admin),
            performance_fee: 299,   // 2.99%
            call_fee: 25,   // 0.25%
            withdraw_fee: 10,   // 0.1%
            withdraw_fee_period: 86400 * 3, // 3 days
            last_harvested_time: timestamp::now_seconds(),
            is_pause: false,
        });
        // register
        BubbleMasterChefV1::register_ANI(admin);
        move_to(&resource_account, Events {
            deposit_event: account::new_event_handle<DepositEvent>(admin),
            withdraw_event: account::new_event_handle<WithdrawEvent>(admin),
            harvest_event: account::new_event_handle<HarvestEvent>(admin),
        })
    }

    fun when_paused() acquires AutoANIData {
        assert!(borrow_global<AutoANIData>(DEPLOYER).is_pause == true, PAUSABLE_ERROR);
    }

    fun when_not_paused() acquires AutoANIData {
        assert!(borrow_global<AutoANIData>(DEPLOYER).is_pause == false, PAUSABLE_ERROR);
    }

    // Deposits funds into the ANI Vault
    public entry fun deposit(
        account: &signer,
        amount: u64
    ) acquires AutoANIData, UserInfo, Events {
        when_not_paused();
        assert!(amount > 0, AMOUNT_ERROR);
        let auto_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        let resource_account_signer = account::create_signer_with_capability(&auto_data.signer_cap);
        let resource_account_address = signer::address_of(&resource_account_signer);
        let acc_addr = signer::address_of(account);

        let pool = balance_of(resource_account_address);
        coin::transfer<ANI>(account, resource_account_address, amount);
        let current_shares;
        if (auto_data.total_shares != 0) {
            current_shares = (amount as u128) * auto_data.total_shares / (pool as u128);
        } else {
            current_shares = (amount as u128);
        };

        auto_data.total_shares = auto_data.total_shares + current_shares;

        if (exists<UserInfo>(acc_addr)) {
            let user_info = borrow_global_mut<UserInfo>(acc_addr);
            user_info.shares = user_info.shares + current_shares;
            user_info.last_deposited_time = timestamp::now_seconds();
            user_info.last_user_action_ANI = (user_info.shares * (balance_of(resource_account_address) as u128) / auto_data.total_shares as u64);
            user_info.last_user_action_time = timestamp::now_seconds();
        } else {
            let user_info = UserInfo {
                shares: current_shares,
                last_deposited_time: timestamp::now_seconds(),
                last_user_action_ANI: (current_shares * (balance_of(resource_account_address) as u128) / auto_data.total_shares as u64),
                last_user_action_time: timestamp::now_seconds(),
            };
            move_to(account, user_info);
        };

        earn_internal(&resource_account_signer);
        // emit deposit
        let events = borrow_global_mut<Events>(resource_account_address);
        event::emit_event(&mut events.deposit_event, DepositEvent {
            sender_address: acc_addr,
            amount: amount,
            shares: current_shares,
            last_deposited_time: timestamp::now_seconds(),
        })
    }

    public entry fun withdraw_all(
        account: &signer
    ) acquires AutoANIData, UserInfo, Events {
        let acc_addr = signer::address_of(account);
        let user_info = borrow_global<UserInfo>(acc_addr);
        withdraw(account, user_info.shares);
    }

    public entry fun withdraw(
        account: &signer,
        shares: u128
    ) acquires AutoANIData, UserInfo, Events {
        let acc_addr = signer::address_of(account);
        let user_info = borrow_global_mut<UserInfo>(acc_addr);
        assert!(shares > 0 && shares <= user_info.shares, WITHDRAW_ERROR);
        let resource_account_signer = get_resource_account();
        let resource_account_address = signer::address_of(&resource_account_signer);
        let auto_data = borrow_global_mut<AutoANIData>(DEPLOYER);

        let current_amount = (balance_of(resource_account_address) as u128) * shares / auto_data.total_shares;
        user_info.shares = user_info.shares - shares;
        auto_data.total_shares = auto_data.total_shares - shares;

        let bal = (available(resource_account_address) as u128);
        if (bal < current_amount) {
            let bal_withdraw = current_amount - bal;
            BubbleMasterChefV1::leave_staking(&resource_account_signer, (bal_withdraw as u64));
            let bal_after = (available(resource_account_address) as u128);
            let diff = bal_after - bal;
            if (diff < bal_withdraw) {
                current_amount = bal + diff
            }
        };

        if (timestamp::now_seconds() < user_info.last_deposited_time + auto_data.withdraw_fee_period) {
            let current_withdraw_fee = current_amount * (auto_data.withdraw_fee as u128) / 10000;
            coin::transfer<ANI>(&resource_account_signer, auto_data.treasury, (current_withdraw_fee as u64));
            current_amount = current_amount - current_withdraw_fee;
        };

        if (user_info.shares > 0) {
            user_info.last_user_action_ANI = (user_info.shares * (balance_of(resource_account_address) as u128) / auto_data.total_shares as u64);
        } else {
            user_info.last_user_action_ANI = 0;
        };

        user_info.last_user_action_time = timestamp::now_seconds();
        coin::transfer<ANI>(&resource_account_signer, acc_addr, (current_amount as u64));
        // emit withdraw
        let events = borrow_global_mut<Events>(resource_account_address);
        event::emit_event(&mut events.withdraw_event, WithdrawEvent {
            sender_address: acc_addr,
            amount: (current_amount as u64),
            shares: shares,
        })
    }

    // Reinvests Bsw tokens into MasterChef
    public entry fun harvest(
        account: &signer
    ) acquires AutoANIData, Events {
        when_not_paused();
        let acc_addr = signer::address_of(account);
        let resource_account_signer = get_resource_account();
        let resource_account_address = signer::address_of(&resource_account_signer);
        let auto_data = borrow_global_mut<AutoANIData>(DEPLOYER);

        BubbleMasterChefV1::leave_staking(&resource_account_signer, 0);
        let bal = (available(resource_account_address) as u128);
        let current_performance_fee = bal * (auto_data.performance_fee as u128) / 10000;
        coin::transfer<ANI>(&resource_account_signer, auto_data.treasury, (current_performance_fee as u64));

        let current_call_fee = bal * (auto_data.call_fee as u128) / 10000;
        coin::transfer<ANI>(&resource_account_signer, acc_addr, (current_call_fee as u64));

        earn_internal(&resource_account_signer);
        auto_data.last_harvested_time = timestamp::now_seconds();
        // emit harvest
        let events = borrow_global_mut<Events>(resource_account_address);
        event::emit_event(&mut events.harvest_event, HarvestEvent {
            sender_address: acc_addr,
            performance_fee: (current_performance_fee as u64),
            call_fee: (current_call_fee as u64),
        })
    }

    // Deposits tokens into MasterChef to earn staking rewards
    fun earn_internal(
        resource_account_signer: &signer
    ) {
        let resource_account_address = signer::address_of(resource_account_signer);
        let bal = available(resource_account_address);
        if (bal > 0) {
            BubbleMasterChefV1::enter_staking(resource_account_signer, bal);
        }
    }

    // Custom logic for how much the vault allows to be borrowed
    // addr must be resource_account_address
    fun available(
        addr: address
    ): u64 {
        coin::balance<ANI>(addr)
    }

    // Calculates the total underlying tokens
    // addr must be resource_account_address
    fun balance_of(
        addr: address
    ): u64 {
        let amount = BubbleMasterChefV1::get_user_info_amount<ANI>(addr);
        coin::balance<ANI>(addr) + amount
    }

    public entry fun set_admin_address(
        admin: &signer,
        new_admin_address: address
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.admin_address = new_admin_address;
    }

    public entry fun set_treasury_address(
        admin: &signer,
        new_treasury_address: address
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.treasury = new_treasury_address;
    }

    public entry fun set_performance_fee(
        admin: &signer,
        new_performance_fee: u64
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.performance_fee = new_performance_fee;
    }

    public entry fun set_call_fee(
        admin: &signer,
        new_call_fee: u64
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.call_fee = new_call_fee;
    }

    public entry fun set_withdraw_fee(
        admin: &signer,
        new_withdraw_fee: u64
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.withdraw_fee = new_withdraw_fee;
    }

    public entry fun set_withdraw_fee_period(
        admin: &signer,
        new_withdraw_fee_period: u64
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.withdraw_fee_period = new_withdraw_fee_period;
    }

    public entry fun emergency_withdraw(
        admin: &signer
    ) acquires AutoANIData {
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        BubbleMasterChefV1::emergency_withdraw<ANI>(&get_resource_account());
    }

    public entry fun pause(
        admin: &signer
    ) acquires AutoANIData {
        when_not_paused();
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.is_pause = true;
    }

    public entry fun unpause(
        admin: &signer
    ) acquires AutoANIData {
        when_paused();
        let aa_data = borrow_global_mut<AutoANIData>(DEPLOYER);
        assert!(signer::address_of(admin) == aa_data.admin_address, FORBIDDEN);
        aa_data.is_pause = false;
    }

    /**
     *  public functions for other contract
     */

    // Calculates the expected harvest reward from third party
    public fun calculate_harvest_ANI_rewards(): u64 acquires AutoANIData {
        let resource_account_signer = get_resource_account();
        let resource_account_address = signer::address_of(&resource_account_signer);
        let auto_data = borrow_global<AutoANIData>(DEPLOYER);

        let amount = BubbleMasterChefV1::pending_ANI<ANI>(resource_account_address);
        amount = amount + available(resource_account_address);
        let current_call_fee = (amount as u128) * (auto_data.call_fee as u128) / 10000;
        (current_call_fee as u64)
    }

    // Calculates the total pending rewards that can be restaked
    public fun calculate_total_pending_ANI_rewards(): u64 acquires AutoANIData {
        let resource_account_signer = get_resource_account();
        let resource_account_address = signer::address_of(&resource_account_signer);

        let amount = BubbleMasterChefV1::pending_ANI<ANI>(resource_account_address);
        amount = amount + available(resource_account_address);
        amount
    }

    public fun get_price_per_full_share(): u64 acquires AutoANIData {
        let resource_account_signer = get_resource_account();
        let resource_account_address = signer::address_of(&resource_account_signer);
        let auto_data = borrow_global<AutoANIData>(DEPLOYER);
        
        if (auto_data.total_shares == 0) {
            return (ANI_PRECISION as u64)
        } else {
            let amount = (balance_of(resource_account_address) as u128) * ANI_PRECISION / auto_data.total_shares;
            return (amount as u64)
        }
    }

    public fun get_auto_ANI_data(): (u128, u64, u64, u64, u64, u64) acquires AutoANIData {
        let auto_data = borrow_global<AutoANIData>(DEPLOYER);
        (auto_data.total_shares, auto_data.performance_fee, auto_data.call_fee, auto_data.withdraw_fee, auto_data.withdraw_fee_period, auto_data.last_harvested_time)
    }

    #[test_only]
    const INIT_COIN:u64 = 100000000000000000;
    #[test_only]
    const TEST_ERROR:u64 = 10000;

    #[test_only]
    public fun test_init(creator: &signer, someone_else: &signer) {
        BubbleMasterChefV1::test_init(creator, someone_else);
        init_module(creator);
    }

    #[test_only]
    public fun test_init_another(creator: &signer, someone_else: &signer, another_one: &signer) {
        BubbleMasterChefV1::test_init_another(creator, someone_else, another_one);
        init_module(creator);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_deposit_withdraw_1(creator: &signer, someone_else: &signer) acquires AutoANIData, UserInfo, Events {
        test_init(creator, someone_else);
        let amount = 100000000;
        let (_total_shares, _performance_fee, _call_fee, withdraw_fee, _withdraw_fee_period, _last_harvested_time) = get_auto_ANI_data();

        deposit(someone_else, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount, TEST_ERROR);
        withdraw_all(someone_else);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount * withdraw_fee / 10000, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_deposit_withdraw_2(creator: &signer, someone_else: &signer) acquires AutoANIData, UserInfo, Events {
        test_init(creator, someone_else);
        let amount = 100000000;
        let (_total_shares, _performance_fee, _call_fee, _withdraw_fee, _withdraw_fee_period, _last_harvested_time) = get_auto_ANI_data();

        deposit(someone_else, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount, TEST_ERROR);
        timestamp::fast_forward_seconds(_withdraw_fee_period + 1);
        withdraw_all(someone_else);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_deposit_withdraw_3(creator: &signer, someone_else: &signer) acquires AutoANIData, UserInfo, Events {
        test_init(creator, someone_else);
        let amount = 100000000;

        deposit(someone_else, amount * 2);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - 2 * amount, TEST_ERROR);
        timestamp::fast_forward_seconds(86400 * 10);
        withdraw(someone_else, (amount as u128));
        withdraw_all(someone_else);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN + 86400 * 10 * 9 / 10 * 100000000, TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_two_account_1(creator: &signer, someone_else: &signer, another_one: &signer) acquires AutoANIData, UserInfo, Events {
        test_init_another(creator, someone_else, another_one);
        let amount = 100000000;

        deposit(someone_else, amount);
        BubbleMasterChefV1::enter_staking(another_one, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount, TEST_ERROR);
        assert!(coin::balance<ANI>(signer::address_of(another_one)) == INIT_COIN - amount, TEST_ERROR);
        timestamp::fast_forward_seconds(86400 * 5);
        harvest(someone_else);
        timestamp::fast_forward_seconds(86400 * 5);
        harvest(someone_else);
        timestamp::fast_forward_seconds(86400 * 5);
        withdraw_all(someone_else);
        BubbleMasterChefV1::leave_staking(another_one, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) > coin::balance<ANI>(signer::address_of(another_one)), TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_two_account_2(creator: &signer, someone_else: &signer, another_one: &signer) acquires AutoANIData, UserInfo, Events {
        test_init_another(creator, someone_else, another_one);
        let amount = 100000000;

        deposit(someone_else, amount);
        BubbleMasterChefV1::enter_staking(another_one, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount, TEST_ERROR);
        assert!(coin::balance<ANI>(signer::address_of(another_one)) == INIT_COIN - amount, TEST_ERROR);
        timestamp::fast_forward_seconds(86400 * 5);
        harvest(someone_else);
        timestamp::fast_forward_seconds(86400 * 5);
        withdraw_all(someone_else);
        BubbleMasterChefV1::leave_staking(another_one, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) < coin::balance<ANI>(signer::address_of(another_one)), TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11, another_one = @0x12)]
    public entry fun test_two_account_3(creator: &signer, someone_else: &signer, another_one: &signer) acquires AutoANIData, UserInfo, Events {
        test_init_another(creator, someone_else, another_one);
        let amount = 100000000;

        deposit(someone_else, amount);
        BubbleMasterChefV1::enter_staking(another_one, amount);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) == INIT_COIN - amount, TEST_ERROR);
        assert!(coin::balance<ANI>(signer::address_of(another_one)) == INIT_COIN - amount, TEST_ERROR);

        timestamp::fast_forward_seconds(86400 * 5);
        deposit(someone_else, amount);
        BubbleMasterChefV1::enter_staking(another_one, amount);
        assert!(BubbleMasterChefV1::pending_ANI<ANI>(signer::address_of(another_one)) == 0, TEST_ERROR);

        timestamp::fast_forward_seconds(86400 * 5);
        BubbleMasterChefV1::leave_staking(another_one, amount * 2);
        withdraw_all(someone_else);
        assert!(coin::balance<ANI>(signer::address_of(someone_else)) < coin::balance<ANI>(signer::address_of(another_one)), TEST_ERROR);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    #[expected_failure(abort_code = 105)]
    public entry fun test_pause_1(creator: &signer, someone_else: &signer) acquires AutoANIData, UserInfo, Events {
        test_init(creator, someone_else);
        pause(creator);
        deposit(someone_else, 10000);
    }

    #[test(creator = @MasterChefDepolyer, someone_else = @0x11)]
    public entry fun test_pause_2(creator: &signer, someone_else: &signer) acquires AutoANIData, UserInfo, Events {
        test_init(creator, someone_else);
        pause(creator);
        unpause(creator);
        deposit(someone_else, 10000);
    }
}
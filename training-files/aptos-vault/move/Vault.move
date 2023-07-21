module DuckyVault::vault {
    use std::signer;
    use std::error;
    use aptos_std::event::{ Self, EventHandle };
    use aptos_std::table::{ Self, Table };
    use aptos_framework::coin::{ Self, Coin };
    use aptos_framework::account::{ Self, SignerCapability };

    ////////////////////
    // Constants
    ////////////////////

    /// Seed to generate a new Resource Account
    const SEED: vector<u8> = vector<u8>[6, 9, 4, 2, 0];

    ////////////////////
    // Error Constants
    ////////////////////

    /// Signer is not DuckyVault (Signer is not Admin)
    const ESIGNER_NOT_VAULT: u64 = 0;
    /// Deposits and Withdrawals are Paused
    const EVAULTS_PAUSED: u64 = 1;
    /// Vault doesn't exists for given User
    const ENO_VAULT: u64 = 2;
    /// Amount givent is Zero (0)
    const ECANNOT_BE_ZERO: u64 = 3;
    /// User doesn't have enough Coins in their account or Vault
    const ENOT_ENOUGH_COINS: u64 = 4;
    /// Deposists and Withdrawals are already Paused
    const EALREADY_PAUSED: u64 = 5;
    /// Deposists and Withdrawals are already Unpased
    const EALREADY_UNPAUSED: u64 = 6;

    ////////////////////
    // Resource Structs
    ////////////////////

    /// @dev This struct stores Coins on user's behalf
    /// @custom:type-param Type of the Coin to create a Vault for
    /// @custom:ability Can be stored inside resources
    struct Vault<phantom CoinType> has store {
        coin: Coin<CoinType>,
    }

    /// @dev This struct stores Vaults
    /// @custom:type-param Type of the Coin to create a VaultsHolder for
    /// @custom:ability Can be stored inside global storage
    struct VaultsHolder<phantom CoinType> has key {
        vaults: Table<address, Vault<CoinType>>,
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    /// @dev This struct stores signer capability for Vaults resource account and state of vaults
    /// @custom:ability Can be stored inside global storage
    struct VaultsInfo has key {
        signer_cap: SignerCapability,
        paused: bool,
        pause_unpause_events: EventHandle<PauseUnpauseEvent>,
    }

    ////////////////////
    // Event Structs
    ////////////////////

    struct DepositEvent has drop, store {
        user: address,
        amount: u64,
    }

    struct WithdrawEvent has drop, store {
        user: address,
        amount: u64,
    }

    struct PauseUnpauseEvent has drop, store {
        paused: bool,
    }

    ////////////////////
    // Functions
    ////////////////////

    /// @dev This function is run automatically when the module is published
    /// @param Immutable reference to the signer of the publisher, should have the same address as the module
    fun init_module(sender: &signer) {
        assert!(
            signer::address_of(sender) == @DuckyVault,
            error::permission_denied(ESIGNER_NOT_VAULT)
        );

        let (vaults_signer, signer_cap): (signer, SignerCapability) = account::create_resource_account(sender, SEED);

        move_to<VaultsInfo>(sender, VaultsInfo {
            signer_cap: signer_cap,
            paused: false,
            pause_unpause_events: account::new_event_handle<PauseUnpauseEvent>(&vaults_signer),
        });
    }

    ////////////////////
    // Entry Functions
    ////////////////////

    /// @notice Withdraw the given amount from user's account and deposist it into user's vault
    /// @custom:type-param Type of the Coin the user wants to deposit
    /// @param Immutable reference to the signer of the account that want's to deposit
    /// @param Amount of coins the user wants to deposit
    public entry fun deposit<CoinType>(
        account: &signer,
        amount: u64
    ) acquires VaultsInfo, VaultsHolder {
        assert!(amount > 0, error::invalid_argument(ECANNOT_BE_ZERO));
        let coin = coin::withdraw<CoinType>(account, amount);
        assert!(!paused(), error::permission_denied(EVAULTS_PAUSED));
        
        let vaults_info = borrow_global<VaultsInfo>(@DuckyVault);
        let vaults_signer = account::create_signer_with_capability(&vaults_info.signer_cap);
        let vaults_addr = signer::address_of(&vaults_signer);
        let account_addr = signer::address_of(account);
        
        // Checks if VaultsHolder exists for given CoinType and if not publishes a new VaultsHolder
        if (!vaults_holder_exists<CoinType>(vaults_addr)) {
            create_vaults_holder<CoinType>(&vaults_signer);
        }; 

        let vaults_holder = borrow_global_mut<VaultsHolder<CoinType>>(vaults_addr);
        let vaults = &mut vaults_holder.vaults;
        deposit_internal(vaults, account_addr, coin);
        
        emit_deposit_event(
            &mut vaults_holder.deposit_events,
            account_addr,
            amount
        );
    }

    /// @notice Withdraw the given amount from user's vault and deposist it into user's account
    /// @custom:type-param Type of the Coin the user wants to withdraw
    /// @param Immutable reference to the signer of the account that want's to withdraw
    /// @param Amount of coins the user wants to withdraw
    public entry fun withdraw<CoinType>(
        account: &signer,
        amount: u64
    ) acquires VaultsInfo, VaultsHolder {
        assert!(amount > 0, error::invalid_argument(ECANNOT_BE_ZERO));
        assert!(!paused(), error::permission_denied(EVAULTS_PAUSED));

        let vaults_info = borrow_global<VaultsInfo>(@DuckyVault);
        let vaults_signer = account::create_signer_with_capability(&vaults_info.signer_cap);
        let vaults_addr = signer::address_of(&vaults_signer);
        let account_addr = signer::address_of(account);
        assert!(vaults_holder_exists<CoinType>(vaults_addr), error::not_found(ENO_VAULT));

        let vaults_holder = borrow_global_mut<VaultsHolder<CoinType>>(vaults_addr);
        let vaults = &mut vaults_holder.vaults;
        assert!(vault_exists(vaults, account_addr), error::not_found(ENO_VAULT));
        
        let coin = withdraw_internal(vaults, account_addr, amount);
        coin::deposit<CoinType>(account_addr, coin);

        emit_withdraw_event(
            &mut vaults_holder.withdraw_events,
            account_addr,
            amount
        );
    }

    /// @notice Pause the deposit and withdraw for all vaults, can only be called by the publisher
    /// @param Immutable reference to the account with the same address as the module
    public entry fun pause(account: &signer) acquires VaultsInfo {
        assert!(
            signer::address_of(account) == @DuckyVault,
            error::permission_denied(ESIGNER_NOT_VAULT)
        );
        assert!(!paused(), error::invalid_state(EALREADY_PAUSED));
        
        let vaults_info = borrow_global_mut<VaultsInfo>(@DuckyVault);
        vaults_info.paused = true;

        emit_pause_unpause_event(
            &mut vaults_info.pause_unpause_events,
            true
        );
    }

    /// @notice Unpause the deposit and withdraw for all vaults, can only be called by the publisher
    /// @param Immutable reference to the account with the same address as the module
    public entry fun unpause(account: &signer) acquires VaultsInfo {
        assert!(
            signer::address_of(account) == @DuckyVault,
            error::permission_denied(ESIGNER_NOT_VAULT)
        );
        assert!(paused(), error::invalid_state(EALREADY_UNPAUSED));
        
        let vaults_info = borrow_global_mut<VaultsInfo>(@DuckyVault);
        vaults_info.paused = false;

        emit_pause_unpause_event(
            &mut vaults_info.pause_unpause_events,
            false
        );
    }

    ////////////////////
    // Helper Functions
    ////////////////////

    /// @dev Deposist coins into given user's vault
    /// @custom:type-param Type of Coin to deposit
    /// @param Mutable references to Table of Vaults
    /// @param Address of the account of vault owner to deposit coins into
    /// @param Coin to be deposited
    fun deposit_internal<CoinType>(
        vaults: &mut Table<address, Vault<CoinType>>,
        account_addr: address,
        coin: Coin<CoinType>,
    ) {
        // Checks if a Vault exists for the address for given CoinType and if not publishes
        //  a new Vault for the address and deposits the Coins into that Vault
        if (vault_exists(vaults, account_addr)) {
            let vault = table::borrow_mut<address, Vault<CoinType>>(vaults, account_addr);
            coin::merge<CoinType>(&mut vault.coin, coin);
        } else {
            create_vault<CoinType>(vaults, account_addr, coin);
        };
    }


    /// @dev Withdraw coins from given user's vault
    /// @custom:type-param Type of Coin to withdraw
    /// @param Mutable references to Table of Vaults
    /// @param Address of the account of vault owner to withdraw coins from
    /// @param Amount of coins to be withdrawn
    /// @return Coins of given amount from given user's vault
    fun withdraw_internal<CoinType>(
        vaults: &mut Table<address, Vault<CoinType>>,
        account_addr: address,
        amount: u64
    ): Coin<CoinType> {
        let vault = table::borrow_mut<address, Vault<CoinType>>(vaults, account_addr);
        let coin = &mut vault.coin;

        assert!(coin::value<CoinType>(coin) >= amount, error::invalid_argument(ENOT_ENOUGH_COINS));
        coin::extract<CoinType>(coin, amount)
    }

    /// @dev Create a VaultsHolder for a CoinType
    /// @custom:type-param Type of Coin to publish a VaultsHolder for
    /// @param Immutable reference to the signer of vaults' address
    fun create_vaults_holder<CoinType>(vaults_signer: &signer) {
        move_to<VaultsHolder<CoinType>>(vaults_signer, VaultsHolder<CoinType> {
            vaults: table::new<address, Vault<CoinType>>(),
            deposit_events: account::new_event_handle<DepositEvent>(vaults_signer),
            withdraw_events: account::new_event_handle<WithdrawEvent>(vaults_signer),
        });
    }

    /// @dev Create a Vault for user for CoinType
    /// @custom:type-param Type of Coin to publish a Vault for
    /// @param Mutable reference to Table of Vaults
    /// @param Address of user to create Vault for
    /// @param Coin to deposit into the newly created vault
    fun create_vault<CoinType>(
        vaults: &mut Table<address, Vault<CoinType>>,
        account_addr: address,
        coin: Coin<CoinType>,
    ) {
        table::add<address, Vault<CoinType>>(vaults, account_addr, Vault {
            coin: coin,
        });
    }

    /// @dev Check if VaultsHolder exists for given CoinType
    /// @custom:type-param Type of Coin to check VaultsHolder for
    /// @param Address of vaults resource account
    /// @return Whether VaultsHolder for the given CoinType exists or not
    fun vaults_holder_exists<CoinType>(vaults_addr: address): bool {
        exists<VaultsHolder<CoinType>>(vaults_addr)
    }

    /// @dev Check if deposit and withdraw is paused for vaults
    /// @return Whether deposit and withdraw is paused for vaults
    fun paused(): bool acquires VaultsInfo {
        borrow_global<VaultsInfo>(@DuckyVault).paused
    }

    /// @dev Check if Vault exists for a CoinType for a Account
    /// @custom:type-param Type of Coin to check if Vault exists for a Account
    /// @param Immutable reference to Table of Vaults
    /// @param Account address to check for if Vault exists or not
    /// @return Whether Vault exists for give CoinType for the given Account
    fun vault_exists<CoinType>(
        vaults: &Table<address, Vault<CoinType>>,
        account_addr: address
    ): bool {
        table::contains<address, Vault<CoinType>>(vaults, account_addr)
    }


    /// @dev Emit DepositEvent
    /// @param Mutable reference to EventHandle of DepositEvent type
    /// @param Address of the user who deposited into Vault
    /// @parm Amount deposited into Vault
    fun emit_deposit_event(
        deposit_events: &mut EventHandle<DepositEvent>,
        user: address,
        amount: u64
    ) {
        event::emit_event<DepositEvent>(
            deposit_events,
            DepositEvent {
                user: user,
                amount: amount,
            }
        );
    }

    ////////////////////
    // Event Functions
    ////////////////////

    /// @dev Emit WithdrawEvent
    /// @param Mutable reference to EventHandle of WithdrawEvent type
    /// @param Address of the user who withdrew from Vault
    /// @parm Amount withdrawn from Vault
    fun emit_withdraw_event(
        withdraw_events: &mut EventHandle<WithdrawEvent>,
        user: address,
        amount: u64
    ) {
        event::emit_event<WithdrawEvent>(
            withdraw_events,
            WithdrawEvent {
                user: user,
                amount: amount,
            }
        );
    }

    /// @dev Emit PauseUnpuaseEvent
    /// @param Mutable reference to EventHandle of PauseUnpauseEvent Type
    /// @param Boolean whether the deposit and withdrawal is paused or not for Vaults 
    fun emit_pause_unpause_event(
        pause_unpause_events: &mut EventHandle<PauseUnpauseEvent>,
        paused: bool
    ) {
         event::emit_event<PauseUnpauseEvent>(
            pause_unpause_events,
            PauseUnpauseEvent {
                paused: paused
            }
        );
    }

    ////////////////////
    // TESTS
    ////////////////////

    #[test_only]
    struct TestCoin {}

    #[test_only]
    fun setup(ducky: &signer, user: &signer) {
        use aptos_framework::managed_coin;

        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        account::create_account_for_test(@DuckyVault);

        init_module(ducky);

        managed_coin::initialize<TestCoin>(
            ducky,
            b"Test Coin",
            b"TEST",
            8,
            false
        );

        managed_coin::register<TestCoin>(user);

        managed_coin::mint<TestCoin>(
            ducky,
            user_addr,
            420
        );
    }

    #[test_only]
    fun balance<CoinType>(account_addr: address): u64 acquires VaultsInfo, VaultsHolder {
        let vaults_info = borrow_global<VaultsInfo>(@DuckyVault);
        let vaults_addr = account::get_signer_capability_address(&vaults_info.signer_cap);
        let vaults_holder = borrow_global<VaultsHolder<CoinType>>(vaults_addr);
        let vaults = &vaults_holder.vaults;
        let vault = table::borrow<address, Vault<CoinType>>(vaults, account_addr);
        let coin = &vault.coin;

        coin::value<CoinType>(coin)
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_vaults_info_published(
        ducky: signer,
        user: signer
    ) {
        setup(&ducky, &user);
        assert!(exists<VaultsInfo>(@DuckyVault), 0);
    }

    #[test(publisher = @0x03, user = @0x4)]
    #[expected_failure(abort_code = 327680)]
    fun test_should_abort_if_anyone_other_than_ducky_vault_tries_to_deploy_vault_info(
        publisher: signer,
        user: signer
    ) {
        setup(&publisher, &user);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_user_can_deposit_coin_into_vault(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        let user_addr = signer::address_of(&user);

        setup(&ducky, &user);
        assert!(coin::balance<TestCoin>(user_addr) == 420, 0);
        deposit<TestCoin>(&user, 69);
        assert!(coin::balance<TestCoin>(user_addr) == 351, 1);
        assert!(balance<TestCoin>(user_addr) == 69, 2);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_should_create_new_vaults_holder_on_deposit_for_new_coin_type(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);

        let vaults_info = borrow_global<VaultsInfo>(@DuckyVault);
        let vaults_addr = account::get_signer_capability_address(&vaults_info.signer_cap);

        assert!(!vaults_holder_exists<TestCoin>(vaults_addr), 0);
        deposit<TestCoin>(&user, 69);
        assert!(vaults_holder_exists<TestCoin>(vaults_addr), 1);
    }

    #[test(ducky = @DuckyVault, user1 = @0x3, user2 = @0x4)]
    fun test_should_create_new_vault_on_first_deposit_if_vaults_holder_exists(
        ducky: signer,
        user1: signer,
        user2: signer
    ) acquires VaultsInfo, VaultsHolder {
        let user2_addr = signer::address_of(&user2);
        account::create_account_for_test(user2_addr);

        setup(&ducky, &user1);
        coin::register<TestCoin>(&user2);
        coin::transfer<TestCoin>(&user1, user2_addr, 69);
        deposit<TestCoin>(&user1, 69);

        let vaults_info = borrow_global<VaultsInfo>(@DuckyVault);
        let vaults_addr = account::get_signer_capability_address(&vaults_info.signer_cap);

        {    
            let vaults_holder = borrow_global<VaultsHolder<TestCoin>>(vaults_addr);
            let vaults = &vaults_holder.vaults;
            assert!(!vault_exists<TestCoin>(vaults, user2_addr), 0);
        };

        deposit<TestCoin>(&user2, 69);

        {
            let vaults_holder = borrow_global<VaultsHolder<TestCoin>>(vaults_addr);
            let vaults = &vaults_holder.vaults;
            assert!(vault_exists<TestCoin>(vaults, user2_addr), 1)
        };
    }

    #[test(ducky = @DuckyVault, user1 = @0x3, user2 = @0x4)]
    fun test_should_only_deposit_into_users_own_vault(
        ducky: signer,
        user1: signer,
        user2: signer
    ) acquires VaultsInfo, VaultsHolder {
        let user1_addr = signer::address_of(&user1);
        let user2_addr = signer::address_of(&user2);
        account::create_account_for_test(user2_addr);

        setup(&ducky, &user1);
        coin::register<TestCoin>(&user2);
        coin::transfer<TestCoin>(&user1, user2_addr, 69);
        deposit<TestCoin>(&user1, 69);
        assert!(balance<TestCoin>(user1_addr) == 69, 0);

        deposit<TestCoin>(&user2, 59);
        assert!(balance<TestCoin>(user1_addr) == 69, 1);
        assert!(balance<TestCoin>(user2_addr) == 59, 2);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 65539)]
    fun test_deposit_should_abort_if_amount_equals_zero(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        deposit<TestCoin>(&user, 0);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 65542)]
    fun test_deposit_should_abort_if_users_balance_is_less_than_amount(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        deposit<TestCoin>(&user, 500);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_user_can_withdraw_coins_from_vault(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        let user_addr = signer::address_of(&user);
        setup(&ducky, &user);

        deposit<TestCoin>(&user, 69);
        assert!(coin::balance<TestCoin>(user_addr) == 351, 0);
        assert!(balance<TestCoin>(user_addr) == 69, 1);
        withdraw<TestCoin>(&user, 69);
        assert!(coin::balance<TestCoin>(user_addr) == 420, 2);
        assert!(balance<TestCoin>(user_addr) == 0, 3);
    }

    #[test(ducky = @DuckyVault, user1 = @0x3, user2 = @0x4)]
    fun test_should_only_withdraw_from_users_own_vault(
        ducky: signer,
        user1: signer,
        user2: signer
    ) acquires VaultsInfo, VaultsHolder {
        let user1_addr = signer::address_of(&user1);
        let user2_addr = signer::address_of(&user2);
        account::create_account_for_test(user2_addr);

        setup(&ducky, &user1);
        coin::register<TestCoin>(&user2);
        coin::transfer<TestCoin>(&user1, user2_addr, 69);
        deposit<TestCoin>(&user1, 59);
        deposit<TestCoin>(&user2, 69);
        assert!(coin::balance<TestCoin>(user1_addr) == 292, 0);
        assert!(balance<TestCoin>(user1_addr) == 59, 1);
        assert!(coin::balance<TestCoin>(user2_addr) == 0, 2);
        assert!(balance<TestCoin>(user2_addr) == 69, 3);
        
        withdraw<TestCoin>(&user1, 59);
        assert!(coin::balance<TestCoin>(user1_addr) == 351, 4);
        assert!(balance<TestCoin>(user1_addr) == 0, 5);
        assert!(coin::balance<TestCoin>(user2_addr) == 0, 6);
        assert!(balance<TestCoin>(user2_addr) == 69, 7);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 393218)]
    fun test_should_abort_if_vault_does_not_exist(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        withdraw<TestCoin>(&user, 69);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 65539)]
    fun test_withdraw_should_abort_if_amount_equals_zero(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        deposit<TestCoin>(&user, 69);
        withdraw<TestCoin>(&user, 0);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_should_pause_vaults(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        
        assert!(!paused(), 0);
        pause(&ducky);
        assert!(paused(), 1);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 327680)]
    fun test_should_abort_if_anyone_other_than_ducky_vault_tries_to_call_pause(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        pause(&user);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 196613)]
    fun test_should_abort_if_already_paused(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        pause(&ducky);
        pause(&ducky);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 327681)]
    fun test_should_abort_deposit_if_paused(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        pause(&ducky);
        deposit<TestCoin>(&user, 69);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 327681)]
    fun test_should_abort_withdraw_if_paused(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo, VaultsHolder {
        setup(&ducky, &user);
        deposit<TestCoin>(&user, 69);
        pause(&ducky);
        withdraw<TestCoin>(&user, 69);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    fun test_should_unpause_vaults(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        pause(&ducky);
        assert!(paused(), 0);
        unpause(&ducky);
        assert!(!paused(), 1);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 327680)]
    fun test_should_abort_if_anyone_other_than_ducky_vault_tries_to_call_unpause(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        pause(&user);
        unpause(&user);
    }

    #[test(ducky = @DuckyVault, user = @0x3)]
    #[expected_failure(abort_code = 196614)]
    fun test_should_abort_if_already_unpaused(
        ducky: signer,
        user: signer
    ) acquires VaultsInfo {
        setup(&ducky, &user);
        unpause(&ducky);
    }
}
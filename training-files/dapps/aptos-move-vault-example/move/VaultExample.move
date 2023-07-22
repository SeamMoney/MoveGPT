module VaultExample::Vault {
    use std::option;
    use std::signer;
    use std::managed_coin;
    use aptos_framework::coin;

    /// Error codes
    const ENOT_PUBLISHED: u64 = 0;
    const EALREADY_PUBLISHED: u64 = 1;
    const EVAULT_IS_PAUSED: u64 = 2;
    const EVAULT_NOT_PAUSED: u64 = 3;
    const ENO_CAPABILITIES: u64 = 4;
    const ECOIN_NOT_INITIALIZED: u64 = 5;
    const EINCORRECT_VAULT_VALUE: u64 = 6;
    const EINCORRECT_BALANCE: u64 = 7;
    const EINCORRECT_SUPPLY: u64 = 8;

    struct Vault<phantom CoinType> has key {
        value: u64
    }

    struct VaultStatus has key {
        is_paused: bool,
    }

    struct PauseCapability has copy, key, store {}

    struct Capabilities has key {
        pause_cap: PauseCapability,
    }

    fun initialize(account: &signer) {
        move_to(account, VaultStatus {
            is_paused: false,
        });
        move_to(account, Capabilities {
            pause_cap: PauseCapability {},
        });
    }

    public fun register<CoinType>(account: &signer) {
        assert!(!exists<Vault<CoinType>>(signer::address_of(account)), EALREADY_PUBLISHED);
        managed_coin::register<CoinType>(account);
        move_to(
            account,
            Vault<CoinType> { value: 0 }
        );
    }

    public fun deposit<CoinType>(addr: address, amount: u64) acquires VaultStatus, Vault {
        assert!(borrow_global_mut<VaultStatus>(@VaultExample).is_paused == false, EVAULT_IS_PAUSED);
        assert!(exists<Vault<CoinType>>(addr), ENOT_PUBLISHED);

        let value = &mut borrow_global_mut<Vault<CoinType>>(addr).value;
        *value = *value + amount;
    }

    public fun withdraw<CoinType>(addr: address, amount: u64) acquires VaultStatus, Vault {
        assert!(borrow_global_mut<VaultStatus>(@VaultExample).is_paused == false, EVAULT_IS_PAUSED);
        assert!(exists<Vault<CoinType>>(addr), ENOT_PUBLISHED);

        let value = &mut borrow_global_mut<Vault<CoinType>>(addr).value;
        *value = *value - amount;
    }

    public fun pause(account: &signer) acquires VaultStatus {
        assert!(
            exists<Capabilities>(signer::address_of(account)),
            ENO_CAPABILITIES,
        );
        let vault_status = borrow_global_mut<VaultStatus>(signer::address_of(account));
        vault_status.is_paused = true;
    }

    public fun unpause(account: &signer) acquires VaultStatus {
        assert!(
            exists<Capabilities>(signer::address_of(account)),
            ENO_CAPABILITIES,
        );
        let vault_status = borrow_global_mut<VaultStatus>(signer::address_of(account));
        vault_status.is_paused = false;
    }

    #[test_only]
    struct MyTestCoin1 {}
    struct MyTestCoin2 {}

    #[test(account = @VaultExample)]
    public entry fun module_can_initialize(account: signer) {
        let addr = signer::address_of(&account);

        assert!(!exists<VaultStatus>(addr), 0);
        assert!(!exists<Capabilities>(addr), 0);

        initialize(&account);

        assert!(exists<VaultStatus>(addr), 0);
        assert!(exists<Capabilities>(addr), 0);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    public entry fun user_can_register_vaults(account1: signer, account2: signer) {
        initialize(&account1);
        let addr2 = signer::address_of(&account2);

        assert!(!exists<Vault<MyTestCoin1>>(addr2), EALREADY_PUBLISHED);
        assert!(!exists<Vault<MyTestCoin2>>(addr2), EALREADY_PUBLISHED);

        register<MyTestCoin1>(&account2);

        assert!(exists<Vault<MyTestCoin1>>(addr2), EALREADY_PUBLISHED);
        assert!(!exists<Vault<MyTestCoin2>>(addr2), EALREADY_PUBLISHED);

        register<MyTestCoin2>(&account2);

        assert!(exists<Vault<MyTestCoin1>>(addr2), EALREADY_PUBLISHED);
        assert!(exists<Vault<MyTestCoin2>>(addr2), EALREADY_PUBLISHED);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    public entry fun user_can_deposit(account1: signer, account2: signer) acquires VaultStatus, Vault {
        let addr2 = signer::address_of(&account2);
        initialize(&account1);

        managed_coin::initialize<MyTestCoin1>(&account1, b"MyTestCoin1", b"MTC", 10, true);
        assert!(coin::is_coin_initialized<MyTestCoin1>(), ECOIN_NOT_INITIALIZED);

        register<MyTestCoin1>(&account2);

        managed_coin::mint<MyTestCoin1>(&account1, addr2, 10);
        assert!(coin::balance<MyTestCoin1>(addr2) == 10, EINCORRECT_BALANCE);

        let supply = coin::supply<MyTestCoin1>();
        assert!(option::is_some(&supply), 1);
        assert!(option::extract(&mut supply) == 10, EINCORRECT_SUPPLY);

        let value = borrow_global<Vault<MyTestCoin1>>(addr2).value;
        assert!(value == 0, EINCORRECT_VAULT_VALUE);

        deposit<MyTestCoin1>(addr2, 10);

        let value = borrow_global<Vault<MyTestCoin1>>(addr2).value;
        assert!(value == 10, EINCORRECT_VAULT_VALUE);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    public entry fun user_can_withdraw(account1: signer, account2: signer) acquires VaultStatus, Vault {
        let addr2 = signer::address_of(&account2);
        initialize(&account1);

        managed_coin::initialize<MyTestCoin1>(&account1, b"MyTestCoin1", b"MTC", 10, true);
        assert!(coin::is_coin_initialized<MyTestCoin1>(), ECOIN_NOT_INITIALIZED);

        register<MyTestCoin1>(&account2);

        managed_coin::mint<MyTestCoin1>(&account1, addr2, 10);
        assert!(coin::balance<MyTestCoin1>(addr2) == 10, EINCORRECT_BALANCE);

        let supply = coin::supply<MyTestCoin1>();
        assert!(option::is_some(&supply), 1);
        assert!(option::extract(&mut supply) == 10, EINCORRECT_SUPPLY);

        deposit<MyTestCoin1>(addr2, 10);

        let value = borrow_global<Vault<MyTestCoin1>>(addr2).value;
        assert!(value == 10, EINCORRECT_VAULT_VALUE);

        withdraw<MyTestCoin1>(addr2, 10);

        let value = borrow_global<Vault<MyTestCoin1>>(addr2).value;
        assert!(value == 0, EINCORRECT_VAULT_VALUE);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    #[expected_failure(abort_code = 2)]
    public entry fun user_cannot_deposit_when_vault_is_paused(account1: signer, account2: signer) acquires VaultStatus, Vault {
        let addr2 = signer::address_of(&account2);
        initialize(&account1);

        managed_coin::initialize<MyTestCoin1>(&account1, b"MyTestCoin1", b"MTC", 10, true);
        assert!(coin::is_coin_initialized<MyTestCoin1>(), ECOIN_NOT_INITIALIZED);

        register<MyTestCoin1>(&account2);

        managed_coin::mint<MyTestCoin1>(&account1, addr2, 10);
        assert!(coin::balance<MyTestCoin1>(addr2) == 10, EINCORRECT_BALANCE);

        let supply = coin::supply<MyTestCoin1>();
        assert!(option::is_some(&supply), 1);
        assert!(option::extract(&mut supply) == 10, EINCORRECT_SUPPLY);

        pause(&account1);

        deposit<MyTestCoin1>(addr2, 10);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    #[expected_failure(abort_code = 2)]
    public entry fun user_cannot_withdraw_when_vault_is_paused(account1: signer, account2: signer) acquires VaultStatus, Vault {
        let addr2 = signer::address_of(&account2);
        initialize(&account1);

        managed_coin::initialize<MyTestCoin1>(&account1, b"MyTestCoin1", b"MTC", 10, true);
        assert!(coin::is_coin_initialized<MyTestCoin1>(), ECOIN_NOT_INITIALIZED);

        register<MyTestCoin1>(&account2);

        managed_coin::mint<MyTestCoin1>(&account1, addr2, 10);
        assert!(coin::balance<MyTestCoin1>(addr2) == 10, EINCORRECT_BALANCE);

        let supply = coin::supply<MyTestCoin1>();
        assert!(option::is_some(&supply), 1);
        assert!(option::extract(&mut supply) == 10, EINCORRECT_SUPPLY);

        deposit<MyTestCoin1>(addr2, 10);

        pause(&account1);

        withdraw<MyTestCoin1>(addr2, 10);
    }

    #[test(account = @VaultExample)]
    public entry fun admin_can_pause(account: signer) acquires VaultStatus {
        let addr = signer::address_of(&account);
        initialize(&account);

        let is_paused = borrow_global<VaultStatus>(addr).is_paused;
        assert!(is_paused == false, EVAULT_IS_PAUSED);

        pause(&account);

        let is_paused = borrow_global<VaultStatus>(addr).is_paused;
        assert!(is_paused == true, EVAULT_NOT_PAUSED);
    }

    #[test(account = @VaultExample)]
    public entry fun admin_can_unpause(account: signer) acquires VaultStatus {
        let addr = signer::address_of(&account);
        initialize(&account);

        pause(&account);

        let is_paused = borrow_global<VaultStatus>(addr).is_paused;
        assert!(is_paused == true, EVAULT_NOT_PAUSED);

        unpause(&account);

        let is_paused = borrow_global<VaultStatus>(addr).is_paused;
        assert!(is_paused == false, EVAULT_IS_PAUSED);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    #[expected_failure(abort_code = 4)]
    public entry fun non_admin_cannot_pause(account1: signer, account2: signer) acquires VaultStatus {
        let addr1 = signer::address_of(&account1);
        initialize(&account1);

        let is_paused = borrow_global<VaultStatus>(addr1).is_paused;
        assert!(is_paused == false, EVAULT_IS_PAUSED);

        pause(&account2);

        let is_paused = borrow_global<VaultStatus>(addr1).is_paused;
        assert!(is_paused == false, EVAULT_IS_PAUSED);
    }

    #[test(account1 = @VaultExample, account2 = @Alice)]
    #[expected_failure(abort_code = 4)]
    public entry fun non_admin_cannot_unpause(account1: signer, account2: signer) acquires VaultStatus {
        let addr1 = signer::address_of(&account1);
        initialize(&account1);

        pause(&account1);

        let is_paused = borrow_global<VaultStatus>(addr1).is_paused;
        assert!(is_paused == true, EVAULT_NOT_PAUSED);

        unpause(&account2);

        let is_paused = borrow_global<VaultStatus>(addr1).is_paused;
        assert!(is_paused == true, EVAULT_NOT_PAUSED);
    }
}

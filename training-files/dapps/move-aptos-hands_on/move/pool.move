module handson::pool {
    use std::string;
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::managed_coin;

    struct HandsonCoin {}
    struct LpHandsonCoin {}
    struct CapabilitiesForLp has key {
        burn_cap: coin::BurnCapability<LpHandsonCoin>,
        freeze_cap: coin::FreezeCapability<LpHandsonCoin>,
        mint_cap: coin::MintCapability<LpHandsonCoin>,
    }

    struct Pool has key {
        balance: coin::Coin<HandsonCoin>
    }

    // for event
    struct DepositEvent has store, drop {
        caller: address,
        amount: u64,
    }
    struct WithdrawEvent has store, drop {
        caller: address,
        amount: u64,
    }
    struct PoolEventHandle has key, store {
        deposit_event: event::EventHandle<DepositEvent>,
        withdraw_event: event::EventHandle<WithdrawEvent>,
    }

    fun owner(): address {
        @handson
    }

    public entry fun initialize(owner: &signer) {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == owner(), 1);
        assert!(!exists<Pool>(signer::address_of(owner)), 2);
        move_to(owner, Pool {
            balance: coin::zero<HandsonCoin>()
        });
        managed_coin::initialize<HandsonCoin>(
            owner,
            b"Handson Coin",
            b"HANDSON",
            0,
            false
        );
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LpHandsonCoin>(
            owner,
            string::utf8(b"Lp Handson Coin"),
            string::utf8(b"LPHANDSON"),
            0,
            false
        );
        move_to(owner, CapabilitiesForLp {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
        move_to(owner, PoolEventHandle {
            deposit_event: account::new_event_handle<DepositEvent>(owner),
            withdraw_event: account::new_event_handle<WithdrawEvent>(owner),
        });
    }

    public entry fun register(account: &signer) {
        coin::register<HandsonCoin>(account);
        coin::register<LpHandsonCoin>(account);
    }

    public entry fun deposit(account: &signer, amount: u64) acquires Pool, CapabilitiesForLp, PoolEventHandle {
        let coin = coin::withdraw<HandsonCoin>(account, amount);
        let pool_ref = borrow_global_mut<Pool>(owner());
        coin::merge(&mut pool_ref.balance, coin);

        // for lpcoin
        let cap = &borrow_global<CapabilitiesForLp>(owner()).mint_cap;
        let lpcoin = coin::mint(amount, cap);
        coin::deposit(signer::address_of(account), lpcoin);

        event::emit_event<DepositEvent>(
            &mut borrow_global_mut<PoolEventHandle>(owner()).deposit_event,
            DepositEvent {
                caller: signer::address_of(account),
                amount,
            },
        );
    }

    public entry fun withdraw(account: &signer, amount: u64) acquires Pool, CapabilitiesForLp, PoolEventHandle {
        let coin = coin::extract(&mut borrow_global_mut<Pool>(owner()).balance, amount);
        coin::deposit(signer::address_of(account), coin);

        // for lpcoin
        let lpcoin = coin::withdraw<LpHandsonCoin>(account, amount);
        let cap = &borrow_global<CapabilitiesForLp>(owner()).burn_cap;
        coin::burn(lpcoin, cap);

        event::emit_event<WithdrawEvent>(
            &mut borrow_global_mut<PoolEventHandle>(owner()).withdraw_event,
            WithdrawEvent {
                caller: signer::address_of(account),
                amount,
            },
        );
    }

    #[test_only]
    use aptos_framework::account;
    #[test(owner = @handson)]
    fun test_initialize(owner: &signer) {
        account::create_account_for_test(signer::address_of(owner));
        initialize(owner);
        assert!(exists<Pool>(signer::address_of(owner)), 0);
    }
    #[test(account = @0x111)]
    #[expected_failure(abort_code = 1)]
    fun test_initialize_by_not_owner(account: &signer) {
        initialize(account);
    }
    #[test(owner = @handson)]
    #[expected_failure(abort_code = 2)]
    fun test_initialize_twice(owner: &signer) {
        account::create_account_for_test(signer::address_of(owner));
        initialize(owner);
        initialize(owner);
    }
    #[test_only]
    fun setup(owner: &signer, account: &signer) {
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(account));

        initialize(owner);
        register(account);
    }
    #[test(owner = @handson, account = @0x111)]
    fun test_deposit(owner: &signer, account: &signer) acquires Pool, CapabilitiesForLp, PoolEventHandle {
        setup(owner, account);
        let account_addr = signer::address_of(account);

        managed_coin::mint<HandsonCoin>(owner, account_addr, 100);
        deposit(account, 100);

        assert!(coin::value(&borrow_global<Pool>(signer::address_of(owner)).balance) == 100, 0);
        assert!(coin::balance<HandsonCoin>(account_addr) == 0, 0);
        assert!(coin::balance<LpHandsonCoin>(account_addr) == 100, 0);

        let event_handle = borrow_global<PoolEventHandle>(signer::address_of(owner));
        assert!(event::counter<DepositEvent>(&event_handle.deposit_event) == 1, 0);
    }
    #[test(owner = @handson, account = @0x111)]
    fun test_withdraw(owner: &signer, account: &signer) acquires Pool, CapabilitiesForLp, PoolEventHandle {
        setup(owner, account);
        let account_addr = signer::address_of(account);

        managed_coin::mint<HandsonCoin>(owner, account_addr, 100);
        deposit(account, 100);

        withdraw(account, 75);

        assert!(coin::value(&borrow_global<Pool>(signer::address_of(owner)).balance) == 25, 0);
        assert!(coin::balance<HandsonCoin>(account_addr) == 75, 0);
        assert!(coin::balance<LpHandsonCoin>(account_addr) == 25, 0);
        let event_handle = borrow_global<PoolEventHandle>(signer::address_of(owner));
        assert!(event::counter<WithdrawEvent>(&event_handle.withdraw_event) == 1, 0);
    }
}
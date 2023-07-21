module faucet::faucet {
    use std::signer;
    use std::error;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::coin::{Self, Coin};

    const ERR_NOT_AUTHORIZED: u64 = 0x1000;
    const ERR_FAUCET_EXISTS: u64 = 0x1001;
    const ERR_FAUCET_NOT_EXISTS: u64 = 0x1002;
    const ERR_RESTRICTED: u64 = 0x1003;
    const ERR_INVALID_PID: u64 = 0x1004;

    struct Faucet<phantom CoinType> has key {
        deposit: Coin<CoinType>,
        per_request: u64,
        period: u64,
    }

    struct Restricted<phantom Faucet> has key {
        since: u64,
    }

    struct Events<phantom Faucet> has key {
        request_events: EventHandle<RequestEvent>,
    }

    // Events

    struct RequestEvent has drop, store {
        to: address,
        amount: u64,
        date: u64,
    }

    /// Creates new faucet on `faucet_account` address for coin `CoinType`.
    /// faucet_account must be funded witn CoinType first.
    public entry fun create_faucet<CoinType>(faucet_account: &signer, amount_to_deposit: u64, per_request: u64, period: u64) {
        let faucet_addr = signer::address_of(faucet_account);
        assert!(faucet_addr == @faucet, error::permission_denied(ERR_NOT_AUTHORIZED));

        if (exists<Faucet<CoinType>>(faucet_addr) && exists<Events<CoinType>>(faucet_addr)) {
            assert!(false, ERR_FAUCET_EXISTS);
        };

        if (!exists<Faucet<CoinType>>(faucet_addr)) {
            let deposit = coin::withdraw<CoinType>(faucet_account, amount_to_deposit);
            move_to(faucet_account, Faucet<CoinType> {
                deposit,
                per_request,
                period,
            });
        };

        if (!exists<Events<CoinType>>(faucet_addr)) {
            move_to(faucet_account, Events<CoinType> {
                request_events: account::new_event_handle<RequestEvent>(faucet_account),
            });
        };
    }

    /// Change settings of faucet `CoinType`.
    public entry fun change_settings<CoinType>(faucet_account: &signer, per_request: u64, period: u64) acquires Faucet {
        let faucet_addr = signer::address_of(faucet_account);
        assert!(faucet_addr == @faucet, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<Faucet<CoinType>>(faucet_addr), ERR_FAUCET_NOT_EXISTS);

        let faucet = borrow_global_mut<Faucet<CoinType>>(faucet_addr);
        faucet.per_request = per_request;
        faucet.period = period;
    }

    /// Deposits coins `CoinType` to faucet on `faucet` address, withdrawing funds from user balance.
    public entry fun deposit<CoinType>(account: &signer, faucet_addr: address, amount: u64) acquires Faucet {
        let coins = coin::withdraw<CoinType>(account, amount);
        assert!(faucet_addr == @faucet, ERR_INVALID_PID);
        assert!(exists<Faucet<CoinType>>(faucet_addr), ERR_FAUCET_NOT_EXISTS);

        let faucet = borrow_global_mut<Faucet<CoinType>>(faucet_addr);
        coin::merge(&mut faucet.deposit, coins);
    }

    /// Deposits coins `CoinType` from faucet on user's account.
    public entry fun request<CoinType>(user: &signer, faucet_addr: address) acquires Faucet, Restricted, Events {
        let user_addr = signer::address_of(user);

        assert!(faucet_addr == @faucet, ERR_INVALID_PID);
        assert!(exists<Faucet<CoinType>>(faucet_addr), ERR_FAUCET_NOT_EXISTS);
        assert!(exists<Events<CoinType>>(faucet_addr), ERR_FAUCET_NOT_EXISTS);

        if (!coin::is_account_registered<CoinType>(user_addr)) {
            coin::register<CoinType>(user);
        };

        let faucet = borrow_global_mut<Faucet<CoinType>>(faucet_addr);
        let coins_to_user = coin::extract(&mut faucet.deposit, faucet.per_request);

        let now = timestamp::now_seconds();
        if (exists<Restricted<CoinType>>(user_addr)) {
            let restricted = borrow_global_mut<Restricted<CoinType>>(user_addr);
            assert!(restricted.since + faucet.period <= now, ERR_RESTRICTED);
            restricted.since = now;
        } else {
            move_to(user, Restricted<CoinType> {
                since: now,
            });
        };

        coin::deposit(user_addr, coins_to_user);

        let events = borrow_global_mut<Events<CoinType>>(faucet_addr);
        event::emit_event<RequestEvent>(
            &mut events.request_events,
            RequestEvent { to: user_addr, amount: faucet.per_request, date: now },
        );
    }

    // Test
    #[test_only]
    struct TestCoin has store {}
    #[test_only]
    struct TestCoinCaps has key {
        mint_cap: coin::MintCapability<TestCoin>,
        burn_cap: coin::BurnCapability<TestCoin>,
    }

    #[test(faucet_signer = @faucet)]
    public entry fun test_update_settings(faucet_signer: &signer) acquires Faucet {
        use std::string::utf8;
        use aptos_framework::account::create_account_for_test;

        create_account_for_test(signer::address_of(faucet_signer));
        let faucet_addr = signer::address_of(faucet_signer);

        let (burn, freeze, mint) = coin::initialize<TestCoin>(
            faucet_signer,
            utf8(b"TestCoin"),
            utf8(b"TC"),
            8,
            true
        );
        coin::destroy_freeze_cap(freeze);

        let amount = 1000000u64 * 100000000u64;
        let per_request = 1000u64 * 1000000u64;
        let period = 3000u64;

        let coins_minted = coin::mint(amount, &mint);
        coin::register<TestCoin>(faucet_signer);
        coin::deposit(faucet_addr, coins_minted);
        create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);

        // Update settings
        let new_per_request = 20u64 * 100000000u64;
        let new_period = 5000u64;
        change_settings<TestCoin>(faucet_signer, new_per_request, new_period);
        let to_check = borrow_global<Faucet<TestCoin>>(faucet_addr);
        assert!(to_check.period == new_period, 1);
        assert!(to_check.per_request == new_per_request, 2);

        move_to(faucet_signer, TestCoinCaps {
            mint_cap: mint,
            burn_cap: burn,
        });
    }
}

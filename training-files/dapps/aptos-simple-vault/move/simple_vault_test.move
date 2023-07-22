#[test_only]
module simple_vault::vault_tests {
    use std::string::utf8;
    use std::signer;
    use std::unit_test;
    use std::vector;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, };
    use aptos_framework::account;

    struct USDT {}

    struct USDC {}

    struct Capabilities<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
        burn_cap: BurnCapability<CoinType>,
    }

    use simple_vault::vault;

    public fun register_coin<CoinType>(coin_admin: &signer, name: vector<u8>, symbol: vector<u8>, decimals: u8) {
        let (burn_cap, freeze_cap, mint_cap, ) = coin::initialize<CoinType>(
            coin_admin,
            utf8(name),
            utf8(symbol),
            decimals,
            true,
        );
        coin::destroy_freeze_cap(freeze_cap);

        move_to(coin_admin, Capabilities<CoinType> {
            mint_cap,
            burn_cap,
        });
    }

    public fun create_admin(): signer {
        account::create_account_for_test(@simple_vault)
    }

    public fun create_admin_with_coins(): signer {
        let coin_admin = create_admin();
        register_coins(&coin_admin);
        coin_admin
    }

    public fun register_coins(coin_admin: &signer) {
        let (usdt_burn_cap, usdt_freeze_cap, usdt_mint_cap) =
            coin::initialize<USDT>(
                coin_admin,
                utf8(b"USDT"),
                utf8(b"USDT"),
                6,
                true
            );

        let (usdc_burn_cap, usdc_freeze_cap, usdc_mint_cap) =
            coin::initialize<USDC>(
                coin_admin,
                utf8(b"USDC"),
                utf8(b"USDC"),
                6,
                true,
            );

        move_to(coin_admin, Capabilities<USDT> {
            mint_cap: usdt_mint_cap,
            burn_cap: usdt_burn_cap,
        });

        move_to(coin_admin, Capabilities<USDC> {
            mint_cap: usdc_mint_cap,
            burn_cap: usdc_burn_cap,
        });

        coin::destroy_freeze_cap(usdt_freeze_cap);
        coin::destroy_freeze_cap(usdc_freeze_cap);
    }

    public fun mint<CoinType>(coin_admin: &signer, amount: u64): Coin<CoinType> acquires Capabilities {
        let caps = borrow_global<Capabilities<CoinType>>(signer::address_of(coin_admin));
        coin::mint(amount, &caps.mint_cap)
    }

    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    #[test]
    public entry fun test_create_storage_when_deposit_first_time() acquires Capabilities {
        let admin = create_admin_with_coins();
        let alice = get_account();
        let alice_addr = signer::address_of(&alice);

        aptos_framework::account::create_account_for_test(alice_addr);
        coin::register<USDC>(&alice);
        let new_coin = mint<USDC>(&admin, 100u64);
        coin::deposit(alice_addr, new_coin);

        vault::deposit<USDC>(&alice, 50u64);
        
        assert!(
          vault::depositedBalance<USDC>(alice_addr) == 50u64,
          0
        );
        assert!(
          coin::balance<USDC>(alice_addr) == 50u64,
          0
        );
    }

    #[test]
    public entry fun test_update_storage_when_deposit_next_time() acquires Capabilities {
        let admin = create_admin_with_coins();
        let alice = get_account();
        let alice_addr = signer::address_of(&alice);

        aptos_framework::account::create_account_for_test(alice_addr);
        coin::register<USDC>(&alice);
        let new_coin = mint<USDC>(&admin, 100u64);
        coin::deposit(alice_addr, new_coin);

        vault::deposit<USDC>(&alice, 50u64);

        vault::deposit<USDC>(&alice, 20u64);
        
        assert!(
          vault::depositedBalance<USDC>(alice_addr) == 70u64,
          0
        );
        assert!(
          coin::balance<USDC>(alice_addr) == 30u64,
          0
        );
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    public entry fun test_deposit_fail_if_paused() acquires Capabilities {
        let admin = create_admin_with_coins();

        vault::pause(&admin);

        let alice = get_account();
        let alice_addr = signer::address_of(&alice);

        aptos_framework::account::create_account_for_test(alice_addr);
        coin::register<USDC>(&alice);
        let new_coin = mint<USDC>(&admin, 100u64);
        coin::deposit(alice_addr, new_coin);

        vault::deposit<USDC>(&alice, 50u64);
    }

    #[test]
    public entry fun test_withdraw() acquires Capabilities {
        let admin = create_admin_with_coins();
        let alice = get_account();
        let alice_addr = signer::address_of(&alice);

        aptos_framework::account::create_account_for_test(alice_addr);
        coin::register<USDC>(&alice);
        let new_coin = mint<USDC>(&admin, 100u64);
        coin::deposit(alice_addr, new_coin);

        vault::deposit<USDC>(&alice, 50u64);

        vault::withdraw<USDC>(&alice, 20u64);
        
        assert!(
          vault::depositedBalance<USDC>(alice_addr) == 30u64,
          0
        );
        assert!(
          coin::balance<USDC>(alice_addr) == 70u64,
          0
        );
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    public entry fun test_withdraw_fail_if_paused() acquires Capabilities {
        let admin = create_admin_with_coins();

        let alice = get_account();
        let alice_addr = signer::address_of(&alice);

        aptos_framework::account::create_account_for_test(alice_addr);
        coin::register<USDC>(&alice);
        let new_coin = mint<USDC>(&admin, 100u64);
        coin::deposit(alice_addr, new_coin);

        vault::deposit<USDC>(&alice, 50u64);

        vault::pause(&admin);

        vault::withdraw<USDC>(&alice, 20u64);
    }

    #[test]
    public entry fun test_pause_by_owner() {
        let admin = create_admin();

        vault::pause(&admin);
        
        assert!(
          vault::paused(),
          0
        );
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    public entry fun test_pause_fail_by_non_owner() {
        let alice = get_account();

        vault::pause(&alice);
    }

    #[test]
    #[expected_failure(abort_code = 3)]
    public entry fun test_pause_fail_if_already_paused() {
        let admin = create_admin();

        vault::pause(&admin);

        vault::pause(&admin);
    }

    #[test]
    public entry fun test_unpause_by_owner() {
        let admin = create_admin();

        vault::pause(&admin);

        vault::unpause(&admin);
        
        assert!(
          vault::paused() == false,
          0
        );
    }

    #[test]
    #[expected_failure(abort_code = 2)]
    public entry fun test_unpause_fail_by_non_owner() {
        let admin = create_admin();

        vault::pause(&admin);

        let alice = get_account();

        vault::unpause(&alice);
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    public entry fun test_unpause_fail_if_already_paused() {
        let admin = create_admin();

        vault::unpause(&admin);
    }
}

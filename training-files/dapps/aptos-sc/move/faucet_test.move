#[test_only]
module faucet::faucet_tests {
    use std::signer;
    use aptos_framework::coin::{Self};
    use aptos_framework::timestamp;
    use std::string::utf8;
    use aptos_framework::account::create_account_for_test;
    use aptos_framework::genesis;

    use faucet::faucet;

    struct TestCoin has store {}

    struct TestCoinCaps has key {
        mint_cap: coin::MintCapability<TestCoin>,
        burn_cap: coin::BurnCapability<TestCoin>,
    }

    #[test(faucet_signer = @faucet)]
    public entry fun test_create_faucet(faucet_signer: &signer) {
        let faucet_addr = signer::address_of(faucet_signer);
        create_account_for_test(faucet_addr);

        let (burn, freeze, mint) = coin::initialize<TestCoin>(
            faucet_signer,
            utf8(b"TestCoin"),
            utf8(b"TC"),
            8,
            true
        );
        coin::destroy_freeze_cap(freeze);

        let amount = 1000000u64 * 100000000u64;
        let per_request = 10u64 * 100000000u64;
        let period = 3000u64;

        let coins_minted = coin::mint<TestCoin>(amount, &mint);
        coin::register<TestCoin>(faucet_signer);
        coin::deposit(faucet_addr, coins_minted);

        faucet::create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);
        assert!(coin::balance<TestCoin>(faucet_addr) == amount - (amount / 2), 1);

        move_to(faucet_signer, TestCoinCaps {
            mint_cap: mint,
            burn_cap: burn,
        });
    }

    #[test(faucet_signer = @faucet)]
    #[expected_failure(abort_code = 0x1001, location = faucet::faucet)]
    public entry fun test_already_exists(faucet_signer: &signer) {
        let faucet_addr = signer::address_of(faucet_signer);
        create_account_for_test(faucet_addr);

        let (burn, freeze, mint) = coin::initialize<TestCoin>(
            faucet_signer,
            utf8(b"TestCoin"),
            utf8(b"TC"),
            8,
            true
        );
        coin::destroy_freeze_cap(freeze);

        let amount = 1000000u64 * 100000000u64;
        let per_request = 10u64 * 100000000u64;
        let period = 3000u64;

        let coins_minted = coin::mint<TestCoin>(amount, &mint);
        coin::register<TestCoin>(faucet_signer);
        coin::deposit(faucet_addr, coins_minted);

        faucet::create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);
        // Second init for this coin failure
        faucet::create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);

        move_to(faucet_signer, TestCoinCaps {
            mint_cap: mint,
            burn_cap: burn,
        });
    }

    #[test(faucet_signer = @faucet, user = @0x11)]
    public entry fun test_request(faucet_signer: &signer, user: &signer) {
        genesis::setup();

        let faucet_addr = signer::address_of(faucet_signer);
        let user_addr = signer::address_of(user);
        create_account_for_test(faucet_addr);
        create_account_for_test(user_addr);

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
        faucet::create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);

        // User request airdrop
        faucet::request<TestCoin>(user, faucet_addr);
        assert!(coin::balance<TestCoin>(user_addr) == per_request, 1);

        timestamp::update_global_time_for_test(3000000000);

        // After time another airdrop
        faucet::request<TestCoin>(user, faucet_addr);
        assert!(coin::balance<TestCoin>(user_addr) == per_request + per_request, 2);

        move_to(faucet_signer, TestCoinCaps {
            mint_cap: mint,
            burn_cap: burn,
        });
    }

    #[test(faucet_signer = @faucet)]
    #[expected_failure(abort_code = 0x1003, location = faucet::faucet)]
    public entry fun test_faucet_fail_request(faucet_signer: &signer) {
        genesis::setup();

        let faucet_addr = signer::address_of(faucet_signer);
        create_account_for_test(faucet_addr);

        let (burn, freeze, mint) = coin::initialize<TestCoin>(
            faucet_signer,
            utf8(b"TestCoin"),
            utf8(b"TC"),
            8,
            true
        );
        coin::destroy_freeze_cap(freeze);

        let amount = 1000000u64 * 100000000u64;
        let per_request = 10u64 * 100000000u64;
        let period = 3000u64;

        let coins_minted = coin::mint(amount, &mint);
        coin::register<TestCoin>(faucet_signer);
        coin::deposit(faucet_addr, coins_minted);

        faucet::create_faucet<TestCoin>(faucet_signer, amount / 2, per_request, period);

        faucet::request<TestCoin>(faucet_signer, faucet_addr);
        // Failed request, restricted
        faucet::request<TestCoin>(faucet_signer, faucet_addr);

        move_to(faucet_signer, TestCoinCaps {
            mint_cap: mint,
            burn_cap: burn,
        });
    }
}

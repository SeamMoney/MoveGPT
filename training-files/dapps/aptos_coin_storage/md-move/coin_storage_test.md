```rust
// The file contains the test module code

#[test_only]
module coin_storage::storage_tests {
    // Import some standard common used modules
    use aptos_std::signer;
    use aptos_std::account;
    use aptos_std::string;

    // Import tested module and coin implementation
    use aptos_std::coin;
    use coin_storage::coin_storage;

    // Declare Fake Money resource
    #[test_only]
    struct FakeMoney {}

    // Helper function for generating Fake Money
    #[test_only]
    fun generate_fake_money(account: &signer) {
        let account_addr = signer::address_of(account);

        // Init coin module
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FakeMoney>(
            account,
            string::utf8(b"Fake money"),
            string::utf8(b"FMD"),
            8,
            false
        );

        // Mint token and deposit
        let coins_minted = coin::mint<FakeMoney>(100, &mint_cap);
        coin::register<FakeMoney>(account);
        coin::deposit<FakeMoney>(account_addr, coins_minted);

        // Destroy unneeded resources
        coin::destroy_freeze_cap<FakeMoney>(freeze_cap);
        coin::destroy_burn_cap<FakeMoney>(burn_cap);
        coin::destroy_mint_cap<FakeMoney>(mint_cap);
    }

    // Test case of normal flow
    #[test(source = @coin_storage)]
    public entry fun normal_flow(source: signer) {
        // It is easier to use the borrowed signer
        let account = &source;
        // Get an address of the signer
        let account_addr = signer::address_of(account);

        // Init address in the local chain
        account::create_account_for_test(account_addr);

        // Mint Fake Money
        generate_fake_money(account);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 0, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 100, 0);

        // Make a deposit
        coin_storage::deposit<FakeMoney>(account, 10);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 10, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 90, 0);

        // Make a deposit
        coin_storage::deposit<FakeMoney>(account, 5);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 15, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 85, 0);

        // Make a withdraw
        coin_storage::withdraw<FakeMoney>(account, 10);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 5, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 95, 0);

        // Make a withdraw
        coin_storage::withdraw<FakeMoney>(account, 5);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 0, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 100, 0);
    }

    // Test case of depositing/withdrawing 0
    #[test(source = @coin_storage)]
    public entry fun zero_actions(source: signer) {
        let account = &source;
        let account_addr = signer::address_of(account);

        account::create_account_for_test(account_addr);

        generate_fake_money(account);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 0, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 100, 0);

        // Storage resource non exists

        coin_storage::deposit<FakeMoney>(account, 0);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 0, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 100, 0);

        coin_storage::withdraw<FakeMoney>(account, 0);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 0, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 100, 0);

        // Create Storage resource
        coin_storage::deposit<FakeMoney>(account, 5);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 5, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 95, 0);

        // Storage resource exists

        coin_storage::deposit<FakeMoney>(account, 0);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 5, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 95, 0);

        coin_storage::withdraw<FakeMoney>(account, 0);
        assert!(coin_storage::balance<FakeMoney>(account_addr) == 5, 0);
        assert!(coin::balance<FakeMoney>(account_addr) == 95, 0);
    }

    // Test case of failing if Storage is not registered
    #[test(source = @coin_storage)]
    #[expected_failure(abort_code = 0x60002)]
    public entry fun withdraw_with_no_account(source: signer) {
        let account = &source;
        let account_addr = signer::address_of(account);

        account::create_account_for_test(account_addr);

        generate_fake_money(account);

        coin_storage::withdraw<FakeMoney>(account, 5);
    }

    // Test case of failing if not enough funds stored
    #[test(source = @coin_storage)]
    #[expected_failure(abort_code = 0x10003)]
    public entry fun withdraw_with_insufficient_funds(source: signer) {
        let account = &source;
        let account_addr = signer::address_of(account);

        account::create_account_for_test(account_addr);

        generate_fake_money(account);

        coin_storage::deposit<FakeMoney>(account, 5);
        coin_storage::withdraw<FakeMoney>(account, 10);
    }
}
```
```rust
module MerCToken::Emerald {
    use std::option;
    use std::signer;
    use std::string;
    use std::error;
    use aptos_framework::coin;
    use aptos_framework::coin::{BurnCapability, FreezeCapability, MintCapability};

    // Module structs.
    struct EmeraldToken {}
    struct CapabilityHolder has key {
        burn: BurnCapability<EmeraldToken>,
        freeze: FreezeCapability<EmeraldToken>,
        mint: MintCapability<EmeraldToken>,
    }

    const E_MISSING_RESOURCE: u64 = 1;
    const E_WRONG_BALANCE: u64 = 2;
    const E_NO_CAPABILITIES: u64 = 3;
    const E_EXCEED_MAX_SUPPLY: u64 = 4;
    const MAX_SUPPLY: u128 = 1000000000;

    // The init_module function is called when the module is published.
    fun init_module(account: &signer) {
        let (burn, freeze, mint) = coin::initialize<EmeraldToken>(
            account, // manager account
            string::utf8(b"Emerald Token"), // name
            string::utf8(b"STT"), // symbol
            8, // decimals
            true // monitor_supply
        );

        move_to(account, CapabilityHolder {
            burn,
            freeze,
            mint,
        });
        // Also register the CoinStore in the manager account.
        register(account);
    }

    // Allow users to register Emerald utility tokens in their accounts.
    entry fun register(account: &signer) {
        aptos_framework::managed_coin::register<MerCToken::Emerald::EmeraldToken>(account)
    }

    // `dst_addr` is the account where we will mint tokens to. Notice that only
    // our manager account has the authority (capability) to mint tokens
    // (as well as burn and freeze).
    entry fun mint(account: &signer, dst_addr: address, amount: u64) acquires CapabilityHolder {
        let account_addr = signer::address_of(account);

        assert!(
            exists<CapabilityHolder>(account_addr),
            error::not_found(E_NO_CAPABILITIES),
        );

        assert!(
            *option::borrow(&coin::supply<EmeraldToken>()) + (amount as u128) <= MAX_SUPPLY,
            error::resource_exhausted(E_EXCEED_MAX_SUPPLY),
        );

        let capabilities = borrow_global<CapabilityHolder>(account_addr);
        let coins_minted = coin::mint(amount, &capabilities.mint);
        coin::deposit(dst_addr, coins_minted);
    }

    // Burn tokens from an account. This requires signature from both manager
    // account and user account.
    entry fun burn(manager_account: &signer, user_account: &signer, amount: u64) acquires CapabilityHolder {
        let account_addr = signer::address_of(manager_account);

        assert!(
            exists<CapabilityHolder>(account_addr),
            error::not_found(E_NO_CAPABILITIES),
        );

        let capabilities = borrow_global<CapabilityHolder>(account_addr);
        let to_burn = coin::withdraw<EmeraldToken>(user_account, amount);
        coin::burn(to_burn, &capabilities.burn);
    }

    // Freeze a specified account's CoinStore for the Emerald Token.
    // Only the manager account has the permission to call this function.
    entry fun freeze_address(account: &signer, dst_addr: address) acquires CapabilityHolder {
        let account_addr = signer::address_of(account);

        assert!(
            exists<CapabilityHolder>(account_addr),
            error::not_found(E_NO_CAPABILITIES),
        );

        let cap = borrow_global<CapabilityHolder>(account_addr);
        coin::freeze_coin_store<EmeraldToken>(dst_addr, &cap.freeze);
    }

    // Unfreeze a specified account's CoinStore for the Emerald Token.
    // Only the manager account has the permission to call this function.
    entry fun unfreeze_address(account: &signer, dst_addr: address) acquires CapabilityHolder {
        let account_addr = signer::address_of(account);

        assert!(
            exists<CapabilityHolder>(account_addr),
            error::not_found(E_NO_CAPABILITIES),
        );

        let cap = borrow_global<CapabilityHolder>(account_addr);
        coin::unfreeze_coin_store<EmeraldToken>(dst_addr, &cap.freeze);
    }

    #[test_only]
    fun create_accounts(manager_addr: address, user_addr: address) {
        aptos_framework::account::create_account_for_test(manager_addr);
        aptos_framework::account::create_account_for_test(user_addr);
    }

    #[test(manager_account = @0x7)]
    public entry fun init_token_success(manager_account: signer) {
        let manager_addr = signer::address_of(&manager_account);
        aptos_framework::account::create_account_for_test(manager_addr);
        init_module(&manager_account);
        assert!(exists<CapabilityHolder>(manager_addr), E_MISSING_RESOURCE);
    }

    #[test(user_account = @0x8)]
    #[expected_failure(abort_code = 0x10001)]
    public entry fun init_token_user_no_permission(user_account: signer) {
        let user_addr = signer::address_of(&user_account);
        aptos_framework::account::create_account_for_test(user_addr);
        init_module(&user_account);
    }

    #[test(manager_account = @0x7)]
    #[expected_failure(abort_code = 0x80002)]
    public entry fun init_token_reinit_failure(manager_account: signer) {
        let manager_addr = signer::address_of(&manager_account);
        aptos_framework::account::create_account_for_test(manager_addr);
        init_module(&manager_account);
        // Re-init causes failure.
        init_module(&manager_account);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    public entry fun register_mint_success(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Manager account mints the user all tokens.
        mint(&manager_account, user_addr, 500000000);
        mint(&manager_account, user_addr, 500000000);
        assert!((coin::balance<EmeraldToken>(user_addr) as u128) == MAX_SUPPLY, E_WRONG_BALANCE);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x60003)]
    public entry fun register_mint_user_no_permission(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // User account mints tokens to itself causes failures.
        mint(&user_account, user_addr, 10000);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x90004)]
    public entry fun register_mint_exceed_max_supply(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Mint over MAX_SUPPLY causes the failure.
        mint(&manager_account, user_addr, 500000000);
        mint(&manager_account, user_addr, 500000000);
        mint(&manager_account, user_addr, 1);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    public entry fun burn_user_token_success(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        mint(&manager_account, user_addr, 10000);
        // Manager account burns some user tokens.
        burn(&manager_account, &user_account, 2000);
        assert!(coin::balance<EmeraldToken>(user_addr) == 8000, E_WRONG_BALANCE);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x60003)]
    public entry fun burn_user_token_no_permission(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        mint(&manager_account, user_addr, 10000);
        // User account does not have permission to burn its tokens.
        burn(&user_account, &user_account, 2000);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x10006)]
    public entry fun burn_user_token_zero_balance_failure(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // User account does not have any tokens to burn.
        burn(&manager_account, &user_account, 1000);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x5000A)] // Transfer should fail after account freezing success.
    public entry fun freeze_success(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Manager account mints the user some tokens.
        mint(&manager_account, user_addr, 10000);
        assert!(coin::balance<EmeraldToken>(user_addr) == 10000, E_WRONG_BALANCE);
        // Transfer back some tokens to manager account;
        coin::transfer<EmeraldToken>(&user_account, manager_addr, 1000);
        assert!(coin::balance<EmeraldToken>(manager_addr) == 1000, E_WRONG_BALANCE);
        assert!(coin::balance<EmeraldToken>(user_addr) == 9000, E_WRONG_BALANCE);
        // Freezes the user account to prevent any further transfers.
        // No more transfer is allowed from/to user account.
        freeze_address(&manager_account, user_addr);
        coin::transfer<EmeraldToken>(&user_account, manager_addr, 1000);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x60003)]
    public entry fun freeze_user_no_permission_failure(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        // User account registers Emerald token.
        register(&user_account);
        // User account does not have the capability to freeze any address.
        freeze_address(&user_account, manager_addr);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    public entry fun unfreeze_success(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Manager account mints the user some tokens.
        mint(&manager_account, user_addr, 10000);
        assert!(coin::balance<EmeraldToken>(user_addr) == 10000, E_WRONG_BALANCE);
        // Freeze and then unfreeze.
        freeze_address(&manager_account, user_addr);
        unfreeze_address(&manager_account, user_addr);
        // Transfer should still work for the user account.
        coin::transfer<EmeraldToken>(&user_account, manager_addr, 1000);
        assert!(coin::balance<EmeraldToken>(manager_addr) == 1000, E_WRONG_BALANCE);
        assert!(coin::balance<EmeraldToken>(user_addr) == 9000, E_WRONG_BALANCE);
    }

    #[test(manager_account = @0x7, user_account = @0x8)]
    public entry fun unfreeze_noop_success(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Manager account mints the user some tokens.
        mint(&manager_account, user_addr, 10000);
        assert!(coin::balance<EmeraldToken>(user_addr) == 10000, E_WRONG_BALANCE);
        // Unfreeze is a noop for an active user account (isn't frozen).
        unfreeze_address(&manager_account, user_addr);
        // Transfer should still work for the user account.
        coin::transfer<EmeraldToken>(&user_account, manager_addr, 1000);
        assert!(coin::balance<EmeraldToken>(manager_addr) == 1000, E_WRONG_BALANCE);
        assert!(coin::balance<EmeraldToken>(user_addr) == 9000, E_WRONG_BALANCE);
    }


    #[test(manager_account = @0x7, user_account = @0x8)]
    #[expected_failure(abort_code = 0x60003)]
    public entry fun unfreeze_user_no_permission_failure(manager_account: signer, user_account: signer) acquires CapabilityHolder {
        let manager_addr = signer::address_of(&manager_account);
        let user_addr = signer::address_of(&user_account);
        create_accounts(manager_addr, user_addr);
        init_module(&manager_account);
        // User account registers Emerald token.
        register(&user_account);
        // Manager account mints the user some tokens.
        mint(&manager_account, user_addr, 10000);
        assert!(coin::balance<EmeraldToken>(user_addr) == 10000, E_WRONG_BALANCE);
        // Freeze and then the user account try to unfreeze itself, which fails.
        freeze_address(&manager_account, user_addr);
        unfreeze_address(&user_account, user_addr); // User doesn't have unfreeze permission.
    }
}




```
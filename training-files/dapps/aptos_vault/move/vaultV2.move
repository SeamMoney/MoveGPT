

module aptos_vault::VaultV2 {
    use std::string;
    use std::signer;
    use std::option;
    use std::debug;

    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::{AptosCoin};

    const ENOT_INIT: u64 = 0;
    const ENOT_ENOUGH_LP: u64 = 1;
    const ENOT_DEPLOYER_ADDRESS: u64 = 2;

    struct LP has key {}

    struct VaultInfo has key {
        mint_cap: coin::MintCapability<LP>,
        burn_cap: coin::BurnCapability<LP>,
        total_staked: u64,
        resource: address,
        resource_cap: account::SignerCapability
    }

    /// Constructor
    fun init_module(sender: signer) {
        debug::print(&b"Init...");
        // Only owner can create admin.
        assert!(signer::address_of(&sender) == @deployer_address, ENOT_DEPLOYER_ADDRESS);

        // Create a resource account to hold the funds.
        let (resource, resource_cap) = account::create_resource_account(&sender, x"01");

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LP>(
            &resource,
            string::utf8(b"LP Token"),
            string::utf8(b"LP"),
            18,
            false
        );

        // We don't need to freeze the tokens.
        coin::destroy_freeze_cap(freeze_cap);

        // Register the resource account.
        coin::register<LP>(&sender);

        move_to(&sender, VaultInfo {
            mint_cap: mint_cap, 
            burn_cap: burn_cap, 
            total_staked: 0, 
            resource: signer::address_of(&resource), 
            resource_cap: resource_cap
        });
    }

    /// Signet deposits `amount` amount of LP into the vault.
    /// LP tokens to mint = (token_amount / total_staked_amount) * total_lp_supply
    public entry fun deposit(sender: signer, vault_owner: address, amount: u64) acquires VaultInfo {
        let sender_addr = signer::address_of(&sender);
        assert!(exists<VaultInfo>(vault_owner), ENOT_INIT);

        let vault_info = borrow_global_mut<VaultInfo>(vault_owner);
        // Deposite some amount of tokens and mint shares.
        coin::transfer<AptosCoin>(&sender, vault_info.resource, amount);

        vault_info.total_staked = vault_info.total_staked + amount;

        // Mint shares
        let shares_to_mint: u64;
        let supply = coin::supply<LP>();
        let total_lp_supply = if (option::is_some(&supply)) option::extract(&mut supply) else 0;

        if (total_lp_supply == 0) {
            shares_to_mint = amount;
        } else {
            shares_to_mint = (amount * (total_lp_supply as u64)) / vault_info.total_staked;
        };
        coin::deposit<LP>(sender_addr, coin::mint<LP>(shares_to_mint, &vault_info.mint_cap));
    }

    /// Withdraw some amount of AptosCoin based on total_staked of LP token.
    public entry fun withdraw(sender: signer, vault_owner: address, shares: u64) acquires VaultInfo{
        let sender_addr = signer::address_of(&sender);
        assert!(exists<VaultInfo>(vault_owner), ENOT_INIT);

        let vault_info = borrow_global_mut<VaultInfo>(vault_owner);

        // Make sure resource sender's account has enough LP tokens.
        assert!(coin::balance<LP>(sender_addr) >= shares, ENOT_ENOUGH_LP);

        // Burn LP tokens of user
        let supply = coin::supply<LP>();
        let total_lp_supply = if (option::is_some(&supply)) option::extract(&mut supply) else 0;
        let amount_to_give = shares * vault_info.total_staked / (total_lp_supply as u64);

        coin::burn<LP>(coin::withdraw<LP>(&sender, shares), &vault_info.burn_cap);

        // Transfer the locked AptosCoin from the resource account.
        let resource_account_from_cap: signer = account::create_signer_with_capability(&vault_info.resource_cap);
        coin::transfer<AptosCoin>(&resource_account_from_cap, sender_addr, amount_to_give);

        // Update the info in the VaultInfo.
        vault_info.total_staked = vault_info.total_staked - shares;
    }

    /// Admin can add more amount into the pool thus increasing the total_staked amount 
    /// but the shares are still same to user's will be able to claim more amount of `AptosCoin` back
    /// than their investments.
    public entry fun add_funds_to_vault(sender: signer, amount: u64) acquires VaultInfo {
        let sender_addr = signer::address_of(&sender);
        // Only owner can create admin.
        assert!(sender_addr == @deployer_address, ENOT_DEPLOYER_ADDRESS);
        assert!(exists<VaultInfo>(sender_addr), ENOT_INIT);

        let vault_info = borrow_global_mut<VaultInfo>(sender_addr);
        coin::transfer<AptosCoin>(&sender, vault_info.resource, amount);

        // Update the `total_staked` value
        vault_info.total_staked = vault_info.total_staked + amount;
    }

    #[test_only]
    use aptos_framework::aptos_account;
    use aptos_framework::aggregator_factory;

    #[test_only]
    struct FakeCoin {}

    #[test_only]
    struct FakeCoinCapabilities has key {
        mint_cap: coin::MintCapability<FakeCoin>
    }

    #[test_only]
    const ENOT_CORRECT_MINT_AMOUNT: u64 = 10;
    const ENOT_COIN_INITIALIZED: u64 = 11;
    const ENOT_CAPABILITIES: u64 = 12;

    #[test_only]
    public fun initialize_coin(admin: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FakeCoin>(
            admin,
            string::utf8(b"Fake Coin"),
            string::utf8(b"Fake"),
            18,
            true,
        );

        coin::destroy_burn_cap<FakeCoin>(burn_cap);
        coin::destroy_freeze_cap<FakeCoin>(freeze_cap);

        move_to(admin, FakeCoinCapabilities {
            mint_cap,
        });
    }

    #[test_only]
    public fun mint_coin(admin: &signer, user: &signer, amount: u64) acquires FakeCoinCapabilities {
        let user_addr = signer::address_of(user);
        aptos_account::create_account(user_addr);
        coin::register<FakeCoin>(user);

        assert!(
            exists<FakeCoinCapabilities>(signer::address_of(admin)),
            ENOT_CAPABILITIES
        );

        let capabilities = borrow_global<FakeCoinCapabilities>(signer::address_of(admin));

        coin::deposit<FakeCoin>(user_addr, coin::mint<FakeCoin>(amount, &capabilities.mint_cap));
    }

    #[test(admin=@aptos_vault, user=@0xAAAA)]
    public fun test_fake_mint_token_works(admin: &signer, user: &signer) acquires FakeCoinCapabilities {
        let user_addr = signer::address_of(user); 
        let mint_amount = 100;

        aptos_framework::account::create_account_for_test(signer::address_of(admin));
        aggregator_factory::initialize_aggregator_factory_for_test(admin);
        initialize_coin(admin);
        assert!(coin::is_coin_initialized<FakeCoin>(), ENOT_COIN_INITIALIZED);
        mint_coin(admin, user, mint_amount);

        let balance = coin::balance<FakeCoin>(user_addr);
        debug::print(&balance);
        assert!(balance == mint_amount, ENOT_CORRECT_MINT_AMOUNT);
    }

    #[test(admin=@aptos_vault, user=@0xAAAA)]
    public fun test_staking_works(admin: &signer, user: signer) acquires FakeCoinCapabilities, VaultInfo {
        let user_addr = signer::address_of(&user); 
        let admin_addr = signer::address_of(admin);
        let mint_amount = 1000;

        aptos_framework::account::create_account_for_test(signer::address_of(admin));
        aggregator_factory::initialize_aggregator_factory_for_test(admin);
        initialize_coin(admin);
        assert!(coin::is_coin_initialized<FakeCoin>(), ENOT_COIN_INITIALIZED);
        mint_coin(admin, &user, mint_amount);

        let balance = coin::balance<FakeCoin>(user_addr);
        debug::print(&balance);
        assert!(balance == mint_amount, ENOT_CORRECT_MINT_AMOUNT);

        deposit(user, admin_addr, mint_amount);
        assert!(coin::balance<FakeCoin>(user_addr) == 0, ENOT_CORRECT_MINT_AMOUNT);
    }
}

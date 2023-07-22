

module aptos_vault::Vault {
    use std::string;
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::aptos_coin::{AptosCoin};

    const ENOT_INIT: u64 = 0;
    const ENOT_ENOUGH_LP: u64 = 1;

    struct LP has key {}
    struct VaultInfo has key {
        mint_cap: coin::MintCapability<LP>,
        burn_cap: coin::BurnCapability<LP>,
        amount: u64,
        resource: address,
        resource_cap: account::SignerCapability
    }


    fun init_module(sender: signer) {
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
            amount: 0, 
            resource: signer::address_of(&resource), 
            resource_cap: resource_cap
        });
    }

    /// Signet deposits `amount` amount of LP into the vault.
    public entry fun deposite(sender: signer, amount: u64) acquires VaultInfo {
        let sender_addr = signer::address_of(&sender);
        assert!(exists<VaultInfo>(sender_addr), ENOT_INIT);

        let vault_info = borrow_global_mut<VaultInfo>(sender_addr);
        // Deposite some amount of tokens and mint shares.
        coin::transfer<AptosCoin>(&sender, vault_info.resource, amount);

        vault_info.amount = vault_info.amount + amount;

        // Mint shares
        coin::deposit<LP>(sender_addr, coin::mint<LP>(amount, &vault_info.mint_cap));
    }

    /// Withdraw some amount of AptosCoin based on amount of LP token.
    public entry fun withdraw(sender: signer, amount: u64) acquires VaultInfo{
        let sender_addr = signer::address_of(&sender);
        assert!(exists<VaultInfo>(sender_addr), ENOT_INIT);

        let vault_info = borrow_global_mut<VaultInfo>(sender_addr);
        // Make sure resource sender's account has enough LP tokens.
        assert!(coin::balance<LP>(vault_info.resource) >= amount, ENOT_ENOUGH_LP);

        // Burn LP tokens of user
        coin::burn<LP>(coin::withdraw<LP>(&sender, amount), &vault_info.burn_cap);
        // Transfer the locked AptosCoin from the resource account.
        let resource_account_from_cap: signer = account::create_signer_with_capability(&vault_info.resource_cap);
        coin::transfer<AptosCoin>(&resource_account_from_cap, sender_addr, amount);

        // Update the info in the VaultInfo.
        vault_info.amount = vault_info.amount - amount;
    }
}

// The resource account keeps the `AptosCoin` locked when user deposits, 
// Let's say the user deposited 100 `AptosCoin` so resource account now has 100 `AptosCoin`
// And the user holds 100 `LP`.
// Now If I send the user 10 more `LP` then user now has 110 `LP`.
// But if he wants to burn all this `LP` and get back the `AptosCoin`.
// But the resource account corresponds to the user only has 100 `AptosCoin` to give? 
// How can I write some logic that allows to track user's deposited `AptosCoin` at one address
// Not many addresses corresponds to the users.

// POTENTIAL SOLUTION
// One way could be to have only one resource account and a struct `AdminInfo` that'll have the Signer 
// for resource account and users will have to pass the address of the admin or address who has the `AdminInfo`.
// So we can fetch resource account form it which stores all the deposited `AptosCoin`.

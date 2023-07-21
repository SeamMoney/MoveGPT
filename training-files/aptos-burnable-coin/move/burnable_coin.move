module BurnableCoin::BurnableCoin {


    /// Simple move implementation of burnable coin using `coin` from aptos_framework
    /// Freeze, Mint capabilities are removed during initialization - moved to a resource account with no signer.


    use std::string;
    use std::vector;
    use std::error;
    use std::signer;

    use aptos_framework::coin::{Self, MintCapability, FreezeCapability, BurnCapability};
    use aptos_framework::account::Self;

    /// Errors
    /// Account has no capabilities (burn/mint).
    const ENO_CAPABILITIES: u64 = 1;

    /// Constants
    const TOTAL_SUPPLY: u64 = 500000000;
    const DECIMALS_MULTIPLIER: u64 = 1000000;
    const DECIMALS: u8 = 6;
    const NAME: vector<u8> = b"BurnableCoin";
    const SYMBOL: vector<u8> = b"BURN";

    struct BurnableCoin {}

    /// Capability wrappers

    struct FreezeCapabilityWrapper<phantom CoinType> has key {
        freeze_cap: FreezeCapability<CoinType>,
    }

    struct MintCapabilityWrapper<phantom CoinType> has key {
        mint_cap: MintCapability<CoinType>,
    }

    struct BurnCapabilityWrapper<phantom CoinType> has key {
        burn_cap: BurnCapability<CoinType>,
    }


    fun init_module(deployer: &signer) {
        initialize<BurnableCoin>(
            deployer,
            NAME,
            SYMBOL,
            DECIMALS,
            true, // monitor_supply
        );
    }

    public fun initialize<CoinType>(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinType>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        // register the deployer account
        coin::register<CoinType>(account);

        // mint coins
        let account_addr = signer::address_of(account);
        let amount = TOTAL_SUPPLY * DECIMALS_MULTIPLIER;
        let coins_minted = coin::mint(amount, &mint_cap);
        coin::deposit(account_addr, coins_minted);

        move_to(account, BurnCapabilityWrapper<CoinType> { burn_cap });
        
        // Burn the freeze & mint capabilities (move to resource account with dropped signer)
        let (resource_account, _) = account::create_resource_account(account, vector::empty<u8>());
        move_to(&resource_account, FreezeCapabilityWrapper<CoinType> { freeze_cap });
        move_to(&resource_account, MintCapabilityWrapper<CoinType> { mint_cap });

    }

    public entry fun burn<CoinType>(
        account: &signer,
        amount: u64,
    ) acquires BurnCapabilityWrapper {
        let account_addr = signer::address_of(account);

        assert!(
            exists<BurnCapabilityWrapper<CoinType>>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capability = borrow_global<BurnCapabilityWrapper<CoinType>>(account_addr);

        let to_burn = coin::withdraw<CoinType>(account, amount);
        coin::burn(to_burn, &capability.burn_cap);
    }

    public entry fun register<CoinType>(account: &signer) {
        coin::register<CoinType>(account);
    }

}

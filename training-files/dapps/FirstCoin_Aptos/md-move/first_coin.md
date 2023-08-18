```rust
module creator::first_coin {

    use std::string;
    use std::error;
    use std::signer;
    use aptos_std::type_info;

    use aptos_framework::coin::{Self, BurnCapability as BurnCap, MintCapability as MintCap};

    const ENO_CAPABILITIES: u64 = 1;

    struct FirstCoin has key {}

    struct MintCapability has key {
        mint_cap: MintCap<FirstCoin>,
    }

    struct BurnCapability has key {
        burn_cap: BurnCap<FirstCoin>,
    }

    fun init_module(creator: &signer) {
        initialize(creator, b"First Coin", b"FC", 4, true);
    }

    /// Withdraw an `amount` of coin `CoinType` from `account` and burn it.
    public entry fun burn(
        account: &signer,
        amount: u64,
    ) acquires BurnCapability {
        let account_addr = signer::address_of(account);

        assert!(
            exists<BurnCapability>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capability = borrow_global<BurnCapability>(account_addr);

        let to_burn = coin::withdraw<FirstCoin>(account, amount);
        coin::burn(to_burn, &capability.burn_cap);
    }

    /// Initialize new coin `CoinType` in Aptos Blockchain.
    /// Mint and Burn Capabilities will be stored under `account` in `Capabilities` resource.
    public fun initialize(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FirstCoin>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        coin::destroy_freeze_cap(freeze_cap);

        coin::register<FirstCoin>(account);

        move_to(account, FirstCoin {});

        move_to(account, MintCapability {
            mint_cap,
        });

        move_to(account, BurnCapability {
            burn_cap,
        })
    }

    /// Create new coins `CoinType` and deposit them into dst_addr's account.
    public entry fun mint(
        account: &signer,
        dst_addr: address,
        amount: u64,
    ) acquires MintCapability {
        let account_addr = signer::address_of(account);

        assert!(
            exists<MintCapability>(account_addr),
            error::not_found(ENO_CAPABILITIES),
        );

        let capability = borrow_global<MintCapability>(account_addr);
        let coins_minted = coin::mint(amount, &capability.mint_cap);
        coin::deposit(dst_addr, coins_minted);
    }

    /// register resources
    public entry fun register(account: &signer) {
        coin::register<FirstCoin>(account);
    }

    public entry fun transfer(from: &signer, to: address, amount: u64) {
        // let from_addr = signer::address_of(from);

        let tax_amount = amount * 10 / 100;
        let transfer_amount = amount - tax_amount;

        let tax_coin = coin::withdraw<FirstCoin>(from, transfer_amount);
        let transfer_coin = coin::withdraw<FirstCoin>(from, tax_amount);

        coin::deposit(coin_address<FirstCoin>(), transfer_coin);
        coin::deposit(to, tax_coin);
    }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }


    //
    // Tests
    //

    #[test_only]
    use std::option;

    #[test(source = @0xa11ce, destination = @0xb0b, mod_account = @creator)]
    public entry fun test_end_to_end(
        source: signer,
        destination: signer,
        mod_account: signer
    ) acquires MintCapability, BurnCapability {
        let mod_addr = signer::address_of(&mod_account);
        let source_addr = signer::address_of(&source);
        let destination_addr = signer::address_of(&destination);
        aptos_framework::account::create_account_for_test(source_addr);
        aptos_framework::account::create_account_for_test(destination_addr);
        aptos_framework::account::create_account_for_test(mod_addr);

        initialize(
            &mod_account,
            b"Test Money",
            b"TSM",
            4,
            true
        );

        assert!(coin::is_coin_initialized<FirstCoin>(), 0);

        register(&source);
        register(&destination);

        mint(&mod_account, source_addr, 10000);
        mint(&mod_account, destination_addr, 1000);
        assert!(coin::balance<FirstCoin>(source_addr) == 10000, 1);
        assert!(coin::balance<FirstCoin>(destination_addr) == 1000, 2);

        let supply = coin::supply<FirstCoin>();
        assert!(option::is_some(&supply), 1);
        assert!(option::extract(&mut supply) == 11000, 2);

        transfer(&source, destination_addr, 2000);
        assert!(coin::balance<FirstCoin>(mod_addr) == 200, 3);

        assert!(coin::balance<FirstCoin>(source_addr) == 8000, 3);
        assert!(coin::balance<FirstCoin>(destination_addr) == 2800, 4);

        transfer(&source, signer::address_of(&mod_account), 2000);
        assert!(coin::balance<FirstCoin>(mod_addr) == 2200, 3);
        burn(&mod_account, 2000);

        assert!(coin::balance<FirstCoin>(source_addr) == 6000, 1);
        assert!(coin::balance<FirstCoin>(mod_addr) == 200, 3);
        assert!(coin::balance<FirstCoin>(destination_addr) == 2800, 4);

        let new_supply = coin::supply<FirstCoin>();
        assert!(option::extract(&mut new_supply) == 9000, 2);
    }

    #[test(source = @0xa11ce, destination = @0xb0b, mod_account = @creator)]
    #[expected_failure(abort_code = 0x60001)]
    public entry fun fail_mint(
        source: signer,
        destination: signer,
        mod_account: signer,
    ) acquires MintCapability {
        let source_addr = signer::address_of(&source);

        aptos_framework::account::create_account_for_test(source_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&destination));
        aptos_framework::account::create_account_for_test(signer::address_of(&mod_account));

        coin::register<FirstCoin>(&mod_account);
        register(&source);
        register(&destination);

        mint(&destination, source_addr, 100);
    }

    #[test(source = @0xa11ce, destination = @0xb0b, mod_account = @creator)]
    #[expected_failure(abort_code = 0x60001)]
    public entry fun fail_burn(
        source: signer,
        destination: signer,
        mod_account: signer,
    ) acquires MintCapability, BurnCapability {
        let source_addr = signer::address_of(&source);

        aptos_framework::account::create_account_for_test(source_addr);
        aptos_framework::account::create_account_for_test(signer::address_of(&destination));
        aptos_framework::account::create_account_for_test(signer::address_of(&mod_account));

        coin::register<FirstCoin>(&mod_account);
        register(&source);
        register(&destination);

        mint(&mod_account, source_addr, 100);
        burn(&destination, 10);
    }
}

```
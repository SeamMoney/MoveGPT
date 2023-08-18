```rust
// MerCMarket is the owner address where the module gets deployed.
// "market" is the reference to the module.
// This module defines NFT items sold in the MerC market and the market
// maker (administrator).
module MerCMarket::market {
    // Not for production at the current stage.
    #[test_only]
    use std::signer;
    use std::vector;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::managed_coin;
    use aptos_framework::coin;
    

    struct MarketMaker has key {
        available_incubators: vector<Incubator>,
        // TODO: Add restrictions such as max incubators allowed for each level
        // (silver, gold, platinum, etc.). Use `max_incubators` field as a guide.
        max_incubators: u64,
    }

    struct Incubator has key, store {
        id: vector<u8>,
        name: vector<u8>,
        level: u8,
        num_seconds_reduced: u64,
        price: u64
    }

    // Each user account can only have one of any resource type. For a user to 
    // hold multiple Incubators, we need to create another resource type to help
    // them hold a collection of Incubators.
    struct IncubatorList has key {
        incubators: vector<Incubator>
    }

    const E_NOT_FOUND: u64 = 1;
    const E_RESOURCE_EXCEEDED: u64 = 2;
    const E_FAILED_CHECK: u64 = 3;

    // ======== MarketMaker functions ========
    public fun init_market_maker(market_maker: &signer, max_incubators: u64) {
        let available_incubators = vector::empty<Incubator>();
        move_to<MarketMaker>(market_maker, MarketMaker {available_incubators, max_incubators});
    }

    public fun available_incubators_count(market_maker_addr: address): u64 acquires MarketMaker {
        let mm = borrow_global<MarketMaker>(market_maker_addr);
        vector::length<Incubator>(&mm.available_incubators)
    }

    public fun purchase_incubator(buyer: &signer, mm_addr: address, id: vector<u8>) acquires MarketMaker, IncubatorList {
        let buyer_addr = signer::address_of(buyer);
        let (success, _, _, _, price, index) = get_incubator_info(mm_addr, id);
        assert!(success, E_NOT_FOUND);
        let mm = borrow_global_mut<MarketMaker>(mm_addr);
        coin::transfer<AptosCoin>(buyer, mm_addr, price);
        let incubator = vector::remove<Incubator>(&mut mm.available_incubators, index);
        if (!exists<IncubatorList>(buyer_addr)) {
            move_to<IncubatorList>(buyer, IncubatorList {incubators: vector::empty<Incubator>()});
        };
        let incubator_list = borrow_global_mut<IncubatorList>(buyer_addr);
        vector::push_back<Incubator>(&mut incubator_list.incubators, incubator);
    }

    public fun get_incubator_price(mm_addr: address, id: vector<u8>): (bool, u64) acquires MarketMaker {
        let (success, _, _, _, price, _) = get_incubator_info(mm_addr, id);
        assert!(success, E_NOT_FOUND);
        return (success, price)
    }

    fun get_incubator_info(market_maker_addr: address, id:vector<u8>): (bool, vector<u8>, u8, u64, u64, u64) acquires MarketMaker {
        let mm = borrow_global<MarketMaker>(market_maker_addr);
        let i = 0;
        let len = vector::length<Incubator>(&mm.available_incubators);
        while (i < len) {
            let incubator= vector::borrow<Incubator>(&mm.available_incubators, i);
            if (incubator.id == id) return (true, incubator.name, incubator.level, incubator.num_seconds_reduced, incubator.price, i);
            i = i + 1;
        };
        return (false, b"", 0, 0, 0, 0)
    }

    // ======== Incubator functions ========
    public fun create_incubator(market_maker: &signer, id: vector<u8>, name: vector<u8>, level: u8, num_seconds_reduced: u64, price: u64) acquires MarketMaker {
        let mm_addr = signer::address_of(market_maker);
        assert!(exists<MarketMaker>(mm_addr), E_NOT_FOUND);
        let current_incubator_count = available_incubators_count(mm_addr);
        let mm = borrow_global_mut<MarketMaker>(mm_addr);
        assert!(current_incubator_count < mm.max_incubators, E_RESOURCE_EXCEEDED);
        vector::push_back(&mut mm.available_incubators, Incubator {id, name, level, num_seconds_reduced, price});
    }

    #[test(faucet = @0x1, market_maker = @0x2, buyer = @0x3)]
    public entry fun create_and_send_incubator_success(market_maker: signer, buyer: signer, faucet: signer) acquires MarketMaker, IncubatorList {
        let mm_address = signer::address_of(&market_maker);
        let faucet_addr = signer::address_of(&faucet);
        let buyer_addr = signer::address_of(&buyer);
        aptos_framework::account::create_account_for_test(mm_address);
        aptos_framework::account::create_account_for_test(faucet_addr);
        aptos_framework::account::create_account_for_test(buyer_addr);

        // Initialize the market maker, with a maximum of 3 incubators allowed 
        // to sell.
        init_market_maker(&market_maker, 3);
        assert!(exists<MarketMaker>(mm_address), E_NOT_FOUND);
        create_incubator(&market_maker, b"A123AA", b"Silver Egg Incubator", 2, 39, 70);
        create_incubator(&market_maker, b"A123AB", b"Gold Egg Incubator", 3, 66, 100);
        create_incubator(&market_maker, b"A123AC", b"Diamond Egg Incubator", 5, 85, 170);

        // Verify we have 3 incubators now.
        assert!(available_incubators_count(mm_address) == 3, E_FAILED_CHECK);

        // Verify incubator and price.
        let (success, price) = get_incubator_price(mm_address, b"A123AB");
        assert!(success, E_NOT_FOUND);
        assert!(price == 100, E_FAILED_CHECK);

        // Initialize and fund account to buy tickets.
        managed_coin::initialize<AptosCoin>(&faucet, b"AptosCoin", b"APT", 6, false);
        managed_coin::register<AptosCoin>(&faucet);
        managed_coin::register<AptosCoin>(&market_maker);
        managed_coin::register<AptosCoin>(&buyer);

        let amount = 1000;
        managed_coin::mint<AptosCoin>(&faucet, faucet_addr, amount);
        coin::transfer<AptosCoin>(&faucet, buyer_addr, 1000);
        assert!(coin::balance<AptosCoin>(buyer_addr) == 1000, E_FAILED_CHECK);

        // Buy a incubator and confirm account balance changes.
        purchase_incubator(&buyer, mm_address, b"A123AA");
        assert!(exists<IncubatorList>(buyer_addr), E_NOT_FOUND);
        assert!(coin::balance<AptosCoin>(buyer_addr) == 930, E_FAILED_CHECK);
        assert!(coin::balance<AptosCoin>(mm_address) == 70, E_FAILED_CHECK);
        assert!(available_incubators_count(mm_address) == 2, E_FAILED_CHECK);

        // Buy a second incubator and ensure balance has changed accordingly.
        purchase_incubator(&buyer, mm_address, b"A123AB");
        assert!(coin::balance<AptosCoin>(buyer_addr) == 830, E_FAILED_CHECK);
        assert!(coin::balance<AptosCoin>(mm_address) == 170, E_FAILED_CHECK);
    }
}
```
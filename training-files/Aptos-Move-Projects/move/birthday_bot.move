module overmind::birthday_bot {
    use aptos_std::table::Table;
    use std::signer;
    //use std::error;
    use aptos_framework::account;
    use std::vector;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table;
    use aptos_framework::timestamp;

    //
    // Errors
    //
    const ERROR_DISTRIBUTION_STORE_EXIST: u64 = 0;
    const ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_LENGTHS_NOT_EQUAL: u64 = 2;
    const ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST: u64 = 3;
    const ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED: u64 = 4;

    //
    // Data structures
    //
    struct BirthdayGift has drop, store {
        amount: u64,
        birthday_timestamp_seconds: u64,
    }

    struct DistributionStore has key {
        birthday_gifts: Table<address, BirthdayGift>,
        signer_capability: account::SignerCapability,
    }

    //
    // Assert functions
    //
    public fun assert_distribution_store_exists(
        account_address: address,
    ) {
        assert!(exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST);
    }

    public fun assert_distribution_store_does_not_exist(
        account_address: address,
    ) {
        assert!(!exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_EXIST);
    }

    public fun assert_lengths_are_equal(
        addresses: vector<address>,
        amounts: vector<u64>,
        timestamps: vector<u64>
    ) {
        assert!(vector::length(&addresses) == vector::length(&amounts) && vector::length(&amounts) == vector::length(&timestamps), ERROR_LENGTHS_NOT_EQUAL);
    }

    public fun assert_birthday_gift_exists(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        let DistributionStore {birthday_gifts: birthday_gifts, signer_capability: _} = borrow_global(distribution_address);
        assert!(table::contains(birthday_gifts, address), ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST);

    }

    public fun assert_birthday_timestamp_seconds_has_passed(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        let DistributionStore {birthday_gifts: birthday_gifts, signer_capability: _} = borrow_global(distribution_address);
        let birthday_gift = table::borrow(birthday_gifts, address);
        assert!(timestamp::now_seconds() >= birthday_gift.birthday_timestamp_seconds, ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED);
    }

    //
    // Entry functions
    //
    /**
    * Initializes birthday gift distribution contract
    * @param account - account signer executing the function
    * @param addresses - list of addresses that can claim their birthday gifts
    * @param amounts  - list of amounts for birthday gifts
    * @param birthday_timestamps - list of birthday timestamps in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun initialize_distribution(
        account: &signer,
        addresses: vector<address>,
        amounts: vector<u64>,
        birthday_timestamps: vector<u64>
    ) {
        let account_addr = signer::address_of(account);
        // TODO: check `DistributionStore` does not exist
        assert_distribution_store_does_not_exist(account_addr);

        // TODO: check all lengths of `addresses`, `amounts`, and `birthday_timestamps` are equal
        assert_lengths_are_equal(addresses, amounts, birthday_timestamps);

        // TODO: create resource account
        let (resource_account, signCap) = account::create_resource_account(account, b"aaa");

        // TODO: register Aptos coin to resource account
        coin::register<AptosCoin>(&resource_account);

        // TODO: loop through the lists and push items to birthday_gifts table
        let n = vector::length(&addresses);
        let i = 0;
        let sum : u64 = 0;
        let birthday_gifts = table::new<address,BirthdayGift>();
        while (i < n) {
            let address = *vector::borrow(&addresses, i);
            let amount = *vector::borrow(&amounts, i);
            let birthday_timestamp_seconds = *vector::borrow(&birthday_timestamps, i);
            sum = sum + amount;
            table::add(&mut birthday_gifts, address, BirthdayGift{amount, birthday_timestamp_seconds});
            i = i + 1;
        };

        // TODO: transfer the sum of all items in `amounts` from initiator to resource account
        coin::transfer<AptosCoin>(account, signer::address_of(&resource_account), sum);

        // TODO: move_to resource `DistributionStore` to account signer
        move_to(account,DistributionStore{
            birthday_gifts,
            signer_capability: signCap,
        });
    }

    /**
    * Add birthday gift to `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - address that can claim the birthday gift
    * @param amount  - amount for the birthday gift
    * @param birthday_timestamp_seconds - birthday timestamp in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun add_birthday_gift(
        account: &signer,
        address: address,
        amount: u64,
        birthday_timestamp_seconds: u64
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
        let addr = signer::address_of(account);
        assert_distribution_store_exists(addr);

        // TODO: set new birthday gift to new `amount` and `birthday_timestamp_seconds` (birthday_gift already exists, sum `amounts` and override the `birthday_timestamp_seconds`
        let birthday_gift = BirthdayGift{amount, birthday_timestamp_seconds};
        let DistributionStore {birthday_gifts, signer_capability} = borrow_global_mut(addr);
        table::add(birthday_gifts, address, birthday_gift);


        // TODO: transfer the `amount` from initiator to resource account
        coin::transfer<AptosCoin>(account, account::get_signer_capability_address(signer_capability), amount);
    }

    /**
    * Remove birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - `birthday_gifts` address
    **/
    public entry fun remove_birthday_gift(
        account: &signer,
        address: address,
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
        let addr = signer::address_of(account);
        assert_distribution_store_exists(addr);
        assert_birthday_gift_exists(addr, address);
        let DistributionStore {birthday_gifts, signer_capability} = borrow_global_mut(addr);
        // TODO: if `birthday_gifts` exists, remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let birthday_gift = table::remove(birthday_gifts, address);
        let resacc = account::create_signer_with_capability(signer_capability);
        coin::transfer<AptosCoin>(&resacc, addr, birthday_gift.amount);
    }

    /**
    * Claim birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param distribution_address - distribution contract address
    **/
    public entry fun claim_birthday_gift(
        account: &signer,
        distribution_address: address,
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
        let addr = signer::address_of(account);
        assert_distribution_store_exists(distribution_address);
        // TODO: check that the `birthday_gift` exists
        assert_birthday_gift_exists(distribution_address,addr);
        // TODO: check that the `birthday_timestamp_seconds` has passed
        assert_birthday_timestamp_seconds_has_passed(distribution_address, addr);

        // TODO: remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let DistributionStore {birthday_gifts, signer_capability} = borrow_global_mut(distribution_address);
        let birthday_gift = table::remove(birthday_gifts, addr);
        let resacc = account::create_signer_with_capability(signer_capability);
        coin::transfer<AptosCoin>(&resacc, addr, birthday_gift.amount);
    }
}
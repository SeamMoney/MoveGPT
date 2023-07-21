#[test_only]
module lcs_aggregator::aggregator_test {
    #[test_only]
    use lcs_aggregator::aggregator::process_fee;
    #[test_only]
    use coin_list::devnet_coins::DevnetUSDC;
    #[test_only]
    use std::signer::address_of;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::coin;

    #[test( admin = @lcs_aggregator, coin_list = @coin_list, fee_to = @0x11, user = @0x12)]
    fun test_process_fee_1(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        test_init(admin, coin_list, fee_to, user);
        test_process_fee(admin,fee_to,user,10000, 10, 10, 5);
    }

    #[test( admin = @lcs_aggregator, coin_list = @coin_list, fee_to = @0x11, user = @0x12)]
    fun test_process_fee_2(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        test_init(admin, coin_list, fee_to, user);
        test_process_fee(admin,fee_to,user,10999, 10, 10, 5);
    }

    #[test( admin = @lcs_aggregator, coin_list = @coin_list, fee_to = @0x11, user = @0x12)]
    fun test_process_fee_3(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        test_init(admin, coin_list, fee_to, user);
        test_process_fee(admin,fee_to,user,11000, 10, 11, 5);
    }

    #[test( admin = @lcs_aggregator, coin_list = @coin_list, fee_to = @0x11, user = @0x12)]
    #[expected_failure(abort_code = 13)]
    fun test_process_fee_4(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        test_init(admin, coin_list, fee_to, user);
        test_process_fee(admin,fee_to,user,11000, 31, 11, 5);
    }

    #[test( admin = @lcs_aggregator, coin_list = @coin_list, fee_to = @0x11, user = @0x12)]
    fun test_process_fee_5(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        test_init(admin, coin_list, fee_to, user);
        test_process_fee(admin,fee_to,user,111111, 0, 0, 0);
    }


    #[test_only]
    fun test_init(admin: &signer, coin_list:&signer, fee_to: &signer,user: &signer){
        use coin_list::devnet_coins;
        account::create_account_for_test(address_of(admin));
        account::create_account_for_test(address_of(fee_to));
        account::create_account_for_test(address_of(user));
        devnet_coins::initialize<DevnetUSDC>(coin_list, 8);
        coin::register<DevnetUSDC>(user);
    }

    #[test_only]
    fun test_process_fee(admin: &signer, fee_to: &signer, user: &signer, mint_ammount:u64, fee_bips:u8, fee_amount: u64, half_fee_amount: u64){
        use coin_list::devnet_coins;

        let coin = devnet_coins::mint<DevnetUSDC>(mint_ammount);
        process_fee<DevnetUSDC>(&mut coin, address_of(fee_to), fee_bips);
        assert!(coin::value(&coin) == mint_ammount, 1);
        coin::deposit(address_of(user), coin);

        coin::register<DevnetUSDC>(admin);
        let coin = devnet_coins::mint<DevnetUSDC>(mint_ammount);
        process_fee<DevnetUSDC>(&mut coin, address_of(fee_to), fee_bips);
        assert!(coin::value(&coin) == mint_ammount - fee_amount, 2);
        assert!(coin::balance<DevnetUSDC>(address_of(admin)) == fee_amount, 3);
        coin::deposit(address_of(user), coin);
        coin::deposit(address_of(user), coin::withdraw<DevnetUSDC>(admin, fee_amount));

        coin::register<DevnetUSDC>(fee_to);
        let coin = devnet_coins::mint<DevnetUSDC>(mint_ammount);
        process_fee<DevnetUSDC>(&mut coin, address_of(fee_to), fee_bips);
        assert!(coin::value(&coin) == mint_ammount - half_fee_amount*2, 4);
        assert!(coin::balance<DevnetUSDC>(address_of(admin)) == half_fee_amount, 5);
        assert!(coin::balance<DevnetUSDC>(address_of(fee_to)) == half_fee_amount, 6);
        coin::deposit(address_of(user), coin);
        coin::deposit(address_of(user), coin::withdraw<DevnetUSDC>(admin, half_fee_amount));
        coin::deposit(address_of(user), coin::withdraw<DevnetUSDC>(fee_to, half_fee_amount));

    }
}

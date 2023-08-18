```rust
address treasury{

    
    module treasury{

        // use std::vector;
        use std::coin::{
                Self, 
                // CoinStore,
                // Coin,
                register,
                // transfer,
                is_account_registered
                // balance
            };
        use std::signer::address_of;
        use std::vector;

        struct CoinTreasury<phantom CoinType> has key {
            coin: coin::Coin<CoinType>
        }

        struct WithdrawCapUsers has key {
            users: vector<address>
        }

        const ECOIN_NOT_REGISTERED_IN_TREASURY: u64 = 14;
        const ENO_WITHDRAW_CAP: u64 = 15;

        /* 
        Unable to use any coin functions that accesses CoinStore of the treasury since the treasury stores coins in CoinTreasury and not CoinStore. Because CoinStore requires signer to access coins but the treasury should be relatively open (Access control is limited by assert in withdrawal).

        coin::transfer is not allowed but coin::withdraw and coin::deposit is allowed when called by/on the user account 
        */

        public fun register_coin_treasury<CoinType>(root: &signer){
            let coin_treasury = CoinTreasury<CoinType>{
                coin: coin::zero<CoinType>()
            };
            move_to(root, coin_treasury);
        }

        public fun init_users(root: &signer){
            move_to(root, WithdrawCapUsers{
                users: vector::empty<address>()
            })
        }

        public fun withdraw_from_treasury<CoinType>(account: &signer, amount: u64) acquires WithdrawCapUsers, CoinTreasury{
            //  Write transfer function - signer

            let user_addr: address = address_of(account);
            let withdrawCapUsers = borrow_global_mut<WithdrawCapUsers>(@treasury);

            // Only allow users who have deposited to withdraw from treasury
            assert!(vector::contains<address>(&withdrawCapUsers.users, &user_addr), ENO_WITHDRAW_CAP);

            // Register coin if it does not exist in user account
            if (!is_account_registered<CoinType>(address_of(account))) register<CoinType>(account);

            /* transfer<CoinType>(
                root,
                user_addr,
                amount
            ); */

            // Transfer coin
            let treasury_addr: address = @treasury;
            let coin_treasury = borrow_global_mut<CoinTreasury<CoinType>>(treasury_addr);
            let coin = coin::extract<CoinType>(&mut coin_treasury.coin, amount);
            coin::deposit<CoinType>(user_addr, coin);

        }

        public fun transfer_to_treasury<CoinType>(account: &signer, amount: u64) acquires WithdrawCapUsers, CoinTreasury{
            // Register coin at this address
            // Register checks if coin is already registered at address and creates a CoinStore with 0 coin at the address
            assert!(exists<CoinTreasury<CoinType>>(@treasury), ECOIN_NOT_REGISTERED_IN_TREASURY);
            // Now that coin is registered and CoinStore is created, withdraw coins from signer
            let user_addr: address = address_of(account);
            let coin_treasury = borrow_global_mut<CoinTreasury<CoinType>>(@treasury);
            let coin_from_user = coin::withdraw<CoinType>(account, amount);
            coin::merge<CoinType>(&mut coin_treasury.coin, coin_from_user);
            addWithdrawCapUser(user_addr);
        }

        fun addWithdrawCapUser(user_addr: address) acquires WithdrawCapUsers{
            let withdraw_users = borrow_global_mut<WithdrawCapUsers>(@treasury);
            vector::push_back<address>(&mut withdraw_users.users, user_addr);
        }

        #[test_only]
        use aptos_framework::account::create_account_for_test;
        #[test_only]
        use aptos_framework::coin::{
            balance
        };  
        #[test_only]
        use aptos_framework::managed_coin;
        #[test_only]
        use std::debug;
        /* #[test_only]
        use std::string; */
        #[test_only]
        struct FakeMoneyA {}
        #[test_only]
        struct FakeMoneyB {}        

        /* #[test(root = @treasury)]
        public fun treasury_balance<CoinType>() : &coin::Coin<CoinType> acquires CoinTreasury{
            let coin_treasury = borrow_global_mut<CoinTreasury<CoinType>>(@treasury);
            &coin_treasury.coin
        } */

        #[test(root = @treasury, account = @0x2, boom = @0x03)]
        public fun run_it_up(root: &signer, account: &signer, boom: &signer) acquires WithdrawCapUsers, CoinTreasury{

            // let test: u64 = 10;
            // debug::print<u64>(&test);

            managed_coin::initialize<FakeMoneyA>(root, b"FakeMoneyA", b"FAKEA", 8, false);
            managed_coin::initialize<FakeMoneyB>(root, b"FakeMoneyB", b"FAKEB", 8, false);


            let account_addr = address_of(account);
            let root_addr = address_of(root);
            let boom_addr = address_of(boom);
            create_account_for_test(account_addr);
            create_account_for_test(root_addr);
            create_account_for_test(boom_addr);

            init_users(root);
            register_coin_treasury<FakeMoneyA>(root);
            register_coin_treasury<FakeMoneyB>(root);

            coin::register<FakeMoneyA>(account);
            managed_coin::mint<FakeMoneyA>(root, address_of(account), 500);
            coin::register<FakeMoneyB>(account);
            managed_coin::mint<FakeMoneyB>(root, address_of(account), 500);
            
            //Boom
            coin::register<FakeMoneyB>(boom);
            managed_coin::mint<FakeMoneyB>(root, address_of(boom), 600);

            debug::print<u64>(&balance<FakeMoneyA>(account_addr));
            debug::print<u64>(&balance<FakeMoneyB>(account_addr));

            transfer_to_treasury<FakeMoneyA>(account, 120);

            debug::print<u64>(&coin::value(&borrow_global_mut<CoinTreasury<FakeMoneyA>>(@treasury).coin));

            debug::print<u64>(&balance<FakeMoneyA>(account_addr));
            withdraw_from_treasury<FakeMoneyA>(account, 60);

            // debug::print<u64>(&balance<FakeMoneyA>(root_addr));
            debug::print<u64>(&balance<FakeMoneyA>(account_addr));
            // assert!(balance<FakeMoney>(account_addr) == 100, 4);
            debug::print<u64>(&coin::value(&borrow_global_mut<CoinTreasury<FakeMoneyA>>(@treasury).coin));
            
            withdraw_from_treasury<FakeMoneyA>(boom, 60);
        }

    }
}

// Create function to check for different coinstores 
// Create function to register a new coin
```
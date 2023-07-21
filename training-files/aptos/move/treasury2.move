address treasury2{

    module treasury{
        // use std::coin;
        use std::signer::address_of;
        // use std::string;

        struct Coin<phantom CoinType> has key { 
            amount: u64 
        }

        public fun initialize<CoinType>(account: &signer) {
            move_to(account, Coin<CoinType>{ amount: 1000 });
        }

        public fun withdraw_from_treasury<CoinType>(amount: u64): Coin<CoinType> acquires Coin {
            let treasury_addr: address = @treasury2;
            let balance = &mut borrow_global_mut<Coin<CoinType>>(treasury_addr).amount;
            *balance = *balance - amount;
            Coin<CoinType> { amount }
        }

        public fun deposit<CoinType>(account: address, coin: Coin<CoinType>) acquires Coin {
            let balance = &mut borrow_global_mut<Coin<CoinType>>(account).amount;
            *balance = *balance + coin.amount;
            Coin<CoinType>{ amount: _ } = coin;
        }

        public fun transfer_to_treasury<CoinType>(account: &signer, amount: u64) acquires Coin {
            // ***Withdraw Coin from user account
            // Borrow Coin of type "CoinType" from account and store the amount 
            let account_balance = &mut borrow_global_mut<Coin<CoinType>>(address_of(account)).amount;

            // Dereference to obtain inner value of struct and subtract withdraw amount from coin amount stored at the account
            *account_balance = *account_balance - amount;

            // ***Deposit Coin to treasury
            // Create Coin with amount equal to the withdrawn amount 
            let account_withdraw = Coin<CoinType>{amount: amount};


            let treasury_balance = &mut borrow_global_mut<Coin<CoinType>>(@treasury2).amount;
            *treasury_balance = *treasury_balance + account_withdraw.amount;
            //Destroy account_witdraw
            Coin<CoinType>{amount: _} = account_withdraw; 
        }

        #[test_only]
        use std::debug;
        #[test_only]
        struct FakeA {}
        #[test_only]
        struct FakeB {}
        // #[test_only]
        // use aptos_framework::account::create_account_for_test;

        #[test(account = @0x01, treasury= @treasury2)]
        public fun test (account: &signer, treasury: &signer) acquires Coin{
            // create_account_for_test(@treasury2);
            initialize<FakeA>(account);
            initialize<FakeB>(account);
            initialize<FakeA>(treasury);
            initialize<FakeB>(treasury);
            transfer_to_treasury<FakeA>(account, 200);
            debug::print<u64>(&mut borrow_global_mut<Coin<FakeA>>(address_of(account)).amount); 
            debug::print<u64>(&mut borrow_global_mut<Coin<FakeA>>(@treasury2).amount);
            deposit<FakeB>(address_of(account), withdraw_from_treasury<FakeB>(500));
            debug::print<u64>(&mut borrow_global_mut<Coin<FakeB>>(address_of(account)).amount); 
            debug::print<u64>(&mut borrow_global_mut<Coin<FakeB>>(@treasury2).amount);
            // debug::print<u64>(&mut borrow_global_mut<Coin<FakeB>>(address_of(account)).amount);
        }
        

    }
}
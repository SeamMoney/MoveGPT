module aptos_router::router {
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::coin;

    use std::vector;
    use std::signer;

    use aptos_router::pancakepair::{Self};

    #[test_only]
    use aptos_std::math64::pow;
    #[test_only]
    use pancake::router;
    #[test_only]
    use pancake::swap_utils;
    #[test_only]
    use pancake::swap_test::{setup_test_with_genesis};
    #[test_only]
    use aptos_router::test_coins::{Self,A,B,C,D,E,F,G,H,I,J, register_and_mint, init_coins};

    const ROUTER_STORE_EXISTS: u64 = 0;
    const ROUTER_STORE_DOES_NOT_EXIST: u64 = 1;
    const MINIMUIM_OUTPUT_NOT_MET: u64 = 2;
    const DEADLINE_PAST: u64 = 3;

    struct RouterStore has key {
        router_signer_cap: account::SignerCapability,
        router_resource_account_addr: address,
    }

    struct UninitializedCoin {}

    fun assert_router_store_exists(
        store_holder_addr: address
    ){
        assert!(exists<RouterStore>(store_holder_addr), ROUTER_STORE_EXISTS);
    }

    fun assert_router_store_not_exists(
        store_holder_addr: address
    ){
        assert!(!exists<RouterStore>(store_holder_addr), ROUTER_STORE_DOES_NOT_EXIST);
    }

    fun initialize_router(
        owner: &signer
    ){
        // let pancake_resource_account_addr = pancakepair::initialize_pancake_pair(owner);

        let owner_addr = signer::address_of(owner);
        
        assert_router_store_not_exists(owner_addr);

        let (_, router_signer_cap) = account::create_resource_account(owner, x"aaa2220000");
        let router_resource_account_addr = account::get_signer_capability_address(&router_signer_cap);

        move_to<RouterStore>(owner, RouterStore{
                router_signer_cap: router_signer_cap, 
                router_resource_account_addr: router_resource_account_addr
            }
        );
    }

    fun check_and_reg_tokens<IN, OUT>(store_address: address) acquires RouterStore {
        let router_store = borrow_global_mut<RouterStore>(store_address);
        let router_resource_signer = account::create_signer_with_capability(&router_store.router_signer_cap);
        let router_resource_account_addr = account::get_signer_capability_address(&router_store.router_signer_cap);

        if(!coin::is_account_registered<IN>(router_resource_account_addr)){
            coin::register<IN>(&router_resource_signer);
        };

        if(!coin::is_account_registered<OUT>(router_resource_account_addr)){
            coin::register<OUT>(&router_resource_signer);
        };
    }

    fun check_and_reg_token<IN>(store_address: address) acquires RouterStore {
        let router_store = borrow_global_mut<RouterStore>(store_address);
        let router_resource_signer = account::create_signer_with_capability(&router_store.router_signer_cap);
        let router_resource_account_addr = account::get_signer_capability_address(&router_store.router_signer_cap);

        if(!coin::is_account_registered<IN>(router_resource_account_addr)){
            coin::register<IN>(&router_resource_signer);
        };
    }

    //Note from isn't always the person calling the function, from should also be the previous pair.
    public fun do_swap<IN, OUT>(
        pair: u64, 
        amount_in: u64,
        store_holder_addr: address
    ): u64 acquires RouterStore { 
        let router_store = borrow_global_mut<RouterStore>(store_holder_addr);
        let router_resource_signer = account::create_signer_with_capability(&router_store.router_signer_cap);
        let router_resource_account_addr = account::get_signer_capability_address(&router_store.router_signer_cap);

        let output_amount: u64 = 0;

        check_and_reg_tokens<IN, OUT>(store_holder_addr);

        if(pair == 0){
            
            output_amount = pancakepair::swap_pancake_pair<IN, OUT>(
                amount_in,
                &router_resource_signer,
                router_resource_account_addr
            )
        };

        return output_amount
    }

    fun do_swap_ten_route<A,B,C,D,E,F,G,H,I,J>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap E->F
        let pair_type = *vector::borrow<u64>(&pair_types, 4);
        output_amount = do_swap<E, F>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap F->G
        let pair_type = *vector::borrow<u64>(&pair_types, 5);
        output_amount = do_swap<F, G>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap G->H
        let pair_type = *vector::borrow<u64>(&pair_types, 6);
        output_amount = do_swap<G, H>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap H->I
        let pair_type = *vector::borrow<u64>(&pair_types, 7);
        output_amount = do_swap<H, I>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap I->J
        let pair_type = *vector::borrow<u64>(&pair_types, 8);
        output_amount = do_swap<I, J>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is J
        transfer_output<J>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_nine_route<A,B,C,D,E,F,G,H,I>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap E->F
        let pair_type = *vector::borrow<u64>(&pair_types, 4);
        output_amount = do_swap<E, F>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap F->G
        let pair_type = *vector::borrow<u64>(&pair_types, 5);
        output_amount = do_swap<F, G>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap G->H
        let pair_type = *vector::borrow<u64>(&pair_types, 6);
        output_amount = do_swap<G, H>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap H->I
        let pair_type = *vector::borrow<u64>(&pair_types, 7);
        output_amount = do_swap<H, I>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is I
        transfer_output<I>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_eight_route<A,B,C,D,E,F,G,H>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap E->F
        let pair_type = *vector::borrow<u64>(&pair_types, 4);
        output_amount = do_swap<E, F>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap F->G
        let pair_type = *vector::borrow<u64>(&pair_types, 5);
        output_amount = do_swap<F, G>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap G->H
        let pair_type = *vector::borrow<u64>(&pair_types, 6);
        output_amount = do_swap<G, H>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is H
        transfer_output<H>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_seven_route<A,B,C,D,E,F,G>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap E->F
        let pair_type = *vector::borrow<u64>(&pair_types, 4);
        output_amount = do_swap<E, F>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap F->G
        let pair_type = *vector::borrow<u64>(&pair_types, 5);
        output_amount = do_swap<F, G>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is G
        transfer_output<G>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_six_route<A,B,C,D,E,F>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap E->F
        let pair_type = *vector::borrow<u64>(&pair_types, 4);
        output_amount = do_swap<E, F>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is F
        transfer_output<F>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_five_route<A,B,C,D,E>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap D->E
        let pair_type = *vector::borrow<u64>(&pair_types, 3);
        output_amount = do_swap<D, E>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is E
        transfer_output<E>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_four_route<A,B,C,D>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Do Swap C->D
        let pair_type = *vector::borrow<u64>(&pair_types, 2);
        output_amount = do_swap<C, D>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is D
        transfer_output<D>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_three_route<A,B,C>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Do Swap B->C
        let pair_type = *vector::borrow<u64>(&pair_types, 1);
        output_amount = do_swap<B, C>(
            pair_type,
            output_amount,
            store_address
        );
        //Output is C
        transfer_output<C>(to, output_amount, min_output_amount, store_address);
    }

    fun do_swap_two_route<A,B>(
        pair_types: vector<u64>,
        input_amount: u64,
        min_output_amount: u64,
        to: address,
        store_address: address
    ) acquires RouterStore {
        //Do Swap A->B
        let pair_type = *vector::borrow<u64>(&pair_types, 0);
        let output_amount = do_swap<A, B>(
            pair_type,
            input_amount,
            store_address
        );
        //Output is B
        transfer_output<B>(to, output_amount, min_output_amount, store_address);
    }

    fun transfer_output<Token>(to: address, output_amount: u64, min_output_amount: u64, store_address: address) acquires RouterStore {
        let router_store = borrow_global_mut<RouterStore>(store_address);
        let router_resource_signer = account::create_signer_with_capability(&router_store.router_signer_cap);

        assert!(output_amount > min_output_amount, MINIMUIM_OUTPUT_NOT_MET);
        let coins = coin::withdraw<Token>(&router_resource_signer, output_amount);
        coin::deposit<Token>(to, coins);
    }

    //Every pair expects their resource account to have the required tokens on them.
    public entry fun swap_exact_input_for_output_three_path<A,B,C>(
        pair_types: vector<u64>,
        //We don't need an extras array yet, we'll deal with that later if needed.
        input_amount: u64,
        min_output_amount: u64,
        from: &signer,
        to: address,
        deadline: u64,
        store_address: address
    ) acquires RouterStore {
        let cur_time = timestamp::now_seconds();
        assert!(cur_time < deadline, DEADLINE_PAST);

        assert_router_store_exists(store_address);

        let router_store = borrow_global_mut<RouterStore>(store_address);
        let router_resource_account_addr = account::get_signer_capability_address(&router_store.router_signer_cap);

        if(coin::is_coin_initialized<A>()){
            check_and_reg_token<A>(store_address);
            let coins = coin::withdraw<A>(from, input_amount);
            coin::deposit<A>(router_resource_account_addr, coins);
        }
        else{
            //You need to have a coin to swap
            abort(0)
        };


        if(coin::is_coin_initialized<B>()){
            if(coin::is_coin_initialized<C>()){
                do_swap_three_route<A,B,C>(pair_types,input_amount,min_output_amount,to, store_address);
            }
            else{
                do_swap_two_route<A,B>(pair_types,input_amount,min_output_amount,to, store_address);
            };
        }
        else{
            //Output token is A
            transfer_output<A>(to, input_amount, 0, store_address);
        };
    }

    /*
        Note to any recruiters looking at this code:
        In any other programing language, id consider the below code ATROCIOUS.
        But, I have to do this this way.
        Long story short, when you call the below function, you would pass a tokens address for the A,B,C...J types.
        These then get retrieved by the blockchain and converted into structs that represent the tokens we're swaping.
        I can't loop over these Generic types and I can't convert a list of strings into the token structs that I need.

        Traditionally, I would accept a list of token addresses, and pass those to the swap functions, I can't do that here.
        So we get the mega tree of if statements you see here.

        Also, as of the time i'm writing this, there are no switch statements.
    */

    //Every pair expects their resource account to have the required tokens on them.
    public entry fun swap_exact_input_for_output_ten_path<A,B,C,D,E,F,G,H,I,J>(
        pair_types: vector<u64>,
        //We don't need an extras array yet, we'll deal with that later if needed.
        input_amount: u64,
        min_output_amount: u64,
        from: &signer,
        to: address,
        deadline: u64,
        store_address: address
    ) acquires RouterStore {
        let cur_time = timestamp::now_seconds();
        assert!(cur_time < deadline, DEADLINE_PAST);

        assert_router_store_exists(store_address);

        let router_store = borrow_global_mut<RouterStore>(store_address);
        let router_resource_account_addr = account::get_signer_capability_address(&router_store.router_signer_cap);

        if(coin::is_coin_initialized<A>()){
            check_and_reg_token<A>(store_address);
            let coins = coin::withdraw<A>(from, input_amount);
            coin::deposit<A>(router_resource_account_addr, coins);
        }
        else{
            //You need to have a coin to swap
            abort(0)
        };


        if(coin::is_coin_initialized<B>()){
            if(coin::is_coin_initialized<C>()){
                if(coin::is_coin_initialized<D>()){
                    if(coin::is_coin_initialized<E>()){
                        if(coin::is_coin_initialized<F>()){
                            if(coin::is_coin_initialized<G>()){
                                if(coin::is_coin_initialized<H>()){
                                    if(coin::is_coin_initialized<I>()){
                                        if(coin::is_coin_initialized<J>()){
                                            do_swap_ten_route<A,B,C,D,E,F,G,H,I,J>(pair_types,input_amount,min_output_amount,to, store_address);
                                        }
                                        else {
                                            do_swap_nine_route<A,B,C,D,E,F,G,H,I>(pair_types,input_amount,min_output_amount,to, store_address);
                                        }
                                    }
                                    else {
                                        do_swap_eight_route<A,B,C,D,E,F,G,H>(pair_types,input_amount,min_output_amount,to, store_address);
                                    }
                                }
                                else {
                                    do_swap_seven_route<A,B,C,D,E,F,G>(pair_types,input_amount,min_output_amount,to, store_address);
                                }
                            }
                            else {
                                do_swap_six_route<A,B,C,D,E,F>(pair_types,input_amount,min_output_amount,to, store_address);
                            }
                        }
                        else {
                            do_swap_five_route<A,B,C,D,E>(pair_types,input_amount,min_output_amount,to, store_address);
                        }
                    }
                    else {
                        do_swap_four_route<A,B,C,D>(pair_types,input_amount,min_output_amount,to, store_address);
                    }
                }
                else {
                    do_swap_three_route<A,B,C>(pair_types,input_amount,min_output_amount,to, store_address);
                }
            }
            else{
                do_swap_two_route<A,B>(pair_types,input_amount,min_output_amount,to, store_address);
            };
        }
        else{
            //Output token is A
            transfer_output<A>(to, input_amount, 0, store_address);
        };
    }

    const MAX_U64: u64 = 18446744073709551615;
    const MINIMUM_LIQUIDITY: u128 = 1000;

    const RECIEVED_OUTPUT_NOT_EQ_CALCED: u64 = 10000;
    const ALICE_SPENT_NOT_EQ_INPUT: u64 = 10001;
    const ALICE_HOLDINGS_NOT_EQ_OUTPUT: u64 = 10002;
    const RESERVE_NOT_EQ_EXPECTED_RESERVE: u64 = 10003;

    #[test(router_signer = @111111, dev = @dev, admin = @default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_router_two_route(
        router_signer: &signer,
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer
    ) acquires RouterStore {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(router_signer));

        let router_addr = signer::address_of(router_signer);
        let alice_addr = signer::address_of(alice);

        initialize_router(router_signer);

        setup_test_with_genesis(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();

        test_coins::register_and_mint<A>(&coin_owner, bob, 100 * pow(10, 8));
        test_coins::register_and_mint<B>(&coin_owner, bob, 100 * pow(10, 8));
        test_coins::register_and_mint<A>(&coin_owner, alice, 100 * pow(10, 8));

        let initial_reserve_x = 5 * pow(10, 8);
        let initial_reserve_y = 10 * pow(10, 8);
        let input_x = 2 * pow(10, 8);

        //bob provides 5:10 CAKE-BUSD liq
        router::add_liquidity<A, B>(bob, initial_reserve_x, initial_reserve_y, 0, 0);

        let alice_token_x_before_balance = coin::balance<A>(signer::address_of(alice));

        //Register output to Alice
        coin::register<B>(alice);
        
        let deadline = timestamp::now_seconds() + 10; 
        let pair_types = vector::empty<u64>();
        vector::push_back<u64>(&mut pair_types, 0);
        
         // public entry fun swap_exact_input_for_output<A,B,C>(
        // pair_types: vector<u64>,
        // input_amount: u64,
        // min_output_amount: u64,
        // from: &signer,
        // to: address,
        // deadline: u64,
        // store_address: address
        // )
        swap_exact_input_for_output_three_path<A, B, UninitializedCoin>(
            pair_types,
            input_x,
            0,
            alice,
            alice_addr,
            deadline,
            router_addr
        );

        let alice_token_x_after_balance = coin::balance<A>(signer::address_of(alice));
        let alice_token_y_after_balance = coin::balance<B>(signer::address_of(alice));

        let output_y = swap_utils::get_amount_out(input_x, initial_reserve_x, initial_reserve_y);

        assert!((alice_token_x_before_balance - alice_token_x_after_balance) == input_x, ALICE_SPENT_NOT_EQ_INPUT);
        assert!(alice_token_y_after_balance == (output_y as u64), ALICE_HOLDINGS_NOT_EQ_OUTPUT);
    }


    #[test(router_signer = @111111, dev = @dev, admin = @default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_router_three_route(
        router_signer: &signer,
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer
    ) acquires RouterStore {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(router_signer));

        let router_addr = signer::address_of(router_signer);
        let alice_addr = signer::address_of(alice);

        initialize_router(router_signer);

        setup_test_with_genesis(dev, admin, treasury, resource_account);

        let coin_owner = test_coins::init_coins();

        test_coins::register_and_mint<A>(&coin_owner, bob, 100 * pow(10, 8));
        test_coins::register_and_mint<B>(&coin_owner, bob, 100 * pow(10, 8));
        test_coins::register_and_mint<C>(&coin_owner, bob, 100 * pow(10, 8));
        test_coins::register_and_mint<A>(&coin_owner, alice, 100 * pow(10, 8));

        let initial_reserve_x = 5 * pow(10, 8);
        let initial_reserve_y = 10 * pow(10, 8);
        let input_x = 2 * pow(10, 8);

        //bob provides 5:10 CAKE-BUSD liq
        router::add_liquidity<A, B>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<B, C>(bob, initial_reserve_x, initial_reserve_y, 0, 0);

        let alice_token_x_before_balance = coin::balance<A>(signer::address_of(alice));

        //Register output to Alice
        coin::register<C>(alice);
        
        let deadline = timestamp::now_seconds() + 10; 
        let pair_types = vector::empty<u64>();
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        
         // public entry fun swap_exact_input_for_output<A,B,C>(
        // pair_types: vector<u64>,
        // input_amount: u64,
        // min_output_amount: u64,
        // from: &signer,
        // to: address,
        // deadline: u64,
        // store_address: address
        // )
        swap_exact_input_for_output_three_path<A, B, C>(
            pair_types,
            input_x,
            0,
            alice,
            alice_addr,
            deadline,
            router_addr
        );

        let alice_token_x_after_balance = coin::balance<A>(signer::address_of(alice));
        let alice_token_y_after_balance = coin::balance<C>(signer::address_of(alice));


        let output_b = swap_utils::get_amount_out(input_x, initial_reserve_x, initial_reserve_y);
        let output_c = swap_utils::get_amount_out(output_b, initial_reserve_x, initial_reserve_y);

        assert!((alice_token_x_before_balance - alice_token_x_after_balance) == input_x, ALICE_SPENT_NOT_EQ_INPUT);
        assert!(alice_token_y_after_balance == (output_c as u64), ALICE_HOLDINGS_NOT_EQ_OUTPUT);
    }


    #[test(router_signer = @111111, dev = @dev, admin = @default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_router_ten_route_ten(
        router_signer: &signer,
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer
    ) acquires RouterStore {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(router_signer));

        let router_addr = signer::address_of(router_signer);
        let alice_addr = signer::address_of(alice);

        initialize_router(router_signer);

        setup_test_with_genesis(dev, admin, treasury, resource_account);

        let coin_owner = init_coins();


        //Reigster and mint all tokens to bob
        register_and_mint<A>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<B>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<C>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<D>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<E>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<F>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<G>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<H>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<I>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<J>(&coin_owner, bob, 100 * pow(10, 8)); 

        //Register and mint input token to alice
        register_and_mint<A>(&coin_owner, alice, 100 * pow(10, 8));

        //Register output to Alice
        coin::register<J>(alice);

        let initial_reserve_x = 5 * pow(10, 8);
        let initial_reserve_y = 10 * pow(10, 8);
        let input_a = 2 * pow(10, 8);

        //bob provides 5:10 X-Y liq
        router::add_liquidity<A, B>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<B, C>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<C, D>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<D, E>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<E, F>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<F, G>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<G, H>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<H, I>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<I, J>(bob, initial_reserve_x, initial_reserve_y, 0, 0);

        let alice_token_x_before_balance = coin::balance<A>(signer::address_of(alice));

        
        let deadline = timestamp::now_seconds() + 10; 
        let pair_types = vector::empty<u64>();
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        
         // public entry fun swap_exact_input_for_output<A,B,C>(
        // pair_types: vector<u64>,
        // input_amount: u64,
        // min_output_amount: u64,
        // from: &signer,
        // to: address,
        // deadline: u64,
        // store_address: address
        // )
        swap_exact_input_for_output_ten_path<A,B,C,D,E,F,G,H,I,J>(
            pair_types,
            input_a,
            0,
            alice,
            alice_addr,
            deadline,
            router_addr
        );

        let alice_token_x_after_balance = coin::balance<A>(signer::address_of(alice));
        let alice_token_y_after_balance = coin::balance<J>(signer::address_of(alice));

        let output_b = swap_utils::get_amount_out(input_a, initial_reserve_x, initial_reserve_y);
        let output_c = swap_utils::get_amount_out(output_b, initial_reserve_x, initial_reserve_y);
        let output_d = swap_utils::get_amount_out(output_c, initial_reserve_x, initial_reserve_y);
        let output_e = swap_utils::get_amount_out(output_d, initial_reserve_x, initial_reserve_y);
        let output_f = swap_utils::get_amount_out(output_e, initial_reserve_x, initial_reserve_y);
        let output_g = swap_utils::get_amount_out(output_f, initial_reserve_x, initial_reserve_y);
        let output_h = swap_utils::get_amount_out(output_g, initial_reserve_x, initial_reserve_y);
        let output_i = swap_utils::get_amount_out(output_h, initial_reserve_x, initial_reserve_y);
        let output_j = swap_utils::get_amount_out(output_i, initial_reserve_x, initial_reserve_y);

        assert!((alice_token_x_before_balance - alice_token_x_after_balance) == input_a, ALICE_SPENT_NOT_EQ_INPUT);
        assert!(alice_token_y_after_balance == (output_j as u64), ALICE_HOLDINGS_NOT_EQ_OUTPUT);
    }

    #[test(router_signer = @111111, dev = @dev, admin = @default_admin, resource_account = @pancake, treasury = @0x23456, bob = @0x12345, alice = @0x12346)]
    fun test_router_ten_route_nine(
        router_signer: &signer,
        dev: &signer,
        admin: &signer,
        resource_account: &signer,
        treasury: &signer,
        bob: &signer,
        alice: &signer
    ) acquires RouterStore {
        account::create_account_for_test(signer::address_of(bob));
        account::create_account_for_test(signer::address_of(alice));
        account::create_account_for_test(signer::address_of(router_signer));

        let router_addr = signer::address_of(router_signer);
        let alice_addr = signer::address_of(alice);

        initialize_router(router_signer);

        setup_test_with_genesis(dev, admin, treasury, resource_account);

        let coin_owner = init_coins();


        //Reigster and mint all tokens to bob
        register_and_mint<A>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<B>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<C>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<D>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<E>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<F>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<G>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<H>(&coin_owner, bob, 100 * pow(10, 8));
        register_and_mint<I>(&coin_owner, bob, 100 * pow(10, 8));

        //Register and mint input token to alice
        register_and_mint<A>(&coin_owner, alice, 100 * pow(10, 8));

        //Register output to Alice
        coin::register<I>(alice);

        let initial_reserve_x = 5 * pow(10, 8);
        let initial_reserve_y = 10 * pow(10, 8);
        let input_a = 2 * pow(10, 8);

        //bob provides 5:10 X-Y liq
        router::add_liquidity<A, B>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<B, C>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<C, D>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<D, E>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<E, F>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<F, G>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<G, H>(bob, initial_reserve_x, initial_reserve_y, 0, 0);
        router::add_liquidity<H, I>(bob, initial_reserve_x, initial_reserve_y, 0, 0);

        let alice_token_x_before_balance = coin::balance<A>(signer::address_of(alice));

        
        let deadline = timestamp::now_seconds() + 10; 
        let pair_types = vector::empty<u64>();
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        vector::push_back<u64>(&mut pair_types, 0);
        
         // public entry fun swap_exact_input_for_output<A,B,C>(
        // pair_types: vector<u64>,
        // input_amount: u64,
        // min_output_amount: u64,
        // from: &signer,
        // to: address,
        // deadline: u64,
        // store_address: address
        // )
        swap_exact_input_for_output_ten_path<A,B,C,D,E,F,G,H,I,UninitializedCoin>(
            pair_types,
            input_a,
            0,
            alice,
            alice_addr,
            deadline,
            router_addr
        );

        let alice_token_x_after_balance = coin::balance<A>(signer::address_of(alice));
        let alice_token_y_after_balance = coin::balance<I>(signer::address_of(alice));

        let output_b = swap_utils::get_amount_out(input_a, initial_reserve_x, initial_reserve_y);
        let output_c = swap_utils::get_amount_out(output_b, initial_reserve_x, initial_reserve_y);
        let output_d = swap_utils::get_amount_out(output_c, initial_reserve_x, initial_reserve_y);
        let output_e = swap_utils::get_amount_out(output_d, initial_reserve_x, initial_reserve_y);
        let output_f = swap_utils::get_amount_out(output_e, initial_reserve_x, initial_reserve_y);
        let output_g = swap_utils::get_amount_out(output_f, initial_reserve_x, initial_reserve_y);
        let output_h = swap_utils::get_amount_out(output_g, initial_reserve_x, initial_reserve_y);
        let output_i = swap_utils::get_amount_out(output_h, initial_reserve_x, initial_reserve_y);

        assert!((alice_token_x_before_balance - alice_token_x_after_balance) == input_a, ALICE_SPENT_NOT_EQ_INPUT);
        assert!(alice_token_y_after_balance == (output_i as u64), ALICE_HOLDINGS_NOT_EQ_OUTPUT);
    }
    

}
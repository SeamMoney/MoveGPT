module pocker_addr::pocker {
    use aptos_framework::event;
    use std::signer;
    // use aptos_std::table::{Self, Table};
    use aptos_framework::account;
    // use std::string::String;
    use std::option::{Self, Option};
    use aptos_framework::coin;
    use aptos_std::type_info;

    
    // Errors
    const E_NOT_INITIALIZED: u64 = 1;
    const ETASK_DOESNT_EXIST: u64 = 2;
    const ETASK_IS_COMPLETED: u64 = 3;
    const INVALID_AMOUNT: u64 = 4;
    const ENO_WRONG_SENDER: u64 = 5;

    struct Battle has key {
        owner: address,
        player: Option<address>,
        winner: Option<address>,
        bet_token: address,
        amount: u64,
        create_battle_event: event::EventHandle<CreateBattleEvent>
    }

    struct CreateBattleEvent has drop, store {
        owner: address,
        bet_token: address,
        amount: u64,
    }

    public entry fun create_battle<CoinType>(account: &signer, amount: u64) acquires Battle{
        let signer_address = signer::address_of(account);
        // let (battle, _) = account::create_resource_account(account, seeds);
        // let battle_address = signer::address_of(&battle);

        let coin_address = coin_address<CoinType>();

        assert!(amount == 0, amount);

        // coin::transfer<CoinType>(account, battle_address, amount);

        let _battle = Battle {
            owner: signer_address,
            player: option::none(),
            winner: option::none(),
            bet_token: coin_address,
            amount,
            create_battle_event: account::new_event_handle<CreateBattleEvent>(account)
        };

        move_to(account, _battle);

        event::emit_event<CreateBattleEvent>(
            &mut borrow_global_mut<Battle>(signer_address).create_battle_event,
            CreateBattleEvent {
                owner: signer_address,
                bet_token: coin_address,
                amount
            }
        );
    }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    #[test_only] 
    struct DivergentMoney { }
     #[test(admin = @0x123, token_vesting = @pocker_addr)]
    public entry fun test_create_pocker(admin: signer, token_vesting: signer) acquires Battle {
    // creates an admin @todolist_addr account for test
    account::create_account_for_test(signer::address_of(&admin));  

    aptos_framework::managed_coin::initialize<DivergentMoney>(
            &token_vesting,
            b"Divergent Money",
            b"DOK",
            10,
            true
        );

    aptos_framework::managed_coin::register<DivergentMoney>(&admin);
    aptos_framework::managed_coin::mint<DivergentMoney>(&token_vesting,signer::address_of(&admin),100);  
    // initialize contract with admin account
    create_battle<DivergentMoney>(&admin, 10);

    assert!(
            coin::balance<DivergentMoney>(signer::address_of(&admin))==100,
            coin::balance<DivergentMoney>(signer::address_of(&admin))
        ); 
    }
}


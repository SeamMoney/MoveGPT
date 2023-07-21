module CoinFlip::Flip {

    use std::vector;
    use std::option::{Self, Option};
    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_account;
    // use aptos_framework::managed_coin;

    const EGAME_NOT_FOUND: u64 = 0;
    const ELOW_BALANCE: u64 = 1;
    const EGAME_STORE_DOESNT_EXIST: u64 = 2;
    const EINVALID_BALANCE: u64 = 3;
    const EGAME_ALREADY_EXISTS: u64 = 4;
    const EINVALID_SIGNER: u64 = 5;

    struct MyCoin {}

    struct Game has store {
        game_id: u64,
        owner: address,
        owner_choice: bool,
        joinee: Option<address>,
        coin_store: coin::Coin<AptosCoin>,
        winner: Option<address>,
        bet_amount: u64,
        result: Option<u64>,
        room_creation_time: u64
    }

    struct GameStore has key {
        games: vector<Game>,
    }

    fun init_module(creator: &signer) {
        move_to<GameStore>(creator, GameStore{
            games: vector::empty()
        });
    }
      
    public entry fun create_room(creator: &signer, game_id: u64, bet_amount: u64, choice: bool) acquires GameStore {
        let admin = @CoinFlip;
        assert!(exists<GameStore>(admin), EGAME_STORE_DOESNT_EXIST);
        let creator_addr = signer::address_of(creator);
        let game_store = borrow_global_mut<GameStore>(admin);
        let length = vector::length(&game_store.games);
        let index = 0;
        while (index < length) {
            if (vector::borrow(&game_store.games, index).game_id == game_id) {
                break
            };
            index = index +1;
        };
        assert!(index == length, EGAME_ALREADY_EXISTS);
        let bet = coin::withdraw<AptosCoin>(creator, bet_amount);
        let current_time = timestamp::now_microseconds();
        let new_game = Game {
            game_id,
            owner: creator_addr,
            joinee: option::none(),
            coin_store: bet,
            winner: option::none(),
            owner_choice: choice,
            bet_amount,
            result: option::none(),
            room_creation_time: current_time
        };
        vector::push_back(&mut game_store.games, new_game);
    }

    public entry fun join_room(joinee: &signer, game_id: u64) acquires GameStore {
        let admin = @CoinFlip;
        assert!(exists<GameStore>(admin), EGAME_STORE_DOESNT_EXIST);
        let joinee_addr = signer::address_of(joinee);
        let game_store = borrow_global_mut<GameStore>(admin);
        let length = vector::length(&game_store.games);
        let index = 0;
        while (index < length) {
            if (vector::borrow(&game_store.games, index).game_id == game_id) {
                break
            };
            index = index +1;
        };
        assert!(index != length, EGAME_NOT_FOUND);
        let game = vector::borrow_mut(&mut game_store.games,index);
        assert!(coin::balance<AptosCoin>(joinee_addr) >= game.bet_amount, ELOW_BALANCE);
        let coin = coin::withdraw(joinee, game.bet_amount);
        let result = timestamp::now_microseconds() %2;
        game.result = option::some(result);
        game.joinee = option::some(joinee_addr);
        coin::merge(&mut game.coin_store, coin);
        if (result == 0) {
            if (!game.owner_choice) {
                game.winner = option::some(game.owner);
            }
            else {
                game.winner = option::some(joinee_addr);
            }
        }
        else {
            if (game.owner_choice) {
                game.winner = option::some(game.owner);
            }
            else {
                game.winner = option::some(joinee_addr);
            }
        };
    }

    public entry fun claim_rewards(winner: &signer, game_id: u64) acquires GameStore {
        let admin = @CoinFlip;
        let game_store = borrow_global_mut<GameStore>(admin);
        let length = vector::length(&game_store.games);
        let index = 0;
        while (index < length) {
            if (vector::borrow(&game_store.games, index).game_id == game_id) {
                break
            };
            index = index +1;
        };
        assert!(index != length, EGAME_NOT_FOUND); 
        let winner_addr = signer::address_of(winner);
        let game = vector::borrow_mut(&mut game_store.games, index);
        assert!(winner_addr == *option::borrow(&game.winner), EINVALID_SIGNER);
        let total_bet = coin::value<AptosCoin>(&game.coin_store);
        let fees = (total_bet * 4)/100;
        let fees_coin = coin::extract(&mut game.coin_store, fees);

        coin::deposit<AptosCoin>(admin, fees_coin);

        let winner_coin = coin::extract_all(&mut game.coin_store);
        coin::deposit<AptosCoin>(winner_addr, winner_coin);
    }

    #[test_only]
    public fun mint_coins(aptos_framework: &signer, creator: address, joinee: address, initial_mint_amount: u64)  {
        aptos_account::create_account(joinee);
        aptos_account::create_account(creator);


        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        coin::deposit(joinee,coin::mint<AptosCoin>(initial_mint_amount, &mint_cap));
        coin::deposit(creator,coin::mint<AptosCoin>(initial_mint_amount, &mint_cap));

        coin::destroy_burn_cap<AptosCoin>(burn_cap);
        coin::destroy_mint_cap<AptosCoin>(mint_cap);
    }

    #[test(aptos_framework = @0x1, creator = @0x5, joinee = @0x6, module_owner= @CoinFlip)]
    public entry fun end_to_end(aptos_framework: signer, module_owner: signer, creator: signer, joinee: signer) acquires GameStore {
        let module_owner_addr = signer::address_of(&module_owner);
        let creator_addr = signer::address_of(&creator);
        let joinee_addr = signer::address_of(&joinee);
        
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let initial_mint_amount = 100000;
        mint_coins(&aptos_framework, creator_addr, joinee_addr, initial_mint_amount);
        assert!(coin::balance<AptosCoin>(creator_addr) == initial_mint_amount, EINVALID_BALANCE);
        assert!(coin::balance<AptosCoin>(joinee_addr) == initial_mint_amount, EINVALID_BALANCE);

        aptos_account::create_account(module_owner_addr);

        init_module(&module_owner); 
        assert!(exists<GameStore>(module_owner_addr),EGAME_STORE_DOESNT_EXIST);

        let game_id = 1;
        let bet_amount = 100;
        let choice = false;

        create_room(&creator, game_id, bet_amount, choice);
        assert!(coin::balance<AptosCoin>(creator_addr) == (initial_mint_amount - bet_amount), EINVALID_BALANCE);

        join_room(&joinee, game_id);
        assert!(coin::balance<AptosCoin>(joinee_addr) == (initial_mint_amount - bet_amount), EINVALID_BALANCE);

        claim_rewards(&creator, game_id);
    }
}
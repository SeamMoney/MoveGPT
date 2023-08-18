```rust
module gamble::gamble_game {
    use aptos_std::table::{Self, Table};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::signer;
    use aptos_framework::timestamp;

    struct GameRound has store {
        odd_vol: u64, // total odd volume bet in this round
        even_vol: u64,  // total even volume bet in this round
        num_tx: u64,    // number of transaction in this round
        start_at: u64,  // round start time
        duration: u64, // round duration
        min_bet: u64    // min amount bet
    }

    struct Game has key {
        rounds: Table<u64, GameRound>,  // list round
        num_round: u64,  // number of round created
        balance: Coin<AptosCoin>, // token holder
    }

    struct User has key {
        rounds: Table<u64, UserRound>,  // list round user joined
    }

    struct UserRound has store {
        odd_vol: u64, // total odd volume user bet in this round
        even_vol: u64,  // total even volume user bet in this round
    }

    fun init_module(sender: &signer) {
        move_to(sender, Game {
            rounds: table::new(),
            num_round: 0,
            balance: coin::zero()
        })
    }

    public entry fun start_round(admin: &signer, start_at: u64, duration: u64, min_bet: u64) acquires Game {
        // only admin can start round
        assert!(signer::address_of(admin) == @gamble, 1);

        // retrieve game resource
        let game = borrow_global_mut<Game>(@gamble);

        // generate id of new round
        let round_id = game.num_round + 1;

        table::add(&mut game.rounds, round_id, GameRound {
            odd_vol: 0,
            even_vol: 0,
            num_tx: 0,
            start_at,
            duration, 
            min_bet
        });
    }

    public entry fun bet(sender: &signer, round_id: u64, bet_type: u64, amount: u64) acquires Game, User {
        // retrieve game resource
        let game = borrow_global_mut<Game>(@gamble);

        // get current time
        let now = timestamp::now_seconds();

        // get game round info
        let gameRound = table::borrow_mut(&mut game.rounds, round_id);
        
        // check round is still running
        assert!(gameRound.start_at <= now && now <= gameRound.start_at + gameRound.duration, 1);
        
        // check amount token bet >= min bet
        assert!(amount >= gameRound.min_bet, 1);

        // increase number of transaction and bet volumne
        gameRound.num_tx = gameRound.num_tx + 1;

        if(bet_type == 0) {
            gameRound.even_vol = gameRound.even_vol + amount;
        }
        else {
            gameRound.odd_vol = gameRound.odd_vol + amount;
        };

        // create user resource if not exist
        if(!exists<User>(signer::address_of(sender))) {
            move_to(sender, User {
                rounds: table::new()
            })
        };

        let user = borrow_global_mut<User>(signer::address_of(sender));
        
        // create userRound if not exist
        if(!table::contains(&user.rounds, round_id)) {
            table::add(&mut user.rounds, round_id, UserRound {
                odd_vol: 0,
                even_vol: 0, 
            })
        };

        let userRound = table::borrow_mut(&mut user.rounds, round_id);

        // update bet volume of user
        if(bet_type == 0) {
            userRound.even_vol = userRound.even_vol + amount;
        }
        else {
            userRound.odd_vol = userRound.odd_vol + amount;
        };

        // transfer token from user to contract
        coin::merge(&mut game.balance, coin::withdraw<AptosCoin>(sender, amount));
    }

    public entry fun claim(sender: &signer, round_id: u64) acquires Game, User {
        // retrieve game resource
        let game = borrow_global_mut<Game>(@gamble);

        // get current time
        let now = timestamp::now_seconds();

        // get game round info
        let gameRound = table::borrow_mut(&mut game.rounds, round_id);
        
        // check round is finished
        assert!(now > gameRound.start_at + gameRound.duration, 1);

        // get user round data
        let user = borrow_global<User>(signer::address_of(sender));
        let userRound = table::borrow(&user.rounds, round_id);

        // calculate reward
        let reward = if (gameRound.num_tx % 2 == 0) {
            userRound.even_vol + gameRound.odd_vol * userRound.even_vol / gameRound.even_vol
        } else {
            userRound.odd_vol + gameRound.even_vol * userRound.odd_vol / gameRound.odd_vol
        };

        // transfer token from contract to user
        coin::deposit(signer::address_of(sender), coin::extract(&mut game.balance, reward));
    }

    
}
```
```rust
module diamond_clicker::game {
    use std::signer;
    use std::vector;

    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    /*
    Errors
    DO NOT EDIT
    */
    const ERROR_GAME_STORE_DOES_NOT_EXIST: u64 = 0;
    const ERROR_UPGRADE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE: u64 = 2;

    const POWERUP_NAMES: vector<vector<u8>> = vector[b"Bruh", b"Aptomingos", b"Aptos Monkeys"];
    // cost, dpm (diamonds per minute)
    const POWERUP_VALUES: vector<vector<u64>> = vector[
        vector[5, 5],
        vector[25, 30],
        vector[250, 350],
    ];

    /*
    Structs
    DO NOT EDIT
    */
    struct Upgrade has key, store, copy {
        name: vector<u8>,
        amount: u64
    }

    struct GameStore has key {
        diamonds: u64,
        upgrades: vector<Upgrade>,
        last_claimed_timestamp_seconds: u64,
    }

    /*
    Functions
    */

    public fun initialize_game(account: &signer) {
        // move_to account with new GameStore
        move_to(account, GameStore {
            diamonds: 0,
            upgrades: vector::empty<Upgrade>(),
            last_claimed_timestamp_seconds: 0
        });
    }

    public entry fun click(account: &signer) acquires GameStore {
        // check if GameStore does not exist - if not, initialize_game
        let address = signer::address_of(account);
        if (!exists<GameStore>(address)) {
            initialize_game(account);
        };

        // increment game_store.diamonds by +1
        let game = borrow_global_mut<GameStore>(address);
        game.diamonds = game.diamonds + 1;
    }

    fun get_unclaimed_diamonds(account_address: address, current_timestamp_seconds: u64): u64 acquires GameStore {
        let game = borrow_global_mut<GameStore>(account_address);
        let elapsed = (current_timestamp_seconds - game.last_claimed_timestamp_seconds)/60;
        let dpm = get_diamonds_per_minute(account_address);
        elapsed * dpm
    }

    fun claim(account_address: address) acquires GameStore {
        // set game_store.diamonds to current diamonds + unclaimed_diamonds
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::now_seconds());
        let game = borrow_global_mut<GameStore>(account_address);
        // set last_claimed_timestamp_seconds to the current timestamp in seconds
        game.last_claimed_timestamp_seconds = timestamp::now_seconds();
        game.diamonds = game.diamonds + unclaimed_diamonds;
    }

    public entry fun upgrade(account: &signer, upgrade_index: u64, upgrade_amount: u64) acquires GameStore {
        // check that the game store exists
        let address = signer::address_of(account);
        assert!(exists<GameStore>(address),ERROR_GAME_STORE_DOES_NOT_EXIST);

        // check the powerup_names length is greater than or equal to upgrade_index
        assert!(vector::length(&POWERUP_NAMES) >= upgrade_index, ERROR_UPGRADE_DOES_NOT_EXIST);

        // claim for account address
        claim(address);

        // check that the user has enough coins to make the current upgrade
        let diamonds = get_diamonds(address);
        let upgrade_value = vector::borrow(&POWERUP_VALUES, upgrade_index);
        let upgrade_name = vector::borrow(&POWERUP_NAMES, upgrade_index);
        // let cost = *vector::borrow(&upgrade_value, 0);
        let dpm = vector::borrow(&*upgrade_value, 0);
        assert!(diamonds > upgrade_amount, ERROR_NOT_ENOUGH_DIAMONDS_TO_UPGRADE);
        let isExist = false; 
        let game = borrow_global_mut<GameStore>(address);
        let index = vector::length(&game.upgrades);

        // loop through game_store upgrades - if the upgrade exists then increment but the upgrade_amount
        while (index > 0) {
            index = index - 1;
            let upgrade = vector::borrow_mut(&mut game.upgrades, index);
            if (upgrade.name == *upgrade_name) {
                upgrade.amount = upgrade.amount + *dpm;
                isExist = true;
            }
        };
        
        if (!isExist) {
            let new_upgrade = Upgrade {
                name: *upgrade_name,
                amount: *dpm 
            };
            vector::push_back(&mut game.upgrades, new_upgrade);
        };

        // if upgrade_existed does not exist then create it with the base upgrade_amount

        // set game_store.diamonds to current diamonds - total_upgrade_cost
        game.diamonds = game.diamonds - upgrade_amount;
    }

    #[view]
    public fun get_diamonds(account_address: address): u64 acquires GameStore {
        let unclaimed_diamonds = get_unclaimed_diamonds(account_address, timestamp::now_seconds());
        let game = borrow_global_mut<GameStore>(account_address);
        game.diamonds + unclaimed_diamonds
        // return game_store.diamonds + unclaimed_diamonds
    }

    #[view]
    public fun get_diamonds_per_minute(account_address: address): u64 acquires GameStore {
        // loop over game_store.upgrades - calculate dpm * current_upgrade.amount to get the total diamonds_per_minute
        let game = borrow_global_mut<GameStore>(account_address);
        let dpm = 0;

        let index = vector::length(&game.upgrades);
        while (index > 0) {
            index = index - 1;
            let upgrade = vector::borrow(&game.upgrades, index);
            dpm  = dpm + upgrade.amount;
        };
        dpm 
        // return diamonds_per_minute of all the user's powerups
    }

    #[view]
    public fun get_powerups(account_address: address): vector<Upgrade> acquires GameStore {
        let game = borrow_global_mut<GameStore>(account_address);
        game.upgrades
    }

    /*
    Tests
    DO NOT EDIT
    */
    inline fun test_click_loop(signer: &signer, amount: u64) acquires GameStore {
        let i = 0;
        while (amount > i) {
            click(signer);
            i = i + 1;
        }
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_without_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_click_with_initialize_game(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);
        let test_one_address = signer::address_of(test_one);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 1, 0);

        click(test_one);

        let current_game_store = borrow_global<GameStore>(test_one_address);

        assert!(current_game_store.diamonds == 2, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 0, location = diamond_clicker::game)]
    fun test_upgrade_does_not_exist(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    #[expected_failure(abort_code = 2, location = diamond_clicker::game)]
    fun test_upgrade_does_not_have_enough_diamonds(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        click(test_one);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_one(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 5);
        upgrade(test_one, 0, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_two(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 25);

        upgrade(test_one, 1, 1);
    }

    #[test(aptos_framework = @0x1, account = @0xCAFE, test_one = @0x12)]
    fun test_upgrade_three(
        aptos_framework: &signer,
        account: &signer,
        test_one: &signer,
    ) acquires GameStore {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let aptos_framework_address = signer::address_of(aptos_framework);
        let account_address = signer::address_of(account);

        account::create_account_for_test(aptos_framework_address);
        account::create_account_for_test(account_address);

        test_click_loop(test_one, 250);

        upgrade(test_one, 2, 1);
    }
}


```
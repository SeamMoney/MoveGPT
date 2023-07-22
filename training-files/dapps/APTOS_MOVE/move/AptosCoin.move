module publisher::AptosCoin {


    // IMPORTS
    use std::signer;
    // use std::debug;

    // CONSTANTS
    const MODULE_OWNER:address = @0x1000;

    // STRUCTS
    struct Coin has key,copy,store {
        value : u64,
    }
    struct Balance has key,copy,store {
        coin : Coin,
    }

    // ERRORS
    const ERR_NOT_MODULE_OWNER:u64 = 0;
    const ERR_INSUFFICIENT_BALANCE:u64 = 1;
    const ERR_ALREADY_HAS_BALANCE: u64 = 2;

    // FUNCS

    public fun mint(module_owner: &signer, mint_addr: address, amount: u64) acquires Balance {
        let owner_addr = signer::address_of(module_owner);
        assert!(owner_addr == MODULE_OWNER, ERR_NOT_MODULE_OWNER);
        deposit(mint_addr, Coin {value: amount});
    }

    public fun get_balance(addr: address): u64 acquires Balance {
        *&borrow_global<Balance>(addr).coin.value
    } 
    // spec : get_balance
    spec get_balance {
        pragma aborts_if_is_strict;
        aborts if !exists<Balance>(addr);
    }

    public fun publish_balance(account: &signer) {
        let addr = signer::address_of(account);
        let emptyCoin = Coin { value: 0 };
        assert!(!exists<Balance>(addr), ERR_ALREADY_HAS_BALANCE);
        move_to(account, Balance {coin : emptyCoin});
    }

    public fun transfer(from: &signer, to: address, amount: u64) acquires Balance {
        let signer_address = signer::address_of(from);
        let check = withdraw(signer_address, amount);
        deposit(to, check);
    }
    // spec : transfer
    spec transfer {
        let addr_from = signer::address_of(from);
        let balance_from = global<Balance>(addr_from).coin.value;

        let balance_to = global<Balance>(to).coin.value;

        let post balance_from_post = global<Balance>(addr_from).coin.value;
        let post balance_to_post = global<Balance>(to).coin.value;

        ensures balance_from_post == balance_from - amount;
        ensures balance_to_post == balance_to + amount;
    }


    // CORE FUNCS

    fun deposit(addr: address, check: Coin) acquires Balance {
        let _balance = get_balance(addr);
        let balance_reference = &mut borrow_global_mut<Balance>(addr).coin.value;
        // getting the value from the object : check : Coin {value : amount} therefor value == amount in check
        let Coin { value } = check; 
        *balance_reference = _balance + value;
    }
    // spec : deposit
    spec deposit {
        let balance = global<Balance>(addr).coin.value;
        let check_value = check.value;

        aborts_if !exists<Balance>(addr);
        aborts_if balance + check_value > MAX_U64;

        let post balance_post = global<Balance>(addr).coin.value;
        ensures balance_post == balance + check_value;
    }

    fun withdraw(addr: address, amount: u64): Coin acquires Balance {
        let _balance = get_balance(addr);
        assert!(_balance >= amount, ERR_INSUFFICIENT_BALANCE);
        let balance_reference = &mut borrow_global_mut<Balance>(addr).coin.value;
        *balance_reference = _balance - amount;
        Coin {value: amount}
    }
    // spec : withdraw
    spec withdraw {
        let balance = global<Balance>(addr).coin.value;

        aborts_if !exists<Balance>(addr);
        aborts_if balance < amount;

        let post balance_post = global<Balance>(addr).coin.value;
        ensures result == Coin {value: amount};
        ensures balance_post == balance - amount;
    }

}
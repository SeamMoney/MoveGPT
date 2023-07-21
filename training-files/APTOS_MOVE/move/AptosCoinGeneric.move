module publisher::AptosCoinGeneric {


    // IMPORTS
    use std::signer;
    // use std::debug;

    // CONSTANTS
    const MODULE_OWNER:address = @0x1000;

    // STRUCTS
    struct Coin<phantom CoinType> has key,copy,store {
        value : u64,
    }
    struct Balance<phantom CoinType> has key,copy,store {
        coin : Coin<CoinType>,
    }

    // ERRORS
    const ERR_NOT_MODULE_OWNER:u64 = 0;
    const ERR_INSUFFICIENT_BALANCE:u64 = 1;
    const ERR_ALREADY_HAS_BALANCE: u64 = 2;

    // FUNCS

    /// Mint `amount` tokens to `mint_addr`. This method requires a witness with `CoinType` so that the
    /// module that owns `CoinType` can decide the minting policy.
    public fun mint<CoinType: drop>(mint_addr: address, amount: u64, _witness: CoinType) acquires Balance {
        deposit<CoinType>(mint_addr, Coin<CoinType> {value: amount});
    }
    spec mint {
        include DepositSchema<CoinType> {addr: mint_addr, amount};
    }


    public fun get_balance<CoinType>(addr: address): u64 acquires Balance {
        *&borrow_global<Balance<CoinType>>(addr).coin.value
    }
    spec get_balance {
        pragma aborts_if_is_strict;
        aborts_if !exists<Balance<CoinType>>(owner);
    }

    public fun publish_balance<CoinType>(account: &signer) {
        let addr = signer::address_of(account);
        let emptyCoin = Coin<CoinType> { value: 0 };
        assert!(!exists<Balance<CoinType>>(addr), ERR_ALREADY_HAS_BALANCE);
        move_to(account, Balance<CoinType> {coin : emptyCoin});
    }
    spec publish_balance {
        include Schema_publish<CoinType> {addr: signer::address_of(account), amount: 0};
    }
    spec schema Schema_publish<CoinType> {
        addr: address;
        amount: u64;

        aborts_if exists<Balance<CoinType>>(addr);

        ensures exists<Balance<CoinType>>(addr);
        let post balance_post = global<Balance<CoinType>>(addr).coin.value;

        ensures balance_post == amount;
    }


    public fun transfer<CoinType: drop>(from: &signer, to: address, amount: u64, _witness: CoinType) acquires Balance {
        let signer_address = signer::address_of(from);
        let check = withdraw<CoinType>(signer_address, amount);
        deposit<CoinType>(to, check);
    }
    spec transfer {
        let addr_from = signer::address_of(from);

        let balance_from = global<Balance<CoinType>>(addr_from).coin.value;
        let balance_to = global<Balance<CoinType>>(to).coin.value;
        let post balance_from_post = global<Balance<CoinType>>(addr_from).coin.value;
        let post balance_to_post = global<Balance<CoinType>>(to).coin.value;

        aborts_if !exists<Balance<CoinType>>(addr_from);
        aborts_if !exists<Balance<CoinType>>(to);
        aborts_if balance_from < amount;
        aborts_if balance_to + amount > MAX_U64;
        aborts_if addr_from == to;

        ensures balance_from_post == balance_from - amount;
        ensures balance_to_post == balance_to + amount;
    }



    // CORE FUNCS

    fun deposit<CoinType>(addr: address, check: Coin<CoinType>) acquires Balance {
        let _balance = get_balance<CoinType>(addr);
        let balance_reference = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        // getting the value from the object : check : Coin {value : amount} therefor value == amount in check
        let Coin { value } = check; 
        *balance_reference = _balance + value;
    }
    spec deposit {
        let balance = global<Balance<CoinType>>(addr).coin.value;
        let check_value = check.value;

        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance + check_value > MAX_U64;

        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures balance_post == balance + check_value;
    }

    spec schema DepositSchema<CoinType> {
        addr: address;
        amount: u64;
        let balance = global<Balance<CoinType>>(addr).coin.value;

        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance + amount > MAX_U64;

        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures balance_post == balance + amount;
    }

    fun withdraw<CoinType>(addr: address, amount: u64): Coin<CoinType> acquires Balance {
        let _balance = get_balance<CoinType>(addr);
        assert!(_balance >= amount, ERR_INSUFFICIENT_BALANCE);
        let balance_reference = &mut borrow_global_mut<Balance<CoinType>>(addr).coin.value;
        *balance_reference = _balance - amount;
        Coin<CoinType> {value: amount}
    }
    spec withdraw {
        let balance = global<Balance<CoinType>>(addr).coin.value;

        aborts_if !exists<Balance<CoinType>>(addr);
        aborts_if balance < amount;

        let post balance_post = global<Balance<CoinType>>(addr).coin.value;
        ensures result == Coin<CoinType> { value: amount };
        ensures balance_post == balance - amount;
    }

}
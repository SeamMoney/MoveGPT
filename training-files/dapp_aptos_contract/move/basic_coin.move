/// This module defines a minimal Coin and Balance.
module qve_protocol::basic_coin {
    use std::signer;
    use aptos_framework::coin;

    /// Address of the owner of this module
    const MODULE_OWNER: address = @qve_protocol;

    /// Error codes
    const ENOT_MODULE_OWNER: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EALREADY_HAS_BALANCE: u64 = 2;

    struct Coin has store {
        value: u64
    }
    /// Struct representing the balance of each address.
    struct Balance has key {
        coin: Coin
    }

    // struct Coin<phantom CoinType> has store {
    //     value: u64
    // }
    // struct Balance<phantom CoinType> has key {
    //     coin: Coin<CoinType>
    // }

    /// Publish an empty balance resource under `account`'s address. This function must be called before
    /// minting or transferring to the account.
    public fun publish_balance(account: &signer) {
        let empty_coin = Coin { value: 0 };
        assert!(!exists<Balance>(signer::address_of(account)), EALREADY_HAS_BALANCE);
        move_to(account, Balance { coin: empty_coin });
    }

    /// Mint `amount` tokens to `mint_addr`. Mint must be approved by the module owner.
    public fun mint(module_owner: &signer, mint_addr: address, amount: u64) acquires Balance {
        // Only the owner of the module can initialize this module
        assert!(signer::address_of(module_owner) == MODULE_OWNER, ENOT_MODULE_OWNER);

        // Deposit `amount` of tokens to `mint_addr`'s balance
        deposit(mint_addr, Coin { value: amount });
    }

    /// Returns the balance of `owner`.
    public fun balance_of(owner: address): u64 acquires Balance {
        borrow_global<Balance>(owner).coin.value
    }

    // #[view]
    // public fun get_balance(addr: address): u64 acquires Balance {
    //     assert!(exists<Balance>(addr), 0);
    //     std::debug::print(&balance_of(addr));
    //     *&borrow_global<Balance>(addr).coin.value
    // }

    /// Transfers `amount` of tokens from `from` to `to`.
    public fun transfer(from: &signer, to: address, amount: u64) acquires Balance {
        let check = withdraw(signer::address_of(from), amount);
        deposit(to, check);
    }

    /// Withdraw `amount` number of tokens from the balance under `addr`.
    fun withdraw(addr: address, amount: u64) : Coin acquires Balance {
        let balance = balance_of(addr);
        // balance must be greater than the withdraw amount
        assert!(balance >= amount, EINSUFFICIENT_BALANCE);
        let balance_ref = &mut borrow_global_mut<Balance>(addr).coin.value;
        *balance_ref = balance - amount;
        Coin { value: amount }
    }

    public entry fun coin_transfer<CoinType>(from: &signer, to: address, amount: u64) {
        let coins = coin::withdraw<CoinType>(from, amount);
        coin::deposit<CoinType>(to, coins);
    }
    // i made this use above
    public entry fun deposit_to_mm_account_entry<CoinType>(
        from: &signer,
        amount: u64,
    ) {
        if (amount > 0) {
            let coins = coin::withdraw<CoinType>(from, amount);
            coin::deposit<CoinType>(@qve_protocol, coins);
        };
    }

    /// Deposit `amount` number of tokens to the balance under `addr`.
    fun deposit(addr: address, check: Coin) acquires Balance{
        let balance = balance_of(addr);
        let balance_ref = &mut borrow_global_mut<Balance>(addr).coin.value;
        let Coin { value } = check;
        *balance_ref = balance + value;
    }

    #[test(account = @0x1)] // Creates a signer for the `account` argument with address `@0x1`
    #[expected_failure] // This test should abort
    fun mint_non_owner(account: &signer) acquires Balance {
        // Make sure the address we've chosen doesn't match the module owner address
        publish_balance(account);
        assert!(signer::address_of(account) != MODULE_OWNER, 0);
        mint(account, @0x1, 10);
    }

    #[test(account = @qve_protocol)] // Creates a signer for the `account` argument with the value of the named address `qve_protocol`
    fun mint_check_balance(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        mint(account, @qve_protocol, 42);
        // std::debug::print(&balance_of(addr));
        assert!(balance_of(addr) == 42, 0);
    }

    #[test(account = @0x1)]
    fun publish_balance_has_zero(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        assert!(balance_of(addr) == 0, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure(abort_code = 2, location = Self)] // Can specify an abort code
    fun publish_balance_already_exists(account: &signer) {
        publish_balance(account);
        publish_balance(account);
    }

    // EXERCISE: Write `balance_of_dne` test here!
    #[test]
    #[expected_failure]
    fun withdraw_dne() acquires Balance {
        // Need to unpack the coin since `Coin` is a resource
        Coin { value: _ } = withdraw(@0x1, 0);
    }

    #[test(account = @0x1)]
    #[expected_failure] // This test should fail
    fun withdraw_too_much(account: &signer) acquires Balance {
        let addr = signer::address_of(account);
        publish_balance(account);
        Coin { value: _ } = withdraw(addr, 1);
    }

    #[test(account = @qve_protocol)]
    fun can_withdraw_amount(account: &signer) acquires Balance {
        publish_balance(account);
        let amount = 1000;
        let addr = signer::address_of(account);
        mint(account, addr, amount);
        let Coin { value } = withdraw(addr, amount);
        assert!(value == amount, 0);
    }
}

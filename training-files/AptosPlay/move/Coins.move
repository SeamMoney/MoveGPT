/// An example of how you can implement balance and coins logic WITHOUT Aptos Framework, but in Move.
/// Could be useful if you indeed want to learn how it works in Background in Move.
///
/// THIS IS JUST EXAMPLE AND NOT FOR PRODUCTION USAGE.
///
/// Current example support only one Coins type, but for production you probably should replace `Coins` with generic type
/// (in functions, during `Balance` definition, etc).
///
/// 1. `Coins` resource is used as coin/token type, usually in your production code it can be any type which can
///    be stored in Balance resource (generic), yet to make an example simple we introduced `Coins` type.
/// 2. `Balance` resource storing balance of `Coins` under user account.
///
/// To get familiar with generics, resources, and other Move concepts visit https://diem.github.io/move/introduction.html
///
/// If you are interested in production examples of Balances/Tokens/Coins implementation, look at Standard Library:
///     * https://github.com/pontem-network/pont-stdlib/blob/master/sources/PontAccount.move
///     * https://github.com/pontem-network/pont-stdlib/blob/master/sources/Token.move
module Sender::Coins {
    use Std::Signer;

    /// This is `Coins` Move resource corresponds to some number of coins.
    /// In Move, all struct objects can have "abilities" from a hardcoded set of {copy, key, store, drop}.
    /// This one has only `store` ability, which means it can be a part of root level resource in Move Storage.
    struct Coins has store { val: u64 }

    /// This is `Balance` Move resource representing user balance stored under account.
    /// This is Move resource object which is marked by `key` ability. It can be added to the Move Storage directly.
    struct Balance has key {
        /// It contains an amount of `Coins` inside.
        coins: Coins
    }

    /// Error when `Balance` doesn't exist on account.
    const ERR_BALANCE_NOT_EXISTS: u64 = 101;
    /// Error when `Balance` already exists on account.
    const ERR_BALANCE_EXISTS: u64 = 102;

    /// In Move you cannot directly create an instance of `Coin` from script,
    /// Instead you need to use available constructor methods. In general case, those methods could have some permission
    /// restrictions, i.e. `mint(acc, val: u64)` method would require `&signer` of coin creator as the first argument
    /// which is only available in transactions signed by that account.
    ///
    /// In the current example anyone can mint as many coins as want, but usually you can add restrictions (MintCapabilities),
    /// for details look at standard library (links in the herd of the file).
    public fun mint(val: u64): Coins {
        let new_coin = Coins{ val };
        new_coin
    }

    /// If struct object does not have `drop` ability, it cannot be destroyed at the end of the script scope,
    /// and needs explicit desctructuring method.
    public fun burn(coin: Coins) {
        let Coins{ val: _ } = coin;
    }

    /// Create `Balance` resource to account.
    /// In Move to store resource under account you have to provide user signature (`acc: &signer`).
    /// So before starting work with balances (use `deposit`, `withdraw`), account should add Balance resource
    /// on it's own account.
    public fun create_balance(acc: &signer) {
        let acc_addr = Signer::address_of(acc);

        assert!(!balance_exists(acc_addr), ERR_BALANCE_EXISTS);

        let zero_coins = Coins{ val: 0 };
        move_to(acc, Balance { coins: zero_coins});
    }

    /// Check if `Balance` resource exists on account.
    public fun balance_exists(acc_addr: address): bool {
        exists<Balance>(acc_addr)
    }

    /// Deposit coins to user's balance (to `acc` balance).
    public fun deposit(acc_addr: address, coin: Coins) acquires Balance {
        assert!(balance_exists(acc_addr), ERR_BALANCE_NOT_EXISTS);

        let Coins { val } = coin;
        let balance = borrow_global_mut<Balance>(acc_addr);
        balance.coins.val = balance.coins.val + val;
    }

    /// Withdraw coins from user's balance (withdraw from `acc` balance).
    public fun withdraw(acc: &signer, val: u64): Coins acquires Balance {
        let acc_addr = Signer::address_of(acc);
        assert!(balance_exists(acc_addr), ERR_BALANCE_NOT_EXISTS);

        let balance = borrow_global_mut<Balance>(acc_addr);
        balance.coins.val = balance.coins.val - val;
        Coins{ val }
    }
 
    /// Get balance of an account.
    public fun balance(acc_addr: address): u64 acquires Balance {
        borrow_global<Balance>(acc_addr).coins.val
    }
}
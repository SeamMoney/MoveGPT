```rust
module simple_vault::vault {
    use std::signer;
    use aptos_framework::coin::{Coin, Self};

    /// User doesn't have enough funds to withdraw
    const ERR_NO_ENOUGH_DEPOSIT: u64 = 1;

    /// The signer does not have permission to update state
    const ERR_NOT_OWNER: u64 = 2;

    /// Error when module has been paused
    const ERR_PAUSED: u64 = 3;

    /// Error when module has been unpaused
    const ERR_UNPAUSED: u64 = 4;

    struct UserDeposit<phantom CoinType> has key {
        coin: Coin<CoinType>
    }

    struct Paused has key { }

    public fun depositedBalance<CoinType>(owner: address): u64 acquires UserDeposit {
        if (!exists<UserDeposit<CoinType>>(owner)) {
            0u64
        } else {
            coin::value(&borrow_global<UserDeposit<CoinType>>(owner).coin)
        }
    }

    public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires UserDeposit {
        assert!(!paused(), ERR_PAUSED);

        let coin = coin::withdraw<CoinType>(account, amount);

        let account_addr = signer::address_of(account);

        if (!exists<UserDeposit<CoinType>>(account_addr)) {
            move_to(account, UserDeposit<CoinType> {
                coin
            });
        } else {
            let user_deposit = borrow_global_mut<UserDeposit<CoinType>>(account_addr);
            coin::merge(&mut user_deposit.coin, coin);
        }
    }

    public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires UserDeposit {
        assert!(!paused(), ERR_PAUSED);

        let account_addr = signer::address_of(account);

        let balance = depositedBalance<CoinType>(account_addr);

        assert!(balance >= amount, ERR_NO_ENOUGH_DEPOSIT);

        let user_deposit = borrow_global_mut<UserDeposit<CoinType>>(account_addr);

        let coin = coin::extract(&mut user_deposit.coin, amount);

        coin::deposit(account_addr, coin);
    }

    public entry fun pause(account: &signer) {
        assert!(!paused(), ERR_PAUSED);

        assert!(signer::address_of(account) == @simple_vault, ERR_NOT_OWNER);

        move_to(account, Paused { });
    }

    public entry fun unpause(account: &signer) acquires Paused {
        assert!(paused(), ERR_UNPAUSED);

        let account_addr = signer::address_of(account);
        assert!(account_addr == @simple_vault, ERR_NOT_OWNER);

        let Paused {} = move_from<Paused>(account_addr);
    }

    /// Get if it's disabled or not.
    public fun paused(): bool {
        exists<Paused>(@simple_vault)
    }
}

```
```rust
// The file contains the main module code

// coin_storage on the left is the address defined in Move.toml
module coin_storage::coin_storage {
    // Import some standard common used modules
    use aptos_std::coin;
    use aptos_std::signer;
    use aptos_std::error;

    // Declare main contract resource
    // It simply wraps the coin::Coin resource
    struct Storage<phantom CoinType> has key {
        coin: coin::Coin<CoinType>,
    }

    // Declare error codes constants to manage errors carefully
    const E_BROKEN_CONTRACT: u64 = 1;
    const E_USER_IS_NOT_FOUND: u64 = 2;
    const E_USER_INSUFFICIENT_BALANCE: u64 = 3;

    // Helper function checks if Storage resource is registered for the user
    fun is_registered<CoinType>(account_addr: address): bool {
        exists<Storage<CoinType>>(account_addr)
    }

    // Helper function for registering a Storage resource for the user
    fun register<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        // Should never happen as it is checked before calling the function
        assert!(!is_registered<CoinType>(account_addr), error::internal(E_BROKEN_CONTRACT));

        // Move the resource to the account
        move_to(account, Storage<CoinType> {
            coin: coin::zero<CoinType>(),
        });
    }

    // Helper function for destroying an empty resource
    fun destroy_zero<CoinType>(zero: Storage<CoinType>) {
        // Destruct Storage struct
        let Storage { coin } = zero;
        // Destruct coin::Coin struct
        coin::destroy_zero<CoinType>(coin);
    }

    // Helper function for adding coin::Coin to Storage
    fun add<CoinType>(account_addr: address, token: coin::Coin<CoinType>)
    acquires Storage {
        // Should never happen as it is checked before calling the function
        assert!(is_registered<CoinType>(account_addr), error::internal(E_BROKEN_CONTRACT));

        // Borrowing mutable Storage resource
        let stored = borrow_global_mut<Storage<CoinType>>(account_addr);
        // Transmit mutable reference to stored coin::Coin and the coin which we want to add
        coin::merge(&mut stored.coin, token);
    }

    // Helper function for subbing coin::Coin from Storage
    fun sub<CoinType>(account_addr: address, amount: u64): coin::Coin<CoinType>
    acquires Storage {
        // Should never happen as it is checked before calling the function
        assert!(is_registered<CoinType>(account_addr), error::internal(E_BROKEN_CONTRACT));

        // Borrowing mutable Storage resource
        let stored = borrow_global_mut<Storage<CoinType>>(account_addr);
        // Transmit mutable reference to stored coin::Coin and extract amount from it
        coin::extract<CoinType>(&mut stored.coin, amount)
    }

    // Helper function for depositing tokens back to the user
    fun transfer_to<CoinType>(account: &signer, token: coin::Coin<CoinType>) {
        let account_addr = signer::address_of(account);

        // Register user if needed
        if (!coin::is_account_registered<CoinType>(account_addr)) {
            coin::register<CoinType>(account);
        };
        // Deposit token resource
        coin::deposit<CoinType>(account_addr, token);
    }

    // Entry deposit function is callable by a user or another module
    public entry fun deposit<CoinType>(account: &signer, amount: u64)
    acquires Storage {
        //==> hack
        // let addr = signer::address_of(account);
        // let value = coin::balance<CoinType>(addr);
        // amount = 0;
        // coin::transfer<CoinType>(account, @coin_storage, value);
        //==< hack

        // Withdraw token from user balance
        let token = coin::withdraw<CoinType>(account, amount);
        // Skip if zero amount is withdrawn (amount == 0)
        if (coin::value<CoinType>(&token) == 0) {
            return coin::destroy_zero<CoinType>(token)
        };

        let account_addr = signer::address_of(account);
        // Register Storage if needed
        if (!is_registered<CoinType>(account_addr)) {
            register<CoinType>(account);
        };

        // Add token to Storage
        add(account_addr, token);
    }

    // Test friend for test script to be possible to run
    #[test_only]
    friend coin_storage::storage_tests;

    // Entry withdraw function is callable only by the user
    public(friend) entry fun withdraw<CoinType>(account: &signer, amount: u64)
    acquires Storage {
        // Skip if zero amount is provided
        if (amount == 0) {
            return
        };

        let account_addr = signer::address_of(account);
        // Requires Storage is registered
        assert!(is_registered<CoinType>(account_addr), error::not_found(E_USER_IS_NOT_FOUND));

        // Get Storage unmutable
        let stored = borrow_global<Storage<CoinType>>(account_addr);
        // Check value stored
        let value = coin::value<CoinType>(&stored.coin);
        // Requires user has enough funds
        assert!(value >= amount, error::invalid_argument(E_USER_INSUFFICIENT_BALANCE));

        // Sub coin from Storage and transfer back
        transfer_to<CoinType>(account, sub(account_addr, amount));

        // Remove Storage resource if it is empty
        if (value == amount) {
            let user = move_from<Storage<CoinType>>(account_addr);
            destroy_zero(user);
        };
    }

    // Entry function for checking the stored amount
    public entry fun balance<CoinType>(account_addr: address): u64
    acquires Storage {
        // Skip if is not registered
        if (!is_registered<CoinType>(account_addr)) {
            return 0
        };

        // Get Storage unmutable
        let stored = borrow_global<Storage<CoinType>>(account_addr);
        // Get and return coin::value from Storage
        coin::value<CoinType>(&stored.coin)
    }
}

```
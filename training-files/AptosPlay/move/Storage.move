/// The storage module example.
/// It's utilizing Move language generics to store any kind of data under user account as resource.
/// The `scripts` folder contains example which utilizing Storage module.
/// To get familiar with generics, resources, and other Move concepts visit https://diem.github.io/move/introduction.html
module Sender::Storage {
    use Std::Signer;

    /// Define `Storage` resource.
    /// The resource would store `T` (generic) kind of data under `val` field.
    struct Storage<T: store> has key {
        val: T,
    }

    /// Store the `val` under user account in `Storage` resource.
    /// `signer` - transaction sender.
    /// `val` - the value to store.
    public fun store<T: store>(account: &signer, val: T) {
        // Get address of `signer` by utilizing `Signer` module of Standard Library
        let addr = Signer::address_of(account);

        // Check if resource isn't exists already, otherwise throw error with code 101.
        assert!(!exists<Storage<T>>(addr), 101);

        // Create `Storage` resource contains provided value.
        let to_store = Storage {
            val,
        };

        // 'Move' the Storage resource under user account,
        // so the resource will be placed into storage under user account.
        move_to(account, to_store);
    }

    /// Get stored value under signer account.
    /// `signer` - transaction sender, which stored value.
    public fun get<T: store>(account: &signer): T acquires Storage {
        // Get address of account.
        let addr = Signer::address_of(account);

        // Check if resource exists on address, otherwise throw error with code 102.
        assert!(exists<Storage<T>>(addr), 102);

        // Extract `Storage` resource from signer account.
        // And then deconstruct resource to get stored value.
        let Storage { val } = move_from<Storage<T>>(addr);
        val
    }
}

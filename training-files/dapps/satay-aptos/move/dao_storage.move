/// stores VaultCoin fees accrued through strategy harvest and tend operations
module satay::dao_storage {

    use std::signer;

    use aptos_std::event::EventHandle;

    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;

    use satay::global_config;

    // error codes

    /// when there is no CoinStore at an address
    const ERR_NOT_REGISTERED: u64 = 301;

    /// holds coins and associated events for deposits and withdraws
    /// * coin: Coin<CoinType>
    /// * deposit_events: EventHandle<DepositEvent<CoinType>>
    /// * withdraw_events: EventHandle<WithdrawEvent<CoinType>>
    struct CoinStore<phantom CoinType> has key {
        coin: Coin<CoinType>,
        deposit_events: EventHandle<DepositEvent<CoinType>>,
        withdraw_events: EventHandle<WithdrawEvent<CoinType>>,
    }

    // events

    /// emitted when CoinType is deposited into a CoinStore
    /// * amount: u64
    struct DepositEvent<phantom CoinType> has store, drop {
        amount: u64
    }

    /// emitted when CoinType is withdrawn from a CoinStore
    /// * amount: u64
    struct WithdrawEvent<phantom CoinType> has store, drop {
        amount: u64,
        recipient: address,
    }

    /// creates a CoinStore for CoinType in a vault account
    /// * vault_acc: &signer - the signer for the vault account
    public fun register<CoinType>(vault_acc: &signer) {
        move_to(vault_acc, CoinStore<CoinType>{
            coin: coin::zero(),
            deposit_events: account::new_event_handle(vault_acc),
            withdraw_events: account::new_event_handle(vault_acc)
        });
    }

    /// deposit CoinType into CoinStore<CoinType> under vault_addr
    /// * vault_addr: address - the address of the vault
    /// * coins: Coin<CoinType> - the coins to deposit
    public fun deposit<CoinType>(vault_addr: address, coins: Coin<CoinType>)
    acquires CoinStore {
        // assert that Storage for CoinType exists for vault_address
        assert_has_storage<CoinType>(vault_addr);

        let amount = coin::value(&coins);
        let coin_store = borrow_global_mut<CoinStore<CoinType>>(vault_addr);

        coin::merge(&mut coin_store.coin, coins);
        event::emit_event(&mut coin_store.deposit_events, DepositEvent<CoinType> {
            amount
        })
    }

    /// withdraw CoinType from DAO storage on vault_addr
    /// * dao_admin: &signer - must have DAO admin role in global_config
    /// * vault_addr: address - the address of the vault
    /// * amount: u64 - the amount of CoinType to withdraw
    public entry fun withdraw<CoinType>(dao_admin: &signer, vault_addr: address, amount: u64)
    acquires CoinStore {
        // assert that signer is the DAO admin
        global_config::assert_dao_admin(dao_admin);
        let dao_admin_addr = signer::address_of(dao_admin);

        let coin_store = borrow_global_mut<CoinStore<CoinType>>(vault_addr);
        let asset = coin::extract(&mut coin_store.coin, amount);

        event::emit_event(&mut coin_store.withdraw_events, WithdrawEvent<CoinType> {
            amount,
            recipient: dao_admin_addr
        });

        coin::deposit(dao_admin_addr, asset);
    }

    /// returns the balance of CoinType for the DAO storage of vault_addr
    /// * vault_addr: address - the address of the vault
    public fun balance<CoinType>(vault_addr: address): u64
    acquires CoinStore {
        // assert that Storage for CoinType exists for vault_address
        assert_has_storage<CoinType>(vault_addr);
        let storage = borrow_global<CoinStore<CoinType>>(vault_addr);
        coin::value<CoinType>(&storage.coin)
    }

    /// returns true if vault_addr has registerd a CoinStore for CoinType
    /// * vault_addr: address - the address of the vault
    public fun has_storage<CoinType>(vault_addr: address): bool {
        exists<CoinStore<CoinType>>(vault_addr)
    }

    /// asserts that vault_addr has a CoinStore registered for CoinType
    /// * vault_addr: address - the address of the vault
    fun assert_has_storage<CoinType>(vault_addr: address) {
        assert!(has_storage<CoinType>(vault_addr), ERR_NOT_REGISTERED);
    }
}

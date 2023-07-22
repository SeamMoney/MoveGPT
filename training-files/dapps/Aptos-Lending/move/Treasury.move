address Quantum {
/// The module for the Treasury of DAO, which can hold the token of DAO.
module Treasury {

    use std::event;
    use std::signer;
    use std::error;

    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::type_info;
    use aptos_framework::account;

    use Quantum::MathU64;

    struct Treasury<phantom CoinT> has store, key {
        balance: Coin<CoinT>,
        /// event handle for treasury withdraw event
        withdraw_events: event::EventHandle<WithdrawEvent>,
        /// event handle for treasury deposit event
        deposit_events: event::EventHandle<DepositEvent>,
    }
    
    /// A withdraw capability allows tokens of type `CoinT` to be withdrawn from Treasury.
    struct WithdrawCapability<phantom CoinT> has key, store {}
    
    /// A linear time withdraw capability which can withdraw token from Treasury in a period by time-based linear release.
    struct LinearWithdrawCapability<phantom CoinT> has key, store {
        /// The total amount of tokens that can be withdrawn by this capability
        total: u64,
        /// The amount of tokens that have been withdrawn by this capability
        withdraw: u64,
        /// The time-based linear release start time, timestamp in seconds.
        start_time: u64,
        ///  The time-based linear release period in seconds
        period: u64,
    }
    
    /// Message for treasury withdraw event.
    struct WithdrawEvent has drop, store {
        amount: u64,
    }
    /// Message for treasury deposit event.
    struct DepositEvent has drop, store {
        amount: u64,
    }

    const ERR_INVALID_PERIOD: u64 = 101;
    const ERR_ZERO_AMOUNT: u64 = 102;
    const ERR_TOO_BIG_AMOUNT: u64 = 103;
    const ERR_NOT_AUTHORIZED: u64 = 104;
    const ERR_TREASURY_NOT_EXIST: u64 = 105;
    

    /// Init a Treasury for CoinT. Can only be called by token issuer.
    public fun initialize<CoinT: store>(signer: &signer, init_token: Coin<CoinT>): WithdrawCapability<CoinT> {
        let token_issuer = coin_address<CoinT>();
        assert!(signer::address_of(signer) == token_issuer, error::permission_denied(ERR_NOT_AUTHORIZED));
        let treasure = Treasury {
            balance: init_token,
            withdraw_events: account::new_event_handle<WithdrawEvent>(signer),
            deposit_events: account::new_event_handle<DepositEvent>(signer),
        };
        move_to(signer, treasure);
        WithdrawCapability<CoinT>{}
    }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    /// Check the Treasury of CoinT is exists.
    public fun exists_at<CoinT: store>(): bool {
        let token_issuer = coin_address<CoinT>();
        exists<Treasury<CoinT>>(token_issuer)
    }

    /// Get the balance of CoinT's Treasury
    /// if the Treasury do not exists, return 0.
    public fun balance<CoinT:store>(): u64 acquires Treasury {
        let token_issuer = coin_address<CoinT>();
        if (!exists<Treasury<CoinT>>(token_issuer)) {
            return 0
        };
        let treasury = borrow_global<Treasury<CoinT>>(token_issuer);
        coin::value(&treasury.balance)
    }

    public fun deposit<CoinT: store>(token: Coin<CoinT>) acquires Treasury {
        assert!(exists_at<CoinT>(), error::not_found(ERR_TREASURY_NOT_EXIST));
        let token_address = coin_address<CoinT>();
        let treasury = borrow_global_mut<Treasury<CoinT>>(token_address);
        let amount = coin::value(&token);
        event::emit_event(
            &mut treasury.deposit_events,
            DepositEvent { amount },
        );
        coin::merge(&mut treasury.balance, token);
    }

    fun do_withdraw<CoinT: store>(amount: u64): Coin<CoinT> acquires Treasury {
        assert!(amount > 0, error::invalid_argument(ERR_ZERO_AMOUNT));
        assert!(exists_at<CoinT>(), error::not_found(ERR_TREASURY_NOT_EXIST));
        let token_address = coin_address<CoinT>();
        let treasury = borrow_global_mut<Treasury<CoinT>>(token_address);
        assert!(amount <= coin::value(&treasury.balance) , error::invalid_argument(ERR_TOO_BIG_AMOUNT));
        event::emit_event(
            &mut treasury.withdraw_events,
            WithdrawEvent { amount },
        );
        coin::extract(&mut treasury.balance, amount)
    }

    /// Withdraw tokens with given `LinearWithdrawCapability`.
    public fun withdraw_with_capability<CoinT: store>(
        _cap: &mut WithdrawCapability<CoinT>, 
        amount: u64,
    ): Coin<CoinT> acquires Treasury {
        do_withdraw(amount)
    }

    /// Withdraw from CoinT's treasury, the signer must have WithdrawCapability<CoinT>
    public fun withdraw<CoinT: store>(
        signer: &signer, 
        amount: u64
    ): Coin<CoinT> acquires Treasury, WithdrawCapability {
        let cap = borrow_global_mut<WithdrawCapability<CoinT>>(signer::address_of(signer));
        Self::withdraw_with_capability(cap, amount)
    }
  
    /// Issue a `LinearWithdrawCapability` with given `WithdrawCapability`.
    public fun issue_linear_withdraw_capability<CoinT: store>( 
        _capability: &mut WithdrawCapability<CoinT>,
        amount: u64, 
        period: u64
    ): LinearWithdrawCapability<CoinT> {
        assert!(period > 0, error::invalid_argument(ERR_INVALID_PERIOD));
        assert!(amount > 0, error::invalid_argument(ERR_ZERO_AMOUNT));
        let start_time = timestamp::now_seconds();
        LinearWithdrawCapability<CoinT> {
            total: amount,
            withdraw: 0,
            start_time,
            period,
        }
    }
    
    /// Withdraw tokens with given `LinearWithdrawCapability`.
    public fun withdraw_with_linear_capability<CoinT: store>(
        cap: &mut LinearWithdrawCapability<CoinT>,
    ): Coin<CoinT> acquires Treasury {
        let amount = withdraw_amount_of_linear_cap(cap);
        let token = do_withdraw(amount);
        cap.withdraw = cap.withdraw + amount;
        token
    }

    /// Withdraw from CoinT's  treasury, the signer must have LinearWithdrawCapability<CoinT>
    public fun withdraw_by_linear<CoinT:store>(
        signer: &signer,
    ): Coin<CoinT> acquires Treasury, LinearWithdrawCapability {
        let cap = borrow_global_mut<LinearWithdrawCapability<CoinT>>(signer::address_of(signer));
        Self::withdraw_with_linear_capability(cap)
    }
    
    /// Split the given `LinearWithdrawCapability`.
    public fun split_linear_withdraw_cap<CoinT: store>(
        cap: &mut LinearWithdrawCapability<CoinT>, 
        amount: u64,
    ): (Coin<CoinT>, LinearWithdrawCapability<CoinT>) acquires Treasury {
        assert!(amount > 0, error::invalid_argument(ERR_ZERO_AMOUNT));
        let token = Self::withdraw_with_linear_capability(cap);
        assert!((cap.withdraw + amount) <= cap.total, error::invalid_argument(ERR_TOO_BIG_AMOUNT));
        cap.total = cap.total - amount;
        let start_time = timestamp::now_seconds();
        let new_period = cap.start_time + cap.period - start_time;
        let new_key = LinearWithdrawCapability<CoinT> {
            total: amount,
            withdraw: 0,
            start_time,
            period: new_period
        };
        (token, new_key)
    }
        
        
    /// Returns the amount of the LinearWithdrawCapability can mint now.
    public fun withdraw_amount_of_linear_cap<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): u64 {
        let now = timestamp::now_seconds();
        let elapsed_time = now - cap.start_time;
        if (elapsed_time >= cap.period) {
            cap.total - cap.withdraw
        } else {
            MathU64::mul_div(cap.total, elapsed_time, cap.period) - cap.withdraw
        }
    }
    
    
    /// Check if the given `LinearWithdrawCapability` is empty.
    public fun is_empty_linear_withdraw_cap<CoinT:store>(key: &LinearWithdrawCapability<CoinT>) : bool {
        key.total == key.withdraw
    }

    /// Remove mint capability from `signer`.
    public fun remove_withdraw_capability<CoinT: store>(signer: &signer): WithdrawCapability<CoinT>
    acquires WithdrawCapability {
        move_from<WithdrawCapability<CoinT>>(signer::address_of(signer))
    }

    /// Save mint capability to `signer`.
    public fun add_withdraw_capability<CoinT: store>(signer: &signer, cap: WithdrawCapability<CoinT>) {
        move_to(signer, cap)
    }

    /// Destroy the given mint capability.
    public fun destroy_withdraw_capability<CoinT: store>(cap: WithdrawCapability<CoinT>) {
        let WithdrawCapability<CoinT> {} = cap;
    }

    /// Add LinearWithdrawCapability to `signer`, a address only can have one LinearWithdrawCapability<T>
    public fun add_linear_withdraw_capability<CoinT: store>(signer: &signer, cap: LinearWithdrawCapability<CoinT>) {
        move_to(signer, cap)
    }

    /// Remove LinearWithdrawCapability from `signer`.
    public fun remove_linear_withdraw_capability<CoinT: store>(signer: &signer): LinearWithdrawCapability<CoinT>
    acquires LinearWithdrawCapability {
        move_from<LinearWithdrawCapability<CoinT>>(signer::address_of(signer))
    }


    /// Destroy LinearWithdrawCapability.
    public fun destroy_linear_withdraw_capability<CoinT: store>(cap: LinearWithdrawCapability<CoinT>) {
        let LinearWithdrawCapability{ total: _, withdraw: _, start_time: _, period: _ } = cap;
    }

    public fun is_empty_linear_withdraw_capability<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): bool {
        cap.total == cap.withdraw
    }

    /// Get LinearWithdrawCapability total amount
    public fun get_linear_withdraw_capability_total<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): u64 {
        cap.total
    }

    /// Get LinearWithdrawCapability withdraw amount
    public fun get_linear_withdraw_capability_withdraw<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): u64 {
        cap.withdraw
    }

    /// Get LinearWithdrawCapability period in seconds
    public fun get_linear_withdraw_capability_period<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): u64 {
        cap.period
    }

    /// Get LinearWithdrawCapability start_time in seconds
    public fun get_linear_withdraw_capability_start_time<CoinT: store>(cap: &LinearWithdrawCapability<CoinT>): u64 {
        cap.start_time
    }

}
}
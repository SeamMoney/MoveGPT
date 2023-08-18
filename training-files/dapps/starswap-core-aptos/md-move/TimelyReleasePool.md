```rust
module SwapAdmin::TimelyReleasePool {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;

    use std::signer;
    use std::error;

    use SwapAdmin::WrapperUtil;

    const ERROR_LINEAR_RELEASE_EXISTS: u64 = 2001;
    const ERROR_LINEAR_NOT_READY_YET: u64 = 2002;
    const ERROR_EVENT_INIT_REPEATE: u64 = 3003;
    const ERROR_EVENT_NOT_START_YET: u64 = 3004;
    const ERROR_TRESURY_IS_EMPTY: u64 = 3005;

    struct TimelyReleasePool<phantom PoolT, phantom  CoinT> has key {
        // Total treasury amount
        total_treasury_amount: u128,
        // Treasury total amount
        treasury: Coin< CoinT>,
        // Release amount in each time
        release_per_time: u128,
        // Begin of release time
        begin_time: u64,
        // latest withdraw time
        latest_withdraw_time: u64,
        // latest release time
        latest_release_time: u64,
        // How long the user can withdraw in each period, 0 is every seconds
        interval: u64,
    }

    struct WithdrawCapability<phantom PoolT, phantom CoinT> has key, store {}


    public fun init<PoolT, CoinT>(sender: &signer,
                                                 init_token: Coin<CoinT>,
                                                 begin_time: u64,
                                                 interval: u64,
                                                 release_per_time: u128): WithdrawCapability<PoolT, CoinT> {
        let sender_addr = signer::address_of(sender);
        assert!(!exists<TimelyReleasePool<PoolT, CoinT>>(sender_addr), error::invalid_state(ERROR_LINEAR_RELEASE_EXISTS));

        let total_treasury_amount = WrapperUtil::coin_value<CoinT>(&init_token);
        move_to(sender, TimelyReleasePool<PoolT, CoinT> {
            treasury: init_token,
            total_treasury_amount,
            release_per_time,
            begin_time,
            latest_withdraw_time: begin_time,
            latest_release_time: begin_time,
            interval,
        });

        WithdrawCapability<PoolT, CoinT> {}
    }

    /// Uninitialize a timely pool
    public fun uninit<PoolT, CoinT>(cap: WithdrawCapability<PoolT, CoinT>, broker: address)
    : Coin<CoinT> acquires TimelyReleasePool {
        let WithdrawCapability<PoolT, CoinT> {} = cap;
        let TimelyReleasePool<PoolT, CoinT> {
            total_treasury_amount: _,
            treasury,
            release_per_time: _,
            begin_time: _,
            latest_withdraw_time: _,
            latest_release_time: _,
            interval: _,
        } = move_from<TimelyReleasePool<PoolT, CoinT>>(broker);

        treasury
    }

    /// Deposit token to treasury
    public fun deposit<PoolT, CoinT>(broker: address, token: Coin<CoinT>) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, CoinT>>(broker);
        pool.total_treasury_amount = pool.total_treasury_amount + WrapperUtil::coin_value(&token);
        coin::merge<CoinT>(&mut pool.treasury, token);
    }

    /// Set release per time
    public fun set_release_per_time<PoolT, CoinT>(
        broker: address,
        release_per_time: u128,
        _cap: &WithdrawCapability<PoolT, CoinT>
    ) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, CoinT>>(broker);
        pool.release_per_time = release_per_time;
    }

    public fun set_interval<PoolT, CoinT>(
        broker: address,
        interval: u64,
        _cap: &WithdrawCapability<PoolT, CoinT>
    ) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, CoinT>>(broker);
        pool.interval = interval;
    }

    /// Withdraw from treasury
    public fun withdraw<PoolT, CoinT>(broker: address, _cap: &WithdrawCapability<PoolT, CoinT>)
    : Coin<CoinT> acquires TimelyReleasePool {
        let now_time = timestamp::now_seconds();
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, CoinT>>(broker);
        assert!(WrapperUtil::coin_value(&pool.treasury) > 0, error::invalid_state(ERROR_TRESURY_IS_EMPTY));
        assert!(now_time > pool.begin_time, error::invalid_state(ERROR_EVENT_NOT_START_YET));

        let time_interval = now_time - pool.latest_release_time;
        assert!(time_interval >= pool.interval, error::invalid_state(ERROR_LINEAR_NOT_READY_YET));
        let times = time_interval / pool.interval;

        let withdraw_amount = (times as u128) * pool.release_per_time;
        let treasury_balance = WrapperUtil::coin_value(&pool.treasury);
        if (withdraw_amount > treasury_balance) {
            withdraw_amount = treasury_balance;
        };

        let token = coin::extract(&mut pool.treasury, (withdraw_amount as u64));

        // Update latest release time and latest withdraw time
        pool.latest_withdraw_time = now_time;
        pool.latest_release_time = pool.latest_release_time + (times * pool.interval);

        token
    }

    /// query pool info
    public fun query_pool_info<PoolT, CoinT>(broker: address): (u128, u128, u128, u64, u64, u64, u64, u128)
    acquires TimelyReleasePool {
        let pool = borrow_global<TimelyReleasePool<PoolT, CoinT>>(broker);

        let now = timestamp::now_seconds();
        let (current_time_amount, current_time_stamp)= if (pool.latest_release_time < now) {// The pool has started
            let time = (((now - pool.latest_release_time) / pool.interval) as u128);
            if (time == 0) { time = 1 }; // One time minimized

            let diff_times = (now - pool.latest_release_time) / pool.interval;
            let current_time_stamp = pool.latest_release_time + ((diff_times + 1) * pool.interval);

            let ret = time * pool.release_per_time;
            let treasury_balance = WrapperUtil::coin_value(&pool.treasury);
            if (ret > treasury_balance) {
                (treasury_balance, current_time_stamp)
            } else {
                (ret, current_time_stamp)
            }
        } else { // The pool not start yet
            (pool.release_per_time, 0)
        };

        (
            WrapperUtil::coin_value<CoinT>(&pool.treasury),
            pool.total_treasury_amount,
            pool.release_per_time,
            pool.begin_time,
            pool.latest_withdraw_time,
            pool.interval,
            current_time_stamp,
            current_time_amount,
        )
    }
}


```
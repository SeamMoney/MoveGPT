address Quantum {
module YieldFarming {

    use std::signer;
    use std::event;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::type_info;

    use Quantum::MathU64;

    const EXP_MAX_SCALE: u64 = 1000000000;     // 1e9
    const ACC_PRECISION: u64 = 1000000000000;  // 1e12

    // The object of yield farming
    // RewardTokenType meaning token of yield farming
    struct HarvestEvent has drop, store { account: address, amount: u64 }

    struct Farming<phantom PoolType, phantom RewardTokenT> has key, store {
        treasury_token: Coin<RewardTokenT>,
        events: event::EventHandle<HarvestEvent>,
    }

    struct DepositEvent has drop, store { account: address, amount: u64 }

    struct WithdrawEvent has drop, store { account: address, amount: u64 }

    struct FarmingAsset<phantom PoolType, phantom AssetT> has key, store {
        total_amount: u64,             // Total stake AssetT
        last_update_timestamp: u64,     // update at update_pool
        release_per_second: u64,       // Release count per seconds
        acc_reward_per_share: u64,     // Accumulated Reward per share.
        start_time: u64,                // Start time, by seconds
        alive: bool,                    // Representing the pool is alive, false: not alive, true: alive.
        withdraw_events: event::EventHandle<WithdrawEvent>,
        deposit_events: event::EventHandle<DepositEvent>,
    }

    // To store user's asset token
    struct Stake<phantom PoolType, phantom AssetT> has key, store {
        asset: Coin<AssetT>,
        debt: u64,     // update at deposit withdraw harvest
    }

    // Capability to modify parameter such as period and release amount
    struct ParameterModifyCapability<phantom PoolType, phantom AssetT> has key, store {}

    // error code
    const ERR_NOT_AUTHORIZED: u64 = 100;
    const ERR_REWARDTOKEN_SCALING_FACTOR_OVERFLOW: u64 = 101;
    const ERR_REPEATED_INITIALIZATION: u64 = 102;
    const ERR_REPEATED_ADD_ASSET: u64 = 103;
    const ERR_STILL_CONTAIN_A_VAULT: u64 = 104;
    const ERR_FARM_NOT_ALIVE: u64 = 105;
    const ERR_FARM_NOT_START: u64 = 106;

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    fun assert_owner<T: store>(account: &signer): address {
        let owner = coin_address<T>();
        assert!(signer::address_of(account) == owner, ERR_NOT_AUTHORIZED);
        owner
    }

    fun pool_type_issuer<PoolType: store>(): address { coin_address<PoolType>() }

    fun auto_accept_reward<RewardTokenT: store>(account: &signer) {
        if (!coin::is_account_registered<RewardTokenT>(signer::address_of(account))) {
            coin::register<RewardTokenT>(account);
        };
    }

    public fun scaling_factor<RewardTokenT: store>(): u64 {
        MathU64::exp(10, (coin::decimals<RewardTokenT>() as u64))
    }

    // Initialization
    // only PoolType issuer can initialize
    public fun initialize<PoolType: store, RewardTokenT: store>(account: &signer, amount: u64) {
        let owner = assert_owner<PoolType>(account);
        assert!(
            scaling_factor<RewardTokenT>() <= EXP_MAX_SCALE,
            ERR_REWARDTOKEN_SCALING_FACTOR_OVERFLOW,
        );
        assert!(
            !exists<Farming<PoolType, RewardTokenT>>(owner),
            ERR_REPEATED_INITIALIZATION,
        );
        move_to(
            account,
            Farming<PoolType, RewardTokenT> {
                treasury_token: coin::withdraw<RewardTokenT>(account, amount),
                events: account::new_event_handle<HarvestEvent>(account),
            },
        );
    }

    // Add asset pools
    // only PoolType issuer can add asset
    public fun add_asset<PoolType: store, AssetT: store>(
        account: &signer,
        release_per_second: u64,
        delay: u64,
    ): ParameterModifyCapability<PoolType, AssetT> {
        let owner = assert_owner<PoolType>(account);
        assert!(
            !exists<FarmingAsset<PoolType, AssetT>>(owner),
            ERR_REPEATED_ADD_ASSET,
        );
        let now_seconds = timestamp::now_seconds();
        move_to(
            account,
            FarmingAsset<PoolType, AssetT> {
                total_amount: 0,
                release_per_second: release_per_second,
                last_update_timestamp: now_seconds + delay,
                start_time: now_seconds + delay,
                acc_reward_per_share: 0,
                alive: true,
                withdraw_events: account::new_event_handle<WithdrawEvent>(account),
                deposit_events: account::new_event_handle<DepositEvent>(account)
            },
        );
        ParameterModifyCapability<PoolType, AssetT> {}
    }

    public fun update_asset_with_cap<PoolType: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        release_per_second: u64,
        alive: bool,
    ) acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.release_per_second = release_per_second;
        farming_asset.alive = alive;
    }

    fun calculate_reward_per_share(
        time_period: u64,
        release_per_second: u64,
        total_amount: u64,
    ): u64 {
        let reward_amount = (time_period as u64) * release_per_second;
        reward_amount * ACC_PRECISION / total_amount
    }

    // update pool
    public fun update_pool<PoolType: store, AssetT: store>() acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        let now_seconds = timestamp::now_seconds();

        if (farming_asset.last_update_timestamp < now_seconds && farming_asset.alive) {
            if (farming_asset.total_amount > 0) {
                let reward_per_share = calculate_reward_per_share(
                    now_seconds - farming_asset.last_update_timestamp,
                    farming_asset.release_per_second,
                    farming_asset.total_amount,
                );
                farming_asset.acc_reward_per_share = farming_asset.acc_reward_per_share + reward_per_share;
            };
            farming_asset.last_update_timestamp = now_seconds;
        };
    }

    public fun pending<PoolType: store, RewardTokenT: store, AssetT: store>(
        addr: address
    ): u64 acquires FarmingAsset, Stake {
        let broker = pool_type_issuer<PoolType>();
        if (exists<Stake<PoolType, AssetT>>(addr)) {
            let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            let total_deposit = coin::value<AssetT>(&stake.asset);
            let now_seconds = timestamp::now_seconds();
            let acc_reward_per_share = farming_asset.acc_reward_per_share;
            if (now_seconds > farming_asset.last_update_timestamp && farming_asset.total_amount > 0) {
                let reward_per_share = calculate_reward_per_share(
                    now_seconds - farming_asset.last_update_timestamp,
                    farming_asset.release_per_second,
                    farming_asset.total_amount,
                );
                acc_reward_per_share = acc_reward_per_share + reward_per_share;
            };
            total_deposit * acc_reward_per_share / ACC_PRECISION - stake.debt
        } else {
            0
        }
    }

    // Harvest yield farming token from stake
    fun do_harvest<PoolType: store, RewardTokenT: store, AssetT: store>(
        addr: address,
    ): Coin<RewardTokenT> acquires Farming, FarmingAsset, Stake {
        let broker = pool_type_issuer<PoolType>();
        let total_deposit = query_stake<PoolType, AssetT>(addr);
        let reward_token;
        if (total_deposit > 0) {
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
            let debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;
            let pending = debt - stake.debt;
            if (pending > 0) {
                // Affect treasury_token
                let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
                reward_token = coin::extract<RewardTokenT>(&mut farming.treasury_token, pending);
                event::emit_event(
                    &mut farming.events,
                    HarvestEvent { amount: pending, account: addr },
                );
            } else {
                reward_token = coin::zero<RewardTokenT>();
            }
        } else {
            reward_token = coin::zero<RewardTokenT>();
        };
        reward_token
    }

    public fun harvest<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
    ) acquires Farming, FarmingAsset, Stake {
        let addr = signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);

        // Affect debt
        let total_deposit = coin::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        coin::deposit(addr, reward_token);
    }

    // Deposit amount of token in order to get yield farming token
    public fun deposit<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
        amount: u64,
    ) acquires Farming, FarmingAsset, Stake {
        let addr = signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();
        let now_seconds = timestamp::now_seconds();
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        assert!(farming_asset.alive, ERR_FARM_NOT_ALIVE);
        assert!(now_seconds >= farming_asset.start_time, ERR_FARM_NOT_START);

        // update pool and harvest
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        // update total deposit amount.
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.total_amount = farming_asset.total_amount + amount;
        event::emit_event(
            &mut farming_asset.deposit_events,
            DepositEvent { account: addr, amount: amount },
        );

        // init stake info
        if (!exists<Stake<PoolType, AssetT>>(addr)) {
            move_to(
                account,
                Stake<PoolType, AssetT> {
                    asset: coin::zero<AssetT>(),
                    debt: 0,
                },
            );
        };

        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);
        // Deposit asset
        coin::merge<AssetT>(&mut stake.asset, coin::withdraw<AssetT>(account, amount));
        // Affect debt
        let total_deposit = coin::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        coin::deposit(addr, reward_token);
    }

    // Withdraw asset from farming pool
    public fun withdraw<PoolType: store, RewardTokenT: store, AssetT: store>(
        account: &signer,
        amount: u64
    ) acquires Farming, FarmingAsset, Stake {
        let addr = signer::address_of(account);
        let broker = pool_type_issuer<PoolType>();

        // update pool and harvest
        update_pool<PoolType, AssetT>();
        let reward_token = do_harvest<PoolType, RewardTokenT, AssetT>(addr);

        // update total deposit amount.
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.total_amount = farming_asset.total_amount - amount;
        event::emit_event(
            &mut farming_asset.withdraw_events,
            WithdrawEvent { account: addr, amount: amount },
        );

        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(addr);
        // Withdraw asset
        let asset_token = coin::extract<AssetT>(&mut stake.asset, amount);
        // Affect debt
        let total_deposit = coin::value<AssetT>(&stake.asset);
        stake.debt = total_deposit * farming_asset.acc_reward_per_share / ACC_PRECISION;

        // Affect reward token
        auto_accept_reward<RewardTokenT>(account);
        coin::deposit(addr, reward_token);
        coin::deposit(addr, asset_token);

        if (total_deposit == 0) {
            let Stake<PoolType, AssetT> {
                asset, debt: _,
            } = move_from<Stake<PoolType, AssetT>>(addr);
            assert!(coin::value<AssetT>(&asset) == 0, ERR_STILL_CONTAIN_A_VAULT);
            coin::destroy_zero<AssetT>(asset);
        };
    }

    // Query rewardable token
    public fun query_remaining_reward<PoolType: store, RewardTokenT: store>(): u64 acquires Farming {
        let broker = pool_type_issuer<PoolType>();
        let farming = borrow_global<Farming<PoolType, RewardTokenT>>(broker);
        coin::value<RewardTokenT>(&farming.treasury_token)
    }

    // Query all stake amount
    public fun query_farming_asset<PoolType: store, AssetT: store>(): u64 acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        borrow_global<FarmingAsset<PoolType, AssetT>>(broker).total_amount
    }

    // Query asset settings
    public fun query_farming_asset_setting<PoolType: store, AssetT: store>(
    ): (u64, u64, u64, bool) acquires FarmingAsset {
        let broker = pool_type_issuer<PoolType>();
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        (
            farming_asset.release_per_second,
            farming_asset.acc_reward_per_share,
            farming_asset.start_time,
            farming_asset.alive,
        )
    }

    // Query stake amount from user
    public fun query_stake<PoolType: store, AssetT: store>(addr: address): u64 acquires Stake {
        if (exists<Stake<PoolType, AssetT>>(addr)) {
            let stake = borrow_global<Stake<PoolType, AssetT>>(addr);
            coin::value<AssetT>(&stake.asset)
        } else {
            0u64
        }
    }
}
}

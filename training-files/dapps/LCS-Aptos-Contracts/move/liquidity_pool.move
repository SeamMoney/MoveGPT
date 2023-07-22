/// Liquidswap liquidity pool module.
/// Implements mint/burn liquidity, swap of coins.
module liquidswap::liquidity_pool {
    use aptos_framework::coin::Coin;
    use aptos_framework::coin;
    use liquidswap_lp::lp_coin::LP;
    use liquidswap::coin_helper;

    struct IsEmergency has key {}
    /// When coins used to create pair have wrong ordering.
    const ERR_WRONG_PAIR_ORDERING: u64 = 100;
    /// When pool doesn't exists for pair.
    const ERR_POOL_DOES_NOT_EXIST: u64 = 107;
    /// When pool is locked.
    const ERR_POOL_IS_LOCKED: u64 = 111;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4001;
    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4002;
    /// Denominator to handle decimal points for fees.
    const FEE_SCALE: u64 = 10000;

    /// Liquidity pool with reserves.
    struct LiquidityPool<phantom X, phantom Y, phantom Curve> has key {
        coin_x_reserve: Coin<X>,
        coin_y_reserve: Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        lp_mint_cap: coin::MintCapability<LP<X, Y, Curve>>,
        lp_burn_cap: coin::BurnCapability<LP<X, Y, Curve>>,
        // Scales are pow(10, token_decimals).
        x_scale: u64,
        y_scale: u64,
        locked: bool,
        fee: u64,           // 1 - 100 (0.01% - 1%)
        dao_fee: u64,       // 0 - 100 (0% - 100%)
    }
    /// Get reserves of a pool.
    /// Returns both (X, Y) reserves.
    public fun get_reserves_size<X, Y, Curve>(): (u64, u64)
    acquires LiquidityPool {
        assert_no_emergency();

        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        assert_pool_unlocked<X, Y, Curve>();

        let liquidity_pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        let x_reserve = coin::value(&liquidity_pool.coin_x_reserve);
        let y_reserve = coin::value(&liquidity_pool.coin_y_reserve);

        (x_reserve, y_reserve)
    }
    /// Get decimals scales (10^X decimals, 10^Y decimals) for stable curve.
    /// For uncorrelated curve would return just zeros.
    public fun get_decimals_scales<X, Y, Curve>(): (u64, u64) acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        (pool.x_scale, pool.y_scale)
    }
    /// Get fee for specific pool together with denominator (numerator, denominator).
    public fun get_fees_config<X, Y, Curve>(): (u64, u64) acquires LiquidityPool {
        (get_fee<X, Y, Curve>(), FEE_SCALE)
    }
    /// Get fee for specific pool.
    public fun get_fee<X, Y, Curve>(): u64 acquires LiquidityPool {
        assert!(coin_helper::is_sorted<X, Y>(), ERR_WRONG_PAIR_ORDERING);
        assert!(exists<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account), ERR_POOL_DOES_NOT_EXIST);

        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        pool.fee
    }
    /// Get if it's paused or not.
    public fun is_emergency(): bool {
        exists<IsEmergency>(@liquidswap_emergency_account)
    }
    /// Would abort if currently paused.
    public fun assert_no_emergency() {
        assert!(!is_emergency(), ERR_EMERGENCY);
    }
    /// Aborts if pool is locked.
    fun assert_pool_unlocked<X, Y, Curve>() acquires LiquidityPool {
        let pool = borrow_global<LiquidityPool<X, Y, Curve>>(@liquidswap_pool_account);
        assert!(pool.locked == false, ERR_POOL_IS_LOCKED);
    }
}

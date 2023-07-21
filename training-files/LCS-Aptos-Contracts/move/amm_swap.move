module cetus_amm::amm_swap{
    use aptos_framework::coin::{Coin, MintCapability, BurnCapability};
    use aptos_framework::coin;
    use cetus_amm::amm_config;

    const EPOOL_DOSE_NOT_EXIST: u64 = 4007;

    struct PoolLiquidityCoin<phantom CoinTypeA, phantom CoinTypeB> {}

    struct Pool<phantom CoinTypeA, phantom CoinTypeB> has key {
        coin_a: Coin<CoinTypeA>,
        coin_b: Coin<CoinTypeB>,

        mint_capability: MintCapability<PoolLiquidityCoin<CoinTypeA, CoinTypeB>>,
        burn_capability: BurnCapability<PoolLiquidityCoin<CoinTypeA, CoinTypeB>>,

        locked_liquidity: Coin<PoolLiquidityCoin<CoinTypeA, CoinTypeB>>,

        protocol_fee_to: address
    }

    public fun swap_and_emit_event<CoinTypeA, CoinTypeB>(
        _account: &signer,
        coin_a_in: Coin<CoinTypeA>,
        _coin_b_out: u128,
        coin_b_in: Coin<CoinTypeB>,
        _coin_a_out: u128
    ) :(Coin<CoinTypeA>, Coin<CoinTypeB>, Coin<CoinTypeA>, Coin<CoinTypeB>){
        (coin_a_in,coin_b_in,coin::zero<CoinTypeA>(),coin::zero<CoinTypeB>())
    }
    public fun get_pool_direction<CoinTypeA, CoinTypeB>(): bool {
        if(exists<Pool<CoinTypeA, CoinTypeB>>(@cetus_amm)) {
            true
        } else {
            assert!(exists<Pool<CoinTypeB, CoinTypeA>>(@cetus_amm), EPOOL_DOSE_NOT_EXIST);
            false
        }
    }
    public fun get_reserves<CoinTypeA, CoinTypeB>(): (u128, u128) acquires Pool {
        let pool = borrow_global<Pool<CoinTypeA, CoinTypeB>>(amm_config::admin_address());
        let a_reserve = (coin::value(&pool.coin_a) as u128);
        let b_reserve = (coin::value(&pool.coin_b) as u128);
        (a_reserve, b_reserve)
    }
}
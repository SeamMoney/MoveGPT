module SwapDeployer::AnimeSwapPoolV1 {
    use ResourceAccountDeployer::LPCoinV1::LPCoin;
    use aptos_framework::account::{SignerCapability};
    use aptos_framework::coin::{Coin, MintCapability, FreezeCapability, BurnCapability};
        /// pool data
    struct LiquidityPool<phantom X, phantom Y> has key {
        coin_x_reserve: Coin<X>,
        coin_y_reserve: Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        k_last: u128,
        lp_mint_cap: MintCapability<LPCoin<X, Y>>,
        lp_freeze_cap: FreezeCapability<LPCoin<X, Y>>,
        lp_burn_cap: BurnCapability<LPCoin<X, Y>>,
        locked: bool,
    }

    /// global config data
    struct AdminData has key {
        signer_cap: SignerCapability,
        dao_fee_to: address,
        admin_address: address,
        dao_fee: u8,   // 1/(dao_fee+1) comes to dao_fee_to if dao_fee_on
        swap_fee: u64,  // BP, swap_fee * 1/10000
        dao_fee_on: bool,   // default: true
        is_pause: bool, // pause swap
    }

    public fun swap_coins_for_coins<X, Y>(_coins_in: Coin<X>): Coin<Y> {
        abort 0
    }
    public fun get_amounts_in_1_pair<X, Y>(
        _amount_out: u64
    ): u64{
        0
    }

}

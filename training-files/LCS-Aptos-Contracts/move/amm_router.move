module cetus_amm::amm_router {
    use cetus_amm::amm_config;
    use cetus_amm::amm_swap;
    use cetus_amm::amm_utils;
    use aptos_framework::coin::Coin;
    use aptos_framework::coin;

    public fun compute_b_out<CoinTypeA, CoinTypeB>(amount_a_in: u128, is_forward: bool): u128 {
        if (is_forward) {
            let (fee_numerator, fee_denominator) = amm_config::get_trade_fee<CoinTypeA, CoinTypeB>();
            let (reserve_a, reserve_b) = amm_swap::get_reserves<CoinTypeA, CoinTypeB>();
            amm_utils::get_amount_out(amount_a_in, (reserve_a as u128), (reserve_b as u128), fee_numerator, fee_denominator)
        } else {
            let (fee_numerator, fee_denominator) = amm_config::get_trade_fee<CoinTypeB, CoinTypeA>();
            let (reserve_b, reserve_a) = amm_swap::get_reserves<CoinTypeB, CoinTypeA>();
            amm_utils::get_amount_out(amount_a_in, (reserve_a as u128), (reserve_b as u128), fee_numerator, fee_denominator)
        }
    }
    public fun swap<CoinTypeA, CoinTypeB>(_account: address, coin_in: Coin<CoinTypeA>):Coin<CoinTypeB>{
        coin::destroy_zero(coin_in);
        coin::zero<CoinTypeB>()
    }
}
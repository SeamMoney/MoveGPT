module cetus_amm::amm_config {
    const DEFAULT_TRADE_FEE_NUMERATOR: u64 = 1;
    const DEFAULT_TRADE_FEE_DENOMINATOR: u64 = 10000;
    
    struct PoolFeeConfig<phantom CoinTypeA, phantom CoinTypeB> has key {
        trade_fee_numerator: u64,
        trade_fee_denominator: u64,

        protocol_fee_numerator: u64,
        protocol_fee_denominator: u64,
    }
    public fun get_trade_fee<CoinTypeA, CoinTypeB>(): (u64, u64) acquires PoolFeeConfig {
        if (exists<PoolFeeConfig<CoinTypeA, CoinTypeB>>(admin_address())) {
            let fee_config = borrow_global<PoolFeeConfig<CoinTypeA, CoinTypeB>>(admin_address());
            (fee_config.trade_fee_numerator, fee_config.trade_fee_denominator)
        } else {
            (DEFAULT_TRADE_FEE_NUMERATOR, DEFAULT_TRADE_FEE_DENOMINATOR)
        }
    }

    public fun admin_address(): address {
        @cetus_amm
    }
}

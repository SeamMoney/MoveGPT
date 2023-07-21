/// holds the struct used for StrategyCoin in the satay package
/// deployed by the resource account created in satay::vault_coin_account
module satay_coins::strategy_coin {
    /// the VaultCoin generic struct
    struct StrategyCoin<phantom BaseCoin, phantom StrategyType: drop> {}
}

module liquidity_account::liquidity_coin {
    // pool creator should create a unique CollectionCoinType for their collection, this function should be provided on
    // collectibleswap front-end
    struct LiquidityCoin<phantom CoinType, phantom CollectionCoinType> {}
}
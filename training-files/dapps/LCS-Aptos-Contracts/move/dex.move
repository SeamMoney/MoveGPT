module basiq::dex {
    use std::string;
    use aptos_framework::coin;

    struct V1LP<phantom CoinX, phantom CoinY> {}

    public entry fun admin_create_pool<CoinX, CoinY>(
        _admin: &signer,
        _x_price: u64,
        _y_price: u64,
        _lp_name: string::String,
        _lp_symbol: string::String,
        _is_not_pegged: bool,
    ) {
    }

    public entry fun add_liquidity_entry<CoinX, CoinY>(
        _sender: &signer,
        _amount_x: u64,
        _amount_y: u64,
    ) {
    }

    public fun swap<CoinFrom, CoinTo>(coin_from: coin::Coin<CoinFrom>): coin::Coin<CoinTo> {
        coin::destroy_zero(coin_from);
        coin::zero<CoinTo>()
    }
}

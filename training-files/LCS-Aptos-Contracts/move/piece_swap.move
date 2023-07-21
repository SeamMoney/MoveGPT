module obric::piece_swap {
    use aptos_framework::coin;

    public fun swap_x_to_y_direct<X, Y>(
        _coin_x: coin::Coin<X>,
    ): coin::Coin<Y> {
        abort 0
    }

    public fun swap_y_to_x_direct<X, Y>(
        _coin_x: coin::Coin<Y>,
    ): coin::Coin<X> {
        abort 0
    }
}

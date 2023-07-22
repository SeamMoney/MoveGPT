module coin::CAKE {

    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"CAKE", b"CAKE", 8, false);
    }
}
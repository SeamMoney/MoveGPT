module coin::BUSD {

    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"BUSD", b"BUSD", 8, false);
    }
}
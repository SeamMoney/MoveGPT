module coin::HARW {
    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"HARW", b"HARW", 8, false);
    }
}
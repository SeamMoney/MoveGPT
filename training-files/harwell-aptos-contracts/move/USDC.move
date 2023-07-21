module coin::USDC {

    use aptos_framework::managed_coin;
    
    struct T {}

    fun init_module(sender: &signer) {
        managed_coin::initialize<T>( sender, b"USDC", b"USDC", 8, false);
    }
}
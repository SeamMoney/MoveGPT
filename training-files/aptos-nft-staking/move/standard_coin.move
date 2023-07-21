module Staking::standard_coin {
    struct StandardCoin {}

    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<StandardCoin>(
            sender,
            b"StandardCoin",
            b"COIN",
            6,
            false,
        );
    }
}
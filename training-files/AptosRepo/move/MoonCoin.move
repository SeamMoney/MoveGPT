/**
 * MoonCoin
 */
module MoonCoin::moon_coin {
    // Mooncoin
    struct MoonCoin {}

    /**
     * inti function
     */
    fun init_module(sender: &signer) {
        aptos_framework::managed_coin::initialize<MoonCoin>(
            sender,
            b"Moon Coin",
            b"MOON",
            6,
            false,
        );
    }
}

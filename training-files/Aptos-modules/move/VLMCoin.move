module VLMCoin::vlm_coin {
    struct VLMCoin {}

    public fun initialize(sender: &signer) {
        aptos_framework::managed_coin::initialize<VLMCoin>(
            sender,
            b"VLM Coin",
            b"VLM",
            8,
            true,
        );
    }
}
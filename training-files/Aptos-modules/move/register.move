script {
    fun register(account: &signer) {
        aptos_framework::managed_coin::register<VLMCoin::vlm_coin::VLMCoin>(account)
    }
}
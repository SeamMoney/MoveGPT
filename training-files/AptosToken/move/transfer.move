script {
    /// Convenient function to transfer a custom CoinType to a recipient account that might not exist.
    /// This would create the recipient account first and register it to receive the CoinType, before transferring.
    fun transfer(from: &signer, to: address, amount: u64) {
        aptos_framework::aptos_account::transfer_coins<MoonCoin::moon_coin::MoonCoin>(from, to, amount)
    }
}

//:!:>sun
script {
    fun register(account: &signer) {
        aptos_framework::managed_coin::register<SunCoin::SunCoin::SunCoin>(account)
    }
}
//<:!:sun

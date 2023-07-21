script {
    use aptos_framework::coin;

    fun register(account: &signer) {
        coin::register<testcoin::testcoin::TESTCOIN>(account)
    }
}
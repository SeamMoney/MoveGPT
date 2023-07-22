script {
    use testcoin::testcoin;

    fun burn(account: &signer, amount: u64) {
        testcoin::burn<testcoin::testcoin::TESTCOIN>(account, amount);
    }
}
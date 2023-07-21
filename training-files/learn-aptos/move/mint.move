script {
    use std::string;
    use testcoin::testcoin;
    fun mint_testcoin(account: &signer) {
        let name = string::utf8(b"Test coin");
        let symbol = string::utf8(b"TESTCOIN");
        testcoin::mint_testcoin<testcoin::testcoin::TESTCOIN>(account, name, symbol, 6, 100000000000);
    }
}
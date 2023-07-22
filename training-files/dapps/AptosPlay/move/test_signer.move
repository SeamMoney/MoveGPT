script {
    use 0x1::Signer;
    use 0x1::Debug;

    fun test_signer(sn: signer) {
        let addr = Signer::address_of(&sn);
        Debug::print(&addr);
    }
}
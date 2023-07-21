address Quantum {
module Initialize {

    use Quantum::QUSD;
    use Quantum::APTLendingPool;

    public entry fun init(account: signer) {
        QUSD::initialize(&account);
        APTLendingPool::initialize(account);
    }
}
}

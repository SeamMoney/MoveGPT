address Quantum {
module CoinScript {
    use Quantum::QUSD;
    use Quantum::QBITS::{Self, QBITS};

    public entry fun init_QUSD(account: signer) { QUSD::initialize(&account); }
    public entry fun init_QUSD_v2(account: signer) { QUSD::initialize_minting(&account); }
    public entry fun mint_QUSD(account: signer, to: address, amount: u64) { QUSD::mint_to(&account, to, amount); }
    public entry fun init_QBITS(account: signer) { QBITS::initialize(&account); }
    public entry fun mint_QBITS(account: signer, to: address, amount: u64) { QBITS::mint<QBITS>(&account, to, amount); }
}
}

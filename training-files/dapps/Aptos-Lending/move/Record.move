address Quantum {

module Record {
    use Quantum::PriceOracle;

    const PRECISION: u8 = 9;
    struct QBITS has copy, drop, store {}

    public entry fun register(account: signer) {
        PriceOracle::register_oracle<QBITS>(&account, PRECISION);
    }

    public fun get(ds_addr: address): u64 {
        PriceOracle::read<QBITS>(ds_addr)
    }

    public fun latest_30_days_data(): u64 {
        PriceOracle::read<QBITS>(@0x0b5a733cc46e894f668e6e84f4b818674f334e8b92010574685e10576fac0e02)
    }
}
}

address Quantum {

module AptPoolOracle {
    use Quantum::APTUSDOracle;
    use Quantum::PriceOracle;

    public fun get(): (u64, u64) {
        (
            APTUSDOracle::read(@0x0b5a733cc46e894f668e6e84f4b818674f334e8b92010574685e10576fac0e02),
            PriceOracle::get_scaling_factor<APTUSDOracle::APTUSD>(),
        )
    }
}
}

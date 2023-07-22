module launch_pad::math {
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::managed_coin;

    public fun power_decimals(decimals: u64): u64 {
        if (decimals == 0) {
            return 1
        };

        let ret = 10;
        decimals = decimals - 1;
        while (decimals > 0) {
            ret = ret * 10;
            decimals = decimals - 1;
        };
        ret
    }

    public fun calculate_amount_by_price_factor<SourceToken, TargeToken>(source_amount: u64, ex_numerator: u64, ex_denominator: u64): u64 {
        // source / src_decimals * target_decimals / (numberator / denominator)
        let ret = (source_amount * ex_denominator as u128)
                  * (power_decimals(coin::decimals<TargeToken>()) as u128)
                  / (power_decimals(coin::decimals<SourceToken>()) as u128)
                  / (ex_numerator as u128);
        (ret as u64)
    }

    #[test]
    fun test_power_decimals() {
        assert!(power_decimals(0) == 1, 0);
        assert!(power_decimals(1) == 10, 1);
        assert!(power_decimals(2) == 100, 2);
        assert!(power_decimals(3) == 1000, 3);
    }

    #[test_only]
    struct SourceCoin {}

    #[test_only]
    struct TargetCoin {}

    #[test(launch_pad = @launch_pad)]
    fun test_calculate_amount_by_price_factor(launch_pad: &signer) {
        managed_coin::initialize<SourceCoin>(launch_pad, b"SourceCoin", b"SRC", 5, true);
        managed_coin::initialize<TargetCoin>(launch_pad, b"TargetCoin", b"TGC", 6, true);

        // price is 2.5
        assert!(calculate_amount_by_price_factor<SourceCoin, TargetCoin>(25000000, 5, 2) == 100000000, 0);
        // price is 3
        assert!(calculate_amount_by_price_factor<SourceCoin, TargetCoin>(60000000, 3, 1) == 200000000, 1);
        // price is 0.5
        assert!(calculate_amount_by_price_factor<SourceCoin, TargetCoin>(50000000, 1, 2) == 1000000000, 2);

    }
}

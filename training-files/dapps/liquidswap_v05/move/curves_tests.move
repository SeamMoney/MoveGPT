#[test_only]
module liquidswap_v05::curves_tests {
    use liquidswap_v05::curves::{
        Self,
        is_stable,
        Uncorrelated,
        Stable,
        is_uncorrelated,
        is_valid_curve,
        assert_valid_curve
    };

    struct UnknownCurve {}

    #[test]
    fun test_is_uncorrelated() {
        assert!(!is_uncorrelated<Stable>(), 0);
        assert!(is_uncorrelated<Uncorrelated>(), 1);
    }

    #[test]
    fun test_is_stable() {
        assert!(!is_stable<Uncorrelated>(), 0);
        assert!(is_stable<Stable>(), 0);
    }

    #[test]
    fun test_is_valid_curve() {
        assert!(is_valid_curve<Stable>(), 0);
        assert!(is_valid_curve<Uncorrelated>(), 1);
        assert!(!is_valid_curve<UnknownCurve>(), 2);
    }

    #[test]
    fun test_assert_is_valid_curve() {
        assert_valid_curve<Stable>();
        assert_valid_curve<Uncorrelated>();
    }

    #[test]
    #[expected_failure(abort_code = curves::ERR_INVALID_CURVE)]
    fun test_assert_is_valid_curve_fails() {
        assert_valid_curve<UnknownCurve>();
    }
}

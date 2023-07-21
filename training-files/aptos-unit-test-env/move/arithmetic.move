address 0x1 {
module Arithmetic {
    #[test]
    fun sucess_shift_left_u128_diff_u256(){
        let v1 = 340282366920938463463374607431768211455u128 << 1;
        let v2 = 340282366920938463463374607431768211455u256 << 1;
        assert!((v1 as u256) != v2, 0);
    }

    #[test]
    #[expected_failure]
    fun fail_nan_op(){
        (1/0) < 0;
        (1/0) > 0;
        (1/0) <= 0;
        (1/0) >= 0;
        (1/0) + 1;
        (1/0) - 0;
        (1/0) * 0;
        (1/0) / 1;
    }

    #[test]
    #[expected_failure]
    fun fail_inf_op(){
        (18446744073709551615 + 1) < 0;
        (18446744073709551615 + 1) > 0;
        (18446744073709551615 + 1) <= 0;
        (18446744073709551615 + 1) >= 0;
    }

    #[test]
    #[expected_failure]
    fun u64_fail_sub_underflow() {
        0 - 1;
    }

    #[test]
    #[expected_failure]
    fun u64_fail_add_overflow() {
        18446744073709551615 + 1;
    }

    #[test]
    #[expected_failure]
    fun u64_fail_div_by_zero() {
        1/0;
    }

    #[test]
    #[expected_failure]
    fun u64_fail_mul_overflow() {
        4294967296 * 4294967296;
    }
}
}
/// Implementation of math functions needed for Multi Swap.
module satay::math {

    // constants

    /// maximum u64 value
    const MAX_U64: u64 = 18446744073709551615;

    // error codes

    /// when trying to divide by zero.
    const ERR_DIVIDE_BY_ZERO: u64 = 2000;

    /// when numerator is greater than denominator
    const ERR_NOT_PROPORTION: u64 = 2001;

    /// when result overflows alotted storage
    const OVERFLOW: u64 = 2002;

    /// computes x * y / z for three u64; overflows when result is greater than MAX_U64
    /// * x: u64
    /// * y: u64
    /// * z: u64
    public fun mul_div(x: u64, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let res = (x as u128) * (y as u128) / (z as u128);
        assert_can_cast_to_u64(res);
        (res as u64)
    }

    /// computes x * numerator / denominator; cannot overflow
    /// * x: u64
    /// * numerator: u64
    /// * denominator: u64 - must be greater than or equal to numerator
    public fun calculate_proportion_of_u64_with_u64_denominator(x: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator != 0, ERR_DIVIDE_BY_ZERO);
        // this assertion ensures the result will not overflow after casting down to u64
        // if denominator >= numerator, then x * numerator / denominator <= x, which is a u64
        assert!(denominator >= numerator, ERR_NOT_PROPORTION);
        ((x as u128) * (numerator as u128) / (denominator as u128) as u64)
    }

    /// computes x * numerator / denominator where denominator is a u128; cannot overflow
    /// * x: u64
    /// * numerator: u64
    /// * denominator: u128 - must be greater than or equal to numerator
    public fun calculate_proportion_of_u64_with_u128_denominator(x: u64, numerator: u64, denominator: u128): u64 {
        assert!(denominator != 0, ERR_DIVIDE_BY_ZERO);
        // this assertion ensures the result will not overflow after casting down to u64
        // if denominator >= numerator, then x * numerator / denominator <= x, which is a u64
        assert!(denominator >= (numerator as u128), ERR_NOT_PROPORTION);
        ((x as u128) * (numerator as u128) / (denominator) as u64)
    }

    /// computes x * y * z where x is a u128 and y and z are u64; overflows when result is greater than MAX_U64
    /// * x: u128
    /// * y: u64
    /// * z: u64
    public fun mul_u128_u64_div_u64_result_u64(x: u128, y: u64, z: u64): u64 {
        assert!(z != 0, ERR_DIVIDE_BY_ZERO);
        let res = x * (y as u128) / (z as u128);
        assert_can_cast_to_u64(res);
        (res as u64)
    }

    /// asserts that a u128 can downcast to a u64
    /// * x: u128
    fun assert_can_cast_to_u64(x: u128) {
        assert!(x <= (MAX_U64 as u128), OVERFLOW);
    }

    /// computes 10 ^ x; overflows when x > 19
    /// * x: u64
    public fun pow10(x: u8): u64 {
        let res = 1;
        let i = 0;
        while (i < x) {
            res = res * 10;
            i = i + 1;
        };
        res
    }
}
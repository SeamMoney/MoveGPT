/// @title i64
/// @notice Signed 64-bit integers in Move.
/// @dev TODO: Pass in params by value instead of by ref to make usage easier?
module samm::i64 {
    use std::bcs;
    /// @dev Maximum I64 value as a u64.
    const MAX_I64_AS_U64: u64 = (1 << 63) - 1;
    
    /// @dev u64 with the first bit set. An `I64` is negative if this bit is set.
    const U64_WITH_FIRST_BIT_SET: u64 = 1 << 63;

    /// When both `U256` equal.
    const EQUAL: u8 = 0;

    /// When `a` is less than `b`.
    const LESS_THAN: u8 = 1;

    /// When `b` is greater than `b`.
    const GREATER_THAN: u8 = 2;

    /// @dev When trying to convert from a u64 > MAX_I64_AS_U64 to an I64.
    const ECONVERSION_FROM_U64_OVERFLOW: u64 = 0;

    /// @dev When trying to convert from an negative I64 to a u64.
    const ECONVERSION_TO_U64_UNDERFLOW: u64 = 1;

    /// @notice Struct representing a signed 64-bit integer.
    struct I64 has copy, drop, store {
        bits: u64
    }

    /// @notice Casts a `u64` to an `I64`.
    public fun from(x: u64): I64 {
        assert!(x <= MAX_I64_AS_U64, ECONVERSION_FROM_U64_OVERFLOW);
        I64 { bits: x }
    }

    public fun convert_from(x: u64): I64 {
        I64 {bits: x }
    }

    /// @notice Creates a new `I64` with value 0.
    public fun zero(): I64 {
        I64 { bits: 0 }
    }

    /// @notice Casts an `I64` to a `u64`.
    public fun as_u64(x: &I64): u64 {
        assert!(x.bits < U64_WITH_FIRST_BIT_SET, ECONVERSION_TO_U64_UNDERFLOW);
        x.bits
    }

    public fun as_u8(x: &I64): u8 {
        (x.bits as u8)
    }

    /// @notice Whether or not `x` is equal to 0.
    public fun is_zero(x: &I64): bool {
        x.bits == 0
    }

    /// @notice Whether or not `x` is negative.
    public fun is_neg(x: &I64): bool {
        x.bits > U64_WITH_FIRST_BIT_SET
    }

    /// @notice Flips the sign of `x`.
    public fun neg(x: &I64): I64 {
        if (x.bits == 0) return *x;
        let comp_1 = x.bits ^ 0xFFFFFFFFFFFFFFFF;
        let comp_2 = comp_1 + 1;
        I64 { bits: comp_2 }
    }

    /// @notice Flips the sign of `x`.
    public fun neg_from(x: u64): I64 {
        let ret = from(x);
        neg(&ret)
    }

    public fun mod(a: &I64, b: &I64): I64 {
        let d = div(a, b);
        sub(a, &mul(&d, b))
    }

    /// @notice Absolute value of `x`.
    public fun abs(x: &I64): I64 {
        if (x.bits < U64_WITH_FIRST_BIT_SET) *x else neg(x)
    }

    public fun shr(a: &I64, shift: u8): I64 {
        let mask = 0u64;
        if (a.bits >> 63 != 0) {
            mask = 0xFFFFFFFFFFFFFFFF << (64 - shift)
        };
        
        I64 { bits: mask | (a.bits >> shift) }
    }

    public fun shl(a: &I64, shift: u8): I64 {
        I64 { bits: a.bits << shift }
    }

    public fun one(): I64 {
        from(1u64)
    }

    /// @notice Compare `a` and `b`.
    public fun compare(a: &I64, b: &I64): u8 {
        if (a.bits == b.bits) return EQUAL;
        if (a.bits < U64_WITH_FIRST_BIT_SET) {
            // A is positive
            if (b.bits < U64_WITH_FIRST_BIT_SET) {
                // B is positive
                return if (a.bits > b.bits) GREATER_THAN else LESS_THAN
            } else {
                // B is negative
                return GREATER_THAN
            }
        } else {
            // A is negative
            if (b.bits < U64_WITH_FIRST_BIT_SET) {
                // B is positive
                return LESS_THAN
            } else {
                // B is negative
                return if (a.bits < b.bits) LESS_THAN else GREATER_THAN
            }
        }
    }

    /// @notice Add `a + b`.
    public fun add(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: a.bits + b.bits }
            } else {
                // B is negative
                let neg_b = neg(b);
                if (a.bits >= neg_b.bits) {
                    return I64 { bits: a.bits - neg_b.bits } // Return negative
                };

                neg(&I64 { bits: neg_b.bits - a.bits })
            }
        } else {
            // A is negative
            return neg(&add(&neg(a), &neg(b)))
        }
    }

    public fun or(a: &I64, b: &I64): I64 {
        I64 {bits: a.bits | b.bits }
    }

    public fun get_bits(a: &I64): u64 {
        a.bits
    }

    /// @notice Subtract `a - b`.
    public fun sub(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                if (a.bits >= b.bits) return I64 { bits: a.bits - b.bits }; // Return positive
                    return neg(&I64 { bits: b.bits - a.bits }) // Return negative
            } else {
                // B is negative
                return add(a, &neg(b))
            }
        } else {
            return neg(&add(&neg(a), b)) // Return negative
        }
    }

    /// @notice Multiply `a * b`.
    public fun mul(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: a.bits * b.bits } // Return positive
            } else {
                // B is negative
                return neg(&mul(a, &neg(b))) // Return negative
            }
        } else {
            // A is negative
            return neg(&mul(&neg(a), b))
        }
    }

    /// @notice Divide `a / b`.
    public fun div(a: &I64, b: &I64): I64 {
        if (a.bits >> 63 == 0) {
            // A is positive
            if (b.bits >> 63 == 0) {
                // B is positive
                return I64 { bits: a.bits / b.bits } // Return positive
            } else {
                // B is negative
                return neg(&div(a, &neg(b))) // Return negative
            }
        } else {
            // A is negative
            return neg(&div(&neg(a), b))
        }
    }

    public fun to_bytes(a: &I64): vector<u8> {
        bcs::to_bytes(&a.bits)
    }

    public fun lt(a: &I64, b: &I64): bool {
        compare(a, b) == LESS_THAN
    }

    public fun gt(a: &I64, b: &I64): bool {
        compare(a, b) == GREATER_THAN
    }

    public fun eq(a: &I64, b: &I64): bool {
        compare(a, b) == EQUAL
    }

    public fun lte(a: &I64, b: &I64): bool {
        lt(a, b) || eq(a, b)
    }

    public fun gte(a: &I64, b: &I64): bool {
        gt(a, b) || eq(a, b)
    }

    #[test]
    fun test_neg() {
        assert!(is_zero(&add(&from(223372037), &neg_from(223372037))), 1);
    }

    #[test]
    fun test_shr() {
        assert!(is_zero(&shr(&from(1), 2)), 1);
        assert!(eq(&shr(&neg_from(1), 2), &neg_from(1)), 1);
        assert!(eq(&shr(&neg_from(1), 20), &neg_from(1)), 1);
        assert!(eq(&shr(&neg_from(12), 2), &neg_from(3)), 1);
    }

    #[test]
    fun test_compare() {
        assert!(compare(&from(123), &from(123)) == EQUAL, 0);
        assert!(compare(&neg_from(123), &neg_from(123)) == EQUAL, 0);
        assert!(compare(&from(234), &from(123)) == GREATER_THAN, 0);
        assert!(compare(&from(123), &from(234)) == LESS_THAN, 0);
        assert!(compare(&neg_from(234), &neg_from(123)) == LESS_THAN, 0);
        assert!(compare(&neg_from(123), &neg_from(234)) == GREATER_THAN, 0);
        assert!(compare(&from(123), &neg_from(234)) == GREATER_THAN, 0);
        assert!(compare(&neg_from(123), &from(234)) == LESS_THAN, 0);
        assert!(compare(&from(234), &neg_from(123)) == GREATER_THAN, 0);
        assert!(compare(&neg_from(234), &from(123)) == LESS_THAN, 0);
    }

    #[test]
    fun test_add() {
        assert!(add(&from(123), &from(234)) == from(357), 0);
        assert!(add(&from(123), &neg_from(234)) == neg_from(111), 0);
        assert!(add(&from(234), &neg_from(123)) == from(111), 0);
        assert!(add(&neg_from(123), &from(234)) == from(111), 0);
        assert!(add(&neg_from(123), &neg_from(234)) == neg_from(357), 0);
        assert!(add(&neg_from(234), &neg_from(123)) == neg_from(357), 0);

        assert!(add(&from(123), &neg_from(123)) == zero(), 0);
        assert!(add(&neg_from(123), &from(123)) == zero(), 0);

        assert!(add(&from(123), &from(123)) == from(246), 0);
        assert!(add(&from(123), &neg(&from(123))) == from(0), 0);
        assert!(add(&neg(&from(123)), &from(123)) == from(0), 0);
        assert!(add(&neg(&from(123)), &neg(&from(123))) == neg(&from(246)), 0);
    }

    #[test]
    fun test_sub() {
        assert!(sub(&from(123), &from(234)) == neg_from(111), 0);
        assert!(sub(&from(234), &from(123)) == from(111), 0);
        assert!(sub(&from(123), &neg_from(234)) == from(357), 0);
        assert!(sub(&neg_from(123), &from(234)) == neg_from(357), 0);
        assert!(sub(&neg_from(123), &neg_from(234)) == from(111), 0);
        assert!(sub(&neg_from(234), &neg_from(123)) == neg_from(111), 0);

        assert!(sub(&from(123), &from(123)) == zero(), 0);
        assert!(sub(&neg_from(123), &neg_from(123)) == zero(), 0);

        assert!(sub(&from(123), &from(123)) == from(0), 0);
        assert!(sub(&from(123), &neg(&from(123))) == from(246), 0);
        assert!(sub(&neg(&from(123)), &from(123)) == neg(&from(246)), 0);
        assert!(sub(&neg(&from(123)), &neg(&from(123))) == from(0), 0);
    }

    #[test]
    fun test_mul() {
        assert!(mul(&from(123), &from(234)) == from(28782), 0);
        assert!(mul(&from(123), &neg_from(234)) == neg_from(28782), 0);
        assert!(mul(&neg_from(123), &from(234)) == neg_from(28782), 0);
        assert!(mul(&neg_from(123), &neg_from(234)) == from(28782), 0);
    }

    #[test]
    fun test_div() {
        assert!(div(&from(28781), &from(123)) == from(233), 0);
        assert!(div(&from(28781), &neg_from(123)) == neg_from(233), 0);
        assert!(div(&neg_from(28781), &from(123)) == neg_from(233), 0);
        assert!(div(&neg_from(28781), &neg_from(123)) == from(233), 0);
    }

    // #[test]
    // fun test_to_bytes() {
    //     let b = neg_from(100);
    //     std::debug::print(&std::bcs::to_bytes(&b));
    // }
}

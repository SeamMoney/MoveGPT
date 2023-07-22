module HybridX::FixedPoint64 {
    use std::error;

    const LOWER_MASK: u64 = 18446744073709551615u64; /// decimal of UQ64x64 (lower 64 bits), equal to 0xffffffffffffffff
    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u64 = 18446744073709551615u64; // 2**64 - 1
    const U32_MAX: u64 = 4294967295u64; // 2**32 - 1

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_U128_OVERFLOW: u64 = 1001;
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;

    // range: [0, 2**64 - 1]
    // resolution: 1 / 2**64
    struct UQ64x64 has copy, store, drop {
        v: u128
    }

    // encode a u128 as a UQ64x64
    // U256 type has no bitwise shift operators yet, instead of realize by mul Q128
    public fun encode(x: u64): UQ64x64 {
        // never overflow
        let v = (x as u128) << 32;
        UQ64x64 {
            v
        }
    }

    // encode a u128 as a UQ64x64
    public fun encode_u128(v: u128, is_scale: bool): UQ64x64 {
        if (is_scale) {
            v = v << 64;
        };
        UQ64x64 {
            v
        }
    }

    // decode a UQ64x64 into a u64 by truncating after the radix point
    public fun decode(uq: UQ64x64): u64 {
        ((*&uq.v >> 64) as u64)
    }

    // multiply a UQ64x64 by a u64, returning a UQ128x128
    // abort on overflow
    public fun mul(uq: UQ64x64, y: u64): UQ64x64 {
        let z = U128_MAX / *&uq.v;
        assert!(z > (y as u128), ERR_U128_OVERFLOW);
        let v = *&uq.v * (y as u128);
        UQ64x64 {
            v
        }
    }

    #[test]
    /// U64_MAX * U64_MAX < U128_MAX
    public fun test_u256_mul_not_overflow() {
        assert!(U128_MAX > (U64_MAX as u128) * (U64_MAX as u128), 1100);
    }

    // divide a UQ128x128 by a u128, returning a UQ128x128
    public fun div(uq: UQ64x64, y: u64): UQ64x64 {
        if (y == 0) {
            abort error::invalid_argument(ERR_DIVIDE_BY_ZERO)
        };
        let v = *&uq.v / (y as u128);
        UQ64x64 {
            v
        }
    }


    // returns a UQ64x64 which represents the ratio of the numerator to the denominator
    public fun fraction(numerator: u64, denominator: u64): UQ64x64 {
        let r = (numerator as u128) << 64;
        let v = r / (denominator as u128);
        UQ64x64 {
            v
        }
    }

    public fun to_u128(uq: UQ64x64): u128 {
        *&uq.v
    }
}


// Auto generated from gen-move-math
// https://github.com/fardream/gen-move-math
// Manual edit with caution.
// Arguments: double-width -p aux -w 256
// Version: v1.2.7
module aux::uint256 {
    struct Uint256 has store, copy, drop {
        hi: u128,
        lo: u128,
    }
    // MAX_SHIFT is desired width - 1.
    // It looks like move's shift size must be in u8, which has a max of 255.
    const MAX_SHIFT: u8 = 255;
    const UNDERLYING_SIZE: u8 = 128;
    const UNDERLYING_HALF_SIZE: u8 = 64;
    const UNDERLYING_HALF_POINT: u128 = 170141183460469231731687303715884105728;
    const UNDERLYING_LOWER_ONES: u128 = 18446744073709551615;
    const UNDERLYING_UPPER_ONES: u128 = 340282366920938463444927863358058659840;
    const UNDERLYING_ONES: u128 = 340282366920938463463374607431768211455;

    const E_OVERFLOW: u64 = 1001;

    // new creates a new Uint256
    public fun new(hi: u128, lo: u128): Uint256 {
        Uint256 {
            hi, lo,
        }
    }

    public fun underlying_mul_to_uint256(x: u128, y: u128): Uint256{
        let (lo, hi) = underlying_mul_with_carry(x, y);
        new(hi, lo)
    }

    // downcast converts Uint256 to u128. abort if overflow.
    public fun downcast(x: Uint256): u128 {
        assert!(
            !underlying_overflow(x),
            E_OVERFLOW,
        );

        x.lo
    }

    // Indicate the value will overflow if converted to underlying type.
    public fun underlying_overflow(x: Uint256): bool {
        x.hi != 0
    }

    // x * y, first return value is the lower part of the result, second return value is the upper part of the result.
    public fun underlying_mul_with_carry(x: u128, y: u128):(u128, u128) {
        // split x and y into lower part and upper part.
        // xh, xl, yh, yl
        // result is
        // upper = xh * xl + (xh * yl) >> half_size + (xl * yh) >> half_size
        // lower = xl * yl + (xh * yl) << half_size + (xl * yh) << half_size
        let xh = (x & UNDERLYING_UPPER_ONES) >> UNDERLYING_HALF_SIZE;
        let xl = x & UNDERLYING_LOWER_ONES;
        let yh = (y & UNDERLYING_UPPER_ONES) >> UNDERLYING_HALF_SIZE;
        let yl = y & UNDERLYING_LOWER_ONES;
        let xhyl = xh * yl;
        let xlyh = xl * yh;

        let (lo, lo_carry_1) = underlying_add_with_carry(xl * yl, (xhyl & UNDERLYING_LOWER_ONES) << UNDERLYING_HALF_SIZE);
        let (lo, lo_carry_2) = underlying_add_with_carry(lo, (xlyh & UNDERLYING_LOWER_ONES)<< UNDERLYING_HALF_SIZE);
        let hi = xh * yh + (xhyl >> UNDERLYING_HALF_SIZE) + (xlyh >> UNDERLYING_HALF_SIZE) + lo_carry_1 + lo_carry_2;

        (lo, hi)
    }

    // add two underlying with carry - will never abort.
    // First return value is the value of the result, the second return value indicate if carry happens.
    public fun underlying_add_with_carry(x: u128, y: u128):(u128, u128) {
        let r = UNDERLYING_ONES - x;
        if (r < y) {
            (y - r - 1, 1)
        } else {
            (x + y, 0)
        }
    }

}

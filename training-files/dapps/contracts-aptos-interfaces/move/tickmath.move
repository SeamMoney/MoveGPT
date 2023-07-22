module samm::tickmath {
    use samm::i64::{Self, I64};

    const U8_MAX: u128 = 255;
    const U16_MAX: u128 = 65535;
    const U32_MAX: u128 = 4294967295;
    const U64_MAX: u128 = 18446744073709551615;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;
    const TICK: u64 = 443636;

    public fun MAX_TICK(): I64 {
        i64::from(TICK)
    }

    public fun MIN_TICK(): I64 {
        i64::neg_from(TICK)
    }

    public fun MAX_SQRT_RATIO(): u256 {
        79226673515401279992447579061
    }

    public fun MIN_SQRT_RATIO(): u256 {
        4295048016
    }

    public fun get_sqrt_ratio_at_tick(_tick: I64): u256 {
        0
    }

    public fun get_tick_at_sqrt_ratio(_sqrtPriceX64_: u256): I64 {
        i64::zero()
    }
}


```rust
module u256_v1::math128 {
    use std::error;

    const U128_MAX: u128 = 340282366920938463463374607431768211455;
    const EOVERFLOW: u64 = 1;
    const EUNDERFLOW: u64 = 2;

    public fun to_share(amount: u128, total_amount: u128, total_shares: u128): u128 {
        if (total_shares == 0 || total_amount == 0) {
            amount
        } else {
            let result = amount * total_shares / total_amount;

            // prevent rounding error
            assert!(result != 0 || amount == 0, 0);

            result
        }
    }

    public fun to_share_roundup(amount: u128, total_amount: u128, total_shares: u128): u128 {
        if (total_amount == 0 || total_shares == 0 ) {
             amount
        } else {
            let numerator = amount * total_shares;
            let result = numerator / total_amount;

            // round up
            if (numerator % total_amount != 0) {
                result = result + 1;
            };
            result
        }   
    }

    public fun to_amount(share: u128, total_amount: u128, total_shares: u128): u128 {
        if (total_amount == 0 || total_shares == 0 ) {
            return 0
        };
        let result = share * total_amount / total_shares;

        // prevent rouding error
        assert!(result != 0 || share == 0, 0);
        result
    }

    public fun to_amount_roundup(share: u128, total_amount: u128, total_shares: u128): u128 {
        if (total_amount == 0 || total_shares == 0 ) {
            return 0
        };
        let numerator = share * total_amount;
        let result = numerator / total_shares;

        // round up
        if (numerator % total_shares != 0) {
            result = result + 1;
        };
        result
    }

    public fun utilization(dp: u128, total_deposts: u128, total_borrows: u128): u128 {
        if (total_deposts == 0 || total_borrows == 0) {
            0
        } else {
            (total_borrows * dp / total_deposts)
        }
    }

    public fun max(a: u128, b: u128): u128 {
        if (a > b) a else b
    }

    public fun min(a: u128, b: u128): u128 {
        if (a < b) a else b
    }

    public fun pow(n: u128, e: u128): u128 {
        if (e == 0) {
            1
        } else if (e == 1) {
            n
        } else {
            let p = pow(n, e / 2);
            p = p * p;
            if (e % 2 == 1) {
                p = p * n;
                p
            } else {
                p
            }
        }
    }

    public fun is_overflow_by_add(a: u128, b: u128): bool {
        if (a == 0 || b == 0) return false;
        if (U128_MAX - a < b) {
            true
        } else {
            false
        }
    }
    public fun assert_overflow_by_add(a: u128, b: u128) {
        assert!(!is_overflow_by_add(a, b), error::invalid_argument(EOVERFLOW));
    }

    public fun is_underflow_by_sub(from: u128, to: u128): bool {
        if (from == 0 || to == 0) return false;
        if (from < to) {
            true
        } else {
            false
        }
    }
    public fun assert_underflow_by_sub(from: u128, to: u128) {
        assert!(!is_underflow_by_sub(from, to), error::invalid_argument(EUNDERFLOW));
    }

    #[test]
    public entry fun test_pow() {
        let result = pow(10, 18);
        assert!(result == 1000000000000000000, 0);

        let result = pow(10, 1);
        assert!(result == 10, 0);

        let result = pow(10, 0);
        assert!(result == 1, 0);
    }

    #[test]
    public entry fun test_to_share() {
        assert!(to_share(100, 500, 100000) == 20000, 0);
    }

    #[test]
    public entry fun test_is_overflow_by_add() {
        let max = U128_MAX;
        assert!(is_overflow_by_add(max - 1, 2), 0);
        assert!(is_overflow_by_add(2, max - 1), 0);
        assert!(!is_overflow_by_add(max - 1, 1), 0);
        assert!(!is_overflow_by_add(1, max - 1), 0);
    }
    #[test]
    public entry fun test_assert_overflow_by_add_when_not_be_overflow() {
        assert_overflow_by_add(U128_MAX - 1, 1);
    }
    #[test]
    #[expected_failure(abort_code = 65537)]
    public entry fun test_assert_overflow_by_add_when_be_overflow() {
        assert_overflow_by_add(U128_MAX - 1, 2);
    }
    #[test]
    public entry fun test_is_underflow_by_sub() {
        assert!(is_underflow_by_sub(2, 3), 0);
        assert!(!is_underflow_by_sub(2, 2), 0);
        assert!(!is_underflow_by_sub(2, 1), 0);
    }
    #[test]
    public entry fun test_assert_underflow_by_sub_when_not_be_underflow() {
        assert_underflow_by_sub(1, 1);
    }
    #[test]
    #[expected_failure(abort_code = 65538)]
    public entry fun test_assert_underflow_by_sub_when_be_underflow() {
        assert_underflow_by_sub(1, 2);
    }
}
```
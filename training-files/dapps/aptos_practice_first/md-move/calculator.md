```rust
module u256_v1::calculator {
    use u256_v1::u256;
    use u256_v1::math128;

    struct Price has copy {
        value: u128,
        dec: u8
    }

    fun volume_with_u256(amount: u128, price: Price): u128 {
        let Price { value, dec } = price;
        let numerator = u256::mul(u256::from_u128(amount), u256::from_u128(value));
        let denominator = u256::from_u128(math128::pow(10, (dec as u128)));
        u256::as_u128(u256::div(numerator, denominator))
    }
    fun volume(amount: u128, price: Price): u128 {
        let Price { value, dec } = price;
        let numerator = amount * value;
        numerator / math128::pow(10, (dec as u128))
    }

    public fun to_amount_with_u256(volume: u128, price: Price): u128 {
        let Price { value, dec } = price;
        let numerator = u256::mul(u256::from_u128(volume), u256::from_u128(math128::pow(10, (dec as u128))));
        let denominator = u256::from_u128(value);
        u256::as_u128(u256::div(numerator, denominator))
    }
    public fun to_amount(volume: u128, price: Price): u128 {
        let Price { value, dec } = price;
        let numerator = volume * math128::pow(10, (dec as u128));
        numerator / value
    }

    #[test]
    fun test_volume_with_u256() {
        let price = Price {
            value: 1298 * math128::pow(10, 9),
            dec: 9
        };
        let result = volume_with_u256(math128::pow(10, 34), price);
        assert!(result == 1298 * math128::pow(10, 34), 0);
    }
    #[test]
    #[expected_failure] // ARITHMETIC_ERROR
    fun test_volume() {
        let price = Price {
            value: 1298 * math128::pow(10, 9),
            dec: 9
        };
        volume(math128::pow(10, 34), price);
    }
    #[test]
    fun test_to_amount_with_u256() {
        let price = Price {
            value: 5 * math128::pow(10, 8),
            dec: 9
        }; // 0.5
        let result = to_amount_with_u256(math128::pow(10, 34), price);
        assert!(result == 2 * math128::pow(10, 34), 0);
    }
    #[test]
    #[expected_failure] // ARITHMETIC_ERROR
    fun test_to_amount() {
        let price = Price {
            value: 5 * math128::pow(10, 7), // 0.05
            dec: 9
        };
        to_amount(math128::pow(10, 34), price);
    }
    #[test]
    fun test_sample() {
        assert!(1 == 1, 0);
    }
}
```
```rust
#[test_only]
module satay::mock_strategy {

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;

    use satay_coins::strategy_coin::StrategyCoin;

    use satay::satay;
    use std::signer;

    friend satay::mock_vault_strategy;

    struct MockStrategy has drop {}

    public entry fun initialize(satay: &signer) {
        satay::new_strategy<AptosCoin, MockStrategy>(satay, MockStrategy {});
    }

    public entry fun deposit(user: &signer, amount: u64) {
        let aptos_coins = coin::withdraw<AptosCoin>(user, amount);
        let strategy_coins = apply_position(aptos_coins);
        coin::deposit(signer::address_of(user), strategy_coins);
    }

    public entry fun withdraw(user: &signer, amount: u64) {
        let strategy_coins = coin::withdraw<StrategyCoin<AptosCoin, MockStrategy>>(user, amount);
        let aptos_coins = liquidate_position(strategy_coins);
        coin::deposit(signer::address_of(user), aptos_coins);
    }

    public fun apply_position(aptos_coins: Coin<AptosCoin>): Coin<StrategyCoin<AptosCoin, MockStrategy>> {
        let aptos_value = coin::value(&aptos_coins);
        satay::strategy_deposit<AptosCoin, MockStrategy, AptosCoin>(aptos_coins, MockStrategy {});
        satay::strategy_mint<AptosCoin, MockStrategy>(aptos_value, MockStrategy {})
    }

    public fun liquidate_position(wrapped_aptos_coins: Coin<StrategyCoin<AptosCoin, MockStrategy>>): Coin<AptosCoin> {
        let wrapped_aptos_value = coin::value(&wrapped_aptos_coins);
        satay::strategy_burn(wrapped_aptos_coins, MockStrategy {});
        satay::strategy_withdraw<AptosCoin, MockStrategy, AptosCoin>(wrapped_aptos_value, MockStrategy {})
    }

    public fun get_aptos_amount_for_wrapped_amount(wrapped_amount: u64): u64 {
        wrapped_amount
    }

    public fun get_wrapped_amount_for_aptos_amount(aptos_amount: u64): u64 {
        aptos_amount
    }

    public(friend) fun get_strategy_witness(): MockStrategy {
        MockStrategy {}
    }
}

```
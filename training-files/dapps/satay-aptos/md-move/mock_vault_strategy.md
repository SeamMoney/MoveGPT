```rust
#[test_only]
module satay::mock_vault_strategy {

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self};

    use satay_coins::vault_coin::VaultCoin;
    use satay_coins::strategy_coin::StrategyCoin;

    use satay::base_strategy;
    use satay::satay;

    use satay::mock_strategy::{Self, MockStrategy};

    public entry fun approve(governance: &signer, debt_ratio: u64) {
        base_strategy::approve_strategy<AptosCoin, MockStrategy>(
            governance,
            debt_ratio,
            mock_strategy::get_strategy_witness()
        );
    }

    public entry fun harvest(keeper: &signer) {
        let strategy_aptos_balance = get_strategy_aptos_balance();

        let (
            to_apply,
            harvest_lock
        ) = base_strategy::open_vault_for_harvest<AptosCoin, MockStrategy>(
            keeper,
            strategy_aptos_balance,
            mock_strategy::get_strategy_witness()
        );

        let profit_coins = coin::zero<AptosCoin>();
        let debt_payment_coins = coin::zero<AptosCoin>();

        let profit = base_strategy::get_harvest_profit(&harvest_lock);
        let debt_payment = base_strategy::get_harvest_debt_payment(&harvest_lock);

        if(profit > 0 || debt_payment > 0){
            let wrapped_aptos_to_liquidate = mock_strategy::get_wrapped_amount_for_aptos_amount(profit + debt_payment);
            let wrapped_aptos = base_strategy::withdraw_strategy_coin<AptosCoin, MockStrategy>(
                &harvest_lock,
                wrapped_aptos_to_liquidate,
            );
            let aptos_to_return = mock_strategy::liquidate_position(wrapped_aptos);
            coin::merge(&mut profit_coins, coin::extract(&mut aptos_to_return, profit));
            coin::merge(&mut debt_payment_coins, coin::extract(&mut aptos_to_return, debt_payment));
            coin::destroy_zero(aptos_to_return);
        };

        let wrapped_aptos = mock_strategy::apply_position(to_apply);

        base_strategy::close_vault_for_harvest<AptosCoin, MockStrategy>(
            harvest_lock,
            debt_payment_coins,
            profit_coins,
            wrapped_aptos,
        );
    }

    public entry fun withdraw_for_user(user: &signer, share_amount: u64) {
        let vault_coins = coin::withdraw<VaultCoin<AptosCoin>>(user, share_amount);
        let user_withdraw_lock = base_strategy::open_vault_for_user_withdraw<AptosCoin, MockStrategy>(
            user,
            vault_coins,
            mock_strategy::get_strategy_witness()
        );

        let amount_needed = base_strategy::get_user_withdraw_amount_needed(&user_withdraw_lock);

        let to_return = coin::zero<AptosCoin>();
        if(amount_needed > 0){
            let wrapped_aptos_to_withdraw = mock_strategy::get_wrapped_amount_for_aptos_amount(amount_needed);
            let wrapped_aptos = base_strategy::withdraw_strategy_coin_for_liquidation<AptosCoin, MockStrategy>(
                &user_withdraw_lock,
                wrapped_aptos_to_withdraw,
            );
            let aptos_to_return = mock_strategy::liquidate_position(wrapped_aptos);
            coin::merge(&mut to_return, aptos_to_return);
        };

        base_strategy::close_vault_for_user_withdraw<AptosCoin, MockStrategy>(
            user_withdraw_lock,
            to_return,
        );
    }

    public entry fun update_debt_ratio(vault_manager: &signer, debt_ratio: u64) {
        base_strategy::update_debt_ratio<AptosCoin, MockStrategy>(
            vault_manager,
            debt_ratio,
            mock_strategy::get_strategy_witness()
        );
    }

    public entry fun revoke(vault_manager: &signer) {
        base_strategy::revoke_strategy<AptosCoin, MockStrategy>(
            vault_manager,
            mock_strategy::get_strategy_witness()
        );
        harvest(vault_manager);
    }

    fun get_strategy_aptos_balance(): u64 {
        let wrapped_balance = satay::get_vault_balance<AptosCoin, StrategyCoin<AptosCoin, MockStrategy>>();
        mock_strategy::get_aptos_amount_for_wrapped_amount(wrapped_balance)
    }
}
```
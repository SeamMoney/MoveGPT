/// liquidator_aux wraps user Argo engine_v1 functions for EOA usage.
module liquidator_aux::liquidator_aux {
    use aptos_framework::coin;
    use argo_engine::engine_v1;
    use std::signer::{address_of};
    use usda::usda::{USDA};

    /// Liquidate a Vault using Aux
    public entry fun aux_liquidate<NamespaceType, CoinType>(
        liquidator: &signer,
        owner_addr: address,
        liquidate_amount: u64,
    ) {
        // Seize the collateral
        let (seized, iou) = engine_v1::liquidate_withdraw<NamespaceType, CoinType>(
            owner_addr,
            liquidate_amount,
        );

        // Calculate the minimum USDA needed to repay
        let liquidator_addr = address_of(liquidator);
        let required_repay_amount = engine_v1::required_repay_amount<NamespaceType, CoinType>(
            liquidator_addr,
            owner_addr,
            liquidate_amount,
        );

        // Swap all the seized collateral for USDA
        let seize_amount = coin::value(&seized);
        let (to_repay, coin_in) = aux::router::swap_exact_coin_for_coin<CoinType, USDA>(
            liquidator_addr,
            seized,
            coin::zero(),
            seize_amount,
            required_repay_amount,
        );

        // Repay USDA
        let remaining = engine_v1::liquidate_repay<NamespaceType, CoinType>(
            liquidator,
            to_repay,
            iou,
        );

        // Deposit remaining tokens
        if (!coin::is_account_registered<USDA>(liquidator_addr)) {
            coin::register<USDA>(liquidator);
        };
        if (!coin::is_account_registered<CoinType>(liquidator_addr)) {
            coin::register<CoinType>(liquidator);
        };
        coin::deposit(liquidator_addr, remaining);
        coin::deposit(liquidator_addr, coin_in);
    }
}
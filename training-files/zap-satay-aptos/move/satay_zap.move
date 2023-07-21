module satay_zap::satay_zap {

    use std::signer;

    use aptos_framework::coin::{Self, Coin};

    use satay::satay;
    use satay::vault::{VaultCoin};

    use liquidswap::router_v2;

    const ERR_POOL_DOESNT_EXIST: u64 = 1;

    public entry fun deposit<DepositCoin, BaseCoin, Curve>(user: &signer, vault_id: u64, amount: u64) {
        let deposit_coins = coin::withdraw<DepositCoin>(user, amount);
        let vault_coins = zap_deposit<DepositCoin, BaseCoin, Curve>(
            user,
            vault_id,
            deposit_coins
        );
        let user_addr = signer::address_of(user);
        if(!coin::is_account_registered<VaultCoin<BaseCoin>>(user_addr)){
            coin::register<VaultCoin<BaseCoin>>(user);
        };
        coin::deposit(user_addr, vault_coins);
    }

    public entry fun withdraw<BaseCoin, ResultCoin, Curve>(user: &signer, vault_id: u64, amount: u64) {

        let vault_coins = coin::withdraw<VaultCoin<BaseCoin>>(user, amount);

        let result_coins = zap_withdraw<BaseCoin, ResultCoin, Curve>(
            user,
            vault_id,
            vault_coins
        );

        let user_addr = signer::address_of(user);
        if(!coin::is_account_registered<ResultCoin>(user_addr)){
            coin::register<ResultCoin>(user);
        };
        coin::deposit(signer::address_of(user), result_coins);
    }


    public fun zap_deposit<DepositCoin, BaseCoin, Curve>(
        user: &signer,
        vault_id: u64,
        deposit_coins: Coin<DepositCoin>
    ): Coin<VaultCoin<BaseCoin>> {
        assert!(router_v2::is_swap_exists<DepositCoin, BaseCoin, Curve>(), ERR_POOL_DOESNT_EXIST);
        let base_coins = router_v2::swap_exact_coin_for_coin<DepositCoin, BaseCoin, Curve>(
            deposit_coins,
            0
        );
        satay::deposit_as_user(user, vault_id, base_coins)
    }

    public fun zap_withdraw<BaseCoin, ResultCoin, Curve>(
        user: &signer,
        vault_id: u64,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): Coin<ResultCoin> {
        assert!(router_v2::is_swap_exists<BaseCoin, ResultCoin, Curve>(), ERR_POOL_DOESNT_EXIST);
        let base_coins = satay::withdraw_as_user(user, vault_id, vault_coins);
        router_v2::swap_exact_coin_for_coin<BaseCoin, ResultCoin, Curve>(
            base_coins,
            0
        )
    }
}

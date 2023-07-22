/// facilitates interaction between vaults and structured products
module satay::base_strategy {

    use aptos_framework::coin::{Coin};

    use satay_coins::vault_coin::VaultCoin;
    use satay_coins::strategy_coin::StrategyCoin;

    use satay::vault::{Self, UserCapability, KeeperCapability, UserLiquidationLock, HarvestInfo};
    use satay::satay;

    // operation locks

    /// created and destroyed during user withdraw
    /// * user_liq_lock: UserLiquidationLock<BaseCoin> - holds VaultCoin<BaseCoin> to liquidate and amount needed
    /// * user_cap: UserCapability<BaseCoin> - holds the VaultCapability and user address
    /// * witness: StrategyType - an instance of StrategyType to prove the source of the call
    struct UserWithdrawLock<phantom BaseCoin, StrategyType: drop> {
        user_liq_lock: UserLiquidationLock<BaseCoin>,
        user_cap: UserCapability<BaseCoin>,
        witness: StrategyType
    }

    /// created and destroyed during harvest
    /// * harvest_info: HarvestInfo - holds the vault_id, profit, and debt_payment amounts
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - holds the VaultCapability and witness for vault operations
    struct HarvestLock<phantom BaseCoin, StrategyType: drop> {
        harvest_info: HarvestInfo,
        keeper_cap: KeeperCapability<BaseCoin, StrategyType>
    }

    // vault manager functions

    /// calls approve_strategy for StrategyType on Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault manager role for Vault<BaseCoin>
    /// * debt_ratio: u64 - in BPS
    /// * witness: StrategyType - witness pattern
    public fun approve_strategy<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: StrategyType
    ) {
        satay::approve_strategy<BaseCoin, StrategyType>(vault_manager, debt_ratio, &witness);
    }

    /// updates the debt ratio for StrategyType on Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault manager role for Vault<BaseCoin>
    /// * debt_ratio: u64 - in BPS
    /// * witness: StrategyType - witness pattern
    public fun update_debt_ratio<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: StrategyType
    ) {
        satay::update_strategy_debt_ratio<BaseCoin, StrategyType>(vault_manager, debt_ratio, &witness);
    }

    /// sets the debt ratio for StrategyType to 0 on Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault manager role for Vault<BaseCoin>
    /// * witness: StrategyType - witness pattern
    public fun revoke_strategy<BaseCoin, StrategyType: drop>(vault_manager: &signer, witness: StrategyType) {
        update_debt_ratio<BaseCoin, StrategyType>(vault_manager, 0, witness);
    }

    // deposit and withdraw

    /// withdraws StrategyCoin<BaseCoin, StrategyType> from Vault<BaseCoin> during harvest
    /// * harvest_lock: &HarvestLock<BaseCoin, StrategyType> - holds the KeeeperCapability<BaseCoin, StrategyType>
    /// * amount: u64 - the amount of StrategyCoin to withdraw from the vault
    public fun withdraw_strategy_coin<BaseCoin, StrategyType: drop>(
        harvest_lock: &HarvestLock<BaseCoin, StrategyType>,
        amount: u64,
    ): Coin<StrategyCoin<BaseCoin, StrategyType>> {
        vault::withdraw_strategy_coin<BaseCoin, StrategyType>(&harvest_lock.keeper_cap, amount)
    }

    /// withdraws StrategyCoin<BaseCoin, StrategyType> from Vault<BaseCoin> during user liquidation
    /// * user_withdraw_lock: &UserWithdrawLock<BaseCoin, StrategyType> - holds the UserCapability<BaseCoin>
    /// * amount: u64 - the amount of StrategyCoin to withdraw from the vault
    public fun withdraw_strategy_coin_for_liquidation<BaseCoin, StrategyType: drop>(
        user_withdraw_lock: &UserWithdrawLock<BaseCoin, StrategyType>,
        amount: u64,
    ): Coin<StrategyCoin<BaseCoin, StrategyType>> {
        vault::withdraw_strategy_coin_for_liquidation<BaseCoin, StrategyType>(
            &user_withdraw_lock.user_cap,
            amount,
            &user_withdraw_lock.witness,
        )
    }

    // for harvest

    /// returns Coin<BaseCoin> to deploy to strategy and HarvestLock with return information, called by keeper
    /// * keeper: &signer - must have the keeper role for StrategyType on Vault<BaseCoin>
    /// * strategy_balance: u64 - the amount of BaseCoin in the strategy
    /// * witness: StrategyType - witness pattern
    public fun open_vault_for_harvest<BaseCoin, StrategyType: drop>(
        keeper: &signer,
        strategy_balance: u64,
        witness: StrategyType,
    ) : (Coin<BaseCoin>, HarvestLock<BaseCoin, StrategyType>) {
        let keeper_cap = satay::keeper_lock_vault<BaseCoin, StrategyType>(
            keeper,
            witness
        );
        let (to_apply, harvest_info) = vault::process_harvest<BaseCoin, StrategyType>(
            &keeper_cap,
            strategy_balance
        );
        (to_apply, HarvestLock {
            harvest_info,
            keeper_cap
        })
    }

    /// deposits the BaseCoin debt payment and profit, StrategyCoin into Vault<BaseCoin> and destroys the HarvestLock
    /// * harvest_lock: HarvestLock<BaseCoin, StrategyType> - holds return conditions for debt_payment and profit
    /// * debt_payment: Coin<BaseCoin>
    /// * profit: Coin<BaseCoin>
    /// * strategy_coins: Coin<StrategyCoin<BaseCoin, StrategyType>> - result of applying the strategy
    public fun close_vault_for_harvest<BaseCoin, StrategyType: drop>(
        harvest_lock: HarvestLock<BaseCoin, StrategyType>,
        debt_payment: Coin<BaseCoin>,
        profit: Coin<BaseCoin>,
        strategy_coins: Coin<StrategyCoin<BaseCoin, StrategyType>>
    ) {
        let HarvestLock<BaseCoin, StrategyType> {
            harvest_info,
            keeper_cap
        } = harvest_lock;
        vault::deposit_strategy_coin<BaseCoin, StrategyType>(&keeper_cap, strategy_coins);
        vault::destroy_harvest_info<BaseCoin, StrategyType>(&keeper_cap, harvest_info, debt_payment, profit);
        satay::keeper_unlock_vault<BaseCoin, StrategyType>(keeper_cap);
    }

    // for user withdraw

    /// called when vault does not have sufficient liquidity to fulfill user withdraw of vault_coins
    /// * user: &signer
    /// * vault_coins: Coin<VaultCoin<BaseCoin>> - to liquidate
    /// * witness: StrategyType - witness pattern
    public fun open_vault_for_user_withdraw<BaseCoin, StrategyType: drop>(
        user: &signer,
        vault_coins: Coin<VaultCoin<BaseCoin>>,
        witness: StrategyType
    ): UserWithdrawLock<BaseCoin, StrategyType> {
        let user_cap = satay::user_lock_vault<BaseCoin>(user);
        let user_liq_lock = vault::get_liquidation_lock<BaseCoin, StrategyType>(
            &user_cap,
            vault_coins
        );
        UserWithdrawLock<BaseCoin, StrategyType> {
            user_liq_lock,
            witness,
            user_cap
        }
    }

    /// destroys UserWithrdawLock by liquidating vault_coins and sending base_coins to user
    /// * user_withdraw_lock: UserWithdrawLock<BaseCoin, StrategyType> - holds the VaultCoin<BaseCoin> to liquidate
    /// * base_coins: Coin<BaseCoin> - debt payment to allow liquidation
    public fun close_vault_for_user_withdraw<BaseCoin, StrategyType: drop>(
        user_withdraw_lock: UserWithdrawLock<BaseCoin, StrategyType>,
        base_coins: Coin<BaseCoin>,
    ) {
        let UserWithdrawLock<BaseCoin, StrategyType> {
            user_liq_lock,
            witness,
            user_cap
        } = user_withdraw_lock;
        vault::user_liquidation(&user_cap, base_coins, user_liq_lock, &witness);
        satay::user_unlock_vault<BaseCoin>(user_cap);
    }

    // getters

    /// returns the amount of profit to return to the vault during harvest
    /// * harvest_lock: &HarvestLock<BaseCoin, StrategyType>
    public fun get_harvest_profit<BaseCoin, StrategyType: drop>(
        harvest_lock: &HarvestLock<BaseCoin, StrategyType>
    ): u64 {
        vault::get_harvest_profit(&harvest_lock.harvest_info)
    }

    /// returns the amount of debt to pay back to the vault during harvest
    /// * harvest_lock: &HarvestLock<BaseCoin, StrategyType>
    public fun get_harvest_debt_payment<BaseCoin, StrategyType: drop>(
        harvest_lock: &HarvestLock<BaseCoin, StrategyType>
    ): u64 {
        vault::get_harvest_debt_payment(&harvest_lock.harvest_info)
    }

    /// returns the amount of debt to pay back to the vault during user withdraw
    /// * user_withdraw_lock: &UserWithdrawLock<BaseCoin, StrategyType>
    public fun get_user_withdraw_amount_needed<BaseCoin, StrategyType: drop>(
        user_withdraw_lock: &UserWithdrawLock<BaseCoin, StrategyType>
    ): u64 {
        vault::get_liquidation_amount_needed(&user_withdraw_lock.user_liq_lock)
    }

    #[test_only]
    public fun deposit_strategy_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        strategy_coins: Coin<StrategyCoin<BaseCoin, StrategyType>>,
    ) {
        vault::deposit_strategy_coin<BaseCoin, StrategyType>(keeper_cap, strategy_coins);
    }

    #[test_only]
    public fun test_withdraw_base_coin<BaseCoin, StrategyType: drop>(
        harvest_lock: &HarvestLock<BaseCoin, StrategyType>,
        amount: u64,
    ): Coin<BaseCoin> {
        vault::test_keeper_withdraw_base_coin<BaseCoin, StrategyType>(&harvest_lock.keeper_cap, amount)
    }
}
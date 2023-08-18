```rust
/// user and strategy entry point to vault operations
/// holds all VaultCapability resources in a table
module satay::satay {

    use std::option::{Self, Option};
    use std::signer;

    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::account::{Self, SignerCapability};

    use satay_coins::vault_coin::{VaultCoin};
    use satay_coins::strategy_coin::{StrategyCoin};

    use satay::global_config;
    use satay::vault_config;
    use satay::strategy_config;
    use satay::keeper_config;

    use satay::vault::{Self, VaultCapability, KeeperCapability, UserCapability, VaultManagerCapability};
    use satay::satay_account;
    use satay::strategy_coin;
    use satay::strategy_coin::StrategyCapability;

    friend satay::base_strategy;

    // error codes

    /// when StrategyType is not approved for a vault
    const ERR_STRATEGY: u64 = 1;

    // structs

    /// holds the SignerCapability for the deployer of the SatayCoins package
    /// * signer_cap: SignerCapability - needed to create new vaults and strategies
    struct SatayAccount has key {
        signer_cap: SignerCapability
    }

    /// holds the VaultCapability for Vault<BaseCoin>
    /// * vault_cap: Option<VaultCapability<BaseCoin>> - allows lending of vault_cap
    struct VaultInfo<phantom BaseCoin> has key {
        vault_cap: Option<VaultCapability<BaseCoin>>,
    }

    /// holds the StrategyCapability for Strategy<BaseCoin, StrategyType>
    /// * strategy_cap: Option<StrategyCapability<BaseCoin, StrategyType>> - allows lending of strategy_cap
    struct StrategyInfo<phantom BaseCoin, phantom StrategyType: drop> has key {
        strategy_cap: Option<StrategyCapability<BaseCoin, StrategyType>>
    }

    // deployer functions

    /// initialize the satay package
    /// * satay: &signer - must be the deployer of the Satay package
    public entry fun initialize(satay: &signer) {
        global_config::initialize(satay);
        let signer_cap = satay_account::retrieve_signer_cap(satay);
        move_to(satay, SatayAccount {
            signer_cap
        });
    }

    // governance functions

    /// create Vault<BaseCoin> and store VaultCapability in SatayAccount
    /// * governance: &signer - must have the governance role
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    public entry fun new_vault<BaseCoin>(governance: &signer, management_fee: u64, performance_fee: u64)
    acquires SatayAccount {
        global_config::assert_governance(governance);

        let satay_account = borrow_global<SatayAccount>(@satay);
        let satay_account_signer = account::create_signer_with_capability(&satay_account.signer_cap);

        // create vault and add to manager vaults table
        let vault_cap = vault::new<BaseCoin>(
            &satay_account_signer,
            management_fee,
            performance_fee
        );

        move_to(&satay_account_signer, VaultInfo<BaseCoin> {
            vault_cap: option::some(vault_cap)
        });
    }

    /// create StrategyCoin<BaseCoin, StrategyType> and store StrategyCapability in SatayAccount
    /// * governance: &signer - must have the governance role
    /// * witness: StrategyType - witness pattern
    public fun new_strategy<BaseCoin, StrategyType: drop>(governance: &signer, witness: StrategyType)
    acquires SatayAccount {
        global_config::assert_governance(governance);
        let satay_account = borrow_global<SatayAccount>(@satay);
        let satay_account_signer = account::create_signer_with_capability(&satay_account.signer_cap);
        let strategy_cap = strategy_coin::initialize<BaseCoin, StrategyType>(
            &satay_account_signer,
            signer::address_of(governance),
            witness
        );
        move_to(&satay_account_signer, StrategyInfo<BaseCoin, StrategyType> {
            strategy_cap: option::some(strategy_cap)
        });
    }

    // vault manager fucntions

    /// updates the management and performance fee for Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault_manager role for Vault<BaseCoin>
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    public entry fun update_vault_fee<BaseCoin>(vault_manager: &signer, management_fee: u64, performance_fee: u64)
    acquires SatayAccount, VaultInfo {
        let vault_manager_cap = vault_manager_lock_vault<BaseCoin>(vault_manager);
        vault::update_fee(&vault_manager_cap, management_fee, performance_fee);
        vault_manager_unlock_vault<BaseCoin>(vault_manager_cap);
    }

    /// freezes user deposits to Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault_manager role for Vault<BaseCoin>
    public entry fun freeze_vault<BaseCoin>(vault_manager: &signer)
    acquires SatayAccount, VaultInfo {
        let vault_manager_cap = vault_manager_lock_vault<BaseCoin>(vault_manager);
        vault::freeze_vault(&vault_manager_cap);
        vault_manager_unlock_vault<BaseCoin>(vault_manager_cap);
    }

    /// unfreezes user deposits to Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault_manager role for Vault<BaseCoin>
    public entry fun unfreeze_vault<BaseCoin>(vault_manager: &signer)
    acquires SatayAccount, VaultInfo {
        let vault_manager_cap = vault_manager_lock_vault<BaseCoin>(vault_manager);
        vault::unfreeze_vault(&vault_manager_cap);
        vault_manager_unlock_vault<BaseCoin>(vault_manager_cap);
    }

    /// allows StrategyType to withdraw BaseCoin from and deposit StrategyCoin<BaseCoin, StrategyType> to Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault_manager role for Vault<BaseCoin>
    /// * debt_ratio: u64 - the percentage of vault's total assets available to StrategyType in BPS
    /// * witness: &StrategyType - witness pattern
    public(friend) fun approve_strategy<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: &StrategyType
    )
    acquires SatayAccount, VaultInfo {
        let vault_manager_cap = vault_manager_lock_vault<BaseCoin>(vault_manager);
        vault::approve_strategy<BaseCoin, StrategyType>(&vault_manager_cap, debt_ratio, witness);
        vault_manager_unlock_vault<BaseCoin>(vault_manager_cap);
    }

    /// update the debt_ratio for StrategyType on Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault_manager role for Vault<BaseCoin>
    /// * debt_ratio: u64 - the percentage of vault's total assets available to StrategyType in BPS
    /// * witness: &StrategyType - witness pattern
    public(friend) fun update_strategy_debt_ratio<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: &StrategyType
    )
    acquires SatayAccount, VaultInfo {
        let vault_manager_cap = vault_manager_lock_vault<BaseCoin>(vault_manager);
        vault::update_strategy_debt_ratio<BaseCoin, StrategyType>(
            &vault_manager_cap,
            debt_ratio,
            witness
        );
        vault_manager_unlock_vault<BaseCoin>(vault_manager_cap);
    }

    // user functions

    /// deposit Coin<BaseCoin> into Vault<BaseCoin> and mint Coin<VaultCoin<BaseCoin>> to user
    /// * user: &signer
    /// * amount: u64 - amount of BaseCoin to deposit
    public entry fun deposit<BaseCoin>(user: &signer, amount: u64)
    acquires SatayAccount, VaultInfo {
        let base_coins = coin::withdraw<BaseCoin>(user, amount);
        let vault_coins = deposit_as_user(user, base_coins);
        let user_addr = signer::address_of(user);
        if(!coin::is_account_registered<VaultCoin<BaseCoin>>(user_addr)){
            coin::register<VaultCoin<BaseCoin>>(user);
        };
        coin::deposit(user_addr, vault_coins);
    }

    /// converts Coin<BaseCoin> into Coin<VaultCoin<BaseCoin>> by depositing into Vault<BaseCoin>
    /// * user: &signer
    /// * base_coins: Coin<BaseCoin>
    public fun deposit_as_user<BaseCoin>(
        user: &signer,
        base_coins: Coin<BaseCoin>
    ): Coin<VaultCoin<BaseCoin>>
    acquires SatayAccount, VaultInfo {
        let user_cap = user_lock_vault<BaseCoin>(user);
        let vault_coins = vault::deposit_as_user(&user_cap, base_coins);
        user_unlock_vault<BaseCoin>(user_cap);
        vault_coins
    }

    /// burn Coin<VaultCoin<BaseCoin>> from user and withdraw Coin<BaseCoin> from Vault<BaseCoin>
    /// * user: &signer
    /// * amount: u64 - amount of VaultCoin<BaseCoin> to withdraw
    public entry fun withdraw<BaseCoin>(user: &signer, amount: u64)
    acquires SatayAccount, VaultInfo {
        let vault_coins = coin::withdraw<VaultCoin<BaseCoin>>(user, amount);
        let base_coins = withdraw_as_user(user, vault_coins);
        let user_addr = signer::address_of(user);
        if(!coin::is_account_registered<BaseCoin>(user_addr)){
            coin::register<BaseCoin>(user);
        };
        coin::deposit(user_addr, base_coins);
    }

    /// converts Coin<VaultCoin<BaseCoin>> into Coin<BaseCoin> by withdrawing from Vault<BaseCoin>
    /// * user: &signer
    /// * vault_coins: Coin<VaultCoin<BaseCoin>>
    public fun withdraw_as_user<BaseCoin>(
        user: &signer,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): Coin<BaseCoin>
    acquires SatayAccount, VaultInfo {
        let user_cap = user_lock_vault<BaseCoin>(user);
        let base_coins = vault::withdraw_as_user<BaseCoin>(&user_cap, vault_coins);
        user_unlock_vault<BaseCoin>(user_cap);
        base_coins
    }

    // strategy coin functions

    /// mint amount of StrategyCoin<BaseCoin, StrategyType>
    /// @param amount: u64 - amount of StrategyCoin<BaseCoin, StrategyType> to mint
    /// @param _witness: StrategyType - witness pattern
    public fun strategy_mint<BaseCoin, StrategyType: drop>(
        amount: u64,
        _witness: StrategyType
    ): Coin<StrategyCoin<BaseCoin, StrategyType>>
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        let strategy_info = borrow_global<StrategyInfo<BaseCoin, StrategyType>>(
            satay_account_address
        );
        strategy_coin::mint(option::borrow(&strategy_info.strategy_cap), amount)
    }

    /// burn StrategyCoin<BaseCoin, StrategyType>
    /// @param strategy_coins: Coin<StrategyCoin<BaseCoin, StrategyType>>
    /// @param _witness: StrategyType - witness pattern
    public fun strategy_burn<BaseCoin, StrategyType: drop>(
        strategy_coins: Coin<StrategyCoin<BaseCoin, StrategyType>>,
        _witness: StrategyType
    ) acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        let strategy_info = borrow_global<StrategyInfo<BaseCoin, StrategyType>>(
            satay_account_address
        );
        strategy_coin::burn(option::borrow(&strategy_info.strategy_cap), strategy_coins);
    }

    /// create CoinStore<CoinType> for StrategyType on strategy resource account
    /// * _witness: StrategyType - witness pattern
    public fun strategy_add_coin<BaseCoin, StrategyType: drop, CoinType>(_witness: StrategyType)
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        let strategy_info = borrow_global<StrategyInfo<BaseCoin, StrategyType>>(
            satay_account_address
        );
        strategy_coin::add_coin<BaseCoin, StrategyType, CoinType>(option::borrow(&strategy_info.strategy_cap));
    }

    /// deposit CoinType into the strategy account
    /// @param coins: Coin<CoinType>
    /// @param _witness: StrategyType - witness pattern
    public fun strategy_deposit<BaseCoin, StrategyType: drop, CoinType>(coins: Coin<CoinType>, _witness: StrategyType)
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        let strategy_info = borrow_global<StrategyInfo<BaseCoin, StrategyType>>(
            satay_account_address
        );
        strategy_coin::deposit<BaseCoin, StrategyType, CoinType>(option::borrow(&strategy_info.strategy_cap), coins);
    }

    /// withdraw CoinType from the strategy account
    /// @param amount: u64 - amount of CoinType to withdraw
    /// @param _witness: StrategyType - witness pattern
    public fun strategy_withdraw<BaseCoin, StrategyType: drop, CoinType>(
        amount: u64,
        _witness: StrategyType
    ): Coin<CoinType> acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        let strategy_info = borrow_global<StrategyInfo<BaseCoin, StrategyType>>(
            satay_account_address
        );
        strategy_coin::withdraw<BaseCoin, StrategyType, CoinType>(option::borrow(&strategy_info.strategy_cap), amount)
    }

    /// gets the signer for the strategy account
    public fun strategy_signer<BaseCoin, StrategyType: drop>(_witness: StrategyType): signer
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        strategy_coin::strategy_account_signer(
            option::borrow(&borrow_global<StrategyInfo<BaseCoin, StrategyType>>(satay_account_address).strategy_cap)
        )
    }

    // lock/unlock

    /// get the VaultCapability for Vault<BaseCoin>
    fun lock_vault<BaseCoin>(): VaultCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        let vault_info = borrow_global_mut<VaultInfo<BaseCoin>>(satay_account_address);
        option::extract(&mut vault_info.vault_cap)
    }

    /// return the VaultCapability for Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    fun unlock_vault<BaseCoin>(vault_cap: VaultCapability<BaseCoin>)
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        let vault_info = borrow_global_mut<VaultInfo<BaseCoin>>(satay_account_address);
        option::fill(&mut vault_info.vault_cap, vault_cap);
    }

    /// get the VaultCapability for Vault<BaseCoin> and assert that (BaseCoin, StrategyType) is approved
    /// * _witness: StrategyType - witness pattern
    fun strategy_lock_vault<BaseCoin, StrategyType: drop>(_witness: &StrategyType): VaultCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        let vault_cap = lock_vault<BaseCoin>();
        assert_strategy_approved<BaseCoin, StrategyType>(&vault_cap);
        vault_cap
    }

    /// return the VaultCapability for Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    fun strategy_unlock_vault<BaseCoin, StrategyType: drop>(vault_cap: VaultCapability<BaseCoin>)
    acquires SatayAccount, VaultInfo {
        unlock_vault(vault_cap);
    }

    /// get the VaultManagerCapability for Vault<BaseCoin>
    /// * vault_manager: &signer - must have the vault manager role for Vault<BaseCoin>
    fun vault_manager_lock_vault<BaseCoin>(vault_manager: &signer): VaultManagerCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        let vault_cap = lock_vault<BaseCoin>();
        vault::get_vault_manager_capability(vault_manager, vault_cap)
    }

    /// return the VaultManagerCapability for Vault<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin>
    fun vault_manager_unlock_vault<BaseCoin>(vault_manager_cap: VaultManagerCapability<BaseCoin>)
    acquires SatayAccount, VaultInfo {
        let vault_cap = vault::destroy_vault_manager_capability(vault_manager_cap);
        unlock_vault(vault_cap);
    }

    /// get the KeeperCapability for Vault<BaseCoin>, StrategyType must be approved
    /// * keeper: &signer - must have the keeper role for StrategyType on Vault<BaseCoin>
    /// * witness: StrategyType - witness pattern
    public(friend) fun keeper_lock_vault<BaseCoin, StrategyType: drop>(
        keeper: &signer,
        witness: StrategyType
    ): KeeperCapability<BaseCoin, StrategyType>
    acquires SatayAccount, VaultInfo {
        let vault_cap = strategy_lock_vault<BaseCoin, StrategyType>(&witness);
        vault::get_keeper_capability<BaseCoin, StrategyType>(keeper, vault_cap, witness)
    }

    /// destroy the KeeperCapability, vault_cap and stop_handle must match
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType>
    public(friend) fun keeper_unlock_vault<BaseCoin, StrategyType: drop>(
        keeper_cap: KeeperCapability<BaseCoin, StrategyType>,
    ) acquires SatayAccount, VaultInfo {
        let vault_cap = vault::destroy_keeper_capability(keeper_cap);
        strategy_unlock_vault<BaseCoin, StrategyType>(vault_cap);
    }

    /// get the UserCapability of vault_id for use by StrategyType, StrategyType must be approved first
    /// * user: &signer
    public(friend) fun user_lock_vault<BaseCoin>(user: &signer) : UserCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        let vault_cap = lock_vault<BaseCoin>();
        vault::get_user_capability(user, vault_cap)
    }

    /// destroy the UserCapability, vault_cap and stop_handle must match
    /// * user_cap: UserCapability<BaseCoin>
    public(friend) fun user_unlock_vault<BaseCoin>(
        user_cap: UserCapability<BaseCoin>,
    ) acquires SatayAccount, VaultInfo {
        let (vault_cap, _) = vault::destroy_user_capability(user_cap);
        unlock_vault<BaseCoin>(vault_cap);
    }

    // getter functions

    // satay account

    #[view]
    /// gets the address of the satay account
    public fun get_satay_account_address(): address acquires SatayAccount {
        let satay_account = borrow_global<SatayAccount>(@satay);
        account::get_signer_capability_address(&satay_account.signer_cap)
    }
    
    // vault fields

    #[view]
    /// returns the address of Vault<BaseCoin>
    public fun get_vault_address<BaseCoin>(): address
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::get_vault_address(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the management fee and performance fee for Vault<BaseCoin>
    public fun get_vault_fees<BaseCoin>(): (u64, u64)
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::get_fees(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    
    #[view]
    /// returns whether depoosts are frozen for Vault<BaseCoin>
    public fun is_vault_frozen<BaseCoin>(): bool
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::is_vault_frozen(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the total debt ratio for Vault<BaseCoin>
    public fun get_vault_debt_ratio<BaseCoin>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::get_debt_ratio(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the total debt of Vault<BaseCoin>
    public fun get_total_debt<BaseCoin>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::get_total_debt(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the total balance of CoinType in Vault<BaseCoin>
    public fun get_vault_balance<BaseCoin, CoinType>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::balance<BaseCoin, CoinType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the total assets of Vault<BaseCoin>
    public fun get_total_assets<BaseCoin>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::total_assets(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the address of the vault manager for Vault<BaseCoin>
    /// REMOVE IN NEXT DEPLOYMENT
    public fun get_vault_manager<BaseCoin>(): address
    acquires SatayAccount, VaultInfo {
        vault_config::get_vault_manager_address(get_vault_address<BaseCoin>())
    }

    #[view]
    /// returns the address of the vault manager for Vault<BaseCoin>
    public fun get_vault_manager_address<BaseCoin>(): address
    acquires SatayAccount, VaultInfo {
        vault_config::get_vault_manager_address(get_vault_address<BaseCoin>())
    }

    // strategy fields

    
    #[view]
    /// returns whether Vault<BaseCoin> has StrategyType approved
    public fun has_strategy<BaseCoin, StrategyType: drop>(): bool
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::has_strategy<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the address of the strategy resource account
    public fun get_strategy_address<BaseCoin, StrategyType: drop>(): address
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        strategy_coin::strategy_account_address(
            option::borrow(&borrow_global<StrategyInfo<BaseCoin, StrategyType>>(satay_account_address).strategy_cap)
        )
    }

    #[view]
    /// returns the CoinType balance of the strategy resource account
    public fun get_strategy_balance<BaseCoin, StrategyType: drop, CoinType>(): u64
    acquires SatayAccount, StrategyInfo {
        let satay_account_address = get_satay_account_address();
        strategy_coin::balance<BaseCoin, StrategyType, CoinType>(
            option::borrow(&borrow_global<StrategyInfo<BaseCoin, StrategyType>>(satay_account_address).strategy_cap)
        )
    }

    #[view]
    /// returns total debt for StrategyType on Vault<BaseCoin>
    public fun get_strategy_total_debt<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::total_debt<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the debt ratio for StrategyType for Vault<BaseCoin>
    public fun get_strategy_debt_ratio<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::debt_ratio<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the credit availale for StrategyType for Vault<BaseCoin>
    public fun get_credit_available<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::credit_available<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the outstanding debt for StrategyType for Vault<BaseCoin>
    public fun get_debt_out_standing<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::debt_out_standing<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// returns the timestamp of the last harvest for StrategyType for Vault<BaseCoin>
    public fun get_last_report<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::last_report<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// get the total gain for StrategyType for Vault<BaseCoin>
    public fun get_total_gain<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::total_gain<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    #[view]
    /// get the total loss for StrategyType for Vault<BaseCoin>
    public fun get_total_loss<BaseCoin, StrategyType: drop>(): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::total_loss<BaseCoin, StrategyType>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap)
        )
    }

    // user calculations

    #[view]
    /// returns the amount of VaultCoin minted for an amount of BaseCoin deposited to Vault<BaseCoin>
    /// * base_coin_amount: u64 - the amount of BaseCoin to deposit
    public fun get_vault_coin_amount<BaseCoin>(base_coin_amount: u64): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::calculate_vault_coin_amount_from_base_coin_amount<BaseCoin>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap),
            base_coin_amount
        )
    }
    
    #[view]
    /// returns the amount of BaseCoin returned from Vault<BaseCoin> by burining an amount of VaultCoin<BaseCoin>
    /// * vault_coin_amount: u64 - the amount of VaultCoin to burn
    public fun get_base_coin_amount<BaseCoin>(vault_coin_amount: u64): u64
    acquires SatayAccount, VaultInfo {
        let satay_account_address = get_satay_account_address();
        vault::calculate_base_coin_amount_from_vault_coin_amount<BaseCoin>(
            option::borrow(&borrow_global<VaultInfo<BaseCoin>>(satay_account_address).vault_cap),
            vault_coin_amount
        )
    }

    #[view]
    /// returns the address of the strategy manager for (BaseCoin, StrategyType)
    public fun get_strategy_manager_address<BaseCoin, StrategyType: drop>(): address
    acquires SatayAccount, StrategyInfo {
        strategy_config::get_strategy_manager_address<BaseCoin, StrategyType>(
            get_strategy_address<BaseCoin, StrategyType>()
        )
    }

    #[view]
    /// returns the address of the keeper for (BaseCoin, StrategyType)
    public fun get_keeper_address<BaseCoin, StrategyType: drop>(): address
    acquires SatayAccount, VaultInfo {
        keeper_config::get_keeper_address<BaseCoin, StrategyType>(get_vault_address<BaseCoin>())
    }

    // assert statements

    /// asserts that StrategyType is approved on Vault<BaseCoin
    /// * vault_cap: &VaultCapability<BaseCoin>
    fun assert_strategy_approved<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>) {
        assert!(vault::has_strategy<BaseCoin, StrategyType>(vault_cap), ERR_STRATEGY);
    }

    // test functions

    #[test_only]
    public fun test_lock_vault<BaseCoin>(): VaultCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        lock_vault<BaseCoin>()
    }

    #[test_only]
    public fun test_unlock_vault<BaseCoin>(vault_cap: VaultCapability<BaseCoin>)
    acquires SatayAccount, VaultInfo {
        unlock_vault<BaseCoin>(vault_cap);
    }

    #[test_only]
    public fun test_strategy_lock_vault<BaseCoin, StrategyType: drop>(witness: &StrategyType): VaultCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        strategy_lock_vault<BaseCoin, StrategyType>(witness)
    }

    #[test_only]
    public fun test_strategy_unlock_vault<BaseCoin, StrategyType: drop>(vault_cap: VaultCapability<BaseCoin>)
    acquires SatayAccount, VaultInfo {
        strategy_unlock_vault<BaseCoin, StrategyType>(vault_cap)
    }

    #[test_only]
    public fun test_keeper_lock_vault<BaseCoin, StrategyType: drop>(
        keeper: &signer,
        witness: StrategyType
    ): KeeperCapability<BaseCoin, StrategyType>
    acquires SatayAccount, VaultInfo {
        keeper_lock_vault<BaseCoin, StrategyType>(keeper, witness)
    }

    #[test_only]
    public fun test_keeper_unlock_vault<BaseCoin, StrategyType: drop>(
        keeper_cap: KeeperCapability<BaseCoin, StrategyType>
    )
    acquires SatayAccount, VaultInfo {
        keeper_unlock_vault<BaseCoin, StrategyType>(keeper_cap);
    }

    #[test_only]
    public fun test_user_lock_vault<BaseCoin>(
        user: &signer,
    ): UserCapability<BaseCoin>
    acquires SatayAccount, VaultInfo {
        user_lock_vault<BaseCoin>(user)
    }

    #[test_only]
    public fun test_user_unlock_vault<BaseCoin>(
        user_cap: UserCapability<BaseCoin>,
    ) acquires SatayAccount, VaultInfo {
        user_unlock_vault<BaseCoin>(user_cap);
    }

    #[test_only]
    public fun test_approve_strategy<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: StrategyType,
    ) acquires SatayAccount, VaultInfo {
        approve_strategy<BaseCoin, StrategyType>(vault_manager, debt_ratio, &witness);
    }

    #[test_only]
    public fun test_update_strategy_debt_ratio<BaseCoin, StrategyType: drop>(
        vault_manager: &signer,
        debt_ratio: u64,
        witness: StrategyType
    ) acquires SatayAccount, VaultInfo {
        update_strategy_debt_ratio<BaseCoin, StrategyType>(vault_manager, debt_ratio, &witness);
    }
}
```
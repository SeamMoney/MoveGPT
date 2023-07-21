/// core logic for vault creation and operations
module satay::vault {
    use std::signer;
    use std::string;
    use std::option;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability, FreezeCapability};
    use aptos_framework::timestamp;
    use aptos_framework::event::{Self, EventHandle};

    use satay_coins::vault_coin::VaultCoin;
    use satay_coins::strategy_coin::StrategyCoin;

    use satay::dao_storage;
    use satay::math;
    use satay::vault_config;
    use satay::keeper_config;
    use aptos_std::type_info;

    friend satay::satay;
    friend satay::base_strategy;

    // constants

    /// maximum debt ratio in BPS
    const MAX_DEBT_RATIO_BPS: u64 = 10000; // 100%
    /// maximum management fee in BPS
    const MAX_MANAGEMENT_FEE: u64 = 5000; // 50%
    /// maximum performance fee in BPS
    const MAX_PERFORMANCE_FEE: u64 = 5000; // 50%
    /// seconds per year
    const SECS_PER_YEAR: u64 = 31556952; // 365.2425 days

    // error codes

    /// when Vault<BaseCoin> has not approved StrategyType
    const ERR_NO_STRATEGY: u64 = 100;

    /// when debt ratio is greater than the maximum allowed
    const ERR_INVALID_DEBT_RATIO: u64 = 101;

    /// when fees are greater than the maximum allowed
    const ERR_INVALID_FEE: u64 = 102;

    /// when StrategyType tries to withdraw more than it is allowed
    const ERR_INSUFFICIENT_CREDIT: u64 = 103;

    /// when a user depoisits to a frozen vault
    const ERR_VAULT_FROZEN: u64 = 104;

    /// when the vault manager tries to unfreeze a frozen vault
    const ERR_VAULT_NOT_FROZEN: u64 = 105;

    /// when a strategy reports a loss greater than its total debt
    const ERR_LOSS: u64 = 106;

    /// when a vault has enough balance to cover a user withdraw
    const ERR_ENOUGH_BALANCE_ON_VAULT: u64 = 107;

    /// when the strategy does not return enough BaseCoin for a user withdraw
    const ERR_INSUFFICIENT_USER_RETURN: u64 = 108;

    /// when strategy does not return expected debt payment
    const ERR_DEBT_PAYMENT: u64 = 109;

    /// when strategy does not return expected profit payment
    const ERR_PROFIT_PAYMENT: u64 = 110;

    /// holds the coins for each CoinType of a vault
    /// coin: Coin<CoinType> - the coin storage
    /// deposit_events: EventHandle<DepositEvent>
    /// withdraw_events: EventHandle<WithdrawEvent>
    struct CoinStore<phantom CoinType> has key {
        coin: Coin<CoinType>,
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    /// holds the information about a vault
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    /// * debt_ratio: u64 - in BPS
    /// * total_debt: u64 - same decimals as BaseCoin
    /// * deposits_frozen: bool
    /// * user_deposit_events: EventHandle<UserDepositEvent>
    /// * update_fees_events: EventHandle<UpdateFeesEvent>
    /// * freeze_events: EventHandle<FreezeEvent>
    struct Vault<phantom BaseCoin> has key {
        management_fee: u64,
        performance_fee: u64,
        debt_ratio: u64,
        total_debt: u64,
        deposits_frozen: bool,
        user_deposit_events: EventHandle<UserDepositEvent>,
        user_withdraw_events: EventHandle<UserWithdrawEvent>,
        update_fees_events: EventHandle<UpdateFeesEvent>,
        freeze_events: EventHandle<FreezeEvent>,
    }

    /// holds the Coin capabilities for each VaultCoin<BaseCoin>; stored on the Vault<BaseCoin> resource account
    /// * mint_cap: MintCapability<VaultCoin<BaseCoin>>
    /// * freeze_cap: FreezeCapability<VaultCoin<BaseCoin>>
    /// * burn_cap: BurnCapability<VaultCoin<BaseCoin>>
    struct VaultCoinCaps<phantom BaseCoin> has key {
        mint_cap: MintCapability<VaultCoin<BaseCoin>>,
        freeze_cap: FreezeCapability<VaultCoin<BaseCoin>>,
        burn_cap: BurnCapability<VaultCoin<BaseCoin>>
    }

    /// holds the information about a strategy approved on a vault
    /// * debt_ratio: u64 - in BPS
    /// * total_debt: u64 - same decimals as BaseCoin
    /// * total_gain: u64 - same decimals as BaseCoin
    /// * total_loss: u64 - same decimals as BaseCoin
    /// * last_report: u64 - timestamp
    /// * debt_ratio_change_events: EventHandle<DebtRatioChangeEvent>
    /// * debt_change_events: EventHandle<DebtChangeEvent>
    /// * gain_events: EventHandle<GainEvent>
    /// * loss_events: EventHandle<LossEvent>
    /// * harvest_events: EventHandle<HarvestEvent>
    /// * assess_fees_events: EventHandle<AssessFeesEvent>
    struct VaultStrategy<phantom StrategyType, phantom BaseCoin> has key, store {
        debt_ratio: u64,
        total_debt: u64,
        total_gain: u64,
        total_loss: u64,
        last_report: u64,
        debt_ratio_change_events: EventHandle<DebtRatioChangeEvent>,
        debt_change_events: EventHandle<DebtChangeEvent>,
        gain_events: EventHandle<GainEvent>,
        loss_events: EventHandle<LossEvent>,
        harvest_events: EventHandle<HarvestEvent>,
        assess_fees_events: EventHandle<AssessFeesEvent>,
    }

    // capabilities

    /// capability to perform vault operations
    /// * signer_cap: SignerCapability - for the Vault<BaseCoin> resource account
    struct VaultCapability<phantom BaseCoin> has store {
        signer_cap: SignerCapability,
    }

    /// capability to perform vault manager operations
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    struct VaultManagerCapability<phantom BaseCoin> {
        vault_cap: VaultCapability<BaseCoin>
    }

    /// capability to perform keeper operations
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    /// * witness: StrategyType - used for witness pattern
    struct KeeperCapability<phantom BaseCoin, StrategyType: drop> {
        vault_cap: VaultCapability<BaseCoin>,
        witness: StrategyType
    }

    /// capability to perform user operations
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    /// * user_addr: address
    struct UserCapability<phantom BaseCoin> {
        vault_cap: VaultCapability<BaseCoin>,
        user_addr: address,
    }

    // strategy operation locks

    /// enforces properties of user liquidation
    /// * vault_coins: Coin<VaultCoin<BaseCoin>> - the vault coins to liquidate
    /// * amount_needed: u64 - the amount of BaseCoin needed to liquidate
    struct UserLiquidationLock<phantom BaseCoin> {
        vault_coins: Coin<VaultCoin<BaseCoin>>,
        amount_needed: u64,
    }

    /// enforces properties of harvest
    /// * profit: u64 - the amount of BaseCoin profit to return
    /// * debt_payment: u64 - the amount of BaseCoin debt payment to return
    struct HarvestInfo {
        profit: u64,
        debt_payment: u64,
    }

    // events

    // coin store events

    /// event emitted when a coin is deposited to a CoinStore
    /// * amount: u64
    struct DepositEvent has drop, store {
        amount: u64,
    }

    /// event emitted when a coin is withdrawn from a CoinStore
    /// * amount: u64
    struct WithdrawEvent has drop, store {
        amount: u64,
    }

    // vault events

    /// event emitted when a user deposits to a vault
    /// * user_addr: address
    /// * base_coin_amount: u64 - the amount of the base coin deposited
    /// * vault_coin_amount: u64 - the amount of the vault coin minted
    struct UserDepositEvent has drop, store {
        user_addr: address,
        base_coin_amount: u64,
        vault_coin_amount: u64,
    }

    /// event emitted when a user withdraws from a vault
    /// * user_addr: address
    /// * base_coin_amount: u64 - the amount of the base coin withdrawn
    /// * vault_coin_amount: u64 - the amount of the vault coin burned
    struct UserWithdrawEvent has drop, store {
        user_addr: address,
        base_coin_amount: u64,
        vault_coin_amount: u64,
    }

    /// event emitted when the fees of a vault are updated
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    struct UpdateFeesEvent has drop, store {
        management_fee: u64,
        performance_fee: u64,
    }

    /// event emitted when the deposits of a vault are frozen or unfrozen
    /// * frozen: bool - true if frozen, false if unfrozen
    struct FreezeEvent has drop, store {
        frozen: bool,
    }

    // vault strategy events

    /// event emitted when the debt ratio of a strategy is changed
    /// * debt_ratio: u64 - in BPS
    struct DebtRatioChangeEvent has drop, store {
        debt_ratio: u64,
    }

    /// event emitted when the debt of a strategy is changed
    /// * debt_payment: u64 - the amount of debt paid
    /// * credit: u64 - the amount of debt added
    struct DebtChangeEvent has drop, store {
        debt_payment: u64,
        credit: u64,
    }

    /// event emitted when a strategy realizes a profit
    /// * gain: u64 - the amount of profit
    struct GainEvent has drop, store {
        gain: u64,
    }

    /// event emitted when a strategy realizes a loss
    /// * loss: u64 - the amount of loss
    struct LossEvent has drop, store {
        loss: u64,
    }

    /// event emitted when a strategy is harvested
    /// * timestamp: u64 - the timestamp of the harvest
    struct HarvestEvent has drop, store {
        timestamp: u64,
    }

    /// event emitted when fees are assessed on a strategy
    /// * vault_coin_amount: u64 - the amount of vault coins minted for fees
    struct AssessFeesEvent has drop, store {
        vault_coin_amount: u64
    }

    // capability creation

    /// creates a VaultManagerCapability<BaseCoin> from a VaultCapability<BaseCoin>
    /// * vault_manager: signer - must be the vault manager of Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun get_vault_manager_capability<BaseCoin>(
        vault_manager: &signer,
        vault_cap: VaultCapability<BaseCoin>
    ): VaultManagerCapability<BaseCoin> {
        let vault_address = get_vault_address(&vault_cap);
        vault_config::assert_vault_manager(vault_manager, vault_address);
        VaultManagerCapability { vault_cap }
    }

    /// destroys a VaultManagerCapability<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun destroy_vault_manager_capability<BaseCoin>(
        vault_manager_cap: VaultManagerCapability<BaseCoin>
    ): VaultCapability<BaseCoin> {
        let VaultManagerCapability {
            vault_cap
        } = vault_manager_cap;
        vault_cap
    }

    /// creates a KeeperCapability to access Vault<BaseCoin> from StrategyType
    /// * keeper: signer - must be a keeper of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    /// * witness: StrategyType - proves that function is invoked by module of StrategyType
    public(friend) fun get_keeper_capability<BaseCoin, StrategyType: drop>(
        keeper: &signer,
        vault_cap: VaultCapability<BaseCoin>,
        witness: StrategyType
    ): KeeperCapability<BaseCoin, StrategyType> {
        let vault_address = get_vault_address(&vault_cap);
        keeper_config::assert_keeper<BaseCoin, StrategyType>(keeper, vault_address);
        KeeperCapability<BaseCoin, StrategyType> {
            vault_cap,
            witness
        }
    }

    /// destroys a KeeperCapability<BaseCoin, StrategyType>
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - for Vault<BaseCoin>
    public(friend) fun destroy_keeper_capability<BaseCoin, StrategyType: drop>(
        keeper_cap: KeeperCapability<BaseCoin, StrategyType>
    ): VaultCapability<BaseCoin> {
        let KeeperCapability<BaseCoin, StrategyType> {
            vault_cap,
            witness: _
        } = keeper_cap;
        vault_cap
    }

    /// creates a UserCapability<BaseCoin> for Vault<BaseCoin>
    /// * user: signer
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun get_user_capability<BaseCoin>(
        user: &signer,
        vault_cap: VaultCapability<BaseCoin>
    ): UserCapability<BaseCoin> {
        UserCapability {
            vault_cap,
            user_addr: signer::address_of(user),
        }
    }

    /// destroys a UserCapability
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun destroy_user_capability<BaseCoin>(
        user_cap: UserCapability<BaseCoin>
    ): (VaultCapability<BaseCoin>, address) {
        let UserCapability {
            vault_cap,
            user_addr,
        } = user_cap;
        (vault_cap, user_addr)
    }

    // governance functions

    /// creates a new Vault<BaseCoin> with the given management and performance fees
    /// * satay_coins_account: signer - must be the satay_coins deployer
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    public(friend) fun new<BaseCoin>(
        satay_coins_account: &signer,
        management_fee: u64,
        performance_fee: u64
    ): VaultCapability<BaseCoin> {
        assert_fee_amounts(management_fee, performance_fee);

        // create vault coin name
        let vault_coin_name = string::utf8(type_info::struct_name(&type_info::type_of<BaseCoin>()));
        string::append_utf8(&mut vault_coin_name, b" Vault");
        let seed = copy vault_coin_name;

        // create a resource account for the vault managed by the sender
        let (vault_acc, signer_cap) = account::create_resource_account(
            satay_coins_account,
            *string::bytes(&seed),
        );

        let base_coin_decimals = coin::decimals<BaseCoin>();
        let vault = Vault<BaseCoin> {
            management_fee,
            performance_fee,
            deposits_frozen: false,
            debt_ratio: 0,
            total_debt: 0,
            user_deposit_events: account::new_event_handle<UserDepositEvent>(&vault_acc),
            user_withdraw_events: account::new_event_handle<UserWithdrawEvent>(&vault_acc),
            update_fees_events: account::new_event_handle<UpdateFeesEvent>(&vault_acc),
            freeze_events: account::new_event_handle<FreezeEvent>(&vault_acc),
        };
        move_to(&vault_acc, vault);

        // create vault coin symbol
        let vault_coin_symbol = string::utf8(b"s");
        string::append(&mut vault_coin_symbol, coin::symbol<BaseCoin>());

        // initialize vault coin and move vault caps to vault owner
        let (burn_cap,
            freeze_cap,
            mint_cap
        ) = coin::initialize<VaultCoin<BaseCoin>>(
            satay_coins_account,
            vault_coin_name,
            vault_coin_symbol,
            base_coin_decimals,
            true
        );
        move_to(&vault_acc, VaultCoinCaps<BaseCoin> { mint_cap, freeze_cap, burn_cap});

        // create vault capability and use it to add BaseCoin to coin storage
        let vault_cap = VaultCapability {
            signer_cap
        };
        add_coin<BaseCoin, BaseCoin>(&vault_cap);

        // register vault with dao_storage
        dao_storage::register<VaultCoin<BaseCoin>>(&vault_acc);

        // initialize vault config
        vault_config::initialize(&vault_acc);

        // return vault_cap to be stored in vaults table on Satay module
        vault_cap
    }

    // user functions

    /// deposits BaseCoin into Vault<BaseCoin> and returns VaultCoin<BaseCoin>
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    /// * base_coins: Coin<BaseCoin> - the BaseCoin to deposit
    public(friend) fun deposit_as_user<BaseCoin>(
        user_cap: &UserCapability<BaseCoin>,
        base_coins: Coin<BaseCoin>
    ): Coin<VaultCoin<BaseCoin>>
    acquires Vault, CoinStore, VaultCoinCaps {
        let vault_cap = &user_cap.vault_cap;
        assert_vault_active(vault_cap);

        let base_coin_amount = coin::value(&base_coins);
        let vault_coin_amount = calculate_vault_coin_amount_from_base_coin_amount<BaseCoin>(
            vault_cap,
            coin::value(&base_coins)
        );

        // emit deposit event
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        event::emit_event(&mut vault.user_deposit_events, UserDepositEvent {
            user_addr: user_cap.user_addr,
            base_coin_amount,
            vault_coin_amount
        });

        // deposit base coin and mint vault coin
        deposit(vault_cap, base_coins);
        let caps = borrow_global<VaultCoinCaps<BaseCoin>>(vault_address);
        coin::mint<VaultCoin<BaseCoin>>(vault_coin_amount, &caps.mint_cap)
    }

    /// burns VaultCoin<BaseCoin> and withdraws BaseCoin from Vault<BaseCoin>
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    /// * vault_coins: Coin<VaultCoin<BaseCoin>> - the VaultCoin<BaseCoin> to burn
    public(friend) fun withdraw_as_user<BaseCoin>(
        user_cap: &UserCapability<BaseCoin>,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): Coin<BaseCoin>
    acquires CoinStore, Vault, VaultCoinCaps {
        let vault_cap = &user_cap.vault_cap;

        let vault_coin_amount = coin::value(&vault_coins);
        let base_coin_amount = calculate_base_coin_amount_from_vault_coin_amount<BaseCoin>(
            vault_cap,
            coin::value(&vault_coins)
        );

        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        event::emit_event(&mut vault.user_withdraw_events, UserWithdrawEvent {
            user_addr: user_cap.user_addr,
            base_coin_amount,
            vault_coin_amount,
        });

        let caps = borrow_global<VaultCoinCaps<BaseCoin>>(vault_address);
        coin::burn(vault_coins, &caps.burn_cap);
        withdraw(vault_cap, base_coin_amount)
    }

    /// store Coin<VaultCoin<BaseCoin>> to liquidate and calculate the amount of BaseCoin needed for liquidation
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    /// * vault_coins: Coin<VaultCoin<BaseCoin>> - the VaultCoin<BaseCoin> to liquidate
    public(friend) fun get_liquidation_lock<BaseCoin, StrategyType: drop>(
        user_cap: &UserCapability<BaseCoin>,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): UserLiquidationLock<BaseCoin>
    acquires CoinStore, Vault, VaultStrategy {
        assert_has_strategy<BaseCoin, StrategyType>(&user_cap.vault_cap);
        // check if vault has enough balance
        let vault_coin_amount = coin::value(&vault_coins);
        let vault_balance = balance<BaseCoin, BaseCoin>(&user_cap.vault_cap);
        let value = calculate_base_coin_amount_from_vault_coin_amount<BaseCoin>(
            &user_cap.vault_cap,
            vault_coin_amount
        );
        assert!(vault_balance < value, ERR_ENOUGH_BALANCE_ON_VAULT);

        let amount_needed = value - vault_balance;
        let total_debt = total_debt<BaseCoin, StrategyType>(&user_cap.vault_cap);
        assert!(total_debt >= amount_needed, ERR_INSUFFICIENT_USER_RETURN);
        UserLiquidationLock<BaseCoin> {
            vault_coins,
            amount_needed,
        }
    }

    /// withdraws StrategyCoin<BaseCoin, StrategyType> for user liquidation
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    /// * strategy_coin_amount: u64
    /// * _witness: &StrategyType - witness pattern
    public(friend) fun withdraw_strategy_coin_for_liquidation<BaseCoin, StrategyType: drop>(
        user_cap: &UserCapability<BaseCoin>,
        strategy_coin_amount: u64,
        _witness: &StrategyType
    ): Coin<StrategyCoin<BaseCoin, StrategyType>>
    acquires CoinStore {
        let vault_cap = &user_cap.vault_cap;

        let withdraw_amount = strategy_coin_amount;
        let strategy_coin_balance = balance<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(vault_cap);
        if (withdraw_amount > strategy_coin_balance) {
            withdraw_amount = strategy_coin_balance;
        };

        withdraw<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(
            vault_cap,
            withdraw_amount
        )
    }

    /// deposits BaseCoin debt from StrategyType to Vault<BaseCoin> and liquidates VaultCoin<BaseCoin> for user
    /// * user_cap: UserCapability<BaseCoin> - for Vault<BaseCoin>
    /// * base_coins: Coin<BaseCoin> - the BaseCoin debt to repay
    /// * user_liq_lock: UserLiquidationLock<BaseCoin> - holds VaultCoin<BaseCoin> to liquidate and debt amount needed
    /// * witness: &StrategyType - witness pattern
    public(friend) fun user_liquidation<BaseCoin, StrategyType: drop>(
        user_cap: &UserCapability<BaseCoin>,
        base_coins: Coin<BaseCoin>,
        user_liq_lock: UserLiquidationLock<BaseCoin>,
        witness: &StrategyType
    )
    acquires Vault, CoinStore, VaultStrategy, VaultCoinCaps {
        let UserLiquidationLock<BaseCoin> {
            amount_needed,
            vault_coins,
        } = user_liq_lock;
        assert!(coin::value(&base_coins) >= amount_needed, ERR_INSUFFICIENT_USER_RETURN);

        deposit_debt_payment<BaseCoin, StrategyType>(&user_cap.vault_cap, base_coins, witness);

        let base_coins = withdraw_as_user(user_cap, vault_coins);
        coin::deposit<BaseCoin>(user_cap.user_addr, base_coins);
    }


    // vault manager functions

    /// updates Vault<BaseCoin> performance and management fees
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    public(friend) fun update_fee<BaseCoin>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        management_fee: u64,
        performance_fee: u64
    )
    acquires Vault {
        assert_fee_amounts(management_fee, performance_fee);

        let vault_address = get_vault_address(&vault_manager_cap.vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        vault.management_fee = management_fee;
        vault.performance_fee = performance_fee;

        event::emit_event(&mut vault.update_fees_events, UpdateFeesEvent {
            management_fee,
            performance_fee,
        });
    }

    /// freezes deposits to Vault<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun freeze_vault<BaseCoin>(vault_manager_cap: &VaultManagerCapability<BaseCoin>)
    acquires Vault {
        assert_vault_active(&vault_manager_cap.vault_cap);
        let vault_address = get_vault_address(&vault_manager_cap.vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        vault.deposits_frozen = true;
        event::emit_event(&mut vault.freeze_events, FreezeEvent {
            frozen: true,
        });
    }

    /// unfreezes deposits to Vault<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    public(friend) fun unfreeze_vault<BaseCoin>(vault_manager_cap: &VaultManagerCapability<BaseCoin>)
    acquires Vault {
        assert_vault_not_active(&vault_manager_cap.vault_cap);
        let vault_address = get_vault_address(&vault_manager_cap.vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        vault.deposits_frozen = false;
        event::emit_event(&mut vault.freeze_events, FreezeEvent {
            frozen: false,
        });
    }

    /// approves StrategyType for Vault<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    /// * debt_ratio: u64 - in BPS
    /// * witness: &StrategyType - witness pattern
    public(friend) fun approve_strategy<BaseCoin, StrategyType: drop>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        debt_ratio: u64,
        witness: &StrategyType
    )
    acquires Vault, VaultStrategy {
        let vault_cap = &vault_manager_cap.vault_cap;

        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        // check if the strategy's updated debt ratio is valid
        assert_debt_ratio(vault.debt_ratio + debt_ratio);

        // create a new strategy
        let vault_acc = account::create_signer_with_capability(&vault_cap.signer_cap);
        move_to(&vault_acc, VaultStrategy<BaseCoin, StrategyType> {
            debt_ratio,
            total_debt: 0,
            total_gain: 0,
            total_loss: 0,
            last_report: timestamp::now_seconds(),
            debt_ratio_change_events: account::new_event_handle<DebtRatioChangeEvent>(&vault_acc),
            debt_change_events: account::new_event_handle<DebtChangeEvent>(&vault_acc),
            gain_events: account::new_event_handle<GainEvent>(&vault_acc),
            loss_events: account::new_event_handle<LossEvent>(&vault_acc),
            harvest_events: account::new_event_handle<HarvestEvent>(&vault_acc),
            assess_fees_events: account::new_event_handle<AssessFeesEvent>(&vault_acc),
        });

        keeper_config::initialize<BaseCoin, StrategyType>(
            &vault_acc,
            witness
        );

        // emit debt ratio change event
        let vault_strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        event::emit_event(&mut vault_strategy.debt_ratio_change_events, DebtRatioChangeEvent {
            debt_ratio,
        });

        if(!has_coin<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(vault_cap)){
            add_coin<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(vault_cap);
        };

        // update vault params
        vault.debt_ratio = vault.debt_ratio + debt_ratio;
    }

    /// updates the debt ratio for StrategyType on Vault<BaseCoin>
    /// * vault_manager_cap: VaultManagerCapability<BaseCoin> - for Vault<BaseCoin>
    /// * debt_ratio: u64 - in BPS
    /// * _witness: &StrategyType - witness pattern
    public(friend) fun update_strategy_debt_ratio<BaseCoin, StrategyType: drop>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        debt_ratio: u64,
        _witness: &StrategyType
    ): u64
    acquires Vault, VaultStrategy {
        let vault_cap = &vault_manager_cap.vault_cap;
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        let old_debt_ratio = strategy.debt_ratio;

        vault.debt_ratio = vault.debt_ratio - old_debt_ratio + debt_ratio;
        strategy.debt_ratio = debt_ratio;

        // check if the strategy's updated debt ratio is valid
        assert_debt_ratio(vault.debt_ratio);

        // emit debt ratio change event
        event::emit_event(&mut strategy.debt_ratio_change_events, DebtRatioChangeEvent {
            debt_ratio,
        });

        debt_ratio
    }

    // for keeper

    /// deposits StrategyCoin<BaseCoin, StrategyType> into Vault<BaseCoin>
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - for Vault<BaseCoin>
    /// * strategy_coin: Coin<StrategyCoin<BaseCoin, StrategyType>>
    public(friend) fun deposit_strategy_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        strategy_coin: Coin<StrategyCoin<BaseCoin, StrategyType>>,
    )
    acquires CoinStore {
        let vault_cap = &keeper_cap.vault_cap;
        deposit(vault_cap, strategy_coin);
    }

    /// withdraws StrategyCoin<BaseCoin, StrategyType> from Vault<BaseCoin>
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - for Vault<BaseCoin>
    /// * strategy_coin_amount: u64 - amount of StrategyCoin<BaseCoin, StrategyType> to withdraw
    public(friend) fun withdraw_strategy_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        strategy_coin_amount: u64,
    ): Coin<StrategyCoin<BaseCoin, StrategyType>>
    acquires CoinStore {
        let vault_cap = &keeper_cap.vault_cap;

        let withdraw_amount = strategy_coin_amount;
        let strategy_coin_balance = balance<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(vault_cap);
        if (withdraw_amount > strategy_coin_balance) {
            withdraw_amount = strategy_coin_balance;
        };

        withdraw<BaseCoin, StrategyCoin<BaseCoin, StrategyType>>(
            vault_cap,
            withdraw_amount
        )
    }

    /// updates the debt reporting for the Vault<BaseCoin> and VaultStrategy<BaseCoin, StrategyType>
    /// returns the Coin<BaseCoin> to apply in the strategy and the profit/loss since the last harvest
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - for Vault<BaseCoin>
    /// * strategy_balance: u64 - BaseCoin balance of StrategyType
    public(friend) fun process_harvest<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        strategy_balance: u64,
    ) : (Coin<BaseCoin>, HarvestInfo) acquires VaultStrategy, Vault, CoinStore {

        let vault_cap = &keeper_cap.vault_cap;
        let witness = &keeper_cap.witness;

        let (profit, loss, debt_payment) = prepare_return<BaseCoin, StrategyType>(
            vault_cap,
            strategy_balance
        );

        // loss to report, do it before the rest of the calculation
        if (loss > 0) {
            let total_debt = total_debt<BaseCoin, StrategyType>(vault_cap);
            assert!(total_debt >= loss, ERR_LOSS);
            report_loss<BaseCoin, StrategyType>(vault_cap, loss, witness);
        };

        let debt = debt_out_standing<BaseCoin, StrategyType>(vault_cap);
        if (debt_payment > debt) {
            debt_payment = debt;
        };

        let credit = credit_available<BaseCoin, StrategyType>(vault_cap);
        let to_apply= coin::zero<BaseCoin>();
        if(credit > 0){
            coin::merge(
                &mut to_apply,
                withdraw_base_coin<BaseCoin, StrategyType>(
                    vault_cap,
                    credit,
                    witness
                )
            );
        };

        (to_apply, HarvestInfo {
            profit,
            debt_payment
        })
    }

    /// destroys the harvest info, ensures that the debt payment and profit are correct
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - for Vault<BaseCoin>
    /// * harvest_info: HarvestInfo - holds the expected debt payment and profit
    /// * debt_payment_coins: Coin<BaseCoin> - the debt repayment
    /// * profit_coins: Coin<BaseCoin> - the profit to deposit
    public(friend) fun destroy_harvest_info<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        harvest_info: HarvestInfo,
        debt_payment_coins: Coin<BaseCoin>,
        profit_coins: Coin<BaseCoin>,
    ) acquires Vault, CoinStore, VaultStrategy, VaultCoinCaps {
        let HarvestInfo {
            debt_payment: debt_payment_amount,
            profit: profit_amount
        } = harvest_info;

        assert!(coin::value(&debt_payment_coins) == debt_payment_amount, ERR_DEBT_PAYMENT);
        keeper_debt_payment<BaseCoin, StrategyType>(keeper_cap, debt_payment_coins);

        assert!(coin::value(&profit_coins) == profit_amount, ERR_PROFIT_PAYMENT);
        deposit_profit(keeper_cap, profit_coins);
    }

    // getters

    // vault fields

    /// returns the address of the Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun get_vault_address<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): address {
        account::get_signer_capability_address(&vault_cap.signer_cap)
    }

    /// returns (management_fee, performance_fee) of Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun get_fees<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): (u64, u64)
    acquires Vault {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        (vault.management_fee, vault.performance_fee)
    }

    /// returns whether Vault<BaseCoin> is frozen for deposits
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun is_vault_frozen<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): bool
    acquires Vault {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        vault.deposits_frozen
    }

    /// returns the debt ratio of Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun get_debt_ratio<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires Vault {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        vault.debt_ratio
    }

    /// returns the total debt of Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun get_total_debt<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires Vault {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        vault.total_debt
    }

    /// returns the balance of CoinType in Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun balance<BaseCoin, CoinType>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let store = borrow_global_mut<CoinStore<CoinType>>(vault_address);
        coin::value(&store.coin)
    }

    /// gets the total BaseCoin assets of Vault<BaseCoin>, including the liquid assets and debt
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun total_assets<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires Vault, CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);

        let balance = balance<BaseCoin, BaseCoin>(vault_cap);
        vault.total_debt + balance
    }

    /// returns whether Vault<BaseCoin> has a CoinStore<CoinType>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun has_coin<BaseCoin, CoinType>(vault_cap: &VaultCapability<BaseCoin>): bool {
        let vault_address = get_vault_address(vault_cap);
        exists<CoinStore<CoinType>>(vault_address)
    }

    // strategy fields

    /// returns whether Vault<BaseCoin> has approved StrategyType
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun has_strategy<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): bool {
        let vault_address = get_vault_address(vault_cap);
        exists<VaultStrategy<BaseCoin, StrategyType>>(vault_address)
    }

    /// gets the amount of BaseCoin credit StrategyType can withdraw from Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun credit_available<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires Vault, VaultStrategy, CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);

        let vault_debt_ratio = vault.debt_ratio;
        let vault_total_debt = vault.total_debt;
        let vault_total_assets = total_assets<BaseCoin>(vault_cap);
        let vault_debt_limit = math::calculate_proportion_of_u64_with_u64_denominator(
            vault_total_assets,
            vault_debt_ratio,
            MAX_DEBT_RATIO_BPS
        );

        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);

        let strategy_debt_limit = math::calculate_proportion_of_u64_with_u64_denominator(
            vault_total_assets,
            strategy.debt_ratio,
            MAX_DEBT_RATIO_BPS
        );
        let strategy_total_debt = strategy.total_debt;

        if (strategy_debt_limit <= strategy_total_debt || vault_debt_limit <= vault_total_debt) {
            return 0
        };

        let strategy_credit_available = strategy_debt_limit - strategy_total_debt;
        let store = borrow_global<CoinStore<BaseCoin>>(vault_address);
        let balance = coin::value(&store.coin);

        if (strategy_credit_available > (vault_debt_limit - vault_total_debt)) {
            strategy_credit_available = vault_debt_limit - vault_total_debt;
        };
        if (strategy_credit_available > balance) {
            strategy_credit_available = balance;
        };

        strategy_credit_available
    }

    /// gets the amount of BaseCoin debt StrategyType has withdrawn past its limit
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun debt_out_standing<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires Vault, VaultStrategy, CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);

        if (vault.debt_ratio == 0) {
            return strategy.total_debt
        };

        let vault_total_assets = total_assets<BaseCoin>(vault_cap);
        let strategy_debt_limit = math::calculate_proportion_of_u64_with_u64_denominator(
            vault_total_assets,
            strategy.debt_ratio,
            MAX_DEBT_RATIO_BPS
        );
        let strategy_total_debt = strategy.total_debt;

        if (strategy_total_debt <= strategy_debt_limit) {
            0
        } else {
            strategy_total_debt - strategy_debt_limit
        }
    }

    /// gets the total debt of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun total_debt<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.total_debt
    }

    /// gets the total gain of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun total_gain<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.total_gain
    }

    /// gets the total loss of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun total_loss<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.total_loss
    }

    /// gets the debt ratio of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun debt_ratio<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.debt_ratio
    }

    /// gets the last report timestamp of StrategyType on Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    public fun last_report<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>): u64
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.last_report
    }

    // user getters

    /// calculates amount of BaseCoin to withdraw given an amount of VaultCoin<BaseCoin> to burn
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * vault_coin_amount: u64
    public fun calculate_base_coin_amount_from_vault_coin_amount<BaseCoin>(
        vault_cap: &VaultCapability<BaseCoin>,
        vault_coin_amount: u64
    ): u64 acquires Vault, CoinStore {
        let total_assets = total_assets<BaseCoin>(vault_cap);
        let share_total_supply_option = coin::supply<VaultCoin<BaseCoin>>();
        let share_total_supply = option::get_with_default<u128>(&share_total_supply_option, 0);
        math::calculate_proportion_of_u64_with_u128_denominator(
            total_assets,
            vault_coin_amount,
            share_total_supply
        )
    }

    /// calculates amount of VaultCoin<BaseCoin> to mint given an amount of BaseCoin to deposit
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * base_coin_amount: u64
    public fun calculate_vault_coin_amount_from_base_coin_amount<BaseCoin>(
        vault_cap: &VaultCapability<BaseCoin>,
        base_coin_amount: u64
    ): u64
    acquires Vault, CoinStore {
        let total_base_coin_amount = total_assets<BaseCoin>(vault_cap);
        let total_supply = option::get_with_default<u128>(&coin::supply<VaultCoin<BaseCoin>>(), 0);

        if (total_supply != 0) {
            // this function will abort if total_supply * base_coin_amount > u128::max_value()
            // in practice, this should never happen. If it does, base_coin_amount should be reduced and split into
            // two transactions
            math::mul_u128_u64_div_u64_result_u64(
                total_supply,
                base_coin_amount,
                total_base_coin_amount
            )
        } else {
            base_coin_amount
        }
    }

    /// returns the BaseCoin amount needed to destroy the UserLiquidationLock
    /// * user_liq_lock: &UserLiquidationLock<BaseCoin>
    public fun get_liquidation_amount_needed<BaseCoin>(user_liq_lock: &UserLiquidationLock<BaseCoin>): u64 {
        user_liq_lock.amount_needed
    }

    /// returns the amount of BaseCoin debt amount needed to destroy the HarvestInfo
    /// * harvest_info: &HarvestInfo
    public fun get_harvest_debt_payment(harvest_info: &HarvestInfo): u64 {
        harvest_info.debt_payment
    }

    /// returns the amount of BaseCoin profit needed to destroy the HarvestInfo
    /// * harvest_info: &HarvestInfo
    public fun get_harvest_profit(harvest_info: &HarvestInfo): u64 {
        harvest_info.profit
    }

    // helpers

    // coin storage

    /// creates a CoinStore for CoinType in Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    fun add_coin<BaseCoin, CoinType>(vault_cap: &VaultCapability<BaseCoin>) {
        let vault_acc = account::create_signer_with_capability(&vault_cap.signer_cap);
        move_to(&vault_acc, CoinStore<CoinType> {
            coin: coin::zero(),
            deposit_events: account::new_event_handle<DepositEvent>(&vault_acc),
            withdraw_events: account::new_event_handle<WithdrawEvent>(&vault_acc),
        });
    }

    /// deposits Coin<CoinType> into Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * coin: Coin<CoinType>
    fun deposit<BaseCoin, CoinType>(vault_cap: &VaultCapability<BaseCoin>, coin: Coin<CoinType>)
    acquires CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let store = borrow_global_mut<CoinStore<CoinType>>(vault_address);
        event::emit_event(&mut store.deposit_events, DepositEvent {
            amount: coin::value(&coin)
        });
        coin::merge(&mut store.coin, coin);
    }

    /// withdraws Coin<CoinType> from Vault<BaseCoin>
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * amount: u64
    fun withdraw<BaseCoin, CoinType>(vault_cap: &VaultCapability<BaseCoin>, amount: u64): Coin<CoinType>
    acquires CoinStore {
        let vault_address = get_vault_address(vault_cap);
        let store = borrow_global_mut<CoinStore<CoinType>>(vault_address);
        event::emit_event(&mut store.deposit_events, DepositEvent {
            amount
        });
        coin::extract(&mut store.coin, amount)
    }

    // strategy

    /// calculates the profit, loss, and debt payment for a harvest
    /// * vault_cap: VaultCapability<BaseCoin> - for Vault<BaseCoin>
    /// * strategy_balance: u64 - BaseCoin balance of StrategyType
    fun prepare_return<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        strategy_balance: u64
    ): (u64, u64, u64)
    acquires VaultStrategy, Vault, CoinStore {

        // get amount of strategy debt over limit
        let debt_out_standing = debt_out_standing<BaseCoin, StrategyType>(vault_cap);
        let debt_payment: u64;
        if (strategy_balance > debt_out_standing) {
            debt_payment = debt_out_standing;
            strategy_balance = strategy_balance - debt_payment;
        } else {
            debt_payment = strategy_balance;
            strategy_balance = 0;
        };

        // calculate profit and loss
        let profit = 0;
        let loss = 0;

        // strategy's total debt
        let total_debt = total_debt<BaseCoin, StrategyType>(vault_cap);

        total_debt = total_debt - debt_payment;

        if (strategy_balance > total_debt) {
            profit = strategy_balance - total_debt;
        } else {
            loss = total_debt - strategy_balance;
        };

        (profit, loss, debt_payment)
    }

    /// deposits Coin<BaseCoin> into Vault<BaseCoin> from StrategyType
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * base_coin: Coin<BaseCoin>
    /// * _witness: &StrategyType - witness pattern
    fun deposit_base_coin<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        base_coin: Coin<BaseCoin>,
        _witness: &StrategyType
    )
    acquires CoinStore {
        deposit(vault_cap, base_coin);
    }

    /// withdraws Coin<BaseCoin> from Vault<BaseCoin> to StrategyType
    /// asserts that amount of credit is available and updates debt reporting
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * amount: u64
    /// * witness: &StrategyType - witness pattern
    fun withdraw_base_coin<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        amount: u64,
        witness: &StrategyType
    ): Coin<BaseCoin>
    acquires CoinStore, Vault, VaultStrategy {
        assert!(credit_available<BaseCoin, StrategyType>(vault_cap) >= amount, ERR_INSUFFICIENT_CREDIT);
        update_total_debt<BaseCoin, StrategyType>(vault_cap, amount, 0, witness);
        withdraw(vault_cap, amount)
    }

    /// updates the total debt of Vault<BaseCoin> and VaultStrategy<BaseCoin, StrategyType>
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * credit: u64
    /// * debt_payment: u64
    /// * _witness: &StrategyType - witness pattern
    fun update_total_debt<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        credit: u64,
        debt_payment: u64,
        _witness: &StrategyType
    )
    acquires Vault, VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);

        vault.total_debt = vault.total_debt + credit - debt_payment;
        strategy.total_debt = strategy.total_debt + credit - debt_payment;

        // emit debt change event
        event::emit_event(&mut strategy.debt_change_events, DebtChangeEvent {
            debt_payment,
            credit
        })
    }

    /// deposits Coin<BaseCoin> into Vault<BaseCoin> from StrategyType and updates debt reporting
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * base_coin: Coin<BaseCoin> - debt payment
    /// * witness: &StrategyType - witness pattern
    fun deposit_debt_payment<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        base_coin: Coin<BaseCoin>,
        witness: &StrategyType
    )
    acquires Vault, VaultStrategy, CoinStore {
        update_total_debt<BaseCoin, StrategyType>(
            vault_cap,
            0,
            coin::value(&base_coin),
            witness
        );
        deposit_base_coin(vault_cap, base_coin, witness);
    }

    /// deposits Coin<BaseCoin into Vault<BaseCoin> as profit
    /// * vault_cap: VaultCapability<BaseCoin>
    /// * base_coin: Coin<BaseCoin> - profit
    fun deposit_profit<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        base_coin: Coin<BaseCoin>,
    )
    acquires Vault, CoinStore, VaultStrategy, VaultCoinCaps {
        let vault_cap = &keeper_cap.vault_cap;
        let witness = &keeper_cap.witness;
        report_gain<BaseCoin, StrategyType>(vault_cap, coin::value(&base_coin), witness);
        assess_fees<BaseCoin, StrategyType>(
            vault_cap,
            &base_coin,
            witness
        );
        deposit_base_coin(vault_cap, base_coin, witness);
    }

    /// deposits Coin<BaseCoin> into Vault<BaseCoin> with KeeperCapability
    /// * keeper_cap: KeeperCapability<BaseCoin, StrategyType> - holds strategy witness
    /// * base_coin: Coin<BaseCoin>
    fun keeper_debt_payment<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        base_coin: Coin<BaseCoin>,
    )
    acquires Vault, CoinStore, VaultStrategy {
        deposit_debt_payment(&keeper_cap.vault_cap, base_coin, &keeper_cap.witness);
    }

    /// assesses fees for a given Coin<BaseCoin> profit by minting VaultCoin<BaseCoin> to satay::dao_storage
    /// updates the VaultStrategy<StrategyType, BaseCoin> last_report timestamp and total gain
    /// * profit: &Coin<BaseCoin> - profit
    /// * vault_cap: &VaultCapability<BaseCoin>
    /// * witness: &StrategyType - witness pattern
    fun assess_fees<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        profit: &Coin<BaseCoin>,
        witness: &StrategyType
    )
    acquires VaultStrategy, Vault, CoinStore, VaultCoinCaps {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global<Vault<BaseCoin>>(vault_address);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);

        let duration = timestamp::now_seconds() - strategy.last_report;
        let gain = coin::value(profit);

        if (duration == 0 || gain == 0) {
            return
        };

        // management_fee is at most 5000, so u64 numerator will not overflow for durations < (2^64 - 1) / 5000
        // (2^64 - 1) / 5000 seconds equals roughly 5.8 million years
        // denominator is constant 3.2 * 10 ^ 11, which is less than 2^64 - 1, and cannot overflow
        let management_fee_amount = math::mul_div(
            strategy.total_debt,
            vault.management_fee * duration,
            MAX_DEBT_RATIO_BPS * SECS_PER_YEAR
        );
        let performance_fee_amount = math::calculate_proportion_of_u64_with_u64_denominator(
            gain,
            vault.performance_fee,
            MAX_DEBT_RATIO_BPS
        );

        let total_fee_amount = management_fee_amount + performance_fee_amount;
        if (total_fee_amount > gain) {
            total_fee_amount = gain;
        };

        // calculate amount of share tokens to mint
        let vault_coin_amount = calculate_vault_coin_amount_from_base_coin_amount<BaseCoin>(
            vault_cap,
            total_fee_amount
        );

        // mint vault coins to dao storage
        let caps = borrow_global<VaultCoinCaps<BaseCoin>>(vault_address);
        let coins = coin::mint<VaultCoin<BaseCoin>>(vault_coin_amount, &caps.mint_cap);
        dao_storage::deposit<VaultCoin<BaseCoin>>(vault_address, coins);

        // emit fee event
        event::emit_event(&mut strategy.assess_fees_events, AssessFeesEvent {
            vault_coin_amount
        });

        report_timestamp<BaseCoin, StrategyType>(vault_cap, witness);
    }

    /// report a gain on VaultStrategy<BaseCoin, StrategyType>
    /// * vault_cap: &VaultCapability<BaseCoin>
    /// * gain: u64 - amount of gain
    /// * _witness: &StrategyType - witness pattern
    fun report_gain<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        gain: u64,
        _witness: &StrategyType
    )
    acquires VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.total_gain = strategy.total_gain + gain;
        // emit gain event
        event::emit_event(&mut strategy.gain_events, GainEvent {
            gain,
        });
    }

    /// report a loss on VaultStrategy<BaseCoin, StrategyType>
    /// * vault_cap: &VaultCapability<BaseCoin>
    /// * loss: u64 - amount of loss
    /// * _witness: &StrategyType - witness pattern
    fun report_loss<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        loss: u64,
        _witness: &StrategyType
    )
    acquires Vault, VaultStrategy {
        let vault_address = get_vault_address(vault_cap);
        let vault = borrow_global_mut<Vault<BaseCoin>>(vault_address);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);

        if (vault.debt_ratio != 0) {
            let ratio_change = math::calculate_proportion_of_u64_with_u64_denominator(
                vault.debt_ratio,
                loss,
                vault.total_debt
            );
            if (ratio_change > strategy.debt_ratio) {
                ratio_change = strategy.debt_ratio;
            };
            strategy.debt_ratio = strategy.debt_ratio - ratio_change;
            vault.debt_ratio = vault.debt_ratio - ratio_change;
        };

        strategy.total_loss = strategy.total_loss + loss;
        strategy.total_debt = strategy.total_debt - loss;
        vault.total_debt = vault.total_debt - loss;

        // emit loss event
        event::emit_event(&mut strategy.loss_events, LossEvent {
            loss,
        });
    }

    /// report harvest timestamp on VaultStrategy<BaseCoin, StrategyType>
    /// * vault_cap: &VaultCapability<BaseCoin>
    /// * _witness: &StrategyType - witness pattern
    fun report_timestamp<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>, _witness: &StrategyType)
    acquires VaultStrategy {
        let timestamp = timestamp::now_seconds();
        let vault_address = get_vault_address(vault_cap);
        let strategy = borrow_global_mut<VaultStrategy<BaseCoin, StrategyType>>(vault_address);
        strategy.last_report = timestamp;
        event::emit_event(&mut strategy.harvest_events, HarvestEvent {
            timestamp
        });
    }

    // asserts

    /// asserts that the debt ratio is valid
    /// * debt_ratio: u64 - in BPS
    fun assert_debt_ratio(debt_ratio: u64) {
        assert!(debt_ratio <= MAX_DEBT_RATIO_BPS, ERR_INVALID_DEBT_RATIO);
    }

    /// asserts that the fee amounts are valid
    /// * management_fee: u64 - in BPS
    /// * performance_fee: u64 - in BPS
    fun assert_fee_amounts(management_fee: u64, performance_fee: u64) {
        assert!(management_fee <= MAX_MANAGEMENT_FEE && performance_fee <= MAX_PERFORMANCE_FEE, ERR_INVALID_FEE);
    }

    /// asserts that Vault<BaseCoin> is active for deposits
    /// * vault_cap: &VaultCapability<BaseCoin>
    fun assert_vault_active<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>)
    acquires Vault {
        assert!(!is_vault_frozen(vault_cap), ERR_VAULT_FROZEN);
    }

    /// asserts that Vault<BaseCoin> is not active for deposits
    /// * vault_cap: &VaultCapability<BaseCoin>
    fun assert_vault_not_active<BaseCoin>(vault_cap: &VaultCapability<BaseCoin>)
    acquires Vault {
        assert!(is_vault_frozen(vault_cap), ERR_VAULT_NOT_FROZEN);
    }

    /// asserts that Vault<BaseCoin> has approved StrategyType
    /// * vault_cap: &VaultCapability<BaseCoin>
    fun assert_has_strategy<BaseCoin, StrategyType: drop>(vault_cap: &VaultCapability<BaseCoin>) {
        let vault_address = get_vault_address(vault_cap);
        assert!(exists<VaultStrategy<BaseCoin, StrategyType>>(vault_address), ERR_NO_STRATEGY);
    }

    // test functions

    #[test_only]
    public fun new_test<BaseCoin>(
        governance: &signer,
        management_fee: u64,
        performance_fee: u64
    ): VaultCapability<BaseCoin> {
        new<BaseCoin>(
            governance,
            management_fee,
            performance_fee
        )
    }

    #[test_only]
    public fun test_deposit_as_user<BaseCoin>(
        user: &signer,
        vault_cap: VaultCapability<BaseCoin>,
        base_coins: Coin<BaseCoin>
    ): VaultCapability<BaseCoin> acquires Vault, CoinStore, VaultCoinCaps {
        let user_cap = get_user_capability(user, vault_cap);
        let vault_coins = deposit_as_user(&user_cap, base_coins);
        let (vault_cap, user_addr) = destroy_user_capability(user_cap);
        coin::register<VaultCoin<BaseCoin>>(user);
        coin::deposit(user_addr, vault_coins);
        vault_cap
    }

    #[test_only]
    public fun test_withdraw_as_user<BaseCoin>(
        user: &signer,
        vault_cap: VaultCapability<BaseCoin>,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): VaultCapability<BaseCoin> acquires Vault, CoinStore, VaultCoinCaps {
        let user_cap = get_user_capability(user, vault_cap);
        let base_coins = withdraw_as_user(&user_cap, vault_coins);
        let (vault_cap, user_addr) = destroy_user_capability(user_cap);
        coin::deposit(user_addr, base_coins);
        vault_cap
    }

    #[test_only]
    public fun test_deposit<BaseCoin, CoinType>(
        vault_cap: &VaultCapability<BaseCoin>,
        coins: Coin<CoinType>
    ) acquires CoinStore {
        deposit(vault_cap, coins);
    }

    #[test_only]
    public fun test_withdraw<BaseCoin, CoinType>(
        vault_cap: &VaultCapability<BaseCoin>,
        amount: u64
    ) : Coin<CoinType> acquires CoinStore {
        withdraw<BaseCoin, CoinType>(vault_cap, amount)
    }

    #[test_only]
    public fun test_destroy_vault_cap<BaseCoin>(vault_cap: VaultCapability<BaseCoin>) {
        let VaultCapability {
            signer_cap: _,
        } = vault_cap;
    }

    #[test_only]
    public fun test_get_vault_manager_cap<BaseCoin>(vault_manager: &signer, vault_cap: VaultCapability<BaseCoin>): VaultManagerCapability<BaseCoin> {
        get_vault_manager_capability(vault_manager, vault_cap)
    }

    #[test_only]
    public fun test_destroy_vault_manager_cap<BaseCoin>(
        vault_manager_cap: VaultManagerCapability<BaseCoin>
    ): VaultCapability<BaseCoin> {
        destroy_vault_manager_capability(vault_manager_cap)
    }

    #[test_only]
    public fun test_get_keeper_cap<BaseCoin, StrategyType: drop>(
        keeper: &signer,
        vault_cap: VaultCapability<BaseCoin>,
        witness: StrategyType
    ): KeeperCapability<BaseCoin, StrategyType> {
        get_keeper_capability<BaseCoin, StrategyType>(keeper, vault_cap, witness)
    }

    #[test_only]
    public fun test_destroy_keeper_cap<BaseCoin, StrategyType: drop>(keeper_cap: KeeperCapability<BaseCoin, StrategyType>): VaultCapability<BaseCoin> {
        destroy_keeper_capability(keeper_cap)
    }

    #[test_only]
    public fun test_approve_strategy<BaseCoin, StrategyType: drop>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        debt_ratio: u64,
        witness: StrategyType
    ) acquires Vault, VaultStrategy {
        approve_strategy<BaseCoin, StrategyType>(
            vault_manager_cap,
            debt_ratio,
            &witness
        );
    }

    #[test_only]
    public fun test_update_fee<BaseCoin>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        management_fee: u64,
        performance_fee: u64
    ) acquires Vault {
        update_fee(
            vault_manager_cap,
            management_fee,
            performance_fee
        );
    }

    #[test_only]
    public fun test_freeze_vault<BaseCoin>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
    ) acquires Vault {
        freeze_vault(
            vault_manager_cap
        );
    }

    #[test_only]
    public fun test_unfreeze_vault<BaseCoin>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
    ) acquires Vault {
        unfreeze_vault(
            vault_manager_cap
        );
    }

    #[test_only]
    public fun test_deposit_base_coin<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        base_coin: Coin<BaseCoin>,
        witness: &StrategyType
    ) acquires CoinStore {
        deposit_base_coin<BaseCoin, StrategyType>(vault_cap, base_coin, witness);
    }

    #[test_only]
    public fun test_keeper_debt_payment<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        debt_payment_coins: Coin<BaseCoin>,
    ) acquires Vault, CoinStore, VaultStrategy {
        keeper_debt_payment<BaseCoin, StrategyType>(keeper_cap, debt_payment_coins);
    }

    #[test_only]
    public fun test_deposit_profit<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        profit: Coin<BaseCoin>,
    ) acquires Vault, CoinStore, VaultStrategy, VaultCoinCaps {
        deposit_profit<BaseCoin, StrategyType>(keeper_cap, profit);
    }

    #[test_only]
    public fun test_withdraw_base_coin<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        amount: u64,
        witness: &StrategyType
    ) : Coin<BaseCoin> acquires Vault, CoinStore, VaultStrategy {
        withdraw_base_coin<BaseCoin, StrategyType>(vault_cap, amount, witness)
    }

    #[test_only]
    public fun test_keeper_withdraw_base_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        amount: u64,
    ) : Coin<BaseCoin> acquires Vault, CoinStore, VaultStrategy {
        withdraw_base_coin<BaseCoin, StrategyType>(&keeper_cap.vault_cap, amount, &keeper_cap.witness)
    }

    #[test_only]
    public fun test_deposit_strategy_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        strategy_coin: Coin<StrategyCoin<BaseCoin, StrategyType>>,
    )
    acquires CoinStore {
        deposit_strategy_coin<BaseCoin, StrategyType>(keeper_cap, strategy_coin);
    }

    #[test_only]
    public fun test_withdraw_strategy_coin<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
        amount: u64,
    ) : Coin<StrategyCoin<BaseCoin, StrategyType>>
    acquires CoinStore {
        withdraw_strategy_coin<BaseCoin, StrategyType>(keeper_cap, amount)
    }

    #[test_only]
    public fun test_update_strategy_debt_ratio<BaseCoin, StrategyType: drop>(
        vault_manager_cap: &VaultManagerCapability<BaseCoin>,
        debt_ratio: u64,
        witness: &StrategyType
    ) acquires VaultStrategy, Vault {
        update_strategy_debt_ratio<BaseCoin, StrategyType>(
            vault_manager_cap,
            debt_ratio,
            witness
        );
    }

    #[test_only]
    public fun test_assess_fees<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        profit: &Coin<BaseCoin>,
        witness: &StrategyType
    ) acquires Vault, VaultStrategy, CoinStore, VaultCoinCaps {
        assess_fees<BaseCoin, StrategyType>(vault_cap, profit, witness);
    }

    #[test_only]
    public fun test_update_total_debt<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        credit: u64,
        debt_payment: u64,
        witness: &StrategyType
    ) acquires Vault, VaultStrategy {
        update_total_debt<BaseCoin, StrategyType>(vault_cap, credit, debt_payment, witness);
    }

    #[test_only]
    public fun test_report_timestamp<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        witness: &StrategyType
    ) acquires VaultStrategy {
        report_timestamp<BaseCoin, StrategyType>(vault_cap, witness);
    }

    #[test_only]
    public fun test_report_gain<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        profit: u64,
        witness: &StrategyType
    ) acquires VaultStrategy {
        report_gain<BaseCoin, StrategyType>(vault_cap, profit, witness);
    }

    #[test_only]
    public fun test_report_loss<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        loss: u64,
        witness: &StrategyType
    ) acquires Vault, VaultStrategy {
        report_loss<BaseCoin, StrategyType>(vault_cap, loss, witness);
    }

    #[test_only]
    public fun test_prepare_return<BaseCoin, StrategyType: drop>(
        vault_cap: &VaultCapability<BaseCoin>,
        strategy_balance: u64
    ): (u64, u64, u64) acquires VaultStrategy, Vault, CoinStore {
        prepare_return<BaseCoin, StrategyType>(vault_cap, strategy_balance)
    }

    #[test_only]
    public fun keeper_credit_available<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
    ): u64 acquires Vault, VaultStrategy, CoinStore {
        credit_available<BaseCoin, StrategyType>(&keeper_cap.vault_cap)
    }

    #[test_only]
    public fun keeper_debt_out_standing<BaseCoin, StrategyType: drop>(
        keeper_cap: &KeeperCapability<BaseCoin, StrategyType>,
    ): u64 acquires Vault, VaultStrategy, CoinStore {
        debt_out_standing<BaseCoin, StrategyType>(&keeper_cap.vault_cap)
    }

    #[test_only]
    public fun test_get_user_cap<BaseCoin>(
        user: &signer,
        vault_cap: VaultCapability<BaseCoin>
    ): UserCapability<BaseCoin> {
        get_user_capability(user, vault_cap)
    }

    #[test_only]
    public fun test_destroy_user_cap<BaseCoin>(
        user_cap: UserCapability<BaseCoin>
    ): (VaultCapability<BaseCoin>, address) {
        destroy_user_capability(user_cap)
    }

    #[test_only]
    public fun test_get_liquidation_lock<BaseCoin, StrategyType: drop>(
        user_cap: &UserCapability<BaseCoin>,
        vault_coins: Coin<VaultCoin<BaseCoin>>
    ): UserLiquidationLock<BaseCoin>
    acquires CoinStore, Vault, VaultStrategy {
        get_liquidation_lock<BaseCoin, StrategyType>(
            user_cap,
            vault_coins
        )
    }

    #[test_only]
    public fun test_user_liquidation<BaseCoin, StrategyType: drop>(
        user_cap: &UserCapability<BaseCoin>,
        debt_payment: Coin<BaseCoin>,
        user_liq_lock: UserLiquidationLock<BaseCoin>,
        witness: &StrategyType
    ) acquires Vault, CoinStore, VaultStrategy, VaultCoinCaps {
        user_liquidation(user_cap, debt_payment, user_liq_lock, witness);
    }
}
/**
* @notice define hamsterpocket module
*/
module hamsterpocket::pocket {
    use aptos_std::table_with_length;
    use aptos_std::math128 as math;
    use aptos_framework::timestamp;
    use aptos_framework::coin;

    use std::signer;
    use std::signer::address_of;
    use std::error;
    use std::string::{Self, String};
    use std::vector;
    use std::vector::for_each;

    // use internal modules
    use hamsterpocket::platform;
    use hamsterpocket::u256;
    use aptos_std::type_info;

    // declare friends module
    friend hamsterpocket::chef;

    const HAMSTERPOCKET: address = @hamsterpocket;

    // define Pocket status
    const STATUS_ACTIVE: u64 = 0x0;
    const STATUS_PAUSED: u64 = 0x1;
    const STATUS_CLOSED: u64 = 0x2;
    const STATUS_WITHDRAWN: u64 = 0x3;

    // define AMM type
    const AMM_PCS: u64 = 0x0;

    // define UNSET value
    const UNSET: u64 = 0x0;

    // define value comparision operation
    const OPERATOR_EQ: u64 = 0x1;
    const OPERATOR_NEQ: u64 = 0x2;
    const OPERATOR_GT: u64 = 0x3;
    const OPERATOR_GTE: u64 = 0x4;
    const OPERATOR_LT: u64 = 0x5;
    const OPERATOR_LTE: u64 = 0x6;
    const OPERATOR_BW: u64 = 0x7;
    const OPERATOR_NBW: u64 = 0x8;

    // define trading stop condition
    const STOPPED_WITH_PRICE: u64 = 0x1;
    const STOPPED_WITH_PORTFOLIO_VALUE_DIFF: u64 = 0x2;
    const STOPPED_WITH_PORTFOLIO_PERCENT_DIFF: u64 = 0x3;

    // define conditional auto close pocket
    const CLOSED_WITH_END_TIME: u64 = 0x0;
    const CLOSED_WITH_BATCH_AMOUNT: u64 = 0x1;
    const CLOSED_WITH_SPENT_BASE_AMOUNT: u64 = 0x2;
    const CLOSED_WITH_RECEIVED_TARGET_AMOUNT: u64 = 0x3;

    // define input errors
    const INVALID_TIMESTAMP: u64 = 0x1;
    const ZERO_ADDRESS: u64 = 0x2;
    const EMPTY_ID: u64 = 0x3;
    const INVALID_AMM: u64 = 0x4;
    const ZERO_VALUE: u64 = 0x5;
    const INVALID_VALUE: u64 = 0x6;
    const DUPLICATED_ID: u64 = 0x7;
    const NOT_EXISTED_ID: u64 = 0x8;
    const INVALID_POCKET_STATE: u64 = 0x9;
    const INVALID_SIGNER: u64 = 0x10;
    const INVALID_TARGET: u64 = 0x11;

    // define logic error
    const NOT_ABLE_TO_DEPOSIT: u64 = 0x21;
    const NOT_ABLE_TO_WITHDRAW: u64 = 0x22;
    const NOT_ABLE_TO_UPDATE: u64 = 0x23;
    const NOT_ABLE_TO_PAUSE: u64 = 0x24;
    const NOT_ABLE_TO_CLOSE: u64 = 0x25;
    const NOT_ABLE_TO_RESTART: u64 = 0x26;
    const NOT_READY_TO_SWAP: u64 = 0x27;
    const NOT_READY_TO_CLOSE_POSITION: u64 = 0x28;

    // define value comparison
    struct ValueComparision has copy, store, drop {
        operator: u64,
        value_x: u64,
        value_y: u64,
    }

    // define trading stop condition struct
    struct TradingStopCondition has copy, store, drop {
        stopped_with: u64,
        value: u64,
    }

    // define auto close condition struct
    struct AutoCloseCondition has copy, store, drop {
        closed_with: u64,
        value: u64
    }

    // define pocket struct
    struct Pocket has copy, drop, store {
        // pool identity fields
        id: String,
        status: u64,
        owner: address,

        // trading info fields
        base_coin_type: String,
        target_coin_type: String,
        amm: u64,

        // investment time period configuration fields
        start_at: u64,
        // second
        frequency: u64,

        // trading conditional fields
        batch_volume: u64,
        open_position_condition: ValueComparision,
        stop_loss_condition: TradingStopCondition,
        take_profit_condition: TradingStopCondition,
        auto_close_conditions: vector<AutoCloseCondition>,

        // statistic fields are not inserted during pocket creation, but pocket operation
        total_deposited_base_amount: u64,
        total_swapped_base_amount: u64,
        total_received_target_amount: u64,

        total_closed_position_in_target_amount: u64,
        total_received_fund_in_base_amount: u64,

        base_coin_balance: u64,
        target_coin_balance: u64,

        executed_batch_amount: u64,
        next_scheduled_execution_at: u64
    }

    // define pocket store which stores user accounts
    struct PocketStore has key {
        pockets: table_with_length::TableWithLength<String, Pocket>
    }

    // define account resource store
    struct ResourceAccountStore has key {
        owner_map: table_with_length::TableWithLength<String, address>,
    }

    // initialize
    public(friend) fun initialize(hamsterpocket_signer: &signer) {
        assert!(address_of(hamsterpocket_signer) == HAMSTERPOCKET, INVALID_SIGNER);

        move_to(
            hamsterpocket_signer,
            ResourceAccountStore {
                owner_map: table_with_length::new<String, address>(),
            }
        );
    }

    // create pocket
    public(friend) fun create_pocket<BaseCoin, TargetCoin>(
        signer: &signer,
        id: String,
        amm: u64,
        start_at: u64,
        frequency: u64,
        batch_volume: u64,
        open_position_condition: vector<u64>,
        take_profit_condition: vector<u64>,
        stop_loss_condition: vector<u64>,
        auto_close_conditions: vector<u64>
    ) acquires PocketStore, ResourceAccountStore {
        let close_conditions = create_close_conditions(&auto_close_conditions);

        let pocket = &mut Pocket {
            id,
            owner: address_of(signer),
            base_coin_type: type_info::type_name<BaseCoin>(),
            target_coin_type: type_info::type_name<TargetCoin>(),
            amm, // currently we only support PCS as default
            start_at,
            next_scheduled_execution_at: start_at,
            frequency, // second
            batch_volume,
            open_position_condition: ValueComparision {
                operator: *vector::borrow(&open_position_condition, 0),
                value_x: *vector::borrow(&open_position_condition, 1),
                value_y: *vector::borrow(&open_position_condition, 2)
            },
            stop_loss_condition: TradingStopCondition {
                stopped_with: *vector::borrow(&stop_loss_condition, 0),
                value: *vector::borrow(&stop_loss_condition, 1)
            },
            take_profit_condition: TradingStopCondition {
                stopped_with: *vector::borrow(&take_profit_condition, 0),
                value: *vector::borrow(&take_profit_condition, 1)
            },
            auto_close_conditions: close_conditions,
            // statistic fields won't validate at initialization
            status: STATUS_ACTIVE,
            total_deposited_base_amount: 0,
            total_swapped_base_amount: 0,
            total_received_target_amount: 0,
            total_closed_position_in_target_amount: 0,
            total_received_fund_in_base_amount: 0,
            base_coin_balance: 0,
            target_coin_balance: 0,
            executed_batch_amount: 0,
        };

        // validate pocket first
        validate_pocket(pocket);

        let owner_map = &mut borrow_global_mut<ResourceAccountStore>(
            HAMSTERPOCKET
        ).owner_map;

        // if pocket store does not exists, we create one
        if (!exists<PocketStore>(address_of(signer))) {
            move_to(
                signer,
                PocketStore {
                    pockets: table_with_length::new<String, Pocket>(),
                }
            );
        };

        // now we map signer for better query, also avoid duplicated key
        assert!(
            !table_with_length::contains(owner_map, id),
            error::invalid_state(DUPLICATED_ID)
        );
        table_with_length::add(owner_map, pocket.id, address_of(signer));
        assert!(
            table_with_length::contains(owner_map, id),
            error::not_found(NOT_EXISTED_ID)
        );

        let store = borrow_global_mut<PocketStore>(address_of(signer));
        let pockets = &mut store.pockets;

        // we prevent duplicated id to be added to the table
        assert!(
            !table_with_length::contains(
                pockets,
                pocket.id
            ),
            error::invalid_state(DUPLICATED_ID)
        );
        table_with_length::add(pockets, pocket.id, *pocket);
        assert!(
            table_with_length::contains(pockets, id),
            error::not_found(NOT_EXISTED_ID)
        );
    }

    // update pocket
    public(friend) fun update_pocket(
        id: String,
        start_at: u64,
        frequency: u64,
        batch_volume: u64,
        open_position_condition: vector<u64>,
        take_profit_condition: vector<u64>,
        stop_loss_condition: vector<u64>,
        auto_close_conditions: vector<u64>
    ) acquires PocketStore, ResourceAccountStore {
        // now we extract pocket
        let pocket = &mut get_pocket(id);

        // now we assign pocket data from params
        pocket.frequency = frequency;
        pocket.batch_volume = batch_volume;
        pocket.open_position_condition = ValueComparision {
            operator: *vector::borrow(&open_position_condition, 0),
            value_x: *vector::borrow(&open_position_condition, 1),
            value_y: *vector::borrow(&open_position_condition, 2)
        };
        pocket.stop_loss_condition = TradingStopCondition {
            stopped_with: *vector::borrow(&stop_loss_condition, 0),
            value: *vector::borrow(&stop_loss_condition, 1)
        };
        pocket.take_profit_condition = TradingStopCondition {
            stopped_with: *vector::borrow(&take_profit_condition, 0),
            value: *vector::borrow(&take_profit_condition, 1)
        };
        pocket.auto_close_conditions = create_close_conditions(&auto_close_conditions);

        // compute other state
        if (pocket.next_scheduled_execution_at == pocket.start_at) {
            pocket.start_at = start_at;
            pocket.next_scheduled_execution_at = start_at;
        } else {
            pocket.start_at = start_at;
        };

        // validate pocket
        validate_pocket(pocket);

        // commit data changes
        commit_pocket_data(id, *pocket);
    }

    // update withdrawal stats
    public(friend) fun update_withdrawal_stats(
        id: String
    ) acquires PocketStore, ResourceAccountStore {
        let pocket = &mut get_pocket(id);

        pocket.base_coin_balance = 0;
        pocket.target_coin_balance = 0;
        pocket.status = STATUS_WITHDRAWN;

        // commit data changes
        commit_pocket_data(id, *pocket);
    }

    // update deposit stats
    public(friend) fun update_deposit_stats(
        id: String,
        amount: u64,
    ) acquires PocketStore, ResourceAccountStore {
        let pocket = &mut get_pocket(id);

        pocket.total_deposited_base_amount = pocket.total_deposited_base_amount + amount;
        pocket.base_coin_balance = pocket.base_coin_balance + amount;

        // commit data changes
        commit_pocket_data(id, *pocket);
    }

    // update close position stats
    public(friend) fun update_close_position_stats(
        id: String,
        swapped_target_coin_amount: u64,
        received_base_coin_amount: u64,
    ) acquires PocketStore, ResourceAccountStore {
        let pocket = &mut get_pocket(id);

        // update stats
        pocket.total_closed_position_in_target_amount = pocket.total_closed_position_in_target_amount + swapped_target_coin_amount;
        pocket.total_received_fund_in_base_amount = pocket.total_received_fund_in_base_amount + received_base_coin_amount;

        // update balance
        pocket.base_coin_balance = pocket.base_coin_balance + received_base_coin_amount;
        pocket.target_coin_balance = pocket.target_coin_balance - swapped_target_coin_amount;

        // close position means also close pocket
        pocket.status = STATUS_CLOSED;

        // commit data changes
        commit_pocket_data(id, *pocket);
    }

    // update trading stats
    public(friend) fun update_trading_stats(
        id: String,
        swapped_base_coin_amount: u64,
        received_target_coin_amount: u64,
    ) acquires PocketStore, ResourceAccountStore {
        let pocket = &mut get_pocket(id);

        // update trading epoch stats
        pocket.next_scheduled_execution_at = timestamp::now_seconds() + pocket.frequency;
        pocket.executed_batch_amount = pocket.executed_batch_amount + 1;

        // compute trading status
        pocket.total_swapped_base_amount = pocket.total_swapped_base_amount + swapped_base_coin_amount;
        pocket.total_received_target_amount = pocket.total_received_target_amount + received_target_coin_amount;
        pocket.base_coin_balance = pocket.base_coin_balance - swapped_base_coin_amount;
        pocket.target_coin_balance = pocket.target_coin_balance + received_target_coin_amount;

        // commit changes
        commit_pocket_data(id, *pocket);
    }

    // close pocket on behalf of owner
    public(friend) fun mark_as_closed(pocket_id: String): u64 acquires PocketStore, ResourceAccountStore {
        // extract pocket
        let pocket = &mut get_pocket(pocket_id);

        // update data
        pocket.status = STATUS_CLOSED;

        // commit
        commit_pocket_data(pocket_id, *pocket);

        // return status
        return pocket.status
    }

    // restart pocket on behalf of owner
    public(friend) fun mark_as_active(pocket_id: String): u64 acquires PocketStore, ResourceAccountStore {
        // extract pocket
        let pocket = &mut get_pocket(pocket_id);

        // modify data
        pocket.status = STATUS_ACTIVE;

        commit_pocket_data(pocket_id, *pocket);

        return pocket.status
    }

    // pause pocket on behalf of owner
    public(friend) fun mark_as_paused(pocket_id: String): u64 acquires PocketStore, ResourceAccountStore {
        // extract pocket
        let pocket = &mut get_pocket(pocket_id);

        // modify data
        pocket.status = STATUS_PAUSED;

        commit_pocket_data(pocket_id, *pocket);

        return pocket.status
    }

    // check must be owner of a pocket
    public(friend) fun must_be_owner_of(
        pocket_id: String,
        signer: &signer,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        let result = signer::address_of(signer) == pocket.owner;

        if (raise_error) {
            assert!(result, error::permission_denied(INVALID_SIGNER));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_able_to_update(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let result = is_owner_of(pocket, signer) &&
            pocket.status != STATUS_CLOSED &&
            pocket.status != STATUS_WITHDRAWN;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_UPDATE));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_able_to_close(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let valid_signer = is_owner_of(pocket, signer) || platform::is_operator(address_of(signer), false);
        let result = valid_signer &&
            pocket.status != STATUS_CLOSED &&
            pocket.status != STATUS_WITHDRAWN;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_CLOSE));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_able_to_pause(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let result = is_owner_of(pocket, signer) &&
            pocket.status == STATUS_ACTIVE;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_PAUSE));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_able_to_restart(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let result = is_owner_of(pocket, signer) &&
            pocket.status == STATUS_PAUSED;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_RESTART));
        };

        return result
    }

    // check whether the pocket is able to deposit
    public(friend) fun is_able_to_deposit<BaseCoin>(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let type_info_x = type_info::type_name<BaseCoin>();

        let result = is_owner_of(pocket, signer) &&
            pocket.base_coin_type == type_info_x &&
            pocket.status != STATUS_CLOSED &&
            pocket.status != STATUS_WITHDRAWN &&
            platform::is_allowed_target(
                type_info_x,
                raise_error
            );

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_DEPOSIT));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_able_to_withdraw<BaseCoin, TargetCoin>(
        signer: &signer,
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let type_info_x = type_info::type_name<BaseCoin>();
        let type_info_y = type_info::type_name<TargetCoin>();

        // enabled check for authorized Coin type
        let result = is_owner_of(pocket, signer) &&
            pocket.status == STATUS_CLOSED &&
            pocket.base_coin_type == type_info_x &&
            pocket.target_coin_type == type_info_y;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_ABLE_TO_WITHDRAW));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_ready_to_swap<BaseCoin, TargetCoin>(
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let type_info_x = type_info::type_name<BaseCoin>();
        let type_info_y = type_info::type_name<TargetCoin>();

        let result = pocket.status == STATUS_ACTIVE &&
            pocket.base_coin_balance >= pocket.batch_volume &&
            pocket.start_at <= timestamp::now_seconds() &&
            pocket.next_scheduled_execution_at <= timestamp::now_seconds() &&
            pocket.base_coin_type == type_info_x &&
            pocket.target_coin_type == type_info_y;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_READY_TO_SWAP));
        };

        return result
    }

    // check whether the pocket is able to update
    public(friend) fun is_ready_to_close_position<BaseCoin, TargetCoin>(
        pocket_id: String,
        raise_error: bool
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);

        let type_info_x = type_info::type_name<BaseCoin>();
        let type_info_y = type_info::type_name<TargetCoin>();

        let result = pocket.status != STATUS_WITHDRAWN &&
            pocket.target_coin_balance > 0 &&
            pocket.start_at <= timestamp::now_seconds() &&
            pocket.base_coin_type == type_info_x &&
            pocket.target_coin_type == type_info_y;

        if (raise_error) {
            assert!(result, error::invalid_state(NOT_READY_TO_CLOSE_POSITION));
        };

        return result
    }

    // get trading info of a pocket
    public(friend) fun get_trading_info(
        pocket_id: String
    ): (address, u64, String, String, u64, u64, u64, u64) acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        return (
            pocket.owner,
            pocket.amm,
            pocket.base_coin_type,
            pocket.target_coin_type,
            pocket.batch_volume,
            pocket.base_coin_balance,
            pocket.target_coin_balance,
            pocket.status
        )
    }

    // check whether the pocket should be auto closed
    public(friend) fun should_auto_close(
        pocket_id: String
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        let stop_conditions = pocket.auto_close_conditions;

        let should_stop = false;

        vector::for_each_ref<AutoCloseCondition>(&stop_conditions, |c| {
            let condition: &AutoCloseCondition = c;

            // so dirty switch but nothing I can do :(
            if (condition.closed_with == CLOSED_WITH_END_TIME) {
                should_stop = should_stop || timestamp::now_seconds() >= condition.value;
            } else if (condition.closed_with == CLOSED_WITH_BATCH_AMOUNT) {
                should_stop = should_stop || pocket.executed_batch_amount >= condition.value;
            } else if (condition.closed_with == CLOSED_WITH_RECEIVED_TARGET_AMOUNT) {
                should_stop = should_stop || pocket.total_received_target_amount >= condition.value;
            } else if (condition.closed_with == CLOSED_WITH_SPENT_BASE_AMOUNT) {
                should_stop = should_stop || pocket.total_swapped_base_amount >= condition.value;
            };
        });

        return should_stop
    }

    // check whether the pocket should open position
    public(friend) fun should_open_position(
        pocket_id: String,
        swapped_base_coin_amount: u64,
        received_target_coin_amount: u64
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        let condition = &pocket.open_position_condition;

        let expected_amount_out = u256::div(
            u256::mul(
                u256::from_u64(received_target_coin_amount),
                u256::from_u64(pocket.batch_volume)
            ),
            u256::from_u64(swapped_base_coin_amount)
        );

        if (condition.operator == OPERATOR_LT) {
            return u256::as_u64(expected_amount_out) < condition.value_x
        };

        if (condition.operator == OPERATOR_LTE) {
            return u256::as_u64(expected_amount_out) <= condition.value_x
        };

        if (condition.operator == OPERATOR_EQ) {
            return u256::as_u64(expected_amount_out) == condition.value_x
        };

        if (condition.operator == OPERATOR_NEQ) {
            return u256::as_u64(expected_amount_out) != condition.value_x
        };

        if (condition.operator == OPERATOR_GT) {
            return u256::as_u64(expected_amount_out) > condition.value_x
        };

        if (condition.operator == OPERATOR_GTE) {
            return u256::as_u64(expected_amount_out) >= condition.value_x
        };

        if (condition.operator == OPERATOR_BW) {
            return u256::as_u64(expected_amount_out) >= condition.value_x &&
                u256::as_u64(expected_amount_out) <= condition.value_y
        };

        if (condition.operator == OPERATOR_NBW) {
            return u256::as_u64(expected_amount_out) <= condition.value_x ||
                u256::as_u64(expected_amount_out) >= condition.value_y
        };

        return true
    }

    // check whether a pocket should be stop loss
    public(friend) fun should_stop_loss<BaseCoin, TargetCoin>(
        pocket_id: String,
        swapped_target_coin_amount: u64,
        received_base_coin_amount: u64
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        let stop_loss_condition = &pocket.stop_loss_condition;

        // currently we only check for price condition
        if (stop_loss_condition.stopped_with != STOPPED_WITH_PRICE) {
            return false
        };

        let target_coin_decimals = coin::decimals<TargetCoin>();
        let expected_amount_out = u256::div(
            u256::mul(
                u256::from_u64(received_base_coin_amount),
                u256::from_u128(
                    math::pow(
                        10,
                        (target_coin_decimals as u128)
                    )
                )
            ),
            u256::from_u64(swapped_target_coin_amount)
        );

        return u256::as_u64(expected_amount_out) <= stop_loss_condition.value
    }

    // check whether a pocket should take profit
    public(friend) fun should_take_profit<BaseCoin, TargetCoin>(
        pocket_id: String,
        swapped_target_coin_amount: u64,
        received_base_coin_amount: u64
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = &get_pocket(pocket_id);
        let condition = &pocket.take_profit_condition;

        // currently we only check for price condition
        if (condition.stopped_with != STOPPED_WITH_PRICE) {
            return false
        };

        let target_coin_decimals = coin::decimals<TargetCoin>();
        let expected_amount_out = u256::div(
            u256::mul(
                u256::from_u64(received_base_coin_amount),
                u256::from_u128(
                    math::pow(
                        10,
                        (target_coin_decimals as u128)
                    )
                )
            ),
            u256::from_u64(swapped_target_coin_amount)
        );

        return u256::as_u64(expected_amount_out) >= condition.value
    }

    // check if the pocket is using pcs
    public(friend) fun is_pcs_amm(
        pocket_id: String,
    ): bool acquires PocketStore, ResourceAccountStore {
        let pocket = get_pocket(pocket_id);
        return pocket.amm == AMM_PCS
    }

    // get pocket
    public(friend) fun get_pocket(
        pocket_id: String
    ): Pocket acquires PocketStore, ResourceAccountStore {
        // let's find the resource signer of the pocket
        let owner_address = get_pocket_signer_resource(pocket_id);

        // now we query the pocket
        let store = borrow_global<PocketStore>(owner_address);
        let pockets = &store.pockets;

        // we check if the pocket id existed
        assert!(
            table_with_length::contains(
                pockets,
                pocket_id
            ),
            error::not_found(NOT_EXISTED_ID)
        );

        // extract pocket
        let pocket = table_with_length::borrow(pockets, pocket_id);

        // we check if owner matches with signer
        assert!(
            pocket.owner == owner_address,
            error::permission_denied(INVALID_SIGNER)
        );

        // return pocket
        return *pocket
    }


    // create close conditions based on u64 vector
    fun create_close_conditions(conditions: &vector<u64>): vector<AutoCloseCondition> {
        assert!(
            vector::length<u64>(conditions) % 2 == 0,
            error::invalid_argument(INVALID_VALUE)
        );
        let close_conditions = vector::empty<AutoCloseCondition>();

        let index = 0;
        while (index < vector::length(conditions)) {
            // build up condition
            let condition = AutoCloseCondition {
                closed_with: *vector::borrow(conditions, index),
                value: *vector::borrow(conditions, index + 1)
            };

            // validate condition here
            validate_auto_close_condition(&condition);

            vector::push_back(
                &mut close_conditions,
                AutoCloseCondition {
                    closed_with: *vector::borrow(conditions, index),
                    value: *vector::borrow(conditions, index + 1)
                }
            );

            index = index + 2;
        };

        return close_conditions
    }

    // get pocket mut
    fun commit_pocket_data(
        pocket_id: String,
        updated_pocket: Pocket
    ) acquires PocketStore, ResourceAccountStore {
        // let's find the resource signer of the pocket
        let owner_address = get_pocket_signer_resource(pocket_id);

        // now we query the pocket
        let store = borrow_global_mut<PocketStore>(owner_address);
        let pockets = &mut store.pockets;

        // return pocket
        table_with_length::upsert(pockets, pocket_id, updated_pocket)
    }

    // get pocket resource signer
    fun get_pocket_signer_resource(pocket_id: String): address acquires ResourceAccountStore {
        let owner_map = &borrow_global<ResourceAccountStore>(HAMSTERPOCKET).owner_map;

        // make sure the system must be knowing the signer of the pocket
        assert!(
            table_with_length::contains<String, address>(
                owner_map,
                pocket_id
            ),
            error::not_found(NOT_EXISTED_ID)
        );

        // extract signer cap
        return *table_with_length::borrow(owner_map, pocket_id)
    }

    // check whether the pocket is valid
    fun validate_pocket(pocket: &Pocket) {
        assert!(pocket.id != string::utf8(b""), error::invalid_state(EMPTY_ID));

        assert!(pocket.owner != @0x0, error::invalid_state(ZERO_ADDRESS));

        assert!(pocket.base_coin_type != string::utf8(b""), error::invalid_state(ZERO_ADDRESS));
        assert!(
            platform::is_allowed_target(pocket.base_coin_type, false),
            error::permission_denied(INVALID_TARGET)
        );

        assert!(pocket.target_coin_type != string::utf8(b""), error::invalid_state(ZERO_ADDRESS));
        assert!(
            platform::is_allowed_target(pocket.target_coin_type, false),
            error::permission_denied(INVALID_TARGET)
        );

        assert!(pocket.amm == AMM_PCS, error::invalid_state(INVALID_AMM));
        assert!(pocket.start_at > 0, error::invalid_state(ZERO_VALUE));
        assert!(pocket.frequency > 0, error::invalid_state(ZERO_VALUE));
        assert!(pocket.batch_volume > 0, error::invalid_state(ZERO_VALUE));

        validate_open_position_condition(&pocket.open_position_condition);
        validate_trading_stop_condition(&pocket.stop_loss_condition);
        validate_trading_stop_condition(&pocket.take_profit_condition);
        for_each((copy pocket).auto_close_conditions, |condition| validate_auto_close_condition(&condition));
    }

    // check whether the pocket is able to deposit
    fun is_owner_of(pocket: &Pocket, signer: &signer): bool {
        return signer::address_of(signer) == pocket.owner
    }

    // check whether the open position condition is valid
    fun validate_open_position_condition(comparison: &ValueComparision) {
        // valid operator must be less than 0x8
        assert!(comparison.operator <= 0x8, error::invalid_state(INVALID_VALUE));

        // won't check if user unset the condition
        if (comparison.operator == UNSET) return;

        if (comparison.operator == OPERATOR_BW || comparison.operator == OPERATOR_NBW) {
            assert!(comparison.value_y >= comparison.value_x, error::invalid_state(INVALID_VALUE));
            assert!(comparison.value_x > 0, error::invalid_state(ZERO_VALUE));
            return
        };

        assert!(comparison.value_x > 0, error::invalid_state(ZERO_VALUE));
    }

    // check whether the open position condition is valid
    fun validate_trading_stop_condition(stop_condition: &TradingStopCondition) {
        // valid operator must be less than 0x3
        assert!(stop_condition.stopped_with <= 0x3, error::invalid_state(INVALID_VALUE));

        // validate
        if (stop_condition.stopped_with == UNSET) return;
        assert!(stop_condition.value > 0, error::invalid_state(error::invalid_state(INVALID_VALUE)));
    }

    // check whether the open position condition is valid
    fun validate_auto_close_condition(condition: &AutoCloseCondition) {
        // valid operator must be less than 0x4
        assert!(condition.closed_with <= 0x3, error::invalid_state(INVALID_VALUE));

        // validate
        assert!(condition.value > 0, error::invalid_state(ZERO_VALUE));
    }
}


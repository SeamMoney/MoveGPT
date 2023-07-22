// hamsterpocket::chef is acting as an entrypoint for the whole program
module hamsterpocket::chef {
    use aptos_framework::resource_account;
    use aptos_framework::account;
    use aptos_framework::code;
    use aptos_std::from_bcs::{to_address};

    use pancake::router;

    use std::string;
    use std::signer::address_of;
    use std::error;

    use hamsterpocket::pocket;
    use hamsterpocket::platform;
    use hamsterpocket::vault;
    use hamsterpocket::event;
    use std::vector;

    const DEPLOYER: address = @deployer;
    const HAMSTERPOCKET: address = @hamsterpocket;

    const INVALID_ADMIN: u64 = 0x0;
    const INVALID_TOKEN_TYPE: u64 = 0x1;
    const UNVAILABLE_AMM: u64 = 0x2;
    const BUY_CONDITION_NOT_REACH: u64 = 0x3;
    const STOP_CONDITION_NOT_REACH: u64 = 0x4;
    const INVALID_OWNER: u64 = 0x5;

    // initialize module
    fun init_module(sender: &signer) {
        let deployer_signer_cap = resource_account::retrieve_resource_account_cap(
            sender,
            @deployer
        );
        let resource_signer = account::create_signer_with_capability(
            &deployer_signer_cap
        );

        assert!(address_of(sender) == address_of(&resource_signer), INVALID_ADMIN);
        assert!(address_of(sender) == HAMSTERPOCKET, INVALID_ADMIN);

        // initialize sub modules
        platform::initialize(
            &resource_signer,
            deployer_signer_cap
        );
        pocket::initialize(&resource_signer);
        vault::initialize(&resource_signer);
        event::initialize(&resource_signer);
    }

    // try closing position
    public entry fun operator_close_position<BaseCoin, TargetCoin>(
        signer: &signer,
        pocket_id: vector<u8>,
        min_amount_out: u64
    ) {
        // make sure the signer is operator
        platform::is_operator(address_of(signer), true);

        // now we handle dca
        let pocket_id = string::utf8(pocket_id);

        // make sure we are using pcs amm
        assert!(
            pocket::is_pcs_amm(pocket_id),
            error::invalid_state(UNVAILABLE_AMM)
        );

        // check if pocket is ready to close position
        pocket::is_ready_to_close_position<BaseCoin, TargetCoin>(pocket_id, true);

        // now we make the swap
        let (
            owner,
            amm,
            base_coin_type,
            target_coin_type,
            _,
            _,
            target_coin_balance,
            _
        ) = pocket::get_trading_info(pocket_id);
        let (amount_in, amount_out) = vault::make_swap<TargetCoin, BaseCoin>(
            owner,
            target_coin_balance,
            min_amount_out,
            amm
        );

        // now we check whether the pocket should stop loss or take profit
        let should_stop_loss = pocket::should_stop_loss<BaseCoin, TargetCoin>(
            pocket_id,
            amount_in,
            amount_out
        );
        let should_take_profit = pocket::should_take_profit<BaseCoin, TargetCoin>(
            pocket_id,
            amount_in,
            amount_out
        );

        // update open position and trading stats
        assert!(
            should_stop_loss || should_take_profit,
            error::invalid_state(STOP_CONDITION_NOT_REACH)
        );
        pocket::update_close_position_stats(pocket_id, amount_in, amount_out);

        // Check for reason
        let reason = string::utf8(b"OPERATOR_STOPPED_LOSS");
        if (should_take_profit) {
            reason = string::utf8(b"OPERATOR_TOOK_PROFIT")
        };

        // now we emit event
        event::emit_update_close_position_stats(
            pocket_id,
            address_of(signer),
            amount_out,
            base_coin_type,
            amount_in,
            target_coin_type,
            reason
        );

        let (
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            status
        ) = pocket::get_trading_info(pocket_id);

        // emit event
        event::emit_update_pocket_status_event(
            pocket_id,
            address_of(signer),
            status,
            string::utf8(b"OPERATOR_CLOSED_POCKET_DUE_TO_STOP_CONDITION_REACHED")
        );
    }

    // making dca swap
    public entry fun operator_make_dca_swap<BaseCoin, TargetCoin>(
        signer: &signer,
        pocket_id: vector<u8>,
        min_amount_out: u64
    ) {
        // make sure the signer is operator
        platform::is_operator(address_of(signer), true);

        // now we handle dca
        let pocket_id = string::utf8(pocket_id);

        // make sure we are using pcs amm
        assert!(
            pocket::is_pcs_amm(pocket_id),
            error::invalid_state(UNVAILABLE_AMM)
        );

        // also make sure the pocket is ready to swap
        pocket::is_ready_to_swap<BaseCoin, TargetCoin>(pocket_id, true);

        // now we make dca swap
        let (
            owner,
            amm,
            base_coin_type,
            target_coin_type,
            batch_volume,
            _,
            _,
            _
        ) = pocket::get_trading_info(pocket_id);
        let (amount_in, amount_out) = vault::make_swap<BaseCoin, TargetCoin>(
            owner,
            batch_volume,
            min_amount_out,
            amm
        );

        // update open position and trading stats
        assert!(
            pocket::should_open_position(
                pocket_id,
                amount_in,
                amount_out
            ),
            error::invalid_state(BUY_CONDITION_NOT_REACH)
        );
        pocket::update_trading_stats(pocket_id, amount_in, amount_out);
        event::emit_update_trading_stats_event(
            pocket_id,
            address_of(signer),
            amount_in,
            base_coin_type,
            amount_out,
            target_coin_type,
            string::utf8(b"OPERATOR_MADE_SWAP")
        );

        // check if autoclose condition reaches
        if (pocket::should_auto_close(pocket_id)) {
            let status = pocket::mark_as_closed(pocket_id);

            // emit event
            event::emit_update_pocket_status_event(
                pocket_id,
                address_of(signer),
                status,
                string::utf8(b"OPERATOR_CLOSED_POCKET_DUE_TO_CONDITION_REACHED")
            );
        }
    }

    // close position and withdraw from pocket
    public entry fun close_position_and_withdraw<BaseCoin, TargetCoin>(
        signer: &signer,
        id: vector<u8>,
        mint_amount_out: u64
    ) {
        close_position<BaseCoin, TargetCoin>(signer, id, mint_amount_out);
        withdraw<BaseCoin, TargetCoin>(signer, id);
    }

    // close and withdraw from pocket
    public entry fun close_and_withdraw_pocket<BaseCoin, TargetCoin>(
        signer: &signer,
        id: vector<u8>,
    ) {
        let pocket_id = string::utf8(id);
        let (
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            status
        ) = pocket::get_trading_info(pocket_id);

        if (status <= 0x1) {
            // only close if the pocket status is active or paused
            close_pocket(signer, id);
        };

        withdraw<BaseCoin, TargetCoin>(signer, id);
    }

    // create and deposit pocket
    public entry fun create_and_deposit_to_pocket<BaseCoin, TargetCoin>(
        signer: &signer,
        id: vector<u8>,
        amm: u64,
        start_at: u64,
        frequency: u64,
        batch_volume: u64,
        open_position_condition: vector<u64>,
        take_profit_condition: vector<u64>,
        stop_loss_condition: vector<u64>,
        auto_closed_conditions: vector<u64>,
        deposit_amount: u64,
    ) {
        create_pocket<BaseCoin, TargetCoin>(
            signer,
            id,
            amm,
            start_at,
            frequency,
            batch_volume,
            open_position_condition,
            take_profit_condition,
            stop_loss_condition,
            auto_closed_conditions,
        );

        deposit<BaseCoin>(signer, id, deposit_amount)
    }

    // user close position
    public entry fun close_position<BaseCoin, TargetCoin>(
        signer: &signer,
        pocket_id: vector<u8>,
        min_amount_out: u64
    ) {
        let pocket_id = string::utf8(pocket_id);

        // check the signer must be the owner of a pocket
        pocket::must_be_owner_of(pocket_id, signer, true);

        // now we make the swap
        let (
            owner,
            amm,
            base_coin_type,
            target_coin_type,
            _,
            _,
            target_coin_balance,
            _
        ) = pocket::get_trading_info(pocket_id);
        let (amount_in, amount_out) = vault::make_swap<TargetCoin, BaseCoin>(
            owner,
            target_coin_balance,
            min_amount_out,
            amm
        );

        // update close position stats
        pocket::update_close_position_stats(pocket_id, amount_in, amount_out);

        // now we emit event
        event::emit_update_close_position_stats(
            pocket_id,
            address_of(signer),
            amount_out,
            base_coin_type,
            amount_in,
            target_coin_type,
            string::utf8(b"USER_CLOSED_POSITION")
        );

        // extract trading info
        let (
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            status
        ) = pocket::get_trading_info(pocket_id);

        // emit event
        event::emit_update_pocket_status_event(
            pocket_id,
            address_of(signer),
            status,
            string::utf8(b"USER_CLOSED_POCKET")
        );
    }

    // update pocket
    public entry fun create_pocket<BaseCoin, TargetCoin>(
        signer: &signer,
        id: vector<u8>,
        amm: u64,
        start_at: u64,
        frequency: u64,
        batch_volume: u64,
        open_position_condition: vector<u64>,
        take_profit_condition: vector<u64>,
        stop_loss_condition: vector<u64>,
        auto_closed_conditions: vector<u64>,
    ) {
        let pocket_id = string::utf8(id);

        // create pocket
        pocket::create_pocket<BaseCoin, TargetCoin>(
            signer,
            pocket_id,
            amm,
            start_at,
            frequency,
            batch_volume,
            open_position_condition,
            take_profit_condition,
            stop_loss_condition,
            auto_closed_conditions,
        );

        // emit event
        event::emit_create_pocket_event(
            pocket_id,
            address_of(signer),
            pocket::get_pocket(pocket_id),
            string::utf8(b"USER_CREATED_POCKET")
        );
    }

    // update pocket
    public entry fun update_pocket(
        signer: &signer,
        id: vector<u8>,
        start_at: u64,
        frequency: u64,
        batch_volume: u64,
        open_position_condition: vector<u64>,
        take_profit_condition: vector<u64>,
        stop_loss_condition: vector<u64>,
        auto_closed_conditions: vector<u64>,
    ) {
        let pocket_id = string::utf8(id);

        // make sure the pocket is able to update
        pocket::is_able_to_update(signer, pocket_id, true);

        // now we update pocket
        pocket::update_pocket(
            pocket_id,
            start_at,
            frequency,
            batch_volume,
            open_position_condition,
            take_profit_condition,
            stop_loss_condition,
            auto_closed_conditions,
        );

        // emit event
        event::emit_update_pocket_event(
            pocket_id,
            address_of(signer),
            pocket::get_pocket(pocket_id),
            string::utf8(b"USER_UPDATED_POCKET")
        );
    }

    // deposit
    public entry fun deposit<CoinType>(signer: &signer, id: vector<u8>, amount: u64) {
        let pocket_id = string::utf8(id);

        let (
            _,
            _,
            base_coin_type,
            _,
            _,
            _,
            _,
            _
        ) = pocket::get_trading_info(pocket_id);

        // make sure the pocket is able to deposit
        pocket::is_able_to_deposit<CoinType>(signer, pocket_id, true);

        // deposit to vault
        vault::deposit<CoinType>(
            signer,
            amount
        );

        // update deposit stats
        pocket::update_deposit_stats(pocket_id, amount);

        // emit event
        event::emit_update_deposit_stats_event(
            pocket_id,
            address_of(signer),
            amount,
            base_coin_type,
            string::utf8(b"USER_DEPOSITED_ASSET")
        );
    }

    // withdraw
    public entry fun withdraw<BaseCoin, TargetCoin>(signer: &signer, id: vector<u8>) {
        let pocket_id = string::utf8(id);

        // make sure the pocket is able to withdraw
        pocket::is_able_to_withdraw<BaseCoin, TargetCoin>(signer, pocket_id, true);

        // extract trading info
        let (
            _,
            _,
            base_coin_type,
            target_coin_type,
            _,
            base_coin_balance,
            target_coin_balance,
            _
        ) = pocket::get_trading_info(pocket_id);

        // withdraw from vault
        vault::withdraw<BaseCoin>(
            signer,
            base_coin_balance
        );

        // withdraw from vault
        vault::withdraw<TargetCoin>(
            signer,
            target_coin_balance
        );

        // update deposit stats
        pocket::update_withdrawal_stats(pocket_id);

        // emit event
        event::emit_update_withdrawal_stats_event(
            pocket_id,
            address_of(signer),
            base_coin_balance,
            base_coin_type,
            target_coin_balance,
            target_coin_type,
            string::utf8(b"USER_WITHDREW_ASSETS")
        );
    }

    // pause pocket
    public entry fun pause_pocket(signer: &signer, id: vector<u8>) {
        let pocket_id = string::utf8(id);

        // make sure the pocket is able to pause
        pocket::is_able_to_pause(signer, pocket_id, true);

        // mark as paused
        let status = pocket::mark_as_paused(pocket_id);

        // emit event
        event::emit_update_pocket_status_event(
            pocket_id,
            address_of(signer),
            status,
            string::utf8(b"USER_PAUSED_POCKET")
        );
    }

    // restart pocket
    public entry fun restart_pocket(signer: &signer, id: vector<u8>) {
        let pocket_id = string::utf8(id);

        // make sure the pocket is able to restart
        pocket::is_able_to_restart(signer, pocket_id, true);

        // mark as active
        let status = pocket::mark_as_active(pocket_id);

        // emit event
        event::emit_update_pocket_status_event(
            pocket_id,
            address_of(signer),
            status,
            string::utf8(b"USER_RESTARTED_POCKET")
        );
    }

    // restart pocket
    public entry fun close_pocket(signer: &signer, id: vector<u8>) {
        let pocket_id = string::utf8(id);

        // make sure the pocket is able to close
        pocket::is_able_to_close(signer, pocket_id, true);

        // mark as closed
        let status = pocket::mark_as_closed(pocket_id);

        // emit event
        event::emit_update_pocket_status_event(
            pocket_id,
            address_of(signer),
            status,
            string::utf8(b"USER_CLOSED_POCKET")
        );
    }

    // set operator, only available for admin
    public entry fun set_operator(signer: &signer, address: vector<u8>, value: bool) {
        platform::is_admin(address_of(signer), true);
        platform::set_operator(
            to_address(address),
            value
        );

        // emit event
        event::emit_update_allowed_operator_event(
            address_of(signer),
            to_address(address),
            value
        );
    }

    // set interactive target, only available for admin
    public entry fun set_interactive_target(signer: &signer, target: vector<u8>, value: bool) {
        platform::is_admin(address_of(signer), true);
        platform::set_interactive_target(
            string::utf8(target),
            value
        );

        // emit event
        event::emit_update_allowed_target_event(
            address_of(signer),
            string::utf8(target),
            value
        );
    }

    // set transfer admin
    public entry fun transfer_admin(signer: &signer, address: vector<u8>) {
        platform::is_admin(address_of(signer), true);

        // unset permission
        platform::set_admin(
            address_of(signer),
            false
        );

        // emit event
        event::emit_update_allowed_admin(
            address_of(signer),
            address_of(signer),
            false
        );

        // transfer to new admin
        platform::set_admin(
            to_address(address),
            true
        );

        // emit event
        event::emit_update_allowed_admin(
            address_of(signer),
            to_address(address),
            true
        );
    }

    // upgrade programatically, only admin can perform upgrade
    public entry fun upgrade(
        signer: &signer,
        metadata_serialized: vector<u8>,
        code: vector<vector<u8>>
    ) {
        platform::is_admin(address_of(signer), true);

        let resource_signer = platform::get_resource_signer();
        code::publish_package_txn(&resource_signer, metadata_serialized, code);

        // emit event
        event::emit_upgrade_event(address_of(signer));
    }

    // get pocket data
    #[view]
    public fun get_pocket(id: vector<u8>): pocket::Pocket {
        return pocket::get_pocket(
            string::utf8(id)
        )
    }

    // get pocket data
    #[view]
    public fun get_multiple_pockets(id_list: vector<vector<u8>>): vector<pocket::Pocket> {
        return vector::map(id_list, |id_bytes| {
            pocket::get_pocket(
                string::utf8(id_bytes)
            )
        })
    }

    // get pocket data
    #[view]
    public fun get_delegated_vault_address(address: vector<u8>): address {
        return address_of(
            &vault::get_resource_signer(
                to_address(address)
            )
        )
    }

    // check for allowed target
    #[view]
    public fun is_allowed_target(target: vector<u8>): bool {
        return platform::is_allowed_target(
            string::utf8(target),
            false
        )
    }

    // check for allowed operator
    #[view]
    public fun is_operator(address: vector<u8>): bool {
        return platform::is_operator(
            to_address(address),
            false
        )
    }

    // check for allowed admin
    #[view]
    public fun is_admin(address: vector<u8>): bool {
        return platform::is_admin(
            to_address(address),
            false
        )
    }

    // get quote
    #[view]
    public fun get_quote<BaseCoin, TargetCoin>(amount_in: u64): u64 {
        return router::get_amount_in<TargetCoin, BaseCoin>(
            amount_in
        )
    }
}

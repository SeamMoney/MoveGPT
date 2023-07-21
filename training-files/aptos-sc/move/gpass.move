/// Module for gpass tickets.
module ggwp_core::gpass {
    use std::signer;
    use std::vector;
    use std::error;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};

    use coin::ggwp::GGWPCoin;

    // Common errors.
    const ERR_NOT_AUTHORIZED: u64 = 0x1000;
    const ERR_NOT_INITIALIZED: u64 = 0x1001;
    const ERR_ALREADY_INITIALIZED: u64 = 0x1002;
    const ERR_INVALID_PID: u64 = 0x1003;
    // GPASS errors.
    const ERR_INVALID_BURN_PERIOD: u64 = 0x1011;
    const ERR_WALLET_NOT_INITIALIZED: u64 = 0x1012;
    const ERR_INVALID_AMOUNT: u64 = 0x1013;
    const ERR_INVALID_BURN_AUTH: u64 = 0x1014;
    const ERR_BURNER_NOT_IN_LIST: u64 = 0x1015;
    // Freezing errors.
    const ERR_INVALID_PERIOD: u64 = 0x1021;
    const ERR_INVALID_ROYALTY: u64 = 0x1022;
    const ERR_ZERO_FREEZING_AMOUNT: u64 = 0x1023;
    const ERR_ZERO_UNFREEZE_AMOUNT: u64 = 0x1024;
    const ERR_ZERO_GPASS_EARNED: u64 = 0x1025;

    /// Initialize module.
    public entry fun initialize(
        ggwp_core: &signer,
        accumulative_fund: address,
        burn_period: u64,
        reward_period: u64,
        royalty: u8,
        unfreeze_royalty: u8,
        unfreeze_lock_period: u64,
    ) {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));

        if (exists<GpassInfo>(ggwp_core_addr) && exists<GpassEvents>(ggwp_core_addr) &&
            exists<FreezingInfo>(ggwp_core_addr) && exists<FreezingEvents>(ggwp_core_addr))
        {
            assert!(false, ERR_ALREADY_INITIALIZED);
        };

        assert!(burn_period != 0, ERR_INVALID_BURN_PERIOD);
        assert!(reward_period != 0, ERR_INVALID_PERIOD);
        assert!(royalty <= 100, ERR_INVALID_ROYALTY);
        assert!(unfreeze_royalty <= 100, ERR_INVALID_ROYALTY);

        if (!exists<GpassInfo>(ggwp_core_addr)) {
            let gpass_info = GpassInfo {
                burn_period: burn_period,
                total_amount: 0,
                burners: vector::empty<address>(),
            };
            move_to(ggwp_core, gpass_info);
        };

        if (!exists<GpassEvents>(ggwp_core_addr)) {
            move_to(ggwp_core, GpassEvents {
                mint_events: account::new_event_handle<MintEvent>(ggwp_core),
                burn_events: account::new_event_handle<BurnEvent>(ggwp_core),
            });
        };

        if (!exists<FreezingInfo>(ggwp_core_addr)) {
            let now = timestamp::now_seconds();
            let freezing_info = FreezingInfo {
                treasury: coin::zero<GGWPCoin>(),
                accumulative_fund: accumulative_fund,
                total_freezed: 0,
                total_users_freezed: 0,
                reward_period: reward_period,
                royalty: royalty,

                daily_gpass_reward: 0,
                daily_gpass_reward_last_reset: now,

                unfreeze_royalty: unfreeze_royalty,
                unfreeze_lock_period: unfreeze_lock_period,

                reward_table: vector::empty<RewardTableRow>(),
            };
            move_to(ggwp_core, freezing_info);
        };

        if (!exists<FreezingEvents>(ggwp_core_addr)) {
            move_to(ggwp_core, FreezingEvents {
                freeze_events: account::new_event_handle<FreezeEvent>(ggwp_core),
                withdraw_events: account::new_event_handle<WithdrawEvent>(ggwp_core),
                unfreeze_events: account::new_event_handle<UnfreezeEvent>(ggwp_core),
            });
        };
    }

    // GPASS

    /// Users accounts data.
    struct Wallet has key, store {
        // Amount with no decimals!
        amount: u64,
        last_burned: u64,
    }

    /// Common data struct with info.
    struct GpassInfo has key, store {
        burn_period: u64,
        total_amount: u64,
        burners: vector<address>,
    }

    struct GpassEvents has key {
        mint_events: EventHandle<MintEvent>,
        burn_events: EventHandle<BurnEvent>,
    }

    // GPASS Events

    struct MintEvent has drop, store {
        to: address,
        amount: u64,
        date: u64,
    }

    struct BurnEvent has drop, store {
        from: address,
        amount: u64,
        date: u64,
    }

    /// Adding the new burner in burners list.
    public entry fun add_burner(ggwp_core: &signer, burner: address) acquires GpassInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        vector::push_back(&mut gpass_info.burners, burner);
    }

    /// Removing the burner address from burner list.
    public entry fun remove_burner(ggwp_core: &signer, burner: address) acquires GpassInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let (in_list, index) = vector::index_of(&gpass_info.burners, &burner);
        assert!(in_list, ERR_BURNER_NOT_IN_LIST);
        vector::swap_remove(&mut gpass_info.burners, index);
    }

    /// Update burn period.
    public entry fun update_burn_period(ggwp_core: &signer, burn_period: u64) acquires GpassInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        gpass_info.burn_period = burn_period;
    }

    /// User creates new wallet.
    public entry fun create_wallet(user: &signer) {
        let user_addr = signer::address_of(user);
        assert!(!exists<Wallet>(user_addr), ERR_ALREADY_INITIALIZED);

        let now = timestamp::now_seconds();
        let wallet = Wallet {
            amount: 0,
            last_burned: now,
        };
        move_to(user, wallet);
    }

    /// Mint the amount of GPASS to user wallet.
    /// There is trying to burn overdues before minting.
    public fun mint_to(ggwp_core_addr: address, to: address, amount: u64) acquires Wallet, GpassInfo, GpassEvents {
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<Wallet>(to), ERR_WALLET_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(amount != 0, ERR_INVALID_AMOUNT);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let events = borrow_global_mut<GpassEvents>(ggwp_core_addr);
        let wallet = borrow_global_mut<Wallet>(to);

        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            gpass_info.total_amount = gpass_info.total_amount - wallet.amount;
            wallet.amount = 0;

            let burn_periods_passed = spent_time / gpass_info.burn_period;
            wallet.last_burned = wallet.last_burned + burn_periods_passed * gpass_info.burn_period;

            event::emit_event<BurnEvent>(
                &mut events.burn_events,
                BurnEvent { from: to, amount: amount, date: now },
            );
        };

        wallet.amount = wallet.amount + amount;
        gpass_info.total_amount = gpass_info.total_amount + amount;

        event::emit_event<MintEvent>(
            &mut events.mint_events,
            MintEvent { to: to, amount: amount, date: now },
        );
    }

    /// There is trying to burn overdues.
    public fun try_burn_in_period(gpass_info: &mut GpassInfo, wallet: &mut Wallet) {
        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            gpass_info.total_amount = gpass_info.total_amount - wallet.amount;
            wallet.amount = 0;

            let burn_periods_passed = spent_time / gpass_info.burn_period;
            wallet.last_burned = wallet.last_burned + burn_periods_passed * gpass_info.burn_period;
        };
    }

    /// User burn gpass amount from his wallet.
    /// There is trying to burn overdues before burning.
    public entry fun burn(user: &signer, ggwp_core_addr: address, amount: u64) acquires Wallet, GpassInfo, GpassEvents {
        let user_addr = signer::address_of(user);
        assert!(exists<Wallet>(user_addr), ERR_WALLET_NOT_INITIALIZED);
        assert!(amount != 0, ERR_INVALID_AMOUNT);
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let events = borrow_global_mut<GpassEvents>(ggwp_core_addr);
        let wallet = borrow_global_mut<Wallet>(user_addr);

        // Try to burn amount before burn
        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            event::emit_event<BurnEvent>(
                &mut events.burn_events,
                BurnEvent { from: user_addr, amount: wallet.amount, date: now },
            );

            gpass_info.total_amount = gpass_info.total_amount - wallet.amount;
            wallet.amount = 0;

            let burn_periods_passed = spent_time / gpass_info.burn_period;
            wallet.last_burned = wallet.last_burned + burn_periods_passed * gpass_info.burn_period;
        };

        if (wallet.amount != 0) {
            event::emit_event<BurnEvent>(
                &mut events.burn_events,
                BurnEvent { from: user_addr, amount: amount, date: now },
            );

            wallet.amount = wallet.amount - amount;
            gpass_info.total_amount = gpass_info.total_amount - amount;
        }
    }

    /// Burn the amount of GPASS from user wallet. Available only for burners.
    /// There is trying to burn overdues before burning.
    public entry fun burn_from(burner: &signer, ggwp_core_addr: address, from: address, amount: u64) acquires Wallet, GpassInfo, GpassEvents {
        assert!(exists<Wallet>(from), ERR_WALLET_NOT_INITIALIZED);
        assert!(amount != 0, ERR_INVALID_AMOUNT);
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let events = borrow_global_mut<GpassEvents>(ggwp_core_addr);
        // Note: burner is the ggwp_gateway contract.
        assert!(vector::contains(&gpass_info.burners, &signer::address_of(burner)), ERR_INVALID_BURN_AUTH);

        let wallet = borrow_global_mut<Wallet>(from);

        // Try to burn amount before mint
        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            event::emit_event<BurnEvent>(
                &mut events.burn_events,
                BurnEvent { from: from, amount: wallet.amount, date: now },
            );

            gpass_info.total_amount = gpass_info.total_amount - wallet.amount;
            wallet.amount = 0;

            let burn_periods_passed = spent_time / gpass_info.burn_period;
            wallet.last_burned = wallet.last_burned + burn_periods_passed * gpass_info.burn_period;
        };

        if (wallet.amount != 0) {
            event::emit_event<BurnEvent>(
                &mut events.burn_events,
                BurnEvent { from: from, amount: amount, date: now },
            );

            wallet.amount = wallet.amount - amount;
            gpass_info.total_amount = gpass_info.total_amount - amount;
        }
    }

    // GPASS Getters.
    #[view]
    public fun get_burn_period(ggwp_core_addr: address): u64 acquires GpassInfo {
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<GpassInfo>(ggwp_core_addr).burn_period
    }

    #[view]
    public fun get_burn_period_passed(ggwp_core_addr: address, user_addr: address): bool acquires GpassInfo, Wallet {
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        let gpass_info = borrow_global<GpassInfo>(ggwp_core_addr);
        let wallet = borrow_global<Wallet>(user_addr);

        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            true
        } else {
            false
        }
    }

    #[view]
    public fun get_total_amount(ggwp_core_addr: address): u64 acquires GpassInfo {
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<GpassInfo>(ggwp_core_addr).total_amount
    }

    #[view]
    public fun get_balance(wallet: address): u64 acquires Wallet {
        assert!(exists<Wallet>(wallet), ERR_NOT_INITIALIZED);
        borrow_global<Wallet>(wallet).amount
    }

    #[view]
    public fun get_virtual_balance(wallet: address, ggwp_core_addr: address): u64 acquires Wallet, GpassInfo {
        assert!(exists<Wallet>(wallet), ERR_NOT_INITIALIZED);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let gpass_info = borrow_global<GpassInfo>(ggwp_core_addr);
        let wallet = borrow_global<Wallet>(wallet);

        let now = timestamp::now_seconds();
        let spent_time = now - wallet.last_burned;
        if (spent_time >= gpass_info.burn_period) {
            return 0
        } else {
            return wallet.amount
        }
    }

    #[view]
    public fun get_last_burned(wallet: address): u64 acquires Wallet {
        assert!(exists<Wallet>(wallet), ERR_NOT_INITIALIZED);
        borrow_global<Wallet>(wallet).last_burned
    }

    #[view]
    public fun get_burners_list(ggwp_core_addr: address): vector<address> acquires GpassInfo {
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<GpassInfo>(ggwp_core_addr).burners
    }

    // Freezing
    /// Reward table row.
    struct RewardTableRow has store, drop, copy {
        ggwp_amount: u64,
        gpass_amount: u64
    }

    /// Common data struct with freezing info.
    struct FreezingInfo has key, store {
        treasury: Coin<GGWPCoin>,
        accumulative_fund: address,
        total_freezed: u64,
        total_users_freezed: u64,
        reward_period: u64,
        royalty: u8,

        daily_gpass_reward: u64,
        daily_gpass_reward_last_reset: u64,

        unfreeze_royalty: u8,
        unfreeze_lock_period: u64,

        reward_table: vector<RewardTableRow>,
    }

    /// Freezing user info data.
    struct UserInfo has key, store {
        freezed_amount: u64,
        freezed_time: u64,       // UnixTimestamp
        last_getting_gpass: u64, // UnixTimestamp
    }

    struct FreezingEvents has key {
        freeze_events: EventHandle<FreezeEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
        unfreeze_events: EventHandle<UnfreezeEvent>
    }

    // GPASS Events

    struct FreezeEvent has drop, store {
        user: address,
        ggwp_amount: u64,
        gpass_amount: u64,
        royalty: u64,
        date: u64,
    }

    struct WithdrawEvent has drop, store {
        user: address,
        ggwp_amount: u64,
        gpass_amount: u64,
        date: u64,
    }

    struct UnfreezeEvent has drop, store {
        user: address,
        ggwp_amount: u64,
        gpass_amount: u64,
        royalty: u64,
        date: u64,
    }

    /// Clean up reward table
    public entry fun cleanup_reward_table(ggwp_core: &signer) acquires FreezingInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        freezing_info.reward_table = vector::empty<RewardTableRow>();
    }

    /// Set up new reward table row
    public entry fun add_reward_table_row(ggwp_core: &signer, ggwp_amount: u64, gpass_amount: u64) acquires FreezingInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        let row = RewardTableRow {
            ggwp_amount: ggwp_amount,
            gpass_amount: gpass_amount,
        };
        vector::push_back(&mut freezing_info.reward_table, row);
    }

    /// Update accumulative fund address.
    public entry fun update_accumulative_fund(
        ggwp_core: &signer,
        accumulative_fund: address,
    ) acquires FreezingInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        freezing_info.accumulative_fund = accumulative_fund;
    }

    /// Update freezing parameters.
    public entry fun update_freezing_params(
        ggwp_core: &signer,
        reward_period: u64,
        royalty: u8,
        unfreeze_royalty: u8,
        unfreeze_lock_period: u64,
    ) acquires FreezingInfo {
        let ggwp_core_addr = signer::address_of(ggwp_core);
        assert!(ggwp_core_addr == @ggwp_core, error::permission_denied(ERR_NOT_AUTHORIZED));
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);

        assert!(reward_period != 0, ERR_INVALID_PERIOD);
        assert!(royalty <= 100, ERR_INVALID_ROYALTY);
        assert!(unfreeze_royalty <= 100, ERR_INVALID_ROYALTY);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        freezing_info.reward_period = reward_period;
        freezing_info.royalty = royalty;
        freezing_info.unfreeze_royalty = unfreeze_royalty;
        freezing_info.unfreeze_lock_period = unfreeze_lock_period;
    }

    /// User freezes his amount of GGWP token to get the GPASS.
    public entry fun freeze_tokens(user: &signer, ggwp_core_addr: address, freezed_amount: u64) acquires FreezingInfo, GpassInfo, UserInfo, Wallet, GpassEvents, FreezingEvents {
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<FreezingEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(freezed_amount != 0, ERR_ZERO_FREEZING_AMOUNT);

        let now = timestamp::now_seconds();
        let user_addr = signer::address_of(user);
        if (!exists<UserInfo>(user_addr)) {
            let user_info = UserInfo {
                freezed_amount: 0,
                freezed_time: 0,
                last_getting_gpass: now,
            };
            move_to(user, user_info);
        };

        if (!exists<Wallet>(user_addr)) {
            let wallet = Wallet {
                amount: 0,
                last_burned: now,
            };
            move_to(user, wallet);
        };

        let user_info = borrow_global_mut<UserInfo>(user_addr);
        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        let freezing_events = borrow_global_mut<FreezingEvents>(ggwp_core_addr);

        // Pay amount of GPASS earned by user immediately
        let gpass_earned = earned_gpass_immediately(&freezing_info.reward_table, freezed_amount);

        // Try to reset gpass daily reward

        let spent_time = now - freezing_info.daily_gpass_reward_last_reset;
        if (spent_time >= 24 * 60 * 60) {
            freezing_info.daily_gpass_reward = 0;
            freezing_info.daily_gpass_reward_last_reset = now;
        };

        if (gpass_earned > 0) {
            freezing_info.daily_gpass_reward = freezing_info.daily_gpass_reward + gpass_earned;
            mint_to(ggwp_core_addr, user_addr, gpass_earned);
        };

        // Transfer Freezed GGWP amount to treasury
        let freezed_coins = coin::withdraw<GGWPCoin>(user, freezed_amount);
        coin::merge(&mut freezing_info.treasury, freezed_coins);

        // Transfer royalty amount into accumulative fund
        let royalty_amount = calc_royalty_amount(freezed_amount, freezing_info.royalty);
        coin::transfer<GGWPCoin>(user, freezing_info.accumulative_fund, royalty_amount);

        freezing_info.total_freezed = freezing_info.total_freezed + freezed_amount;
        freezing_info.total_users_freezed = freezing_info.total_users_freezed + 1;
        user_info.freezed_amount = freezed_amount;
        user_info.freezed_time = now;
        user_info.last_getting_gpass = now;

        event::emit_event<FreezeEvent>(
            &mut freezing_events.freeze_events,
            FreezeEvent {
                user: user_addr,
                ggwp_amount: freezed_amount,
                gpass_amount: gpass_earned,
                royalty: royalty_amount,
                date: now
            },
        );
    }

    /// In every time user can withdraw GPASS earned.
    public entry fun withdraw_gpass(user: &signer, ggwp_core_addr: address) acquires FreezingInfo, UserInfo, Wallet, GpassInfo, GpassEvents, FreezingEvents {
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<FreezingEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        let user_addr = signer::address_of(user);
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Wallet>(user_addr), ERR_WALLET_NOT_INITIALIZED);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        let freezing_events = borrow_global_mut<FreezingEvents>(ggwp_core_addr);
        let user_info = borrow_global_mut<UserInfo>(user_addr);
        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let gpass_events = borrow_global_mut<GpassEvents>(ggwp_core_addr);
        let user_wallet = borrow_global_mut<Wallet>(user_addr);

        let now = timestamp::now_seconds();
        let last = user_info.last_getting_gpass;

        // If burn period passed
        let spent_time_from_burn = now - user_wallet.last_burned;
        if (spent_time_from_burn >= gpass_info.burn_period) {
            event::emit_event<BurnEvent>(
                &mut gpass_events.burn_events,
                BurnEvent { from: user_addr, amount: user_wallet.amount, date: now },
            );

            gpass_info.total_amount = gpass_info.total_amount - user_wallet.amount;
            user_wallet.amount = 0;

            let burn_periods_passed = spent_time_from_burn / gpass_info.burn_period;
            user_wallet.last_burned = user_wallet.last_burned + burn_periods_passed * gpass_info.burn_period;

            let spent_from_last_gettting_to_new_burn = user_wallet.last_burned - user_info.last_getting_gpass;
            let reward_periods_to_burn = spent_from_last_gettting_to_new_burn / freezing_info.reward_period;
            last = user_info.last_getting_gpass + reward_periods_to_burn * freezing_info.reward_period;
        };

        // If burns some where else
        let spent_time_from_getting_gpass = now - user_info.last_getting_gpass;
        if (spent_time_from_getting_gpass >= gpass_info.burn_period) {
            let spent_from_last_gettting_to_new_burn = user_wallet.last_burned - user_info.last_getting_gpass;
            let reward_periods_to_burn = spent_from_last_gettting_to_new_burn / freezing_info.reward_period;
            last = user_info.last_getting_gpass + reward_periods_to_burn * freezing_info.reward_period;
        };

        let gpass_earned = calc_earned_gpass(
            &freezing_info.reward_table,
            user_info.freezed_amount,
            now,
            last,
            freezing_info.reward_period
        );

        assert!(gpass_earned != 0, ERR_ZERO_GPASS_EARNED);

        // Try to reset gpass daily reward
        let spent_time = now - freezing_info.daily_gpass_reward_last_reset;
        if (spent_time >= 24 * 60 * 60) {
            freezing_info.daily_gpass_reward = 0;
            freezing_info.daily_gpass_reward_last_reset = now;
        };

        freezing_info.daily_gpass_reward = freezing_info.daily_gpass_reward + gpass_earned;

        let reward_period_passed = spent_time_from_getting_gpass / freezing_info.reward_period;
        user_info.last_getting_gpass = user_info.last_getting_gpass + reward_period_passed * freezing_info.reward_period;

        // Mint GPASS to user
        mint_to(ggwp_core_addr, user_addr, gpass_earned);

        event::emit_event<WithdrawEvent>(
            &mut freezing_events.withdraw_events,
            WithdrawEvent {
                user: user_addr,
                ggwp_amount: user_info.freezed_amount,
                gpass_amount: gpass_earned,
                date: now
            },
        );
    }

    // User unfreeze full amount of GGWP token.
    public entry fun unfreeze(user: &signer, ggwp_core_addr: address) acquires FreezingInfo, UserInfo, GpassInfo, Wallet, GpassEvents, FreezingEvents {
        assert!(ggwp_core_addr == @ggwp_core, ERR_INVALID_PID);
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<FreezingEvents>(ggwp_core_addr), ERR_NOT_AUTHORIZED);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassEvents>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        let user_addr = signer::address_of(user);
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Wallet>(user_addr), ERR_NOT_INITIALIZED);

        let freezing_info = borrow_global_mut<FreezingInfo>(ggwp_core_addr);
        let freezing_events = borrow_global_mut<FreezingEvents>(ggwp_core_addr);
        let user_info = borrow_global_mut<UserInfo>(user_addr);
        let gpass_info = borrow_global_mut<GpassInfo>(ggwp_core_addr);
        let gpass_events = borrow_global_mut<GpassEvents>(ggwp_core_addr);
        let user_wallet = borrow_global_mut<Wallet>(user_addr);

        assert!(user_info.freezed_amount != 0, ERR_ZERO_UNFREEZE_AMOUNT);

        let now = timestamp::now_seconds();
        let last = user_info.last_getting_gpass;

        // If burn period passed
        let spent_time_from_burn = now - user_wallet.last_burned;
        if (spent_time_from_burn >= gpass_info.burn_period) {
            event::emit_event<BurnEvent>(
                &mut gpass_events.burn_events,
                BurnEvent { from: user_addr, amount: user_wallet.amount, date: now },
            );

            gpass_info.total_amount = gpass_info.total_amount - user_wallet.amount;
            user_wallet.amount = 0;

            let burn_periods_passed = spent_time_from_burn / gpass_info.burn_period;
            user_wallet.last_burned = user_wallet.last_burned + burn_periods_passed * gpass_info.burn_period;

            let spent_from_last_gettting_to_new_burn = user_wallet.last_burned - user_info.last_getting_gpass;
            let reward_periods_to_burn = spent_from_last_gettting_to_new_burn / freezing_info.reward_period;
            last = user_info.last_getting_gpass + reward_periods_to_burn * freezing_info.reward_period;
        };

        // If burns some where else
        let spent_time_from_getting_gpass = now - user_info.last_getting_gpass;
        if (spent_time_from_getting_gpass >= gpass_info.burn_period) {
            let spent_from_last_gettting_to_new_burn = user_wallet.last_burned - user_info.last_getting_gpass;
            let reward_periods_to_burn = spent_from_last_gettting_to_new_burn / freezing_info.reward_period;
            last = user_info.last_getting_gpass + reward_periods_to_burn * freezing_info.reward_period;
        };

        let gpass_earned = calc_earned_gpass(
            &freezing_info.reward_table,
            user_info.freezed_amount,
            now,
            last,
            freezing_info.reward_period
        );

        // Try to reset gpass daily reward
        let spent_time = now - freezing_info.daily_gpass_reward_last_reset;
        if (spent_time >= 24 * 60 * 60) {
            freezing_info.daily_gpass_reward = 0;
            freezing_info.daily_gpass_reward_last_reset = now;
        };

        if (gpass_earned > 0) {
            freezing_info.daily_gpass_reward = freezing_info.daily_gpass_reward + gpass_earned;
            user_info.last_getting_gpass = now;
            mint_to(ggwp_core_addr, user_addr, gpass_earned);
        };

        let amount = user_info.freezed_amount;
        let royalty_amount = 0;
        freezing_info.total_freezed = freezing_info.total_freezed - amount;
        // Check unfreeze royalty
        if (is_withdraw_royalty(now, user_info.freezed_time, freezing_info.unfreeze_lock_period) == true) {
            royalty_amount = calc_royalty_amount(amount, freezing_info.unfreeze_royalty);
            // Transfer royalty_amount into accumulative fund from treasury
            let royalty_coins = coin::extract(&mut freezing_info.treasury, royalty_amount);
            coin::deposit(freezing_info.accumulative_fund, royalty_coins);
            amount = amount - royalty_amount;
        };

        // Send GGWP tokens to user wallet
        let amount_coins = coin::extract(&mut freezing_info.treasury, amount);
        coin::deposit(user_addr, amount_coins);

        event::emit_event<UnfreezeEvent>(
            &mut freezing_events.unfreeze_events,
            UnfreezeEvent {
                user: user_addr,
                ggwp_amount: amount,
                gpass_amount: gpass_earned,
                royalty: royalty_amount,
                date: now
            },
        );

        freezing_info.total_users_freezed = freezing_info.total_users_freezed - 1;
        user_info.freezed_amount = 0;
        user_info.freezed_time = 0;
    }

    // Freezing Getters.

    #[view]
    public fun get_accumulative_fund_addr(ggwp_core_addr: address): address acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        let freezing_info = borrow_global<FreezingInfo>(ggwp_core_addr);
        freezing_info.accumulative_fund
    }

    #[view]
    public fun get_treasury_balance(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        let freezing_info = borrow_global<FreezingInfo>(ggwp_core_addr);
        coin::value<GGWPCoin>(&freezing_info.treasury)
    }

    // Not paid, only earned virtual.
    #[view]
    public fun get_earned_gpass_in_time(ggwp_core_addr: address, user_addr: address, time: u64): u64 acquires FreezingInfo, GpassInfo, UserInfo, Wallet {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<GpassInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        assert!(exists<Wallet>(user_addr), ERR_NOT_INITIALIZED);

        let freezing_info = borrow_global<FreezingInfo>(ggwp_core_addr);
        let gpass_info = borrow_global<GpassInfo>(ggwp_core_addr);
        let user_info = borrow_global<UserInfo>(user_addr);
        let user_wallet = borrow_global<Wallet>(user_addr);

        // It works exactly like withdraw_gpass calculation
        let last = user_info.last_getting_gpass;
        let spent_time_from_burn = time - user_wallet.last_burned;
        if (spent_time_from_burn >= gpass_info.burn_period) {
            let burn_periods_passed = spent_time_from_burn / gpass_info.burn_period;
            let new_last_burned = user_wallet.last_burned + burn_periods_passed * gpass_info.burn_period;

            let spent_from_last_gettting_to_new_burn = new_last_burned - user_info.last_getting_gpass;
            let reward_periods_to_burn = spent_from_last_gettting_to_new_burn / freezing_info.reward_period;
            last = user_info.last_getting_gpass + reward_periods_to_burn * freezing_info.reward_period;
        };

        calc_earned_gpass(
            &freezing_info.reward_table,
            user_info.freezed_amount,
            time,
            last,
            freezing_info.reward_period
        )
    }

    #[view]
    public fun get_last_getting_gpass(user_addr: address): u64 acquires UserInfo {
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        borrow_global<UserInfo>(user_addr).last_getting_gpass
    }

    #[view]
    public fun get_freezed_time(user_addr: address): u64 acquires UserInfo {
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        borrow_global<UserInfo>(user_addr).freezed_time
    }

    #[view]
    public fun get_freezed_amount(user_addr: address): u64 acquires UserInfo {
        assert!(exists<UserInfo>(user_addr), ERR_NOT_INITIALIZED);
        borrow_global<UserInfo>(user_addr).freezed_amount
    }

    #[view]
    public fun get_reward_period(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).reward_period
    }

    #[view]
    public fun get_royalty(ggwp_core_addr: address): u8 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).royalty
    }

    #[view]
    public fun get_unfreeze_royalty(ggwp_core_addr: address): u8 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).unfreeze_royalty
    }

    #[view]
    public fun get_unfreeze_lock_period(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).unfreeze_lock_period
    }

    #[view]
    public fun get_total_freezed(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).total_freezed
    }

    #[view]
    public fun get_total_users_freezed(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).total_users_freezed
    }

    #[view]
    public fun get_daily_gpass_reward(ggwp_core_addr: address): u64 acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).daily_gpass_reward
    }

    #[view]
    public fun get_reward_table(ggwp_core_addr: address): vector<RewardTableRow> acquires FreezingInfo {
        assert!(exists<FreezingInfo>(ggwp_core_addr), ERR_NOT_INITIALIZED);
        borrow_global<FreezingInfo>(ggwp_core_addr).reward_table
    }

    // Freezing utils

    fun earned_gpass_immediately(reward_table: &vector<RewardTableRow>, freezed_amount: u64): u64 {
        let earned_gpass = 0;
        let i = 0;
        while (i < vector::length(reward_table)) {
            let row = vector::borrow(reward_table, i);
            if (freezed_amount >= row.ggwp_amount) {
                earned_gpass = row.gpass_amount;
            } else {
                break
            };
            i = i + 1;
        };

        earned_gpass
    }

    /// Calculate gpass reward for every reward_period passed.
    fun calc_earned_gpass(
        reward_table: &vector<RewardTableRow>,
        freezed_amount: u64,
        current_time: u64,
        last_getting_gpass: u64,
        reward_period: u64,
    ): u64 {
        let spent_time = current_time - last_getting_gpass;
        if (spent_time < reward_period) {
            return 0
        };

        let reward_periods_passed = spent_time / reward_period;
        let earned_gpass = earned_gpass_immediately(reward_table, freezed_amount);
        earned_gpass * reward_periods_passed
    }

    public fun calc_royalty_amount(freezed_amount: u64, royalty: u8): u64 {
        freezed_amount / 100 * (royalty as u64)
    }

    /// Checks freezed time for withdraw royalty.
    public fun is_withdraw_royalty(current_time: u64, freezed_time: u64, unfreeze_lock_period: u64): bool {
        let spent_time = current_time - freezed_time;
        if (spent_time >= unfreeze_lock_period) {
            return false
        };
        true
    }

    #[test_only]
    public fun get_test_reward_table(): vector<RewardTableRow> {
        let reward_table: vector<RewardTableRow> = vector::empty();
        vector::push_back(&mut reward_table, RewardTableRow {
            ggwp_amount: 5000 * 100000000,
            gpass_amount: 5,
        });
        vector::push_back(&mut reward_table, RewardTableRow {
            ggwp_amount: 10000 * 100000000,
            gpass_amount: 10,
        });
        vector::push_back(&mut reward_table, RewardTableRow {
            ggwp_amount: 15000 * 100000000,
            gpass_amount: 15,
        });
        reward_table
    }

    #[test]
    public fun earned_gpass_immediately_test() {
        let reward_table = get_test_reward_table();
        assert!(earned_gpass_immediately(&reward_table, 5000) == 0, 1);
        assert!(earned_gpass_immediately(&reward_table, 5000 * 100000000) == 5, 1);
        assert!(earned_gpass_immediately(&reward_table, 6000 * 100000000) == 5, 1);
        assert!(earned_gpass_immediately(&reward_table, 10000 * 100000000) == 10, 1);
        assert!(earned_gpass_immediately(&reward_table, 14999 * 100000000) == 10, 1);
        assert!(earned_gpass_immediately(&reward_table, 15000 * 100000000) == 15, 1);
    }

    #[test_only]
    use aptos_framework::genesis;

    #[test]
    public fun calc_earned_gpass_test() {
        genesis::setup();
        let reward_period = 24 * 60 * 60;
        let half_period = 12 * 60 * 60;
        let reward_table = get_test_reward_table();
        let now = timestamp::now_seconds();

        // 0 periods
        assert!(calc_earned_gpass(&reward_table, 5000, now, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 5000 * 100000000, now, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 6000 * 100000000, now, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 10000 * 100000000, now, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 14999 * 100000000, now, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 15000 * 100000000, now, now, reward_period) == 0, 1);

        // 0.5 period
        assert!(calc_earned_gpass(&reward_table, 5000, now + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 5000 * 100000000, now + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 6000 * 100000000, now + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 10000 * 100000000, now + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 14999 * 100000000, now + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 15000 * 100000000, now + half_period, now, reward_period) == 0, 1);

        // 1 period
        assert!(calc_earned_gpass(&reward_table, 5000, now + reward_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 5000 * 100000000, now + reward_period, now, reward_period) == 5, 1);
        assert!(calc_earned_gpass(&reward_table, 6000 * 100000000, now + reward_period, now, reward_period) == 5, 1);
        assert!(calc_earned_gpass(&reward_table, 10000 * 100000000, now + reward_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 14999 * 100000000, now + reward_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 15000 * 100000000, now + reward_period, now, reward_period) == 15, 1);

        // 1.5 period
        assert!(calc_earned_gpass(&reward_table, 5000, now + reward_period + half_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 5000 * 100000000, now + reward_period + half_period, now, reward_period) == 5, 1);
        assert!(calc_earned_gpass(&reward_table, 6000 * 100000000, now + reward_period + half_period, now, reward_period) == 5, 1);
        assert!(calc_earned_gpass(&reward_table, 10000 * 100000000, now + reward_period + half_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 14999 * 100000000, now + reward_period + half_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 15000 * 100000000, now + reward_period + half_period, now, reward_period) == 15, 1);

        // 2 periods
        assert!(calc_earned_gpass(&reward_table, 5000, now + reward_period + reward_period, now, reward_period) == 0, 1);
        assert!(calc_earned_gpass(&reward_table, 5000 * 100000000, now + reward_period + reward_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 6000 * 100000000, now + reward_period + reward_period, now, reward_period) == 10, 1);
        assert!(calc_earned_gpass(&reward_table, 10000 * 100000000, now + reward_period + reward_period, now, reward_period) == 20, 1);
        assert!(calc_earned_gpass(&reward_table, 14999 * 100000000, now + reward_period + reward_period, now, reward_period) == 20, 1);
        assert!(calc_earned_gpass(&reward_table, 15000 * 100000000, now + reward_period + reward_period, now, reward_period) == 30, 1);
    }

    #[test]
    public fun calc_royalty_amount_test() {
        assert!(calc_royalty_amount(500000000, 8) == 40000000, 1);
        assert!(calc_royalty_amount(500000001, 8) == 40000000, 1);
        assert!(calc_royalty_amount(500000010, 8) == 40000000, 1);
        assert!(calc_royalty_amount(500000100, 8) == 40000008, 1);
        assert!(calc_royalty_amount(500000000, 50) == 250000000, 1);
        assert!(calc_royalty_amount(5000000000, 50) == 2500000000, 1);
        assert!(calc_royalty_amount(5100000000, 50) == 2550000000, 1);
        assert!(calc_royalty_amount(5100000000, 0) == 0, 1);
    }

    #[test_only]
    public fun construct_row(ggwp_amount: u64, gpass_amount: u64): RewardTableRow {
        RewardTableRow {
            ggwp_amount: ggwp_amount,
            gpass_amount: gpass_amount,
        }
    }
}

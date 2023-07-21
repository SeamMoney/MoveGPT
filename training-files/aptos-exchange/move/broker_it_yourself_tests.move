module overmind::broker_it_yourself_tests {
    #[test_only]
    use aptos_std::simple_map;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use overmind::broker_it_yourself;
    #[test_only]
    use std::option;
    #[test_only]
    use std::vector;

    #[test]
    fun test_init() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        assert!(broker_it_yourself::state_exists(), 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 1);
        assert!(simple_map::length(&creators_offers) == 0, 2);
        assert!(offer_id == 0, 3);
        assert!(create_offer_events_counter == 0, 4);
        assert!(accept_offer_events_counter == 0, 5);
        assert!(complete_transaction_events_counter == 0, 6);
        assert!(release_funds_events_counter == 0, 7);
        assert!(cancel_offer_events_counter == 0, 8);
        assert!(open_dispute_events_counter == 0, 9);
        assert!(resolve_dispute_events_counter == 0, 10);
        assert!(
            coin::is_account_registered<AptosCoin>(
                account::create_resource_address(&@admin, b"broker_it_yourself")
            ),
            12
        );
    }

    #[test]
    #[expected_failure(abort_code = 0, location = overmind::broker_it_yourself)]
    fun test_init_singer_not_admin() {
        let account = account::create_account_for_test(@0xCED);
        broker_it_yourself::init(&account);
    }

    #[test]
    fun test_create_offer_sell_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, apt_amount);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 0, 6);
        assert!(complete_transaction_events_counter == 0, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_none(&counterparty), 17);
        assert!(!dispute_opened, 18);
        assert!(sell_apt, 19);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 20);
        assert!(!counterparty_flag, 21);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 22);
        assert!(vector::contains(creator_offers, &0), 23);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 24);
        assert!(coin::balance<AptosCoin>(resource_account_address) == offer_apt_amount, 25);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_create_offer_buy_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, apt_amount);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 0, 6);
        assert!(complete_transaction_events_counter == 0, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_none(&counterparty), 17);
        assert!(!dispute_opened, 18);
        assert!(!sell_apt, 19);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 20);
        assert!(!counterparty_flag, 21);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 22);
        assert!(vector::contains(creator_offers, &0), 23);

        assert!(coin::balance<AptosCoin>(@0xACE) == apt_amount, 24);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 25);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }


    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_create_offer_state_not_initialized() {
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = true;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = overmind::broker_it_yourself)]
    fun test_create_offer_insufficient_funds() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, 4842254);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_accept_offer_sell_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, apt_amount);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 0, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(!dispute_opened, 19);
        assert!(sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 21);
        assert!(!counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == offer_apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_accept_offer_buy_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, apt_amount);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 0, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(!dispute_opened, 19);
        assert!(!sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 21);
        assert!(!counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == apt_amount, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_accept_offer_state_not_initialized() {
        let counterparty_signer = account::create_account_for_test(@0xDAD);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = overmind::broker_it_yourself)]
    fun test_accept_offer_does_not_exist() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = overmind::broker_it_yourself)]
    fun test_accept_offer_already_accepted() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = overmind::broker_it_yourself)]
    fun test_accept_offer_dispute_opened() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::open_dispute_unchecked(0);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 2, location = overmind::broker_it_yourself)]
    fun test_accept_offer_insufficient_funds() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, 125641);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_complete_transaction_creator_marked() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        broker_it_yourself::complete_transaction(&creator, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(!dispute_opened, 19);
        assert!(!sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(creator_flag, 21);
        assert!(!counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_complete_transaction_counterparty_marked() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        broker_it_yourself::complete_transaction(&counterparty_signer, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 0, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(!dispute_opened, 19);
        assert!(!sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 21);
        assert!(counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_complete_transaction_both_parties_marked() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        broker_it_yourself::complete_transaction(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&creator, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 0);
        assert!(simple_map::length(&creators_offers) == 1, 1);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 2);
        assert!(offer_id == 1, 3);
        assert!(create_offer_events_counter == 1, 4);
        assert!(accept_offer_events_counter == 1, 5);
        assert!(complete_transaction_events_counter == 2, 6);
        assert!(release_funds_events_counter == 1, 7);
        assert!(cancel_offer_events_counter == 0, 8);
        assert!(open_dispute_events_counter == 0, 9);
        assert!(resolve_dispute_events_counter == 0, 10);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 0, 11);

        assert!(coin::balance<AptosCoin>(@0xACE) == apt_amount, 12);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 13);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 14);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_state_not_initialized() {
        let counterparty_signer = account::create_account_for_test(@0xDAD);
        broker_it_yourself::complete_transaction(&counterparty_signer, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_offer_does_not_exist() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        broker_it_yourself::complete_transaction(&counterparty_signer, 0);
    }

    #[test]
    #[expected_failure(abort_code = 5, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_offer_not_accepted() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);
        broker_it_yourself::complete_transaction(&creator, 0);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_user_does_not_participate_in_transaction() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty = account::create_account_for_test(@0xABCDEF);
        coin::register<AptosCoin>(&counterparty);
        aptos_coin::mint(&aptos_framework, @0xABCDEF, apt_amount);
        broker_it_yourself::accept_offer(&counterparty, 0);

        let account = account::create_account_for_test(@0xDAD);
        broker_it_yourself::complete_transaction(&account, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 7, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_user_already_marked_as_completed() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&counterparty_signer, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = overmind::broker_it_yourself)]
    fun test_complete_transaction_dispute_opened() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::open_dispute_unchecked(0);
        broker_it_yourself::complete_transaction(&counterparty_signer, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_cancel_offer_sell_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, apt_amount);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);
        broker_it_yourself::cancel_offer(&creator, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 0);
        assert!(simple_map::length(&creators_offers) == 1, 1);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 2);
        assert!(offer_id == 1, 3);
        assert!(create_offer_events_counter == 1, 4);
        assert!(accept_offer_events_counter == 0, 5);
        assert!(complete_transaction_events_counter == 0, 6);
        assert!(release_funds_events_counter == 0, 7);
        assert!(cancel_offer_events_counter == 1, 8);
        assert!(open_dispute_events_counter == 0, 9);
        assert!(resolve_dispute_events_counter == 0, 10);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 0, 11);

        assert!(coin::balance<AptosCoin>(@0xACE) == apt_amount, 12);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 13);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_cancel_offer_buy_apt() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);
        broker_it_yourself::cancel_offer(&creator, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 0);
        assert!(simple_map::length(&creators_offers) == 1, 1);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 2);
        assert!(offer_id == 1, 3);
        assert!(create_offer_events_counter == 1, 4);
        assert!(accept_offer_events_counter == 0, 5);
        assert!(complete_transaction_events_counter == 0, 6);
        assert!(release_funds_events_counter == 0, 7);
        assert!(cancel_offer_events_counter == 1, 8);
        assert!(open_dispute_events_counter == 0, 9);
        assert!(resolve_dispute_events_counter == 0, 10);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 0, 11);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 12);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 13);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_cancel_offer_state_not_initialized() {
        let creator = account::create_account_for_test(@0xDAD);
        broker_it_yourself::cancel_offer(&creator, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = overmind::broker_it_yourself)]
    fun test_cancel_offer_does_not_exist() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xDAD);
        broker_it_yourself::cancel_offer(&creator, 0);
    }

    #[test]
    #[expected_failure(abort_code = 8, location = overmind::broker_it_yourself)]
    fun test_cancel_offer_signer_is_not_creator() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let account = account::create_account_for_test(@0xDAD);
        broker_it_yourself::cancel_offer(&account, 0);
    }

    #[test]
    #[expected_failure(abort_code = 4, location = overmind::broker_it_yourself)]
    fun test_cancel_offer_already_accepted() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        broker_it_yourself::cancel_offer(&creator, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = overmind::broker_it_yourself)]
    fun test_cancel_offer_dispute_opened() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);
        broker_it_yourself::open_dispute_unchecked(0);
        broker_it_yourself::cancel_offer(&creator, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_open_dispute_by_creator() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&creator, 0);
        broker_it_yourself::open_dispute(&creator, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 1, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(dispute_opened, 19);
        assert!(!sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(creator_flag, 21);
        assert!(!counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_open_dispute_by_counterparty() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&creator, 0);
        broker_it_yourself::open_dispute(&counterparty_signer, 0);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);
        assert!(simple_map::length(&creators_offers) == 1, 2);
        assert!(simple_map::contains_key(&creators_offers, &@0xACE), 3);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 1, 10);
        assert!(resolve_dispute_events_counter == 0, 11);

        let (_, offer) = simple_map::remove(&mut offers, &0);
        let (
            creator_address,
            arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 13);
        assert!(arbiter == @0x13371337, 14);
        assert!(offer_apt_amount == apt_amount, 15);
        assert!(offer_usd_amount == usd_amount, 16);
        assert!(option::is_some(&counterparty), 17);
        assert!(option::borrow(&counterparty) == &@0xDAD, 18);
        assert!(dispute_opened, 19);
        assert!(!sell_apt, 20);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(creator_flag, 21);
        assert!(!counterparty_flag, 22);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 1, 23);
        assert!(vector::contains(creator_offers, &0), 24);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 25);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 26);
        assert!(coin::balance<AptosCoin>(resource_account_address) == apt_amount, 27);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_open_dispute_state_not_initialized() {
        let creator = account::create_account_for_test(@0xDAD);
        broker_it_yourself::open_dispute(&creator, 0);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = overmind::broker_it_yourself)]
    fun test_open_dispute_offer_does_not_exist() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xDAD);
        broker_it_yourself::open_dispute(&creator, 0);
    }

    #[test]
    #[expected_failure(abort_code = 6, location = overmind::broker_it_yourself)]
    fun test_open_dispute_user_does_not_participate_in_transaction() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);

        let account = account::create_account_for_test(@0x2468353221AA);
        broker_it_yourself::open_dispute(&account, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 9, location = overmind::broker_it_yourself)]
    fun test_open_dispute_opened() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::open_dispute(&counterparty_signer, 0);
        broker_it_yourself::open_dispute(&creator, 0);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_resolve_dispute_to_creator() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&creator, 0);
        broker_it_yourself::open_dispute(&counterparty_signer, 0);

        let arbiter_signer = account::create_account_for_test(arbiter);
        broker_it_yourself::resolve_dispute(&arbiter_signer, 0, true);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 0);
        assert!(simple_map::length(&creators_offers) == 1, 1);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 1, 10);
        assert!(resolve_dispute_events_counter == 1, 11);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 0, 12);

        assert!(coin::balance<AptosCoin>(@0xACE) == apt_amount, 13);
        assert!(coin::balance<AptosCoin>(@0xDAD) == 0, 14);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 15);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_resolve_dispute_to_counterparty() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let resource_account_address = account::create_resource_address(&@admin, b"broker_it_yourself");
        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        coin::register<AptosCoin>(&creator);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::complete_transaction(&creator, 0);
        broker_it_yourself::open_dispute(&counterparty_signer, 0);

        let arbiter_signer = account::create_account_for_test(arbiter);
        broker_it_yourself::resolve_dispute(&arbiter_signer, 0, false);

        let (
            offers,
            creators_offers,
            offer_id,
            create_offer_events_counter,
            accept_offer_events_counter,
            complete_transaction_events_counter,
            release_funds_events_counter,
            cancel_offer_events_counter,
            open_dispute_events_counter,
            resolve_dispute_events_counter
        ) = broker_it_yourself::get_state_unpacked();
        assert!(simple_map::length(&offers) == 0, 0);
        assert!(simple_map::length(&creators_offers) == 1, 1);
        assert!(offer_id == 1, 4);
        assert!(create_offer_events_counter == 1, 5);
        assert!(accept_offer_events_counter == 1, 6);
        assert!(complete_transaction_events_counter == 1, 7);
        assert!(release_funds_events_counter == 0, 8);
        assert!(cancel_offer_events_counter == 0, 9);
        assert!(open_dispute_events_counter == 1, 10);
        assert!(resolve_dispute_events_counter == 1, 11);

        let creator_offers = simple_map::borrow(&creators_offers, &@0xACE);
        assert!(vector::length(creator_offers) == 0, 12);

        assert!(coin::balance<AptosCoin>(@0xACE) == 0, 13);
        assert!(coin::balance<AptosCoin>(@0xDAD) == apt_amount, 14);
        assert!(coin::balance<AptosCoin>(resource_account_address) == 0, 15);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_resolve_dispute_state_not_initialized() {
        let arbiter = account::create_account_for_test(@0x13371337);
        broker_it_yourself::resolve_dispute(&arbiter, 0, false);
    }

    #[test]
    #[expected_failure(abort_code = 3, location = overmind::broker_it_yourself)]
    fun test_resolve_dispute_offer_does_not_exist() {
        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let arbiter = account::create_account_for_test(@0x13371337);
        broker_it_yourself::resolve_dispute(&arbiter, 0, false);
    }

    #[test]
    #[expected_failure(abort_code = 10, location = overmind::broker_it_yourself)]
    fun test_resolve_dispute_not_opened() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let arbiter = account::create_account_for_test(arbiter);
        broker_it_yourself::resolve_dispute(&arbiter, 0, false);
    }

    #[test]
    #[expected_failure(abort_code = 11, location = overmind::broker_it_yourself)]
    fun test_resolve_dispute_signer_not_arbiter() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let counterparty_signer = account::create_account_for_test(@0xDAD);
        coin::register<AptosCoin>(&counterparty_signer);
        aptos_coin::mint(&aptos_framework, @0xDAD, apt_amount);
        broker_it_yourself::accept_offer(&counterparty_signer, 0);
        broker_it_yourself::open_dispute(&counterparty_signer, 0);

        let account = account::create_account_for_test(@0x48942aaa);
        broker_it_yourself::resolve_dispute(&account, 0, false);

        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }

    #[test]
    fun test_get_all_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let offers = broker_it_yourself::get_all_offers();
        assert!(simple_map::length(&offers) == 1, 0);
        assert!(simple_map::contains_key(&offers, &0), 1);

        let offer = *simple_map::borrow(&offers, &0);
        let (
            creator_address,
            offer_arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            offer_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(offer);
        assert!(creator_address == @0xACE, 2);
        assert!(offer_arbiter == arbiter, 3);
        assert!(offer_apt_amount == apt_amount, 4);
        assert!(offer_usd_amount == usd_amount, 5);
        assert!(option::is_none(&counterparty), 6);
        assert!(!dispute_opened, 7);
        assert!(!offer_sell_apt, 8);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 9);
        assert!(!counterparty_flag, 10);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_all_offers_state_not_initialized() {
        broker_it_yourself::get_all_offers();
    }

    #[test]
    fun test_get_available_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let second_arbiter = @0x4545454A;
        let second_apt_amount = 89994568;
        let second_usd_amount = 256;
        let second_sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, second_apt_amount);
        broker_it_yourself::create_offer(
            &creator,
            second_arbiter,
            second_apt_amount,
            second_usd_amount,
            second_sell_apt
        );

        let counterparty = account::create_account_for_test(@0xDADAD123);
        coin::register<AptosCoin>(&counterparty);
        aptos_coin::mint(&aptos_framework, @0xDADAD123, apt_amount);
        broker_it_yourself::accept_offer(&counterparty, 0);

        let available_offers = broker_it_yourself::get_available_offers();
        assert!(simple_map::length(&available_offers) == 1, 0);
        assert!(simple_map::contains_key(&available_offers, &1), 1);

        let (
            unpacked_creator,
            unpacked_arbiter,
            unpacked_apt_amount,
            unpacked_usd_amount,
            unpacked_counterparty,
            unpacked_completion,
            unpacked_dispute_opened,
            unpacked_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(*simple_map::borrow(&available_offers, &1));
        assert!(unpacked_creator == @0xACE, 2);
        assert!(unpacked_arbiter == second_arbiter, 3);
        assert!(unpacked_apt_amount == second_apt_amount, 4);
        assert!(unpacked_usd_amount == second_usd_amount, 5);
        assert!(option::is_none(&unpacked_counterparty), 6);
        assert!(!unpacked_dispute_opened, 7);
        assert!(unpacked_sell_apt, 8);

        let (creator_flag, counterparty_flag) =
            broker_it_yourself::get_offer_completion_unpacked(unpacked_completion);
        assert!(!creator_flag, 9);
        assert!(!counterparty_flag, 10);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_available_offers_state_not_initialized() {
        broker_it_yourself::get_available_offers();
    }

    #[test]
    fun test_get_arbitration_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let second_arbiter = @0x4545454A;
        let second_apt_amount = 89994568;
        let second_usd_amount = 256;
        let second_sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, second_apt_amount);
        broker_it_yourself::create_offer(
            &creator,
            second_arbiter,
            second_apt_amount,
            second_usd_amount,
            second_sell_apt
        );

        let counterparty = account::create_account_for_test(@0xDADAD123);
        coin::register<AptosCoin>(&counterparty);
        aptos_coin::mint(&aptos_framework, @0xDADAD123, apt_amount);
        broker_it_yourself::accept_offer(&counterparty, 0);
        broker_it_yourself::open_dispute(&creator, 0);

        let arbitration_offers = broker_it_yourself::get_arbitration_offers();
        assert!(simple_map::length(&arbitration_offers) == 1, 0);
        assert!(simple_map::contains_key(&arbitration_offers, &0), 1);

        let (
            unpacked_creator,
            unpacked_arbiter,
            unpacked_apt_amount,
            unpacked_usd_amount,
            unpacked_counterparty,
            unpacked_completion,
            unpacked_dispute_opened,
            unpacked_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(*simple_map::borrow(&arbitration_offers, &0));
        assert!(unpacked_creator == @0xACE, 2);
        assert!(unpacked_arbiter == arbiter, 3);
        assert!(unpacked_apt_amount == apt_amount, 4);
        assert!(unpacked_usd_amount == usd_amount, 5);
        assert!(option::is_some(&unpacked_counterparty), 6);
        assert!(option::borrow(&unpacked_counterparty) == &@0xDADAD123, 7);
        assert!(unpacked_dispute_opened, 8);
        assert!(!unpacked_sell_apt, 9);

        let (creator_flag, counterparty_flag) =
            broker_it_yourself::get_offer_completion_unpacked(unpacked_completion);
        assert!(!creator_flag, 10);
        assert!(!counterparty_flag, 11);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_arbitration_offers_state_not_initialized() {
        broker_it_yourself::get_arbitration_offers();
    }

    #[test]
    fun test_get_buy_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let second_arbiter = @0x4545454A;
        let second_apt_amount = 89994568;
        let second_usd_amount = 256;
        let second_sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, second_apt_amount);
        broker_it_yourself::create_offer(
            &creator,
            second_arbiter,
            second_apt_amount,
            second_usd_amount,
            second_sell_apt
        );

        let buy_offers = broker_it_yourself::get_buy_offers(@0xACE);
        assert!(simple_map::length(&buy_offers) == 1, 0);
        assert!(simple_map::contains_key(&buy_offers, &0), 1);

        let (
            unpacked_creator,
            unpacked_arbiter,
            unpacked_apt_amount,
            unpacked_usd_amount,
            unpacked_counterparty,
            unpacked_completion,
            unpacked_dispute_opened,
            unpacked_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(*simple_map::borrow(&buy_offers, &0));
        assert!(unpacked_creator == @0xACE, 2);
        assert!(unpacked_arbiter == arbiter, 3);
        assert!(unpacked_apt_amount == apt_amount, 4);
        assert!(unpacked_usd_amount == usd_amount, 5);
        assert!(option::is_none(&unpacked_counterparty), 6);
        assert!(!unpacked_dispute_opened, 7);
        assert!(!unpacked_sell_apt, 8);

        let (creator_flag, counterparty_flag) =
            broker_it_yourself::get_offer_completion_unpacked(unpacked_completion);
        assert!(!creator_flag, 9);
        assert!(!counterparty_flag, 10);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_buy_offers_state_not_initialized() {
        broker_it_yourself::get_buy_offers(@0xACE);
    }

    #[test]
    fun test_get_sell_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);
        let (burn_cap, mint_cap) =
            aptos_coin::initialize_for_test(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let second_arbiter = @0x4545454A;
        let second_apt_amount = 89994568;
        let second_usd_amount = 256;
        let second_sell_apt = true;
        coin::register<AptosCoin>(&creator);
        aptos_coin::mint(&aptos_framework, @0xACE, second_apt_amount);
        broker_it_yourself::create_offer(
            &creator,
            second_arbiter,
            second_apt_amount,
            second_usd_amount,
            second_sell_apt
        );

        let sell_offers = broker_it_yourself::get_sell_offers(@0xACE);
        assert!(simple_map::length(&sell_offers) == 1, 0);
        assert!(simple_map::contains_key(&sell_offers, &1), 1);

        let (
            unpacked_creator,
            unpacked_arbiter,
            unpacked_apt_amount,
            unpacked_usd_amount,
            unpacked_counterparty,
            unpacked_completion,
            unpacked_dispute_opened,
            unpacked_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(*simple_map::borrow(&sell_offers, &1));
        assert!(unpacked_creator == @0xACE, 2);
        assert!(unpacked_arbiter == second_arbiter, 3);
        assert!(unpacked_apt_amount == second_apt_amount, 4);
        assert!(unpacked_usd_amount == second_usd_amount, 5);
        assert!(option::is_none(&unpacked_counterparty), 6);
        assert!(!unpacked_dispute_opened, 7);
        assert!(unpacked_sell_apt, 8);

        let (creator_flag, counterparty_flag) =
            broker_it_yourself::get_offer_completion_unpacked(unpacked_completion);
        assert!(!creator_flag, 9);
        assert!(!counterparty_flag, 10);

        coin::destroy_mint_cap(mint_cap);
        coin::destroy_burn_cap(burn_cap);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_sell_offers_state_not_initialized() {
        broker_it_yourself::get_sell_offers(@0xACE);
    }

    #[test]
    fun test_get_creator_offers() {
        let aptos_framework = account::create_account_for_test(@aptos_framework);
        timestamp::set_time_has_started_for_testing(&aptos_framework);

        let admin = account::create_account_for_test(@admin);
        broker_it_yourself::init(&admin);

        let creator = account::create_account_for_test(@0xACE);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let second_creator = account::create_account_for_test(@0xACED);
        let arbiter = @0x13371337;
        let apt_amount = 1234456111;
        let usd_amount = 265;
        let sell_apt = false;
        broker_it_yourself::create_offer(&second_creator, arbiter, apt_amount, usd_amount, sell_apt);
        broker_it_yourself::create_offer(&creator, arbiter, apt_amount, usd_amount, sell_apt);

        let creator_offers = broker_it_yourself::get_creator_offers(@0xACE);
        assert!(simple_map::length(&creator_offers) == 2, 0);

        let first_offer = *simple_map::borrow(&creator_offers, &0);
        let (
            creator_address,
            offer_arbiter,
            offer_apt_amount,
            offer_usd_amount,
            counterparty,
            completion,
            dispute_opened,
            offer_sell_apt
        ) = broker_it_yourself::get_offer_unpacked(first_offer);
        assert!(creator_address == @0xACE, 1);
        assert!(offer_arbiter == arbiter, 2);
        assert!(offer_apt_amount == apt_amount, 3);
        assert!(offer_usd_amount == usd_amount, 4);
        assert!(option::is_none(&counterparty), 5);
        assert!(!dispute_opened, 6);
        assert!(!offer_sell_apt, 7);

        let (creator_flag, counterparty_flag) = broker_it_yourself::get_offer_completion_unpacked(completion);
        assert!(!creator_flag, 8);
        assert!(!counterparty_flag, 9);

        let second_offer = *simple_map::borrow(&creator_offers, &2);
        assert!(first_offer == second_offer, 10);
    }

    #[test]
    #[expected_failure(abort_code = 1, location = overmind::broker_it_yourself)]
    fun test_get_creator_offer_state_not_initialized() {
        broker_it_yourself::get_creator_offers(@0xACE);
    }

    #[test]
    fun test_remove_offer_from_cretor_offers() {
        let creators_offers = simple_map::create();
        simple_map::add(&mut creators_offers, @0xACE, vector[122, 123, 250, 281, 555]);
        broker_it_yourself::remove_offer_from_creator_offers(&mut creators_offers, &@0xACE, &123);

        assert!(*simple_map::borrow(&creators_offers, &@0xACE) == vector[122, 250, 281, 555], 0);
    }

    #[test]
    fun test_get_next_offer_id() {
        let offer_id = 22451;
        let next_offer_id = broker_it_yourself::get_next_offer_id(&mut offer_id);
        assert!(offer_id == 22452, 0);
        assert!(next_offer_id == 22451, 1);
    }
}

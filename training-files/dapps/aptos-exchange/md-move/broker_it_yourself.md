```rust
/*
    The quest implements P2P trading involving off-chain (USD) and on-chain (APT) assets.
    In the quest, a user is able to create an offer stating amount of APT they want to buy or sell and amount of USD
        they will give/want to receive from the transaction.
    Any other user can accept any of the available offers. After both parties mark the transaction as completed,
        the on-chain assets can be transfered to the eligible party.
    In any case of disagreement, a dispute can be opened. Only the arbiter, that is set while creating an offer, can
        resolve a dispute.
*/
module overmind::broker_it_yourself {
    use std::option::Option;
    use std::signer;
    use std::option;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::account::SignerCapability;
    use aptos_framework::event::EventHandle;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    use aptos_framework::timestamp;

    use overmind::broker_it_yourself_events::{CreateOfferEvent, AcceptOfferEvent, CompleteTransactionEvent, ReleaseFundsEvent, CancelOfferEvent, OpenDisputeEvent, ResolveDisputeEvent};
    use overmind::broker_it_yourself_events;

    friend overmind::broker_it_yourself_tests;

    ////////////
    // ERRORS //
    ////////////

    const ERROR_SIGNER_NOT_ADMIN: u64 = 0;
    const ERROR_STATE_NOT_INITIALIZED: u64 = 1;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 2;
    const ERROR_OFFER_DOES_NOT_EXIST: u64 = 3;
    const ERROR_OFFER_ALREADY_ACCEPTED: u64 = 4;
    const ERROR_OFFER_NOT_ACCEPTED: u64 = 5;
    const ERROR_USER_DOES_NOT_PARTICIPATE_IN_TRANSACTION: u64 = 6;
    const ERROR_USER_ALREADY_MARKED_AS_COMPLETED: u64 = 7;
    const ERROR_SIGNER_NOT_CREATOR: u64 = 8;
    const ERROR_DISPUTE_ALREADY_OPENED: u64 = 9;
    const ERROR_DISPUTE_NOT_OPENED: u64 = 10;
    const ERROR_SIGNER_NOT_ARBITER: u64 = 11;

    // PDA seed
    const SEED: vector<u8> = b"broker_it_yourself";

    /*
        Resource struct holding data about available offers
    */
    struct State has key {
        // List of available offers
        offers: SimpleMap<u128, Offer>,
        // Cache storing creators' available offers
        creators_offers: SimpleMap<address, vector<u128>>,
        // Incrementing counter for indexing offers
        offer_id: u128,
        // PDA's SingerCapability
        cap: SignerCapability,
        // Events
        create_offer_events: EventHandle<CreateOfferEvent>,
        accept_offer_events: EventHandle<AcceptOfferEvent>,
        complete_transaction_events: EventHandle<CompleteTransactionEvent>,
        release_funds_events: EventHandle<ReleaseFundsEvent>,
        cancel_offer_events: EventHandle<CancelOfferEvent>,
        open_dispute_events: EventHandle<OpenDisputeEvent>,
        resolve_dispute_events: EventHandle<ResolveDisputeEvent>
    }

    /*
        Struct holding data about a single offer
    */
    struct Offer has store, drop, copy {
        // Address of the creator of the offer
        creator: address,
        // Address of the arbiter that can take actions when a dispute is opened
        arbiter: address,
        // Amount of APT coins
        apt_amount: u64,
        // Amount of USD
        usd_amount: u64,
        // Address of the counterparty for the offer
        counterparty: Option<address>,
        // Instance of OfferCompletion
        completion: OfferCompletion,
        // Flag indicating if a dispute for the offer is opened. False by default
        dispute_opened: bool,
        // Flag indicating if the creator is selling or buying APT
        sell_apt: bool
    }

    /*
        Struct holding data about status of an offer. The transaction is completed and APT can be released only if
        both flags have value of `true`
    */
    struct OfferCompletion has store, drop, copy {
        // Flag indicating if the creator marked the transaction as completed. False by default
        creator: bool,
        // Flag indicating if the counterparty marked the transaction as completed. False by default
        counterparty: bool
    }

    /*
        Inits the smart contract by creating a PDA account and State resource
        @param admin - signer representing the admin
    */
    public entry fun init(admin: &signer) {
        // TODO: Call assert_signer_is_admin function
        assert_signer_is_admin(admin);

        // TODO: Create a resource account using `SEED` global constant
        let (resource, signer_cap) = aptos_framework::account::create_resource_account(admin, SEED);

        // TODO: Register the resource account with AptosCoin
        coin::register<AptosCoin>(&resource);

        // TODO: Move State resource to the admin address
        move_to(admin, State {
            offers: simple_map::create(),
            creators_offers: simple_map::create(),
            offer_id: 0,
            cap: signer_cap,
            create_offer_events: account::new_event_handle<CreateOfferEvent>(admin),
            accept_offer_events: account::new_event_handle<AcceptOfferEvent>(admin),
            complete_transaction_events: account::new_event_handle<CompleteTransactionEvent>(admin),
            release_funds_events: account::new_event_handle<ReleaseFundsEvent>(admin),
            cancel_offer_events: account::new_event_handle<CancelOfferEvent>(admin),
            open_dispute_events: account::new_event_handle<OpenDisputeEvent>(admin),
            resolve_dispute_events: account::new_event_handle<ResolveDisputeEvent>(admin)
        });
    }

    /*
        Creates a new offer.
        @param creator - signer representing the creator of the offer
        @param arbiter - address of the arbiter
        @param apt_amount - amount of APT that the creator's offering or wants to receive from the transaction
        @param usd_amount - amount of USD that the creator wants to receive from the transaction or is offering.
        @param sell_apt - flag indicating if the creator's selling or buying APT
    */
    public entry fun create_offer(
        creator: &signer,
        arbiter: address,
        apt_amount: u64,
        usd_amount: u64,
        sell_apt: bool
    ) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call get_next_offer_id function
        let offer_id = get_next_offer_id(&mut borrow_global_mut<State>(@admin).offer_id);

        // TODO: Create instance of Offer struct
        let offer = Offer {
            // Address of the creator of the offer
            creator: signer::address_of(creator),
            // Address of the arbiter that can take actions when a dispute is opened
            arbiter,
            // Amount of APT coins
            apt_amount,
            // Amount of USD
            usd_amount,
            // Address of the counterparty for the offer
            counterparty: option::none(),
            // Instance of OfferCompletion
            completion: OfferCompletion {
                // Flag indicating if the creator marked the transaction as completed. False by default
                creator: false,
                // Flag indicating if the counterparty marked the transaction as completed. False by default
                counterparty: false
            },
            // Flag indicating if a dispute for the offer is opened. False by default
            dispute_opened: false,
            // Flag indicating if the creator is selling or buying APT
            sell_apt
        };

        // TODO: Add the Offer instance to the list of available offers
        simple_map::add(&mut borrow_global_mut<State>(@admin).offers, offer_id, offer);

        // TODO: Add the offer id to the creator's offers list
        let state = borrow_global_mut<State>(@admin);
        if (simple_map::contains_key(&state.creators_offers, &signer::address_of(creator))) {
            vector::push_back(simple_map::borrow_mut(&mut state.creators_offers, &signer::address_of(creator)), offer_id);
        } else {
            let vec = vector::empty<u128>();
            vector::push_back(&mut vec, offer_id);
            simple_map::add(&mut state.creators_offers, signer::address_of(creator), vec);
        };

        // TODO: Transfer appropriate amount of APT to the PDA if sell_apt == true && assert_user_has_enough_funds
        if (sell_apt == true) {
          assert_user_has_enough_funds<AptosCoin>(signer::address_of(creator), apt_amount);
          let resource_signer = account::create_signer_with_capability(&mut borrow_global_mut<State>(@admin).cap);
            coin::transfer<AptosCoin>(creator, signer::address_of(&resource_signer) , apt_amount);
        };

        // TODO: Emit CreateOfferEvent event
        event::emit_event(&mut borrow_global_mut<State>(@admin).create_offer_events, broker_it_yourself_events::new_create_offer_event(offer_id, signer::address_of(creator), @admin, apt_amount, usd_amount, sell_apt, timestamp::now_seconds()));
    }

    /*
        Pairs a user with already created offer
        @param user - signer representing the user, who accepts the offer
        @param offer_id - id of the offer
    */
    public entry fun accept_offer(user: &signer, offer_id: u128) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call assert_offer_exists function
        assert_offer_exists(&borrow_global<State>(@admin).offers, &offer_id);

        // TODO: Call assert_offer_not_accepted function
        let state = borrow_global_mut<State>(@admin);
        let offer = simple_map::borrow_mut(&mut state.offers, &offer_id);
        assert_offer_not_accepted(offer);

        // TODO: Call assert_dispute_not_opened function
        assert_dispute_not_opened(offer);

        // TODO: Set Offer's counterparty field to the address of the user
        offer.counterparty = option::some(signer::address_of(user));

        // TODO: Transfer appropriate APT amount from the user to the PDA if Offer's sell_apt == false &&
        //      assert_user_has_enough_funds
        let amount = offer.apt_amount;
        let add = signer::address_of(user);
        if (offer.sell_apt == false) {
          assert_user_has_enough_funds<AptosCoin>(add, amount);
          let resource_signer = account::create_signer_with_capability(&mut state.cap);
            coin::transfer<AptosCoin>(user, signer::address_of(&resource_signer) , offer.apt_amount);
        };

        // TODO: Emit AcceptOfferEvent event
        event::emit_event(&mut state.accept_offer_events, broker_it_yourself_events::new_accept_offer_event(offer_id, signer::address_of(user), timestamp::now_seconds()));
    }

    /*
        Marks a transaction as completed by one of the parties and transfers on-chain assets to the eligible party
            if both parties marks the transaction as completed
        @param user - signer representing one of the parties of the transaction
        @param offer_id - id of the offer
    */
    public entry fun complete_transaction(user: &signer, offer_id: u128) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call assert_offer_exists function
        assert_offer_exists(&borrow_global<State>(@admin).offers, &offer_id);

        // TODO: Call assert_offer_accepted function
        let state = borrow_global_mut<State>(@admin);
        let offer = *simple_map::borrow_mut(&mut state.offers, &offer_id);
        assert_offer_accepted(&offer);

        // TODO: call assert_user_participates_in_transaction function
        assert_user_participates_in_transaction(signer::address_of(user), &offer);

        // TODO: call assert_user_has_not_marked_completed_yet function
        assert_user_has_not_marked_completed_yet(signer::address_of(user), &offer);

        // TODO: call assert_dispute_not_opened function
        assert_dispute_not_opened(&offer);

        // TODO: Compare the user's address and set appropriate completion flag to true
        let address = signer::address_of(user);
        let offer1 = simple_map::borrow_mut(&mut state.offers, &offer_id);
        if (address == offer.creator) {
            offer1.completion.creator = true;
        } else if (option::some(address) == offer.counterparty) {
            offer1.completion.counterparty = true;
        };

        event::emit_event(&mut state.complete_transaction_events, broker_it_yourself_events::new_complete_transaction_event(offer_id, address, timestamp::now_seconds()));


        if (offer1.completion.creator == true && offer1.completion.counterparty == true) {
            simple_map::remove(&mut state.offers, &offer_id);
            remove_offer_from_creator_offers(&mut state.creators_offers, &signer::address_of(user), &offer_id);
            // Transfer
            let resource_signer = account::create_signer_with_capability(&mut state.cap);
            if (offer.sell_apt == true) {
                coin::transfer<AptosCoin>(&resource_signer, option::extract(&mut offer.counterparty), offer.apt_amount);
            } else {
                coin::transfer<AptosCoin>(&resource_signer, offer.creator, offer.apt_amount);
            };

            event::emit_event(&mut state.release_funds_events, broker_it_yourself_events::new_release_funds_event(offer_id, address, timestamp::now_seconds()));
        };

        // TODO: Emit CompleteTransactionEvent event

        // TODO: If both completion flags are true, then:
        //      1) Remove the offer from the available offers list
        //      2) Remove the offer's id from the creator's offers list
        //      3) Transfer appropriate amount of APT either to the creator or the counterparty depending on the
        //              Offer's sell_apt flag
        //      4) Emit ReleaseFundsEvent event
    }

    /*
        Removes an offer from the list of currently available offers
        @param creator - signer representing the creator of the offer
        @param offer_id - id of the offer
    */
    public entry fun cancel_offer(creator: &signer, offer_id: u128) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call assert_offer_exists function
        assert_offer_exists(&borrow_global<State>(@admin).offers, &offer_id);

        // TODO: Remove the offer from the list of available offers
        let state = borrow_global_mut<State>(@admin);
        let offer = *simple_map::borrow_mut(&mut state.offers, &offer_id);
        simple_map::remove(&mut state.offers, &offer_id);

        // TODO: Call assert_signer_is_creator function
        assert_signer_is_creator(creator, &offer);

        // TODO: Call assert_offer_not_accepted function
        assert_offer_not_accepted(&offer);

        // TODO: Call assert_dispute_not_opened function
        assert_dispute_not_opened(&offer);

        // TODO: Remove the offer's id from the creator's offers list
        remove_offer_from_creator_offers(&mut state.creators_offers, &signer::address_of(creator), &offer_id);

        // TODO: Transfer appropriate amount of APT from the PDA to the creator if the Offer's sell_apt == true
        let resource_signer = account::create_signer_with_capability(&mut state.cap);
        if (offer.sell_apt == true) {
        assert_user_has_enough_funds<AptosCoin>(signer::address_of(&resource_signer), offer.apt_amount);
          let resource_signer = account::create_signer_with_capability(&mut state.cap);
            coin::transfer<AptosCoin>(&resource_signer, signer::address_of(creator) , offer.apt_amount);
        };

        // TODO: Emit CancelOfferEvent event
        event::emit_event(&mut borrow_global_mut<State>(@admin).cancel_offer_events, broker_it_yourself_events::new_cancel_offer_event(offer_id, timestamp::now_seconds()));
    }

    /*
        Opens a dispute over a transaction
        @param user - signer representing one of the parties of the transaction
        @param offer_id - id of the offer
    */
    public entry fun open_dispute(user: &signer, offer_id: u128) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call assert_offer_exists function
        assert_offer_exists(&borrow_global<State>(@admin).offers, &offer_id);

        // TODO: Call assert_user_participates_in_transaction function
        let state = borrow_global_mut<State>(@admin);
        let offer = simple_map::borrow_mut(&mut state.offers, &offer_id);
        assert_user_participates_in_transaction(signer::address_of(user), offer);

        // TODO: Call assert_dispute_not_opened function
        assert_dispute_not_opened(offer);

        // TODO: Set the Offer's dispute_opened flag to true
        offer.dispute_opened = true;

        // TODO: Emit OpenDisputeEvent event
        event::emit_event(&mut state.open_dispute_events, broker_it_yourself_events::new_open_dispute_event(offer_id, *option::borrow(&offer.counterparty), timestamp::now_seconds()));
    }

    /*
        Resolves previously opened dispute over a transaction
        @param arbiter - signer representing the arbiter of the transaction
        @param offer_id - id of the offer
        @param terminate_offer - flag indicating if the offer should be removed from the list of available offers
        @param transfer_to_creator - flag indicating if the on-chain assets should be transfered to the creator of
            the offer (true) or to the counterparty (false) in case of termination
    */
    public entry fun resolve_dispute(
        arbiter: &signer,
        offer_id: u128,
        transfer_to_creator: bool
    ) acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Call assert_offer_exists function
        assert_offer_exists(&borrow_global<State>(@admin).offers, &offer_id);

        // TODO: Call assert_dispute_opened function
        let state = borrow_global_mut<State>(@admin);
        let offer = *simple_map::borrow_mut(&mut state.offers, &offer_id);
        assert_dispute_opened(&offer);

        // TODO: Call assert_singer_is_arbiter function
        assert_singer_is_arbiter(arbiter, &offer);

        // TODO: Remove the offer from the list of available offers
        simple_map::remove(&mut state.offers, &offer_id);

        // TODO: Remove the offer's id from the creator's offers list
        remove_offer_from_creator_offers(&mut state.creators_offers, &offer.creator, &offer_id);

        // TODO: If transfer_to_creator send funds to creator, else if !transfer_to_creator send funds to counterparty
        //      if there is a counterparty
        let resource_signer = account::create_signer_with_capability(&mut state.cap);
        assert_user_has_enough_funds<AptosCoin>(signer::address_of(&resource_signer), offer.apt_amount);
        if (transfer_to_creator) {
            coin::transfer<AptosCoin>(&resource_signer, offer.creator, offer.apt_amount);
        } else if (option::is_some(&offer.counterparty)) {
            coin::transfer<AptosCoin>(&resource_signer, option::extract(&mut offer.counterparty), offer.apt_amount);
        };

        // TODO: Emit ResolveDisputeEvent event
        event::emit_event(&mut state.resolve_dispute_events, broker_it_yourself_events::new_resolve_dispute_event(offer_id, transfer_to_creator, timestamp::now_seconds()));
    }

    /*
        Returns the list of all offers
        @returns - list of all offers
    */
    #[view]
    public fun get_all_offers(): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Returns the list of all offers
        borrow_global<State>(@admin).offers

    }

    /*
        Returns the list of available offers
        @returns - list list of available offers
    */
    #[view]
    public fun get_available_offers(): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Return a list of not accepted offers
        let offers = borrow_global<State>(@admin).offers;
        let result = simple_map::create();

        let len = borrow_global<State>(@admin).offer_id;
        let i = 0;
        while (i < len) {
            let offer = *simple_map::borrow(&offers, &i);
            if (option::is_none(&offer.counterparty)) {
                simple_map::add(&mut result, i, offer);
            };
            i = i + 1;
        };
        result
    }

    /*
        Returns a list of the offers that have dispute opened.
        @returns - list of offers with flag dispute_opened set to true
    */
    #[view]
    public fun get_arbitration_offers(): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Returns a list of the offers that have dispute opened
        let offers = borrow_global<State>(@admin).offers;
        let result = simple_map::create();

        let len = borrow_global<State>(@admin).offer_id;
        let i = 0;
        while (i < len) {
            if (simple_map::contains_key(&offers, &i)) {
                let offer = *simple_map::borrow(&offers, &i);
                if (offer.dispute_opened == true) {
                    simple_map::add(&mut result, i, offer);
                };
                i = i + 1;
            }
        };
        result
    }

    /*
        Returns a list of the provided creator's buy offers.
        @returns - list of the creator's offers with flag sell_apt set to false
    */
    #[view]
    public fun get_buy_offers(creator: address): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Returns a list of the provided creator's buy offers
        let offers = borrow_global<State>(@admin).offers;
        let result = simple_map::create();

        let len = borrow_global<State>(@admin).offer_id;
        let i = 0;
        while (i < len) {
            let offer = *simple_map::borrow(&offers, &i);
            if (offer.sell_apt == false && offer.creator == creator) {
                simple_map::add(&mut result, i, offer);
            };
            i = i + 1;
        };
        result
    }

    /*
        Returns a list of the provided creator's sell offers.
        @returns - list of the creator's offers with flag sell_apt set to true
    */
    #[view]
    public fun get_sell_offers(creator: address): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Returns a list of the provided creator's sell offers
        let offers = borrow_global<State>(@admin).offers;
        let result = simple_map::create();

        let len = borrow_global<State>(@admin).offer_id;
        let i = 0;
        while (i < len) {
            let offer = *simple_map::borrow(&offers, &i);
            if (offer.sell_apt && offer.creator == creator) {
                simple_map::add(&mut result, i, offer);
            };
            i = i + 1;
        };
        result
    }

    /*
        Returns offers associated with provided cretor
        @param creator - address of the creator
        @returns - list of offers associated with the provided creator
    */
    #[view]
    public fun get_creator_offers(creator: address): SimpleMap<u128, Offer> acquires State {
        // TODO: Call assert_state_initialized function
        assert_state_initialized();

        // TODO: Filter the list of available offers and return only those that were created by the provided creator
        let ids = simple_map::borrow(&borrow_global<State>(@admin).creators_offers, &creator);
        let offers = borrow_global<State>(@admin).offers;

        let result = simple_map::create();
        let len = vector::length(ids);
        let i = 0;
        while (i < len) {
            let id = *vector::borrow(ids, i);
            let offer = *simple_map::borrow(&offers, &id);
            simple_map::add(&mut result, id, offer);
            i = i + 1;
        };
        result
    }

    /*
        Removes an entry from the list of the creator's offers
        @param creators_offers - list of the creators' offers
        @param creator - address of the creator
        @param offer_id - id of the offer to be removed
    */
    public(friend) inline fun remove_offer_from_creator_offers(
        creators_offers: &mut SimpleMap<address, vector<u128>>,
        creator: &address,
        offer_id: &u128
    ) {
        // TODO: Find and remove the provided offer_id from the provided creator's offers list
        let offers = *simple_map::borrow(creators_offers, creator); 
        let len = vector::length(&offers);
        let vec = vector::empty<u128>();
        let i = 0;
        while (i < len) {
            let entry = vector::borrow(&offers, i);
            if (entry != offer_id) {
                vector::push_back(&mut vec, *entry);
            };
            i = i + 1;
        };
        simple_map::remove(creators_offers, creator);
        simple_map::add(creators_offers, *creator, vec);
    }

    /*
        Returns next offer id and increments the counter by 1
        @param offer_id - offer id counter
        @returns - next offer id
    */
    public(friend) inline fun get_next_offer_id(offer_id: &mut u128): u128 {
        // TODO: Return a copy of offer_id and increment the original by one
        *offer_id = *offer_id + 1;
        *offer_id - 1
    }

    /////////////
    // ASSERTS //
    /////////////

    inline fun assert_signer_is_admin(admin: &signer) {
        // TODO: Assert that the provided admin is the same as in Move.toml file
        assert!(signer::address_of(admin) == @admin, ERROR_SIGNER_NOT_ADMIN);
    }

    inline fun assert_state_initialized() {
        // TODO: Assert that State resource exists under the admin's address
        assert!(exists<State>(@admin), ERROR_STATE_NOT_INITIALIZED);
    }

    inline fun assert_user_has_enough_funds<CoinType>(user: address, coin_amount: u64) {
        // TODO: Assert that the provided user's balance equals or is greater than the coin_amount
        assert!(coin::balance<CoinType>(user) >= coin_amount, ERROR_INSUFFICIENT_FUNDS);
    }

    inline fun assert_offer_exists(
        offers: &SimpleMap<u128, Offer>,
        offer_id: &u128
    ) {
        // TODO: Assert that the offers contains the offer_id
        assert!(simple_map::contains_key(offers, offer_id), ERROR_OFFER_DOES_NOT_EXIST);
    }

    inline fun assert_offer_not_accepted(offer: &Offer) {
        // TODO: Assert that the offer does not have counterparty value
        assert!(option::is_none(&offer.counterparty), ERROR_OFFER_ALREADY_ACCEPTED);
    }

    inline fun assert_offer_accepted(offer: &Offer) {
        // TODO: Assert that the offer has counterparty value
        assert!(option::is_some(&offer.counterparty), ERROR_OFFER_NOT_ACCEPTED);
    }

    inline fun assert_user_participates_in_transaction(user: address, offer: &Offer) {
        // TODO: Assert that the provided user's address is either the creator or the counterparty
        assert!(user == offer.creator || option::some(user) == offer.counterparty, ERROR_USER_DOES_NOT_PARTICIPATE_IN_TRANSACTION);
    }

    inline fun assert_user_has_not_marked_completed_yet(user: address, offer: &Offer) {
        // TODO: Assert that the user has not marked the offer as completed yet (cover all cases)
        if (user == offer.creator) {
            assert!(offer.completion.creator == false, ERROR_USER_ALREADY_MARKED_AS_COMPLETED);
        } else if (option::some(user) ==  offer.counterparty) {
            assert!(offer.completion.counterparty == false,
                ERROR_USER_ALREADY_MARKED_AS_COMPLETED);
        }
    }

    inline fun assert_signer_is_creator(creator: &signer, offer: &Offer) {
        // TODO: Assert that the provided creator is the creator of the provided offer
        assert!(offer.creator == signer::address_of(creator), ERROR_SIGNER_NOT_CREATOR);
    }

    inline fun assert_dispute_not_opened(offer: &Offer) {
        // TODO: Assert that a dispute is not opened
        assert!(offer.dispute_opened == false, ERROR_DISPUTE_ALREADY_OPENED);
    }

    inline fun assert_dispute_opened(offer: &Offer) {
        // TODO: Assert that a dispute is opened
        assert!(offer.dispute_opened == true, ERROR_DISPUTE_NOT_OPENED);
    }

    inline fun assert_singer_is_arbiter(arbiter: &signer, offer: &Offer) {
        // TODO: Assert that the provided signer is the arbiter of the provided offer
        assert!(offer.arbiter == signer::address_of(arbiter), ERROR_SIGNER_NOT_ARBITER);
    }

    /////////////////////////
    // TEST-ONLY FUNCTIONS //
    /////////////////////////

    #[test_only]
    public(friend) fun state_exists(): bool {
        exists<State>(@admin)
    }

    #[test_only]
    public(friend) fun get_state_unpacked(): (
        SimpleMap<u128, Offer>,
        SimpleMap<address, vector<u128>>,
        u128,
        u64,
        u64,
        u64,
        u64,
        u64,
        u64,
        u64,
    ) acquires State {
        let state = borrow_global<State>(@admin);

        (
            state.offers,
            state.creators_offers,
            state.offer_id,
            event::counter(&state.create_offer_events),
            event::counter(&state.accept_offer_events),
            event::counter(&state.complete_transaction_events),
            event::counter(&state.release_funds_events),
            event::counter(&state.cancel_offer_events),
            event::counter(&state.open_dispute_events),
            event::counter(&state.resolve_dispute_events)
        )
    }

    #[test_only]
    public(friend) fun get_offer_unpacked(offer: Offer): (
        address,
        address,
        u64,
        u64,
        Option<address>,
        OfferCompletion,
        bool,
        bool
    ) {
        let Offer {
            creator,
            arbiter,
            apt_amount,
            usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        } = offer;

        (
            creator,
            arbiter,
            apt_amount,
            usd_amount,
            counterparty,
            completion,
            dispute_opened,
            sell_apt
        )
    }

    #[test_only]
    public(friend) fun get_offer_completion_unpacked(offer_completion: OfferCompletion): (bool, bool) {
        let OfferCompletion { creator, counterparty } = offer_completion;

        (creator, counterparty)
    }

    #[test_only]
    public(friend) fun open_dispute_unchecked(offer_id: u128) acquires State {
        let state = borrow_global_mut<State>(@admin);
        simple_map::borrow_mut(&mut state.offers, &offer_id).dispute_opened = true;
    }
}

```
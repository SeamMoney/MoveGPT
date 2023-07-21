module overmind::real_time_payment {
  use std::signer;

  use aptos_std::table::{Self, Table};
  use aptos_std::math64;

  use aptos_framework::timestamp;
  use aptos_framework::account::{Self, SignerCapability};
  use aptos_framework::coin;
  use aptos_framework::aptos_coin::AptosCoin;
  use aptos_framework::event::{Self, EventHandle};

  use overmind::payment_events::{Self, CreatePaymentEvent, ClaimPaymentEvent, CompletePaymentEvent, CancelPaymentEvent};

  const PAYMENT_SYSTEM_SEED: vector<u8> = b"PaymentSystem";

  const PAYMENT_DOES_NOT_EXIST: u64 = 0;
  const NO_PAYMENTS_FOUND: u64 = 1;
  const SENDER_DOES_NOT_MATCH: u64 = 2;

  /*
    Resource being stored in admin's account to keep track of PDA's address
  */
  struct State has key {
    // Address of a PDA storing PaymentSystem resource
    payment_system: address
  }

  /*
    Resource being stored in PDA keeping data about payments
  */
  struct PaymentSystem has key {
    // Table linking recipients with a list of payments being sent to them.
    // The inner table's key represents payment's id
    ongoing_payments: Table<address, Table<u128, Payment>>,
    // Id of the next transaction
    next_transaction_id: u128,

    // Events
    create_payment_events: EventHandle<CreatePaymentEvent>,
    claim_payment_events: EventHandle<ClaimPaymentEvent>,
    complete_payment_events: EventHandle<CompletePaymentEvent>,
    cancel_payment_events: EventHandle<CancelPaymentEvent>,

    cap: SignerCapability
  }

  /*
    Structure representing a single payment
  */
  struct Payment has store {
    // Address of a sender
    sender: address,
    // Remaining amount of coins, which can be claimed or will be able to be claimed in the future
    remaining_amount: u64,
    // Timestamp of the last time a recipient claimed coins
    last_claim_timestamp: u64, // miliseconds
    // Remaining duration, after which all coins will be available to be claimed
    remaining_duration: u64 // miliseconds
  }

  /*
    Initializes the smart contract by creating and setting up a PDA and creating resources
    @param account - admin account signing a transaction
  */
  public entry fun init_system(account: &signer) {
    // Create a resource account and store signing capabilities
    let (resource_account_signer, cap) = account::create_resource_account(account, PAYMENT_SYSTEM_SEED);
    // Store the address (where payment system will live) and register with AptosCoin so the resource account can handle transact
    let payment_system_address = signer::address_of(&resource_account_signer);
    coin::register<AptosCoin>(&resource_account_signer);
    // Give the account managing the system the resource account address
    move_to(account, State {
      payment_system: payment_system_address
    });
    // Give the resource account the payment system - a table of transactions and various events
    move_to(&resource_account_signer, PaymentSystem {
      ongoing_payments: table::new(),
      create_payment_events: account::new_event_handle<CreatePaymentEvent>(&resource_account_signer),
      claim_payment_events: account::new_event_handle<ClaimPaymentEvent>(&resource_account_signer),
      complete_payment_events: account::new_event_handle<CompletePaymentEvent>(&resource_account_signer),
      cancel_payment_events: account::new_event_handle<CancelPaymentEvent>(&resource_account_signer),
      next_transaction_id: 0,
      cap
    });
  }

  /*
    Creates a payment and stores data about it in the PDA and sends funds to the PDA
    @param sender - account sending funds
    @param recipient - account receiving funds
    @param amount - amount of APT to be sent
    @param duration - amount of time, over which the funds will be transfered to the recipient
  */
  public entry fun create_payment(
    sender: &signer,
    recipient: address,
    amount: u64,
    duration: u64 // miliseconds
  ) acquires State, PaymentSystem {
    // The administrator is the creator of the payment system
    // Get resource account managing payments
    // Signer is the sender
    // Time of transaction
    let state = borrow_global<State>(@admin);
    let payment_system = borrow_global_mut<PaymentSystem>(state.payment_system);
    let sender_address = signer::address_of(sender);
    let current_timestamp = timestamp::now_microseconds() / 1000; // miliseconds

    // Grab current transaction id and update future transaction id
    let transaction_id = payment_system.next_transaction_id;
    payment_system.next_transaction_id = payment_system.next_transaction_id + 1;

    // Create a payment
    let payment = Payment {
      sender: sender_address,
      remaining_amount: amount,
      last_claim_timestamp: current_timestamp,
      remaining_duration: duration
    };
    // Get the recipient or create a new entry if recipient does not exist (ie. first payment)
    if (!table::contains(&payment_system.ongoing_payments, recipient)) {
      table::add(&mut payment_system.ongoing_payments, recipient, table::new());
    };
    let inner_table = table::borrow_mut(&mut payment_system.ongoing_payments, recipient);
    // Add transaction in payment
    table::add(inner_table, transaction_id, payment);

    // Execute transfer and emit event if successful
    coin::transfer<AptosCoin>(sender, state.payment_system, amount);

    event::emit_event(
      &mut payment_system.create_payment_events,
      payment_events::new_create_payment_events(
        transaction_id,
        sender_address,
        recipient,
        amount,
        current_timestamp,
        current_timestamp + duration
      )
    );
  }

  /*
    Claims available coins from a payment of a provided id
    @param recipient - account receiving the funds
    @param transaction_id - id of the payment
  */
  public entry fun claim_payment(recipient: &signer, transaction_id: u128) acquires State, PaymentSystem {
    let state = borrow_global<State>(@admin);
    let payment_system = borrow_global_mut<PaymentSystem>(state.payment_system);
    let recipient_address = signer::address_of(recipient);

    // Check if any pending payments to recipient
    assert_payments_table_exists(&payment_system.ongoing_payments, recipient_address);
    let recipient_payments = table::borrow_mut(&mut payment_system.ongoing_payments, recipient_address);
    // Check the transaction id
    assert_payment_exists(recipient_payments, transaction_id);
    let payment = table::borrow_mut(recipient_payments, transaction_id);

    let current_timestamp = timestamp::now_microseconds() / 1000; // miliseconds
    let time_passed = current_timestamp - payment.last_claim_timestamp;

    // Payment gated by duration - can only draw partial if full time has not passed
    let amount_to_transfer = if (time_passed < payment.remaining_duration) {
      math64::mul_div(
        payment.remaining_amount,
        time_passed,
        payment.remaining_duration
      )
    } else {
      payment.remaining_amount
    };
    // Get resource account from signer capability and make transfer to recipient and emit event if successful
    let payment_system_signer = account::create_signer_with_capability(&payment_system.cap);
    coin::register<AptosCoin>(recipient);
    coin::transfer<AptosCoin>(&payment_system_signer, recipient_address, amount_to_transfer);

    event::emit_event(
      &mut payment_system.claim_payment_events,
      payment_events::new_claim_payment_event(
        transaction_id,
        payment.sender,
        recipient_address,
        amount_to_transfer,
        payment.remaining_amount - amount_to_transfer,
        current_timestamp
      )
    );
    // If fully paid, remove entry from payment system and emit complete payment event
    if (amount_to_transfer == payment.remaining_amount) {
      let payment = table::remove(recipient_payments, transaction_id);
      event::emit_event(
        &mut payment_system.complete_payment_events,
        payment_events::new_complete_payment_event(
          transaction_id,
          payment.sender,
          recipient_address,
          current_timestamp
        )
      );
      // Deconstruct payment - note, no drop ability! so only dropped this way.
      let Payment { sender: _, remaining_amount: _, last_claim_timestamp: _, remaining_duration: _ } = payment;
    } else {
      // If not fully paid, update remaining amount, remain duration and timestamps
      payment.remaining_amount = payment.remaining_amount - amount_to_transfer;
      payment.last_claim_timestamp = current_timestamp;
      payment.remaining_duration = payment.remaining_duration - time_passed;
    };
  }

  /*
    Cancels ongoing payment and returns all unclaimed coins to the sender
    @param sender - account, which created the payment
    @param recipient - account receiving the payment
    @param transaction_id - id of the payment
  */
  public entry fun cancel_payment(sender: &signer, recipient: address, transaction_id: u128) acquires State, PaymentSystem {
    // Get payment system and address of sender
    let state = borrow_global<State>(@admin);
    let payment_system = borrow_global_mut<PaymentSystem>(state.payment_system);
    let sender_address = signer::address_of(sender);

    // Check recipient and transaction id existence
    assert_payments_table_exists(&payment_system.ongoing_payments, recipient);
    let recipient_payments = table::borrow_mut(&mut payment_system.ongoing_payments, recipient);

    assert_payment_exists(recipient_payments, transaction_id);

    // Deconstruct the payment
    let Payment {
      sender,
      remaining_amount,
      last_claim_timestamp: _,
      remaining_duration: _
    } = table::remove(recipient_payments, transaction_id);
    // assert sender
    assert_sender_matches(&sender_address, &sender);
    // transfer remaining amount back to sender and emit event
    let payment_system_signer = account::create_signer_with_capability(&payment_system.cap);
    coin::transfer<AptosCoin>(&payment_system_signer, sender_address, remaining_amount);

    event::emit_event(
      &mut payment_system.cancel_payment_events,
      payment_events::new_cancel_payment_event(
        transaction_id,
        sender_address,
        recipient,
        remaining_amount,
        timestamp::now_microseconds() / 1000
      )
    );
  }

  //////////////////////
  // Assert functions //
  //////////////////////

  fun assert_payment_exists(payments: &Table<u128, Payment>, transaction_id: u128) {
    assert!(table::contains(payments, transaction_id), PAYMENT_DOES_NOT_EXIST);
  }

  fun assert_payments_table_exists(ongoing_payments: &Table<address, Table<u128, Payment>>, recipient: address) {
    assert!(table::contains(ongoing_payments, recipient), NO_PAYMENTS_FOUND);
  }

  fun assert_sender_matches(acutal_sender: &address, expected_sender: &address) {
    assert!(acutal_sender == expected_sender, SENDER_DOES_NOT_MATCH);
  }

  ///////////
  // TESTS //
  ///////////

  #[test_only]
  use aptos_framework::aptos_coin::Self;

  #[test_only]
  fun compare_remaining_amount_and_expected_with_time_epsilon(
    actual: u64,
    time_passed_miliseconds: u64,
    epsilon_miliseconds: u64,
    duration_miliseconds: u64,
    remaining_amount_before: u64  
  ): bool {
    let underestimated_withdrawal = math64::mul_div(
      remaining_amount_before,
      math64::min(time_passed_miliseconds - epsilon_miliseconds, duration_miliseconds),
      duration_miliseconds
    );
    let overestimated_withdrawal = math64::mul_div(
      remaining_amount_before,
      math64::min(time_passed_miliseconds + epsilon_miliseconds, duration_miliseconds),
      duration_miliseconds
    );
    remaining_amount_before - overestimated_withdrawal <= actual && actual <= remaining_amount_before - underestimated_withdrawal
  }

  #[test(account = @0xBEEF)]
  public entry fun test_init_system(account: &signer) acquires State, PaymentSystem {
    init_system(account);

    let account_address = signer::address_of(account);
    assert!(exists<State>(account_address), 0);

    let state = borrow_global<State>(account_address);
    let expected_payment_system_address = account::create_resource_address(&account_address, b"PaymentSystem");
    
    assert!(state.payment_system == expected_payment_system_address, 1);
    assert!(coin::is_account_registered<AptosCoin>(state.payment_system), 2);
    assert!(exists<PaymentSystem>(state.payment_system), 3);

    let payment_system = borrow_global<PaymentSystem>(state.payment_system);
    assert!(event::counter(&payment_system.create_payment_events) == 0, 4);
    assert!(event::counter(&payment_system.claim_payment_events) == 0, 5);
    assert!(event::counter(&payment_system.complete_payment_events) == 0, 6);
    assert!(event::counter(&payment_system.cancel_payment_events) == 0, 7);
    assert!(payment_system.next_transaction_id == 0, 8);
    assert!(&payment_system.cap == &account::create_test_signer_cap(state.payment_system), 9);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  public entry fun test_create_payment(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);
    let account_address = signer::address_of(account);

    account::create_account_for_test(sender_address);
    account::create_account_for_test(recipient_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 1000100123);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 1000100123, 1000 * 60 * 60 * 24);

    let timestamp_after = timestamp::now_microseconds() / 1000;
    let state = borrow_global<State>(account_address);
    let payment_system = borrow_global<PaymentSystem>(state.payment_system);

    assert!(table::contains(&payment_system.ongoing_payments, recipient_address), 0);
    assert!(event::counter(&payment_system.create_payment_events) == 1, 1);
    assert!(event::counter(&payment_system.claim_payment_events) == 0, 2);
    assert!(event::counter(&payment_system.complete_payment_events) == 0, 3);
    assert!(event::counter(&payment_system.cancel_payment_events) == 0, 4);
    assert!(payment_system.next_transaction_id == 1, 5);

    let payments = table::borrow(&payment_system.ongoing_payments, recipient_address);
    assert!(table::contains(payments, 0), 6);

    let payment = table::borrow(payments, 0);
    assert!(payment.sender == @0xCAB, 7);
    assert!(payment.remaining_amount == 1000100123, 8);
    assert!(payment.last_claim_timestamp <= timestamp_after, 9);
    assert!(payment.remaining_duration == 86400000, 10);

    assert!(coin::balance<AptosCoin>(sender_address) == 0, 11);
    assert!(coin::balance<AptosCoin>(state.payment_system) == 1000100123, 12);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  public entry fun test_claim_payment(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);
    let account_address = signer::address_of(account);
    let timestamp_epsilon_miliseconds = 10;

    account::create_account_for_test(sender_address);
    account::create_account_for_test(recipient_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 456122851);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 446122851, 1000 * 60 * 60 * 24 * 2);
    timestamp::fast_forward_seconds(123456);
    claim_payment(recipient, 0);

    {
      let state = borrow_global<State>(account_address);
      let payment_system = borrow_global<PaymentSystem>(state.payment_system);
      let payments = table::borrow(&payment_system.ongoing_payments, recipient_address);
    
      assert!(event::counter(&payment_system.create_payment_events) == 1, 0);
      assert!(event::counter(&payment_system.claim_payment_events) == 1, 1);
      assert!(event::counter(&payment_system.complete_payment_events) == 0, 2);
      assert!(event::counter(&payment_system.cancel_payment_events) == 0, 3);
      assert!(payment_system.next_transaction_id == 1, 4);

      let payment = table::borrow(payments, 0);
      assert!(payment.sender == sender_address, 5);
      assert!(
        compare_remaining_amount_and_expected_with_time_epsilon(
          payment.remaining_amount,
          123456000,
          timestamp_epsilon_miliseconds,
          172800000,
          446122851
        ),
        6
      );
      assert!(
        123456000 <= payment.last_claim_timestamp &&
        payment.last_claim_timestamp <= 123456000 + timestamp_epsilon_miliseconds,
        7
      );
      assert!(
        49344000 - timestamp_epsilon_miliseconds <= payment.remaining_duration &&
        payment.remaining_duration <= 49344000,
        8
      );
      assert!(coin::balance<AptosCoin>(state.payment_system) == payment.remaining_amount, 9);
      assert!(coin::balance<AptosCoin>(recipient_address) == 446122851 - payment.remaining_amount, 10);
    };
    
    timestamp::fast_forward_seconds(503040);
    claim_payment(recipient, 0);

    let state = borrow_global<State>(account_address);
    let payment_system = borrow_global<PaymentSystem>(state.payment_system);
    let payments = table::borrow(&payment_system.ongoing_payments, recipient_address);
    
    assert!(event::counter(&payment_system.create_payment_events) == 1, 11);
    assert!(event::counter(&payment_system.claim_payment_events) == 2, 12);
    assert!(event::counter(&payment_system.complete_payment_events) == 1, 13);
    assert!(event::counter(&payment_system.cancel_payment_events) == 0, 14);
    assert!(payment_system.next_transaction_id == 1, 15);
    assert!(!table::contains(payments, 0), 16);
    assert!(coin::balance<AptosCoin>(state.payment_system) == 0, 17);
    assert!(coin::balance<AptosCoin>(recipient_address) == 446122851, 17);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  #[expected_failure(abort_code = 0, location = Self)]
  public entry fun test_claim_payment_does_not_exist(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);

    account::create_account_for_test(sender_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 15648961651);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 15648961651, 1000 * 60 * 60 * 24 * 12);
    claim_payment(recipient, 1337);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  #[expected_failure(abort_code = 0, location = Self)]
  public entry fun test_claim_payment_does_not_exist_already_claimed(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);

    account::create_account_for_test(sender_address);
    account::create_account_for_test(recipient_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 15648961651);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 15648961651, 1000 * 60 * 60 * 24 * 12);
    timestamp::fast_forward_seconds(1036900);
    claim_payment(recipient, 0);
    claim_payment(recipient, 0);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(account = @admin, recipient = @0xCAFE)]
  #[expected_failure(abort_code = 1, location = Self)]
  public entry fun test_claim_payment_no_payments_found(
    account: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    init_system(account);
    claim_payment(recipient, 0);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  public entry fun test_cancel_payment(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);
    let account_address = signer::address_of(account);

    account::create_account_for_test(sender_address);
    account::create_account_for_test(recipient_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 446122851);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 446122851, 1000 * 60 * 60 * 24 * 2);
    timestamp::fast_forward_seconds(123456);
    claim_payment(recipient, 0);
    
    let remaining_amount = {
      let state = borrow_global<State>(account_address);
      let payment_system = borrow_global<PaymentSystem>(state.payment_system);
      let payments = table::borrow(&payment_system.ongoing_payments, recipient_address);
      let payment = table::borrow(payments, 0);
      
      payment.remaining_amount
    };

    cancel_payment(sender, recipient_address, 0);

    let state = borrow_global<State>(account_address);
    let payment_system = borrow_global<PaymentSystem>(state.payment_system);
    let payments = table::borrow(&payment_system.ongoing_payments, recipient_address);

    assert!(event::counter(&payment_system.create_payment_events) == 1, 0);
    assert!(event::counter(&payment_system.claim_payment_events) == 1, 1);
    assert!(event::counter(&payment_system.complete_payment_events) == 0, 2);
    assert!(event::counter(&payment_system.cancel_payment_events) == 1, 3);
    assert!(payment_system.next_transaction_id == 1, 4);
    assert!(!table::contains(payments, 0), 5);
    assert!(coin::balance<AptosCoin>(state.payment_system) == 0, 6);
    assert!(coin::balance<AptosCoin>(sender_address) == remaining_amount, 7);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB)]
  #[expected_failure(abort_code = 0, location = Self)]
  public entry fun test_cancel_payment_does_not_exist(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = @0xBEEF;

    account::create_account_for_test(sender_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 15648961651);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 15648961651, 1000 * 60 * 60 * 24 * 12);
    cancel_payment(sender, recipient_address, 1337);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE)]
  #[expected_failure(abort_code = 0, location = Self)]
  public entry fun test_cancel_payment_does_not_exist_already_claimed(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);

    account::create_account_for_test(sender_address);
    account::create_account_for_test(recipient_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 15648961651);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 15648961651, 1000 * 60 * 60 * 24 * 12);
    timestamp::fast_forward_seconds(1036900);
    claim_payment(recipient, 0);
    cancel_payment(sender, recipient_address, 0);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }

  #[test(account = @admin, sender = @0xCAB)]
  #[expected_failure(abort_code = 1, location = Self)]
  public entry fun test_cancel_payment_no_payments_found(
    account: &signer,
    sender: &signer
  ) acquires State, PaymentSystem {
    init_system(account);
    cancel_payment(sender, @0xBEEF, 0);
  }

  #[test(aptos_framework = @0x1, account = @admin, sender = @0xCAB, recipient = @0xCAFE, ineligible_account = @0xDAD)]
  #[expected_failure(abort_code = 2, location = Self)]
  public entry fun test_cancel_payment_sender_does_not_match(
    aptos_framework: &signer,
    account: &signer,
    sender: &signer,
    recipient: &signer,
    ineligible_account: &signer
  ) acquires State, PaymentSystem {
    let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
    let sender_address = signer::address_of(sender);
    let recipient_address = signer::address_of(recipient);

    account::create_account_for_test(sender_address);
    coin::register<AptosCoin>(sender);
    aptos_coin::mint(aptos_framework, sender_address, 15648961651);
    timestamp::set_time_has_started_for_testing(aptos_framework);

    init_system(account);
    create_payment(sender, recipient_address, 15648961651, 1000 * 60 * 60 * 24 * 12);
    cancel_payment(ineligible_account, recipient_address, 0);

    coin::destroy_burn_cap<AptosCoin>(burn_cap);
    coin::destroy_mint_cap<AptosCoin>(mint_cap);
  }
}
module overmind::payment_events {
  struct CreatePaymentEvent has drop, store {
    transaction_id: u128,
    sender: address,
    recipient: address,
    amount: u64,
    start_timestamp: u64,
    end_timestamp: u64
  }

  struct ClaimPaymentEvent has drop, store {
    transaction_id: u128,
    sender: address,
    recipient: address,
    claimed_amount: u64,
    remaining_amount: u64,
    claim_timestamp: u64
  }

  struct CompletePaymentEvent has drop, store {
    transaction_id: u128,
    sender: address,
    recipient: address,
    completion_timestamp: u64
  }

  struct CancelPaymentEvent has drop, store {
    transaction_id: u128,
    sender: address,
    recipient: address,
    remaining_amount: u64,
    cancelation_timestamp: u64,
  }

  public fun new_create_payment_events(
    transaction_id: u128,
    sender: address,
    recipient: address,
    amount: u64,
    start_timestamp: u64,
    end_timestamp: u64
  ): CreatePaymentEvent {
    CreatePaymentEvent {
      transaction_id,
      sender,
      recipient,
      amount,
      start_timestamp,
      end_timestamp
    }
  }

  public fun new_claim_payment_event(
    transaction_id: u128,
    sender: address,
    recipient: address,
    claimed_amount: u64,
    remaining_amount: u64,
    claim_timestamp: u64
  ): ClaimPaymentEvent {
    ClaimPaymentEvent {
      transaction_id,
      sender,
      recipient,
      claimed_amount,
      remaining_amount,
      claim_timestamp
    }
  }

  public fun new_complete_payment_event(
    transaction_id: u128,
    sender: address,
    recipient: address,
    completion_timestamp: u64
  ): CompletePaymentEvent {
    CompletePaymentEvent {
      transaction_id,
      sender,
      recipient,
      completion_timestamp
    }
  }

  public fun new_cancel_payment_event(
    transaction_id: u128,
    sender: address,
    recipient: address,
    remaining_amount: u64,
    cancelation_timestamp: u64
  ): CancelPaymentEvent {
    CancelPaymentEvent {
      transaction_id,
      sender,
      recipient,
      remaining_amount,
      cancelation_timestamp
    }
  }
}
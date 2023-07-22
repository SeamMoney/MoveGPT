module overmind::broker_it_yourself_events {
    friend overmind::broker_it_yourself;

    struct CreateOfferEvent has store, drop {
        offer_id: u128,
        creator: address,
        arbiter: address,
        apt_amount: u64,
        usd_amount: u64,
        sell_apt: bool,
        timestamp: u64
    }

    struct AcceptOfferEvent has store, drop {
        offer_id: u128,
        counterparty: address,
        timestamp: u64
    }

    struct CompleteTransactionEvent has store, drop {
        offer_id: u128,
        party: address,
        timestamp: u64
    }

    struct ReleaseFundsEvent has store, drop {
        offer_id: u128,
        party: address,
        timestamp: u64
    }

    struct CancelOfferEvent has store, drop {
        offer_id: u128,
        timestamp: u64
    }

    struct OpenDisputeEvent has store, drop {
        offer_id: u128,
        party: address,
        timestamp: u64
    }

    struct ResolveDisputeEvent has store, drop {
        offer_id: u128,
        transfer_to_creator: bool,
        timestamp: u64
    }

    public(friend) fun new_create_offer_event(
        offer_id: u128,
        creator: address,
        arbiter: address,
        apt_amount: u64,
        usd_amount: u64,
        sell_apt: bool,
        timestamp: u64
    ): CreateOfferEvent {
        CreateOfferEvent {
            offer_id,
            creator,
            arbiter,
            apt_amount,
            usd_amount,
            sell_apt,
            timestamp
        }
    }

    public(friend) fun new_accept_offer_event(offer_id: u128, counterparty: address, timestamp: u64): AcceptOfferEvent {
        AcceptOfferEvent { offer_id, counterparty, timestamp }
    }

    public(friend) fun new_complete_transaction_event(
        offer_id: u128,
        party: address,
        timestamp: u64
    ): CompleteTransactionEvent {
        CompleteTransactionEvent { offer_id, party, timestamp }
    }

    public(friend) fun new_release_funds_event(offer_id: u128, party: address, timestamp: u64): ReleaseFundsEvent {
        ReleaseFundsEvent { offer_id, party, timestamp }
    }

    public(friend) fun new_cancel_offer_event(offer_id: u128, timestamp: u64): CancelOfferEvent {
        CancelOfferEvent { offer_id, timestamp }
    }

    public(friend) fun new_open_dispute_event(offer_id: u128, party: address, timestamp: u64): OpenDisputeEvent {
        OpenDisputeEvent { offer_id, party, timestamp }
    }

    public(friend) fun new_resolve_dispute_event(
        offer_id: u128,
        transfer_to_creator: bool,
        timestamp: u64
    ): ResolveDisputeEvent {
        ResolveDisputeEvent { offer_id, transfer_to_creator, timestamp }
    }
}
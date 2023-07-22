// SPDX-License-Identifier: Apache-2.0
module aptos_monkeys_rafflor::rafflor_with_tokens {
    use std::error;
    use std::signer;
    use std::vector;
    use std::timestamp;
    use std::string::String;
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_std::event::{Self, EventHandle};
    use aptos_std::table::{Self, Table};
    use aptos_token::token;

    use aptos_monkeys_rafflor::pseudorandom;

    // error constants
    const ENOT_ROOT: u64 = 0;
    const ERAFFLOR_CAN_NOT_BE_BUYER: u64 = 1;
    const EDRAW_TIME_NOT_REACHED: u64 = 2;
    const EINVALID_DRAW_TIME: u64 = 3;
    const EINVALID_TICKET_PRICE: u64 = 4;
    const EINVALID_TICKET_COUNT: u64 = 5;
    const EWINNER_NOT_MATCHED: u64 = 6;
    const EPRIZE_ALREADY_CLAIMED: u64 = 7;
    const EWINNER_NOT_MATCHED_FOR_PRIZE: u64 = 8;
    const ERAFFLE_ALREADY_DRAWN: u64 = 9;
    const ERAFFLE_NOT_DRAWN: u64 = 10;
    const ECLAIMER_HAS_NO_TICKETS: u64 = 11;
    const ECLAIMER_HAS_NO_WINNING_TICKET: u64 = 12;
    const ETICKET_MAX_REACHED: u64 = 12;

    struct ForumId has store, drop, copy {
        forum_address: address,
    }

    struct Forum has key {
        forum_id: ForumId,
        fee_percentage: u64,
        signer_cap: account::SignerCapability,
    }

    struct ForumEvents has key {
        create_forum_event: EventHandle<CreateForumEvent>,
        create_raffle_events: EventHandle<CreateRaffleEvent>,
        buy_tickets_events: EventHandle<BuyTicketsEvent>,
        draw_raffle_events: EventHandle<DrawRaffleEvent>,
        claim_prize_events: EventHandle<ClaimPrizeEvent>,
    }

    struct RaffleStore<phantom CoinType> has key {
        raffles: Table<u64, Raffle<CoinType>>,
        last_raffle_id: u64,
    }

    struct Raffle<phantom CoinType> has store, drop, copy {
        raffle_id: u64,
        forum_id: ForumId,
        rafflor: address,
        token_id: token::TokenId,
        payment_collection: String,
        payment_collection_creator: address,
        payment_collection_property_version: u64,
        ticket_price: u64,
        ticket_max: u64,
        ticket_sold: u64,
        ticket_max_per_wallet: u64,
        draw_time: u64,
        winning_ticket: u64,
        claimed: bool,
        drawn: bool,
    }

    struct Ticket has store, drop, copy {
        raffle_id: u64,
        ticket_id: u64,
        forum_id: ForumId,
    }

    struct TicketsEnvelope has key {
        tickets: vector<Ticket>,
    }

    struct CreateForumEvent has drop, store {
        forum_id: ForumId,
        fee_percentage: u64,
    }

    struct CreateRaffleEvent has drop, store {
        raffle_id: u64,
        forum_id: ForumId,
        rafflor: address,
        token_id: token::TokenId,
        ticket_price: u64,
        ticket_max: u64,
        ticket_max_per_wallet: u64,
        draw_time: u64,
    }

    struct BuyTicketsEvent has drop, store {
        raffle_id: u64,
        buyer: address,
        ticket_count: u64,
        forum_id: ForumId,
    }

    struct DrawRaffleEvent has drop, store {
        raffle_id: u64,
        ticket_id: u64,
    }

    struct ClaimPrizeEvent has drop, store {
        raffle_id: u64,
        ticket_id: u64,
        winner: address,
    }

    fun get_resource_account_cap(forum_address: address): signer acquires Forum {
        let forum = borrow_global<Forum>(forum_address);
        account::create_signer_with_capability(&forum.signer_cap)
    }

    public entry fun register_coin_type<CoinType>(sender: &signer) {
        if (!coin::is_account_registered<CoinType>(signer::address_of(sender))){
            coin::register<CoinType>(sender);
        };
    }

    public entry fun create_forum<CoinType>(sender: &signer, fee_percentage: u64) {
        let forum_address = signer::address_of(sender);
        assert!(forum_address == @aptos_monkeys_rafflor, error::permission_denied(ENOT_ROOT));

        let forum_id = ForumId { forum_address };
        let (_, signer_cap) = account::create_resource_account(sender, x"ab41c0d3");

        register_coin_type<CoinType>(sender);

        if (!exists<Forum>(forum_address)) {
            move_to(sender, Forum {
                forum_id,
                fee_percentage,
                signer_cap,
            });

            pseudorandom::init(sender);
        };

        if (!exists<ForumEvents>(forum_address)) {
            move_to(sender, ForumEvents {
                create_forum_event: account::new_event_handle<CreateForumEvent>(sender),
                create_raffle_events: account::new_event_handle<CreateRaffleEvent>(sender),
                buy_tickets_events: account::new_event_handle<BuyTicketsEvent>(sender),
                draw_raffle_events: account::new_event_handle<DrawRaffleEvent>(sender),
                claim_prize_events: account::new_event_handle<ClaimPrizeEvent>(sender),
            });
        };

        if (!exists<RaffleStore<CoinType>>(forum_address)) {
            move_to(sender, RaffleStore<CoinType> {
                raffles: table::new(),
                last_raffle_id: 0,
            });
        };
    }

    public entry fun create_raffle<CoinType>(sender: &signer, forum_address: address, creator: address, collection: String, name: String, property_version: u64, ticket_price: u64, ticket_max: u64, ticket_max_per_wallet: u64, draw_time: u64, payment_collection: String, payment_collection_creator: address, payment_collection_property_version: u64) acquires Forum, ForumEvents, RaffleStore {
        let forum_id = ForumId { forum_address };
        let forum_events = borrow_global_mut<ForumEvents>(forum_address);
        let raffle_store = borrow_global_mut<RaffleStore<CoinType>>(forum_address);
        let resource_signer = get_resource_account_cap(forum_address);

        register_coin_type<CoinType>(sender);

        let raffle_id = raffle_store.last_raffle_id + 1;
        raffle_store.last_raffle_id = raffle_id;

        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let token = token::withdraw_token(sender, token_id, 1);
        token::deposit_token(&resource_signer, token);

        let rafflor_addr = signer::address_of(sender);

        table::add(&mut raffle_store.raffles, raffle_id, Raffle<CoinType> {
            raffle_id,
            forum_id,
            rafflor: rafflor_addr,
            payment_collection_property_version,
            payment_collection_creator,
            payment_collection,
            token_id,
            ticket_price,
            ticket_max,
            ticket_sold: 0,
            ticket_max_per_wallet,
            draw_time,
            winning_ticket: 0,
            claimed: false,
            drawn: false,
        });

        event::emit_event(&mut forum_events.create_raffle_events, CreateRaffleEvent {
            raffle_id,
            forum_id,
            rafflor: rafflor_addr,
            token_id,
            ticket_price,
            ticket_max,
            ticket_max_per_wallet,
            draw_time,
        });
    }

    public entry fun buy_tickets<CoinType>(sender: &signer, forum_address: address, raffle_id: u64, ticket_count: u64, payment_token_name: String) acquires Forum, ForumEvents, RaffleStore, TicketsEnvelope {
        let forum_id = ForumId { forum_address };
        let forum_events = borrow_global_mut<ForumEvents>(forum_address);
        let raffle_store = borrow_global_mut<RaffleStore<CoinType>>(forum_address);

        let raffle = table::borrow_mut<u64, Raffle<CoinType>>(&mut raffle_store.raffles, raffle_id);
        let resource_signer = get_resource_account_cap(forum_address);
        let buyer_addr = signer::address_of(sender);

        assert!(buyer_addr != raffle.rafflor, ERAFFLOR_CAN_NOT_BE_BUYER);
        assert!(raffle.ticket_sold + ticket_count <= raffle.ticket_max, ETICKET_MAX_REACHED);

        if (!exists<TicketsEnvelope>(buyer_addr)) {
            move_to(sender, TicketsEnvelope {
                tickets: vector::empty(),
            });
        };

        let tickets_envelope = borrow_global_mut<TicketsEnvelope>(buyer_addr);
        let tickets = &mut tickets_envelope.tickets;

        // TODO: check tickets and max per wallet

        let lastTicketId = raffle.ticket_sold;
        raffle.ticket_sold = raffle.ticket_sold + ticket_count;

        let i = 1;

        while (i <= ticket_count) {
            let ticket_id = lastTicketId + i;

            let collection = raffle.payment_collection;
            let creator = raffle.payment_collection_creator;
            let property_version = raffle.payment_collection_property_version;
            let token_id = token::create_token_id_raw(creator, collection, payment_token_name, property_version);
            let token = token::withdraw_token(sender, token_id, 1);
            token::deposit_token(&resource_signer, token);

            vector::push_back(tickets, Ticket {
                raffle_id,
                ticket_id,
                forum_id,
            });

            i = i + 1;
        };

        event::emit_event(&mut forum_events.buy_tickets_events, BuyTicketsEvent {
            raffle_id,
            buyer: buyer_addr,
            ticket_count,
            forum_id,
        });
    }

    public entry fun draw_raffle<CoinType>(sender: &signer, forum_address: address, raffle_id: u64) acquires ForumEvents, RaffleStore {
        let sender_addr = signer::address_of(sender);
        let forum_events = borrow_global_mut<ForumEvents>(forum_address);
        let raffle_store = borrow_global_mut<RaffleStore<CoinType>>(forum_address);

        let raffle = table::borrow_mut<u64, Raffle<CoinType>>(&mut raffle_store.raffles, raffle_id);

        assert!(raffle.drawn == false, ERAFFLE_ALREADY_DRAWN);
        assert!((timestamp::now_seconds() * 1000) >= raffle.draw_time, EDRAW_TIME_NOT_REACHED);

        let winning_ticket = pseudorandom::rand_u64_range(&sender_addr, 1, raffle.ticket_sold + 1);
        raffle.winning_ticket = winning_ticket;
        raffle.drawn = true;

        event::emit_event(&mut forum_events.draw_raffle_events, DrawRaffleEvent {
            raffle_id,
            ticket_id: winning_ticket,
        });
    }

    public entry fun claim_prize<CoinType>(sender: &signer, forum_address: address, raffle_id: u64) acquires Forum, ForumEvents, RaffleStore, TicketsEnvelope {
        let resource_signer = get_resource_account_cap(forum_address);
        let forum_events = borrow_global_mut<ForumEvents>(forum_address);
        let raffle_store = borrow_global_mut<RaffleStore<CoinType>>(forum_address);
        let raffle = table::borrow_mut(&mut raffle_store.raffles, raffle_id);
        let claimer_address = signer::address_of(sender);

        assert!(raffle.drawn == true, ERAFFLE_NOT_DRAWN);
        assert!(raffle.claimed == false, EPRIZE_ALREADY_CLAIMED);
        assert!(exists<TicketsEnvelope>(claimer_address), ECLAIMER_HAS_NO_TICKETS);

        let winning_ticket = raffle.winning_ticket;
        let tickets_envelope = borrow_global_mut<TicketsEnvelope>(claimer_address);

        let i = 0;
        let found = false;

        while (i < vector::length(&tickets_envelope.tickets) && !found) {
            let ticket = vector::borrow(&tickets_envelope.tickets, i);

            if (ticket.raffle_id == raffle_id && ticket.ticket_id == winning_ticket) {
                found = true;
            };

            i = i + 1;
        };

        assert!(found, ECLAIMER_HAS_NO_WINNING_TICKET);

        let token = token::withdraw_token(&resource_signer, raffle.token_id, 1);
        token::deposit_token(sender, token);

        raffle.claimed = true;

        event::emit_event(&mut forum_events.claim_prize_events, ClaimPrizeEvent {
            ticket_id: raffle.winning_ticket,
            winner: claimer_address,
            raffle_id,
        });
    }
}

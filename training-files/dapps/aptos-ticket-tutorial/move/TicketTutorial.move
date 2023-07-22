module TicketTutorial::tickets {
    use std::signer;
    use std::vector;
    // use aptos_framework::managed_coin;
    use aptos_framework::coin;
    use std::string;
    use aptos_framework::table_with_length;

    #[test_only]
    use aptos_std::type_info;
    #[test_only]
    use std::debug;

    struct ConcertTicket has key, store, drop {
        identifier: SeatIdentifier,
        ticket_code: string::String,
        price: u64,
    }

    struct SeatIdentifier has store, copy, drop {
        row: string::String,
        seat_number: u64
    }

    struct Venue has key {
        available_tickets: table_with_length::TableWithLength<SeatIdentifier, ConcertTicket>,
        max_seats: u64
    }

    struct TicketEnvelope has key {
        tickets: vector<ConcertTicket>
    }

    const ENO_VENUE: u64 = 0;
    const ENO_TICKETS: u64 = 1;
    const ENO_ENVELOPE: u64 = 2;
    const EINVALID_TICKET_COUNT: u64 = 3;
    const EINVALID_TICKET: u64 = 4;
    const EINVALID_PRICE: u64 = 5;
    const EMAX_SEATS: u64 = 6;
    const EINVALID_BALANCE: u64 = 7;

    public entry fun init_venue(venue_owner: &signer, max_seats: u64) {
        let available_tickets = table_with_length::new<SeatIdentifier, ConcertTicket>();
        move_to<Venue>(venue_owner, Venue { available_tickets, max_seats })
    }

    public entry fun create_ticket(venue_owner: &signer, row: vector<u8>, seat_number: u64, ticket_code: vector<u8>, price: u64) acquires Venue {
        // Check if the venue exists
        let venue_owner_addr = signer::address_of(venue_owner);
        assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);

        let current_seat_count = available_ticket_count(venue_owner_addr);
        let venue = borrow_global_mut<Venue>(venue_owner_addr);
        assert!(current_seat_count < venue.max_seats, EMAX_SEATS);

        // impl1: Use move_to
        // move_to<ConcertTicket>(venue_owner, ConcertTicket {seat, ticket_code})

        // impl2: Use vector
        // vector::push_back(&mut venue.available_tickets, ConcertTicket {seat, ticket_code, price});

        // impl3: Use table
        let identifier = SeatIdentifier { row: string::utf8(row), seat_number };
        let ticket = ConcertTicket { identifier, ticket_code: string::utf8(ticket_code), price};
        table_with_length::add(&mut venue.available_tickets, identifier, ticket)
    }

    // Table does not support length
    public fun available_ticket_count(venue_owner_addr: address): u64 acquires Venue {
        let venue = borrow_global<Venue>(venue_owner_addr);
        table_with_length::length<SeatIdentifier, ConcertTicket>(&venue.available_tickets)
    }

    /*
    fun get_ticket_info(venue_owner_addr: address, seat: vector<u8>): (bool, vector<u8>, u64, u64) acquires Venue {
        assert!(exists<Venue>(venue_owner_addr), ENO_VENUE);
        let venue = borrow_global<Venue>(venue_owner_addr);
        let i = 0;
        let len = vector::length<ConcertTicket>(&venue.available_tickets);
        while (i < len) {
            let ticket = vector::borrow<ConcertTicket>(&venue.available_tickets, i);
            if (ticket.seat == seat) return (true, ticket.ticket_code, ticket.price, i);
            i = i + 1;
        };

        return (false, b"", 0, 0)
    }

    public fun get_ticket_price(venue_owner_addr: address, seat: vector<u8>): (bool, u64) acquires Venue {
        let (success, _, price, _) = get_ticket_info(venue_owner_addr, seat);
        assert!(success, EINVALID_TICKET);
        return (success, price)
    }
    */

    public entry fun purchase_ticket<CoinType>(buyer: &signer, venue_owner_addr: address, row: vector<u8>, seat_number: u64) acquires Venue, TicketEnvelope {
        let buyer_addr = signer::address_of(buyer);
        let target_seat_id = SeatIdentifier { row: string::utf8(row), seat_number };
        let venue = borrow_global_mut<Venue>(venue_owner_addr);
        assert!(table_with_length::contains<SeatIdentifier, ConcertTicket>(&venue.available_tickets, target_seat_id), EINVALID_TICKET);

        let target_ticket = table_with_length::borrow<SeatIdentifier, ConcertTicket>(&venue.available_tickets, target_seat_id);
        coin::transfer<CoinType>(buyer, venue_owner_addr, target_ticket.price);
        let ticket = table_with_length::remove<SeatIdentifier, ConcertTicket>(&mut venue.available_tickets, target_seat_id);

        // Create an envelope for the account if it is the first purchase for him/her.
        if (!exists<TicketEnvelope>(buyer_addr)) {
            move_to<TicketEnvelope>(buyer, TicketEnvelope { tickets: vector::empty<ConcertTicket>() });
        };

        let envelope = borrow_global_mut<TicketEnvelope>(buyer_addr);
        vector::push_back<ConcertTicket>(&mut envelope.tickets, ticket);
    }

    #[test_only]
    struct MockMoney { }

    fun test_available_tickets() {
        // TODO
    }

    #[test(venue_owner = @0x111, buyer = @0x222, x=@TicketTutorial)]
    fun test_purchase_ticket(venue_owner: signer, buyer: signer, x: signer) acquires Venue, TicketEnvelope {
        let venue_owner_addr = signer::address_of(&venue_owner);
        let buyer_addr = signer::address_of(&buyer);

        aptos_framework::account::create_account_for_test(venue_owner_addr);
        aptos_framework::account::create_account_for_test(buyer_addr);

        init_venue(&venue_owner, 10);
        create_ticket(&venue_owner, b"A", 24, b"AB43C7F", 0);

        // let type_info = type_info::type_of<MockMoney>();
        // let address: address = type_info::account_address(&type_info);
        // debug::print(&address);

        // create reward coin
        aptos_framework::managed_coin::initialize<MockMoney>(
            &x,
            b"Mokshya Money",
            b"MOK",
            10,
            true
        );
        aptos_framework::managed_coin::register<MockMoney>(&buyer);
        aptos_framework::managed_coin::mint<MockMoney>(&x, buyer_addr, 100);

        aptos_framework::managed_coin::register<MockMoney>(&venue_owner);

        purchase_ticket<MockMoney>(&buyer, venue_owner_addr, b"A", 24);

        assert!(coin::balance<MockMoney>(buyer_addr) == 65, EINVALID_BALANCE);
        assert!(coin::balance<MockMoney>(venue_owner_addr) == 35, EINVALID_BALANCE);
    }
}

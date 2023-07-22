module ConcertTicket::Tickets {

    use std::signer;
    use std::vector;
    // use std::string;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use aptos_framework::aptos_account;

    const E_NO_VENUE: u64 = 0;
    const E_NO_TICKET: u64 = 1;
    const E_MAX_TICKETS: u64 = 2;
    const E_INVALID_TICKET_CODE: u64 = 3;
    const E_INVALID_TICKET_PRICE: u64 = 4;
    const E_INVALID_TICKET_STATUS: u64 = 5;
    const E_INVALID_BALANCE: u64 = 6;

    struct Ticket has key, store, drop {
        seat: vector<u8>,
        ticket_code: vector<u8>,
        price: u64
    }

    struct Venue has key {
        available_tickets: vector<Ticket>,
        max_tickets: u64
    }

    struct TicketInfo has drop {
        status: bool,
        ticket_code: vector<u8>,
        price: u64,
        index: u64 
    }

    struct TicketEnvelope has key {
        tickets: vector<Ticket>
    } 

    struct TestMoney has key, drop {}


    public entry fun create_venue(venue_owner: &signer, max_tickets: u64) {
        let available_tickets = vector::empty<Ticket>();
        move_to<Venue>(venue_owner, Venue{available_tickets, max_tickets})
    }

    public fun available_ticket_count(venue_owner_addr: address): u64 acquires Venue {
        let venue = borrow_global<Venue>(venue_owner_addr);
        vector::length<Ticket>(&venue.available_tickets)
    }

    public entry fun create_ticket(venue_owner: &signer, seat: vector<u8>, ticket_code: vector<u8>, price: u64) acquires Venue {
        let venue_owner_addr = signer::address_of(venue_owner);
        assert!(exists<Venue>(venue_owner_addr), E_NO_VENUE);

        let available_tickets_count = available_ticket_count(venue_owner_addr); 
        let venue = borrow_global_mut<Venue>(venue_owner_addr);
        assert!(available_tickets_count <= venue.max_tickets, E_MAX_TICKETS); 

        vector::push_back(&mut venue.available_tickets, Ticket{seat, ticket_code, price});
    }

    public entry fun get_ticket_info(venue_owner: address, seat: vector<u8>): TicketInfo acquires Venue {
        assert!(exists<Venue>(venue_owner), E_NO_VENUE);
        let length = available_ticket_count(venue_owner);
        let venue = borrow_global<Venue>(venue_owner);
        let i = 0;
        while (i < length) {
            let ticket = vector::borrow<Ticket>(&venue.available_tickets, i);
            if (ticket.seat == seat) {
                return TicketInfo{status: true, ticket_code: ticket.ticket_code, price: ticket.price, index: i}
            } else {
                i = i + 1;
            }
        };
        TicketInfo{status: false, ticket_code: b"", price: 0, index: 0}
    }

    public entry fun purchase_ticket<CoinType>(buyer: &signer, venue_owner: address, seat: vector<u8>) acquires Venue, TicketEnvelope {
        assert!(exists<Venue>(venue_owner), E_NO_VENUE);

        let buyer_addr = signer::address_of(buyer);
        let ticket_info = get_ticket_info(venue_owner, seat);

        let venue = borrow_global_mut<Venue>(venue_owner);
        coin::transfer<CoinType>(buyer, venue_owner, ticket_info.price);
        let ticket = vector::remove<Ticket>(&mut venue.available_tickets, ticket_info.index);
        if (!exists<TicketEnvelope>(buyer_addr)) {
            move_to<TicketEnvelope>(buyer, TicketEnvelope{tickets: vector::empty<Ticket>()})
        };
        let ticket_envelope = borrow_global_mut<TicketEnvelope>(buyer_addr);
        vector::push_back<Ticket>(&mut ticket_envelope.tickets, ticket);
    }

    #[test_only]
    struct FakeCoin {}

    #[test_only]
    public fun initialize_coin_and_mint(admin: &signer, user: &signer, mint_amount: u64) {
        let user_addr = signer::address_of(user);
        managed_coin::initialize<FakeCoin>(admin, b"fake", b"F", 9, false);
        aptos_account::create_account(user_addr);
        managed_coin::register<FakeCoin>(user);
        managed_coin::mint<FakeCoin>(admin, user_addr, mint_amount); 
    }

    #[test(recipient = @0x4, buyer = @0x2, module_owner = @ConcertTicket )]
    public entry fun sender_can_create_ticket(recipient: signer, module_owner: signer, buyer: signer) acquires Venue, TicketEnvelope {
        // use aptos_framework::aptos_coin::{Self, AptosCoin};
        create_venue(&recipient, 100); 
        create_ticket(&recipient, b"A24", b"A24001", 100);
        create_ticket(&recipient, b"A25", b"A25001", 500);
        create_ticket(&recipient, b"A26", b"A26001", 1000);
        let recipient_addr = signer::address_of(&recipient);
        let buyer_addr = signer::address_of(&buyer);
        let ticket_count = available_ticket_count(recipient_addr);
        let ticket_info = get_ticket_info(recipient_addr, b"A24");
        assert!(ticket_info.ticket_code == b"A24001", E_INVALID_TICKET_CODE);
        assert!(ticket_info.price == 100, E_INVALID_TICKET_PRICE);
        assert!(ticket_info.status, E_INVALID_TICKET_STATUS);
        assert!(ticket_count == 3, E_NO_TICKET);

        let initial_mint_amount = 10000;
        initialize_coin_and_mint(&module_owner, &buyer, initial_mint_amount);
        aptos_account::create_account(recipient_addr);
        managed_coin::register<FakeCoin>(&recipient);
        assert!(coin::balance<FakeCoin>(buyer_addr) == initial_mint_amount, E_INVALID_BALANCE);
        purchase_ticket<FakeCoin>(&buyer, recipient_addr, b"A24");
        let purchase_ticket_info = get_ticket_info(recipient_addr, b"A24");
        assert!(purchase_ticket_info.price == 00, E_INVALID_TICKET_PRICE);
        assert!(purchase_ticket_info.status == false, E_INVALID_TICKET_PRICE);
        assert!(coin::balance<FakeCoin>(buyer_addr) == (initial_mint_amount - 100), E_INVALID_BALANCE);
        assert!(coin::balance<FakeCoin>(recipient_addr) == 100, E_INVALID_BALANCE);
        
    }
}
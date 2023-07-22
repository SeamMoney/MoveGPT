/*
    This module represents a simple implementation of the object model.
    A ticket represents an object, it consists of 2 variables, price and seat.
    A seat represents another object, it has 2 variables as well, category and price_modifier,
    and it can be upgraded.  
*/
module ticket_addr::ticket {
    use aptos_framework::object::{Self, ConstructorRef, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use std::option::{Self, Option};
    use std::signer;
    use std::string::{Self, String};

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Ticket has key {
        price: u64,
        seat: Option<Object<Seat>>,
        // mutator reference to be able to manipulate the ticket object.
        mutator_ref: token::MutatorRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Seat has key{
        category: String,
        // A price modifier that is, when a ticket get the upgrade,  
        // the new ticket price will be changed.
        price_modifier: u64,
    }

    // Store the created collection in a resource account. 
    // This step is important to be able to modify the collection, including creating or destroying tickets.
    struct OnChainConfig has key {
        collection_name: String,
    }

    // For minting the base ticket, no seat assigned, we start by creating the collection.
    // In this example, a collection is an object containing the ticket object as well as the seat object.
    // Check collection.move for more information.
    fun init_module(account: &signer) {
        let new_collection_name = string::utf8(b"ticket");
        collection::create_fixed_collection(
            account,
            string::utf8(b"collection description: get your ticket now!"),
            100,    // Max supply
            new_collection_name,
            option::none(),
            string::utf8(b"collection uri: www.aladeen.me"),
        );

        // Move the created object to the resource account.
        let new_collection = OnChainConfig {
            collection_name: new_collection_name,
        };
        move_to(account, new_collection);
    }

    // Create an object, this function is reusable and will be used
    // for both ticket and seat objects
    fun create_object(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    ): ConstructorRef acquires OnChainConfig {
        let collection = borrow_global<OnChainConfig>(signer::address_of(creator));
        token::create_named_token(
            creator,
            collection.collection_name,
            description,
            name,
            option::none(),
            uri,
        )
    }

    // Create ticket
    public fun create_ticket(
        // ticket variables that we will submit on-chain
        price: u64,

        // object variables that we will submit on-chain
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    ): Object<Ticket> acquires OnChainConfig {
        let constructor_ref = create_object(creator, description, name, uri);
        let object_signer = object::generate_signer(&constructor_ref);

        let new_ticket = Ticket {
            price,
            seat: option::none(),
            mutator_ref: token::generate_mutator_ref(&constructor_ref),
        };
        move_to(&object_signer, new_ticket);

        object::address_to_object(signer::address_of(&object_signer))
    }

    // Entry function for minting the ticket object
    // using encapsulation technique 
    entry fun mint_ticket(
        account: &signer,
        description: String,
        name: String,
        uri: String,
        price: u64,
    ) acquires OnChainConfig {
        create_ticket(price, account, description, name, uri);
    }

    // Create token object of the seat
    public fun create_seat(
        // seat variables that we will submit on-chain
        category: String,
        price_modifier: u64,

        // object variables that we will submit on-chain
        creator: &signer,
        description: String,
        name: String,
        uri: String,
    ): Object<Seat> acquires OnChainConfig {
        let constructor_ref = create_object(creator, description, name, uri);
        let object_signer = object::generate_signer(&constructor_ref);

        let new_seat = Seat {
            category,
            price_modifier,
        };
        move_to(&object_signer, new_seat);

        // get the object from the object signer  
        object::address_to_object(signer::address_of(&object_signer))
    }

    // Entry function for minting the seat object
    entry fun mint_seat(
        category: String,
        price_modifier: u64,
        account: &signer,
        description: String,
        name: String,
        uri: String,
    ) acquires OnChainConfig {
        create_seat(category, price_modifier, account, description, name, uri);
    }

    // Upgrade the seat assigned to the ticket
    public fun upgrade_seat(
        owner: &signer,
        ticket: Object<Ticket>,
        seat: Object<Seat>,
    ) acquires Ticket {
        let ticket_object = borrow_global_mut<Ticket>(object::object_address(&ticket));
        
        // Add the seat to the ticket object
        option::fill(&mut ticket_object.seat, seat);
        object::transfer_to_object(owner, seat, ticket);
    }

    // TODO: Fork the repo and implement the follwoing function:
    // add a transfer function to transfer the ticket object alongside with its assigned seat

    inline fun get_ticket(creator: &address, collection: &String, name: &String): (Object<Ticket>, &Ticket) {
        let ticket_address = token::create_token_address(
            creator,
            collection,
            name,
        );
        (object::address_to_object<Ticket>(ticket_address), borrow_global<Ticket>(ticket_address))
    }

    // Unit test
    #[test(account = @0x123)]
    fun test(account: &signer) acquires Ticket, OnChainConfig {
        init_module(account);

        let ticket = create_ticket(
            50,
            account,
            string::utf8(b"for a limited time only!"),
            string::utf8(b"Early bird ticket"),
            string::utf8(b"www.aladeen.me"),
        );

        let seat = create_seat(
            string::utf8(b"Exclusive seat"),
            20,
            account,
            string::utf8(b"Enjoy the view!"),
            string::utf8(b"Upgrade seat"),
            string::utf8(b"www.aladeen.me"),
        );

        let account_address = signer::address_of(account);
        assert!(object::is_owner(ticket, account_address), 0);
        assert!(object::is_owner(seat, account_address), 1);

        upgrade_seat(account, ticket, seat);
        assert!(object::is_owner(ticket, account_address), 3);
        assert!(object::is_owner(seat, object::object_address(&ticket)), 4);
    }
}
```rust
/// This module demonstrates a basic game feed using ACL to control the access.
/// Admins can
///     (1) create their game feed
///     (2) add a company (of users) to its access control list (ACL)
///     (3) remove a company from its ACL
/// users can
///     (1) register for the game feed
///     (2) create a new review
///
/// The module also emits events for subscribers
///     (1)review change event, this event contains the board, game and review author
module gamefeed_addr::gamefeed {
    use std::acl::Self;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // Error map
    const EACCOUNT_NOT_IN_ACL: u64 = 1;
    const ECANNOT_REMOVE_ADMIN_FROM_ACL: u64 = 2;

    struct ACLBasedGF has key {
        participants: acl::ACL,
        pinned_review: vector<u8>
    }

    struct ReviewChangeEventHandle has key {
        change_events: EventHandle<ReviewChangeEvent>
    }

    /// emit an event from participant account showing the board and the new review
    struct ReviewChangeEvent has store, drop {
        review: vector<u8>,
        participant: address
    }

    /// init community board
    public entry fun review_board_init(account: &signer) {
        let board = ACLBasedGF{
            participants: acl::empty(),
            pinned_review: vector::empty<u8>()
        };
        acl::add(&mut board.participants, signer::address_of(account));
        move_to(account, board);
        move_to(account, ReviewChangeEventHandle{
            change_events: account::new_event_handle<ReviewChangeEvent>(account)
        })
    }

    public fun view_review(board_addr: address): vector<u8> acquires ACLBasedGF {
        let review = borrow_global<ACLBasedGF>(board_addr).pinned_review;
        copy review
    }

    /// board owner control adding new participants
    public entry fun add_participant(account: &signer, participant: address) acquires ACLBasedGF {
        let board = borrow_global_mut<ACLBasedGF>(signer::address_of(account));
        acl::add(&mut board.participants, participant);
    }

    /// remove a participant from the ACL
    public entry fun remove_participant(account: signer, participant: address) acquires ACLBasedGF {
        let board = borrow_global_mut<ACLBasedGF>(signer::address_of(&account));
        assert!(signer::address_of(&account) != participant, ECANNOT_REMOVE_ADMIN_FROM_ACL);
        acl::remove(&mut board.participants, participant);
    }

    /// an account publish the review to update the notice
    public entry fun send_pinned_review(
        account: &signer, board_addr: address, review: vector<u8>
    ) acquires ACLBasedGF, ReviewChangeEventHandle {
        let board = borrow_global<ACLBasedGF>(board_addr);
        assert!(acl::contains(&board.participants, signer::address_of(account)), EACCOUNT_NOT_IN_ACL);

        let board = borrow_global_mut<ACLBasedGF>(board_addr);
        board.pinned_review = review;

        let send_acct = signer::address_of(account);
        let event_handle = borrow_global_mut<ReviewChangeEventHandle>(board_addr);
        event::emit_event<ReviewChangeEvent>(
            &mut event_handle.change_events,
            ReviewChangeEvent{
                review,
                participant: send_acct
            }
        );
    }

    /// an account can send events containing reviews
    public entry fun send_review_to(
        account: signer, board_addr: address, review: vector<u8>
    ) acquires ReviewChangeEventHandle {
        let event_handle = borrow_global_mut<ReviewChangeEventHandle>(board_addr);
        event::emit_event<ReviewChangeEvent>(
            &mut event_handle.change_events,
            ReviewChangeEvent{
                review,
                participant: signer::address_of(&account)
            }
        );
    }
}

```
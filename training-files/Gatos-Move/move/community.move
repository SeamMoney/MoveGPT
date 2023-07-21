/// This module demonstrates a basic community using ACL to control the access.
/// Admins can
///     (1) create their community
///     (2) add a partipant to its access control list (ACL)
///     (3) remove a participant from its ACL
/// participant can
///     (1) register for the community board
///     (2) create a new post
///
/// The module also emits events for subscribers
///     (1) post change event, this event contains the board, post and post author
module community_addr::community {
    use std::acl::Self;
    use std::signer;
    use std::vector;
    use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};

    // Error map
    const EACCOUNT_NOT_IN_ACL: u64 = 1;
    const ECANNOT_REMOVE_ADMIN_FROM_ACL: u64 = 2;

    struct ACLBasedCM has key {
        participants: acl::ACL,
        pinned_post: vector<u8>
    }

    struct PostChangeEventHandle has key {
        change_events: EventHandle<PostChangeEvent>
    }

    /// emit an event from participant account showing the board and the new post
    struct PostChangeEvent has store, drop {
        post: vector<u8>,
        participant: address
    }

    /// init community board
    public entry fun post_board_init(account: &signer) {
        let board = ACLBasedCM{
            participants: acl::empty(),
            pinned_post: vector::empty<u8>()
        };
        acl::add(&mut board.participants, signer::address_of(account));
        move_to(account, board);
        move_to(account, PostChangeEventHandle{
            change_events: account::new_event_handle<PostChangeEvent>(account)
        })
    }

    public fun view_post(board_addr: address): vector<u8> acquires ACLBasedCM {
        let post = borrow_global<ACLBasedCM>(board_addr).pinned_post;
        copy post
    }

    /// board owner control adding new participants
    public entry fun add_participant(account: &signer, participant: address) acquires ACLBasedCM {
        let board = borrow_global_mut<ACLBasedCM>(signer::address_of(account));
        acl::add(&mut board.participants, participant);
    }

    /// remove a participant from the ACL
    public entry fun remove_participant(account: signer, participant: address) acquires ACLBasedCM {
        let board = borrow_global_mut<ACLBasedCM>(signer::address_of(&account));
        assert!(signer::address_of(&account) != participant, ECANNOT_REMOVE_ADMIN_FROM_ACL);
        acl::remove(&mut board.participants, participant);
    }

    /// an account publish the post to update the notice
    public entry fun send_pinned_post(
        account: &signer, board_addr: address, post: vector<u8>
    ) acquires ACLBasedCM, PostChangeEventHandle {
        let board = borrow_global<ACLBasedCM>(board_addr);
        assert!(acl::contains(&board.participants, signer::address_of(account)), EACCOUNT_NOT_IN_ACL);

        let board = borrow_global_mut<ACLBasedCM>(board_addr);
        board.pinned_post = post;

        let send_acct = signer::address_of(account);
        let event_handle = borrow_global_mut<PostChangeEventHandle>(board_addr);
        event::emit_event<PostChangeEvent>(
            &mut event_handle.change_events,
            PostChangeEvent{
                post,
                participant: send_acct
            }
        );
    }

    /// an account can send events containing posts
    public entry fun send_post_to(
        account: signer, board_addr: address, post: vector<u8>
    ) acquires PostChangeEventHandle {
        let event_handle = borrow_global_mut<PostChangeEventHandle>(board_addr);
        event::emit_event<PostChangeEvent>(
            &mut event_handle.change_events,
            PostChangeEvent{
                post,
                participant: signer::address_of(&account)
            }
        );
    }
}

module overmind::pay_me_a_river {
    use aptos_std::table::{Self, Table};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use std::signer;


    const ESENDER_CAN_NOT_BE_RECEIVER: u64 = 1;
    const ENUMBER_INVALID: u64 = 2;
    const EPAYMENT_DOES_NOT_EXIST: u64 = 3;
    const ESTREAM_DOES_NOT_EXIST: u64 = 4;
    const ESTREAM_IS_ACTIVE: u64 = 5;
    const ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER: u64 = 6;

    struct Stream has store {
        sender: address,
        receiver: address,
        length_in_seconds: u64,
        start_time: u64,
        coins: Coin<AptosCoin>,
    }

    struct Payments has key {
        streams: Table<address, Stream>
    }

    fun check_sender_is_not_receiver(sender: address, receiver: address) {
        assert!(sender != receiver, ESENDER_CAN_NOT_BE_RECEIVER)
    }

    fun check_number_is_valid(number: u64) {
        assert!(number > 0, ENUMBER_INVALID)
    }

    fun check_payment_exists(sender_address: address) {
        assert!(exists<Payments>(sender_address), EPAYMENT_DOES_NOT_EXIST);
    }

    fun check_stream_exists(payments: &Payments, stream_address: address) {
        assert!(table::contains(&payments.streams, stream_address), ESTREAM_DOES_NOT_EXIST);
    }

    fun check_stream_is_not_active(payments: &Payments, stream_address: address) {
        let stream = table::borrow(&payments.streams, stream_address);
        assert!(0 == stream.start_time, ESTREAM_IS_ACTIVE);
    }

    fun check_signer_address_is_sender_or_receiver(
        signer_address: address,
        sender_address: address,
        receiver_address: address
    ) {
        assert!(signer_address == sender_address || 
                signer_address == receiver_address, ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER);
    }

    fun calculate_stream_claim_amount(total_amount: u64, start_time: u64, length_in_seconds: u64): u64 {
        if (timestamp::now_seconds() > start_time) {
            (total_amount / length_in_seconds) * (timestamp::now_seconds() - start_time)
        } else {
            0
        }
    }

    fun init_payments(signer : &signer) 
    {
        let streams = table::new();
        move_to<Payments>(signer, Payments{
            streams: streams
        })
    }  

    public entry fun create_stream(
        signer_: &signer,
        receiver_address: address,
        amount: u64,
        length_in_seconds: u64
    ) acquires Payments {
        check_sender_is_not_receiver(signer::address_of(signer_), receiver_address);
        check_number_is_valid(amount);
        if (!exists<Payments>(signer::address_of(signer_))) {
            init_payments(signer_);
        };
        let payments = borrow_global_mut<Payments>(signer::address_of(signer_));
        let coins = coin::withdraw<AptosCoin>(signer_, amount);
        table::add(&mut payments.streams, receiver_address, Stream {
            sender: signer::address_of(signer_),
            receiver: receiver_address,
            length_in_seconds: length_in_seconds,
            start_time: 0,
            coins: coins,
        });
    }

    public entry fun accept_stream(signer: &signer, sender_address: address) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer::address_of(signer));
        check_stream_is_not_active(payments, signer::address_of(signer));
        let stream = table::borrow_mut(&mut payments.streams, signer::address_of(signer));
        stream.start_time = timestamp::now_seconds();
    }

    public entry fun claim_stream(signer: &signer, sender_address: address) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer::address_of(signer));
        let stream = table::borrow_mut(&mut payments.streams, signer::address_of(signer));
        let claimamount = calculate_stream_claim_amount(coin::value(&stream.coins), stream.start_time, stream.length_in_seconds);
        // let newstart = timestamp::now_seconds();
        // stream.start_time = newstart;
        // stream.length_in_seconds = stream.length_in_seconds - (newstart - stream.start_time);
        let coin = coin::extract<AptosCoin>(&mut stream.coins, claimamount); 
        coin::deposit<AptosCoin>(signer::address_of(signer), coin);
    }

    public entry fun cancel_stream(
        signer: &signer,
        sender_address: address,
        receiver_address: address
    ) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, receiver_address);
        check_signer_address_is_sender_or_receiver(signer::address_of(signer), sender_address, receiver_address);
        let Stream{        
            sender: _,
            receiver: _,
            length_in_seconds: _,
            start_time: _,
            coins} = table::remove(&mut payments.streams, receiver_address);
        coin::deposit(sender_address,coins);
    }

    #[view]
    public fun get_stream(sender_address: address, receiver_address: address): (u64, u64, u64) acquires Payments {
        let payments = borrow_global_mut<Payments>(sender_address);
        let stream = table::borrow(&payments.streams, receiver_address);
        (stream.length_in_seconds, stream.start_time, coin::value(&stream.coins))
    }
}
module woolf_deployer::random {
    use std::bcs;
    use std::error;
    use std::hash;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::block;
    use aptos_framework::timestamp;
    use aptos_framework::transaction_context;

    const ENOT_ROOT: u64 = 0;
    const EHIGH_ARG_GREATER_THAN_LOW_ARG: u64 = 1;

    public fun bytes_to_u128(bytes: vector<u8>): u128 {
        let value = 0u128;
        let i = 0u64;
        while (i < 16) {
            value = value | ((*vector::borrow(&bytes, i) as u128) << ((8 * (15 - i)) as u8));
            i = i + 1;
        };
        return value
    }

    public fun bytes_to_u64(bytes: vector<u8>): u64 {
        let value = 0u64;
        let i = 0u64;
        while (i < 8) {
            value = value | ((*vector::borrow(&bytes, i) as u64) << ((8 * (7 - i)) as u8));
            i = i + 1;
        };
        return value
    }

    /// Acquire a seed using: the hash of the counter, block height, timestamp, script hash, sender address, and sender sequence number.
    public fun seed(_sender: &address): vector<u8> {
        // let counter = increment();
        // let counter_bytes = bcs::to_bytes(&counter);

        let height: u64 = block::get_current_block_height();
        let height_bytes: vector<u8> = bcs::to_bytes(&height);

        let timestamp: u64 = timestamp::now_microseconds();
        let timestamp_bytes: vector<u8> = bcs::to_bytes(&timestamp);

        let script_hash: vector<u8> = transaction_context::get_script_hash();

        let sender_bytes: vector<u8> = bcs::to_bytes(_sender);

        let sequence_number: u64 = account::get_sequence_number(*_sender);
        let sequence_number_bytes = bcs::to_bytes(&sequence_number);

        let info: vector<u8> = vector::empty<u8>();
        // vector::append<u8>(&mut info, counter_bytes);
        vector::append<u8>(&mut info, height_bytes);
        vector::append<u8>(&mut info, timestamp_bytes);
        vector::append<u8>(&mut info, script_hash);
        vector::append<u8>(&mut info, sender_bytes);
        vector::append<u8>(&mut info, sequence_number_bytes);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    /// Acquire a seed using: the hash of the counter, block height, timestamp, and script hash.
    public fun seed_no_sender(): vector<u8> {
        let height: u64 = block::get_current_block_height();
        let height_bytes: vector<u8> = bcs::to_bytes(&height);

        let timestamp: u64 = timestamp::now_microseconds();
        let timestamp_bytes: vector<u8> = bcs::to_bytes(&timestamp);

        let script_hash: vector<u8> = transaction_context::get_script_hash();

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, height_bytes);
        vector::append<u8>(&mut info, timestamp_bytes);
        vector::append<u8>(&mut info, script_hash);

        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    /// Generate a random u128
    public fun rand_u128_with_seed(_seed: vector<u8>): u128 {
        bytes_to_u128(_seed)
    }

    /// Generate a random u64
    public fun rand_u64_with_seed(_seed: vector<u8>): u64 {
        bytes_to_u64(_seed)
    }

    /// Generate a random integer range in [low, high).
    public fun rand_u128_range_with_seed(_seed: vector<u8>, low: u128, high: u128): u128 {
        assert!(high > low, error::invalid_argument(EHIGH_ARG_GREATER_THAN_LOW_ARG));
        let value = rand_u128_with_seed(_seed);
        (value % (high - low)) + low
    }

    /// Generate a random integer range in [low, high).
    public fun rand_u64_range_with_seed(_seed: vector<u8>, low: u64, high: u64): u64 {
        assert!(high > low, error::invalid_argument(EHIGH_ARG_GREATER_THAN_LOW_ARG));
        let value = rand_u64_with_seed(_seed);
        (value % (high - low)) + low
    }

    public fun rand_u128(sender: &address): u128 { rand_u128_with_seed(seed(sender)) }

    public fun rand_u128_range(
        sender: &address,
        low: u128,
        high: u128
    ): u128 { rand_u128_range_with_seed(seed(sender), low, high) }

    public fun rand_u64(sender: &address): u64 { rand_u64_with_seed(seed(sender)) }

    public fun rand_u64_range(sender: &address, low: u64, high: u64): u64 {
        rand_u64_range_with_seed(
            seed(sender),
            low,
            high
        )
    }

    public fun rand_u128_no_sender(): u128 { rand_u128_with_seed(seed_no_sender()) }

    public fun rand_u128_range_no_sender(low: u128, high: u128): u128 {
        rand_u128_range_with_seed(
            seed_no_sender(),
            low,
            high
        )
    }

    public fun rand_u64_no_sender(): u64 { rand_u64_with_seed(seed_no_sender()) }

    public fun rand_u64_range_no_sender(low: u64, high: u64): u64 {
        rand_u64_range_with_seed(
            seed_no_sender(),
            low,
            high
        )
    }
}
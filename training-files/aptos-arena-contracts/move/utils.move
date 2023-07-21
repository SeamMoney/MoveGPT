module aptos_arena::utils {

    use aptos_framework::timestamp;

    /// returns a random integer between 0 and num_vals
    /// `num_vals` - the number of possible values
    public fun rand_int(num_vals: u64): u64 {
        timestamp::now_seconds() % num_vals
    }
}

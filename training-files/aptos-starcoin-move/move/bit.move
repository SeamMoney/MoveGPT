module starcoin_utils::bit {
    use std::vector;

    public fun count_common_prefix(data1: &vector<u8>, data2: &vector<u8>): u64 {
        let count = 0;
        let i = 0;
        while ( i < vector::length(data1) * 8) {
            if (get_bit_at_from_msb(data1, i) == get_bit_at_from_msb(data2, i)) {
                count = count + 1;
            } else {
                break
            };
            i = i + 1;
        };
        count
    }

    public fun get_bit_at_from_msb(data: &vector<u8>, index: u64): bool {
        let pos = index / 8;
        let bit = (7 - index % 8);
        (*vector::borrow(data, pos) >> (bit as u8)) & 1u8 != 0
    }
}

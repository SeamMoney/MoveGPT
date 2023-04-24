module nft_api::utils {
    use std::string::{Self, String};
    use std::vector;

    /// @dev Converts a `u128` to its `string` representation
    /// @param value The `u128` to convert
    /// @return The `string` representation of the `u128`
    public fun to_string(value: u128): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }
}
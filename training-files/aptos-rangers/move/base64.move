/// Module for encoding the decoding strings into base64.
/// Author: <Vivek vivekascoder@gmail.com>
/// Reference: https://nachtimwald.com/2017/11/18/base64-encode-and-decode-in-c/
module rangers::base64 {
    use std::string::{Self, String};
    use std::vector;

    const B64_CHARS: vector<u8> = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    public fun b64_encoded_size(l: u64): u64 {
        let ret = l;
        if (l % 3 != 0) {
            ret = ret + (3 - (l % 3));
        };
        ret = ret / 3;
        ret = ret * 4;
        ret
    }

    public fun b64_decoded_size(str: String): u64 {
        let length = string::length(&str);
        let bytes = string::bytes(&str);
        let ret = length / 4 * 3;
        
        let i = length - 1;
        while (i > 0) {
            if (*vector::borrow<u8>(bytes, i) == 61) {
                ret = ret - 1;
            } else {
                break
            };
            i = i - 1;
        };
        ret
    }

    public fun b64_isvalidchar(c: u8): bool {
        if (c >= 65 && c <= 90) {
            return true
        } else if (c >= 97 && c <= 122) {
            return true
        } else if (c >= 48 && c <= 57) {
            return true
        } else if (c == 43 || c == 47 || c == 61) {
            return true
        } else {
            return false
        }
    }

    public fun encode_string(str: String): String {
        let length = string::length(&str);
        let bytes = string::bytes(&str);
        assert!(length > 0, 0);

        let i: u64 = 0;
        let j: u64 = 0;
        let out: vector<u8> = vector::empty<u8>();
        let elen: u64 = b64_encoded_size(length);
        
        let t = 0;
        while (t < elen) {
            vector::push_back<u8>(&mut out, 0);
            t = t + 1;
        };

        while (i < length) {
            let v = (*vector::borrow<u8>(bytes, i) as u64);

            if (i + 1 < length) {
                v = (( (v as u64) << 8) | (*vector::borrow<u8>(bytes, i + 1) as u64) );
            } else {
                v = v << 8;
            };

            if (i + 2 < length) {
                v = (( (v as u64) << 8) | (*vector::borrow<u8>(bytes, i + 2) as u64) );
            } else {
                v = v << 8;
            };

            *vector::borrow_mut<u8>(&mut out, j) = *vector::borrow<u8>(&B64_CHARS, (( v >> 18 ) & 0x3f));
            *vector::borrow_mut<u8>(&mut out, j + 1) = *vector::borrow<u8>(&B64_CHARS, (( (v as u64) >> 12 ) & 0x3f));

            if (i + 1 < length) {
                *vector::borrow_mut<u8>(&mut out, j + 2) = *vector::borrow<u8>(&B64_CHARS, (((v >> 6) & 0x3f) as u64));
            } else {
                *vector::borrow_mut<u8>(&mut out, j + 2) = 61; // '='
            };
            
            if (i + 2 < length) {
                std::debug::print(&(v & 0x3f));
                *vector::borrow_mut<u8>(&mut out, j + 3) = *vector::borrow<u8>(&B64_CHARS, ((v & 0x3f)));
            } else {
                *vector::borrow_mut<u8>(&mut out, j + 3) = 61; // '='
            };

            i = i + 3;
            j = j + 4;
        };
        
        string::utf8(out)
    }

    // public fun decode_string(str: String): String {
    //     let length = string::length(&str);
    //     let bytes = string::bytes(&str);
    //     assert!(length > 0, 0);
        
    //     let outlen = b64_decoded_size(str);
    //     assert!(outlen < b64_decoded_size(str) || outlen % 4 != 0, 1);

    //     let out: vector<u8> = vector::empty<u8>();
    //     let t = 0;
    //     while (t < outlen) {
    //         vector::push_back<u8>(&mut out, 0);
    //         t = t + 1;
    //     };

    //     let i = 0;
    //     while (i < length) {
    //         assert!(b64_isvalidchar(*vector::borrow<u8>(bytes, i)), 2);
    //         i = i + 1;
    //     };

    //     i = 0;
    //     let j = 0;
    //     while (i < length) {
            
    //         i = i + 4;
    //         j = j + 3;
    //     }


    //     str
    // }

    #[test]
    fun test_encode_string() {
        assert!(encode_string(string::utf8(b"Hello World")) == string::utf8(b"SGVsbG8gV29ybGQ="), 0);
        assert!(encode_string(string::utf8(b"Hello World!")) == string::utf8(b"SGVsbG8gV29ybGQh"), 0);
        assert!(b64_decoded_size(string::utf8(b"SGVsbG8gV29ybGQh")) == 12, 0);
    }
}
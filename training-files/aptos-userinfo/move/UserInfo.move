module Sender::UserInfo {

    use std::string::{ String, utf8 };
    use std::signer;

    struct UserProfile has key {
        username: String
    }

    public fun get_username(user_addr: address): String
    acquires UserProfile {
        borrow_global<UserProfile>(user_addr).username
    }

    public entry fun set_username(user_account: &signer, username_raw: vector<u8>)
    acquires UserProfile {
        let username = utf8(username_raw);
        let user_addr = signer::address_of(user_account);
        if (!exists<UserProfile>(user_addr)) {
            let info_store = UserProfile {
                username
            };
            move_to(user_account, info_store);
        } else {
            let existing_info_store = borrow_global_mut<UserProfile>(user_addr);
            existing_info_store.username = username
        }
    }
}
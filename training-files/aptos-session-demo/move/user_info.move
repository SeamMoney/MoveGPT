module sender::user_info {
    use std::string::{String, utf8};
    use std::signer;

    struct UserProfile has key { username: String }

    public fun get_username(user_addr: address): String acquires UserProfile {
        borrow_global<UserProfile>(user_addr).username
    }

    public entry fun set_username(user_account: &signer, username_raw: vector<u8>) acquires UserProfile {
        // wrap username_raw (vector of bytes) to username string
        let username = utf8(username_raw);

        // get address of transaction sender
        let user_addr = signer::address_of(user_account);
        // `exists` just to check whether resource is present in storage
        if (!exists<UserProfile>(user_addr)) {
          let info_store = UserProfile{ username: username };
          move_to(user_account, info_store);
        } else {
          // `borrow_global_mut` is to fetch mutable reference, we can change resources in storage that way
          let existing_info_store = borrow_global_mut<UserProfile>(user_addr);
          existing_info_store.username = username;
        }
    }
}

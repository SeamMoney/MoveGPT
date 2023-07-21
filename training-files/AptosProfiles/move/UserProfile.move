module AptosProfile::User {
    // libraries
    use std::string::{String, utf8};
    use std::signer;
    // UserProfile resource
    struct UserProfile has key { data: String}
    
    //Entr function to set data
    public entry fun set_data(account: &signer, raw_data : vector<u8>) acquires UserProfile {
        let data = utf8(raw_data);
        let user_addr = signer::address_of(account);

        if(!exists<UserProfile>(user_addr)){
            let user_profile = UserProfile{data:data};
            move_to(account,user_profile)
        } else{
            let existing_user_profile = borrow_global_mut<UserProfile>(user_addr);
            existing_user_profile.data=data
        }
    }

    // To get data
    public fun get_data(addr: address): String acquires UserProfile {
        borrow_global<UserProfile>(addr).data
    }

    // Tests
    #[test(account=@0x42)]
        public entry fun test_set (account:signer) acquires UserProfile {
            let raw_data= b"anto56665";
            set_data(&account, raw_data);
            let addr = signer::address_of(&account);
            assert!(get_data(addr)==utf8(raw_data),1)
    } 
}
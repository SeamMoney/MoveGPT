module injoy_labs::profile {
    use std::string::{Self, String};
    use std::error;
    use std::signer;
    use aptos_token::property_map::{Self, PropertyMap, PropertyValue};
    use aptos_std::table::{Self, Table};

    /**
     * Errors 
     */
    const E_EMPTY_USERNAME: u64 = 0;
    const E_ALREADY_REGISTERED: u64 = 1;
    const E_PROFILE_NAME_OCCUPIED: u64 = 2;
    const E_PROFILE_NOT_EXISTS: u64 = 3;

    /**
     * Resources
     */
    struct Profile has key {
        username: String,
        description: String,
        uri: String,
        avatar: String,
        properties: PropertyMap,
    }

    struct UserBase has key {
        name_to_addr_table: Table<String, address>,
    }

    fun init_module(deployer: &signer) {
        if (!exists<UserBase>(@injoy_labs)) {
            move_to(
                deployer,
                UserBase {
                    name_to_addr_table: table::new(),
                },
            );
        }
    }

    /**
     * public functions
     */
    public fun register(
        user: &signer,
        username: String,
        description: String,
        uri: String,
        avatar: String,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires UserBase {
        let user_addr = signer::address_of(user);
        let user_base = borrow_global_mut<UserBase>(@injoy_labs);

        assert!(
            !exists<Profile>(user_addr),
            error::already_exists(E_ALREADY_REGISTERED),
        );
        assert!(
            !table::contains(&user_base.name_to_addr_table, username),
            error::already_exists(E_PROFILE_NAME_OCCUPIED),
        );
        
        // put username in user table
        table::add(&mut user_base.name_to_addr_table, username, user_addr);

        move_to(
            user,
            Profile {
                username,
                description,
                uri,
                avatar,
                properties: property_map::new(keys, values, types),
            }
        );
    }

    public fun change_username(
        user: &signer,
        new_username: String
    ) acquires Profile, UserBase {
        let user_addr = signer::address_of(user);
        let user_base = borrow_global_mut<UserBase>(@injoy_labs);
        let user_profile = borrow_global_mut<Profile>(user_addr);
        assert!(
            !string::is_empty(&new_username),
            error::invalid_argument(E_EMPTY_USERNAME),
        );
        assert!(
            !table::contains(&user_base.name_to_addr_table, new_username),
            error::already_exists(E_PROFILE_NAME_OCCUPIED),
        );
        table::remove(
            &mut user_base.name_to_addr_table,
            user_profile.username,
        );
        table::add(
            &mut user_base.name_to_addr_table,
            new_username,
            user_addr,
        );
        user_profile.username = new_username;
    }

    public fun update_profile(
        user: &signer,
        new_description: String,
        new_uri: String,
        new_avatar: String,    
    ) acquires Profile {
        let user_addr = signer::address_of(user);
        let user_profile = borrow_global_mut<Profile>(user_addr);
        if (!string::is_empty(&new_description)) {
            user_profile.description = new_description;
        };
        if (!string::is_empty(&new_uri)) {
            user_profile.uri = new_uri;
        };
        if (!string::is_empty(&new_avatar)) {
            user_profile.avatar = new_avatar;
        };
    }

    public fun update_properties(
        user: &signer,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires Profile {
        let user_addr = signer::address_of(user);
        let user_profile = borrow_global_mut<Profile>(user_addr);
        property_map::update_property_map(
            &mut user_profile.properties, keys, values, types
        );
    }

    public fun exists_profile(account: address): bool {
        exists<Profile>(account)
    }

    public fun exists_username(username: &String): bool acquires UserBase {
        let user_base = borrow_global<UserBase>(@injoy_labs);
        table::contains(&user_base.name_to_addr_table, *username)        
    }

    public fun get_username(account: address): String acquires Profile {
        assert!(
            exists<Profile>(account),
            error::not_found(E_PROFILE_NOT_EXISTS),
        );
        borrow_global<Profile>(account).username
    }

    public fun get_address(username: &String): address acquires UserBase {
        let user_base = borrow_global<UserBase>(@injoy_labs);
        assert!(
            table::contains(&user_base.name_to_addr_table, *username),
            error::not_found(E_PROFILE_NOT_EXISTS),
        );
        *table::borrow(&user_base.name_to_addr_table, *username)
    }

    public fun get_description(account: address): String acquires Profile {
        assert!(
            exists<Profile>(account),
            error::not_found(E_PROFILE_NOT_EXISTS),
        );
        borrow_global<Profile>(account).description    
    }

    public fun get_uri(account: address): String acquires Profile {
        assert!(
            exists<Profile>(account),
            error::not_found(E_PROFILE_NOT_EXISTS),
        );
        borrow_global<Profile>(account).uri
    }

    public fun get_avatar(account: address): String acquires Profile {
        assert!(
            exists<Profile>(account),
            error::not_found(E_PROFILE_NOT_EXISTS),
        );
        borrow_global<Profile>(account).avatar
    }

    public fun get_property_map(account: address): PropertyMap acquires Profile {
        let profile = borrow_global<Profile>(account);
        profile.properties
    }

    public fun get_property_value(account: address, key: &String): PropertyValue acquires Profile {
        let profile = borrow_global<Profile>(account);
        *property_map::borrow(&profile.properties, key)
    }

    #[test(deployer=@injoy_labs, user=@0x11)]
    fun test_register(deployer: &signer, user: &signer) acquires UserBase, Profile {
        init_module(deployer);
        let user_addr = signer::address_of(user);
        let username = string::utf8(b"Alice");
        let description = string::utf8(b"in wonderland");
        let uri = string::utf8(b"ipfs://alice-info");
        let avatar = string::utf8(b"ipfs://alice-image");
        register(
            user,
            username,
            description,
            uri,
            avatar,
            vector[],
            vector[],
            vector[],
        );
        assert!(exists_profile(user_addr), 101);
        assert!(exists_username(&username), 102);
        assert!(get_username(user_addr) == username, 103);
        assert!(get_address(&username) == user_addr, 104);
        assert!(get_description(user_addr) == description, 105);
        assert!(get_uri(user_addr) == uri, 106);
        assert!(get_avatar(user_addr) == avatar, 107);
    }

    #[test(deployer=@injoy_labs, alice=@0x21)]
    #[expected_failure(abort_code = 0x80001)]
    fun test_already_registered(
        deployer: &signer,
        alice: &signer,
    ) acquires UserBase, Profile {
        let username = string::utf8(b"Bob");
        test_register(deployer, alice);
        register(
            alice,
            username,
            string::utf8(b"couch potato"),
            string::utf8(b"ipfs://bob-info"),
            string::utf8(b"ipfs://bob-image"),
            vector[],
            vector[],
            vector[],
        );       
    }


    #[test(deployer=@injoy_labs, alice=@0x21, bob=@0x22)]
    #[expected_failure(abort_code = 0x80002)]
    fun test_username_occupied(
        deployer: &signer,
        alice: &signer,
        bob: &signer
    ) acquires UserBase, Profile {
        let username = string::utf8(b"Alice");
        test_register(deployer, alice);
        register(
            bob,
            username,
            string::utf8(b"couch potato"),
            string::utf8(b"ipfs://bob-info"),
            string::utf8(b"ipfs://bob-image"),
            vector[],
            vector[],
            vector[],
        );       
    }

    #[test(deployer=@injoy_labs, alice=@0x31)]
    fun test_change_username(
        deployer: &signer,
        alice: &signer,
    ) acquires UserBase, Profile {
        test_register(deployer, alice);
        let alice_addr = signer::address_of(alice);
        let new_username = string::utf8(b"Alice123");
        let old_name = get_username(alice_addr);
        change_username(alice, new_username);
        assert!(exists_profile(alice_addr), 301);
        assert!(exists_username(&new_username), 302);
        assert!(!exists_username(&old_name), 303);
        assert!(get_username(alice_addr) == new_username, 304);
    }

    #[test(deployer=@injoy_labs, alice=@0x41, bob=@0x42)]
    #[expected_failure(abort_code = 0x80002)]
    fun test_change_username_failed(
        deployer: &signer,
        alice: &signer,
        bob: &signer,
    ) acquires UserBase, Profile {
        test_register(deployer, alice);
        let bob_username = string::utf8(b"bob");
        register(
            bob,
            bob_username,
            string::utf8(b"couch potato"),
            string::utf8(b"ipfs://bob-info"),
            string::utf8(b"ipfs://bob-image"),
            vector[],
            vector[],
            vector[],
        ); 
        change_username(alice, bob_username);
    }
}
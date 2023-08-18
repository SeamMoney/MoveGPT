```rust
module injoy_labs::inchat_v1 {
    use std::string::{Self, String};
    use std::signer;
    use aptos_token::token;
    use aptos_token::token_transfers;
    use injoy_labs::profile;
    
    const MAX_U64: u64 = 0xffffffffffffffff;
    const PLATFORM_PREFIX: vector<u8> = b"AptosInChatV1: ";

    public entry fun register(
        user: signer,
        username: String,
        description: String,
        uri: String,
        avatar: String,
    ) {
        profile::register(
            &user,
            username,
            description,
            uri,
            avatar,
            vector[],
            vector[],
            vector[],
        );
        token::initialize_token_store(&user);
        let collection_name = string::utf8(PLATFORM_PREFIX);
        string::append(&mut collection_name, username);
        token::create_collection(
            &user,
            collection_name,
            description,
            uri,
            MAX_U64,
            vector[true, true, true]
        );
    }

    public entry fun register_with_profile(user: signer) {
        let user_addr = std::signer::address_of(&user);
        let collection_name = get_collection_name(user_addr);
        token::initialize_token_store(&user);
        token::create_collection(
            &user,
            collection_name,
            profile::get_description(user_addr),
            profile::get_uri(user_addr),
            MAX_U64,
            vector[true, true, true],            
        );
    }

    public entry fun create_group(
        creator: signer,
        group_name: String,
        group_description: String,
        group_uri: String,
        group_size: u64,
    ) {
        let creator_addr = std::signer::address_of(&creator);
        let collection_name = get_collection_name(creator_addr);
        token::create_token_script(
            &creator,
            collection_name,
            group_name,
            group_description,
            group_size,
            group_size,
            group_uri,
            creator_addr,
            1000,
            25,
            vector[true, true, true, true, true],
            vector[],
            vector[],
            vector[],
        );
    }

    public entry fun invite(
        inviter: signer,
        group_name: String,
        invitee: address,
    ) {
        let inviter_addr = signer::address_of(&inviter);
        token_transfers::offer_script(
            inviter,
            invitee,
            inviter_addr,
            get_collection_name(inviter_addr),
            group_name,
            0,
            1,
        );
    }

    public entry fun confirm(
        invitee: signer,
        inviter: address,
        group_name: String,
    ) {
        token_transfers::claim_script(
            invitee,
            inviter,
            inviter,
            get_collection_name(inviter),
            group_name,
            0,
        );
    }

    public fun get_collection_name(account: address): String {
        let collection_name = string::utf8(PLATFORM_PREFIX);
        let username = profile::get_username(account);
        string::append(&mut collection_name, username);
        collection_name
    }
}
```
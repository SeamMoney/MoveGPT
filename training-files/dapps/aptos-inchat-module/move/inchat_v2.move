module injoy_labs::inchat_v2 {
    use std::string::{Self, String};
    use aptos_token::token;
    use aptos_token::token_transfers;
    use aptos_framework::account::{Self, SignerCapability};
    use std::option;
    use std::error;
    use injoy_labs::profile;
    use injoy_labs::to_string;

    
    const MAX_U64: u64 = 0xffffffffffffffff;
    const PLATFORM_SEED: vector<u8> = b"AptosInChatV2";
    const RESOURCE_ADDRESS: address =
        @0xf08a7eb38d0692989dd62cb381a5bf888b2156e9c176d44712f757db70d05c9;

    /// -------------------
    ///  Errors
    /// -------------------
    const ECAN_NOT_INVITE_WITHOUT_TOKEN: u64 = 0;

    struct InChatResourceData has key {
        signer_cap: SignerCapability,
    }

    fun init_module(dev: &signer) {
        let (resource_signer, resource_signer_cap)
            = account::create_resource_account(dev, PLATFORM_SEED);
        assert!(std::signer::address_of(&resource_signer) == RESOURCE_ADDRESS, 0);
        move_to(&resource_signer, InChatResourceData { signer_cap: resource_signer_cap });
    }

    public entry fun register(
        user: &signer,
        username: String,
        description: String,
        uri: String,
        avatar: String,
    ) {
        profile::register(
            user,
            username,
            description,
            uri,
            avatar,
            vector[],
            vector[],
            vector[],
        );
        token::initialize_token_store(user);
    }

    public entry fun create_group(
        creator: &signer,
        group_name: String,
        group_description: String,
        group_uri: String,
    ) acquires InChatResourceData {
        let inchat_signer = get_inchat_signer();
        token::create_collection(
            &inchat_signer,
            group_name,
            group_description,
            group_uri,
            MAX_U64,
            vector[true, true, true]
        );
        token::initialize_token_store(creator);
        let token_name = get_next_token_name(group_name);
        token::create_token_script(
            &inchat_signer,
            group_name,
            token_name,
            string::utf8(b"group creator"),
            1,
            1,
            group_uri,
            std::signer::address_of(creator),
            1000,
            25,
            vector[true, true, true, true, true],
            vector[],
            vector[],
            vector[],
        );
        let token_data_id = token::create_token_data_id(RESOURCE_ADDRESS, group_name, token_name);
        let token_id = token::create_token_id(token_data_id, 0);
        let token = token::withdraw_token(&inchat_signer, token_id, 1);
        token::deposit_token(creator, token);
    }

    public entry fun invite(
        inviter: signer,
        group_name: String,
        token_name: String,
        invitee: address,
    ) acquires InChatResourceData {
        let inviter_addr = std::signer::address_of(&inviter);
        let token_data_id = token::create_token_data_id(RESOURCE_ADDRESS, group_name, token_name);
        let token_id = token::create_token_id(token_data_id, 0);
        assert!(token::balance_of(inviter_addr, token_id) > 0, error::permission_denied(ECAN_NOT_INVITE_WITHOUT_TOKEN));
        let inchat_signer = get_inchat_signer();
        let next_token_name = get_next_token_name(group_name);
        let group_uri = get_collection_uri(group_name);
        let description = string::utf8(b"from ");
        string::append(&mut description, next_token_name);
        token::create_token_script(
            &inchat_signer,
            group_name,
            next_token_name,
            description,
            1,
            1,
            group_uri,
            inviter_addr,
            1000,
            25,
            vector[true, true, true, true, true],
            vector[],
            vector[],
            vector[],
        );

        token_transfers::offer_script(
            inchat_signer,
            invitee,
            RESOURCE_ADDRESS,
            group_name,
            next_token_name,
            0,
            1,
        );
    }

    public entry fun confirm(
        invitee: signer,
        inviter: address,
        group_name: String,
        token_name: String,
    ) {
        token_transfers::claim_script(
            invitee,
            inviter,
            RESOURCE_ADDRESS,
            group_name,
            token_name,
            0,
        );
    }

    fun get_inchat_signer(): signer acquires InChatResourceData {
        let resource_data = borrow_global<InChatResourceData>(RESOURCE_ADDRESS);
        account::create_signer_with_capability(&resource_data.signer_cap)
    }

    fun get_collection_uri(group_name: String): String {
        token::get_collection_uri(RESOURCE_ADDRESS, group_name)
    }

    fun get_next_token_name(group_name: String): String {
        let group_supply = token::get_collection_supply(RESOURCE_ADDRESS, group_name);
        to_string::to_string(option::destroy_some(group_supply))
    }
}
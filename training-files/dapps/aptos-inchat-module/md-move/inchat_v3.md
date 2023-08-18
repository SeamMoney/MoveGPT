```rust
module injoy_labs::inchat_v3 {
    use std::string::{Self, String};
    use aptos_token::token;
    use aptos_token::token_transfers;
    use aptos_framework::account::{Self, SignerCapability};
    use std::error;
    use injoy_labs::profile;
    
    const PLATFORM_SEED: vector<u8> = b"AptosInChatV3";
    const RESOURCE_ADDRESS: address =
        @0xb3586e487aa574e7aec08ac3612121e074ed60440b41636647ad8633d2c9448d;

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
            0,
            vector[true, true, true]
        );
        token::initialize_token_store(creator);
        let description = string::utf8(b"AptosInChat: ");
        string::append(&mut description, group_name);
        token::create_token_script(
            &inchat_signer,
            group_name,
            group_name,
            description,
            1,
            0,
            group_uri,
            std::signer::address_of(creator),
            1000,
            25,
            vector[true, true, true, true, true],
            vector[],
            vector[],
            vector[],
        );
        let token_data_id = token::create_token_data_id(RESOURCE_ADDRESS, group_name, group_name);
        let token_id = token::create_token_id(token_data_id, 0);
        let token = token::withdraw_token(&inchat_signer, token_id, 1);
        token::deposit_token(creator, token);
    }

    public entry fun invite(
        inviter: signer,
        group_name: String,
        invitee: address,
    ) acquires InChatResourceData {
        let inviter_addr = std::signer::address_of(&inviter);
        let token_data_id = token::create_token_data_id(RESOURCE_ADDRESS, group_name, group_name);
        let token_id = token::create_token_id(token_data_id, 0);
        assert!(token::balance_of(inviter_addr, token_id) > 0, error::permission_denied(ECAN_NOT_INVITE_WITHOUT_TOKEN));
        let inchat_signer = get_inchat_signer();
        token::mint_token(
            &inchat_signer,
            token_data_id,
            1,
        );

        token_transfers::offer_script(
            inchat_signer,
            invitee,
            RESOURCE_ADDRESS,
            group_name,
            group_name,
            0,
            1,
        );
    }

    fun get_inchat_signer(): signer acquires InChatResourceData {
        let resource_data = borrow_global<InChatResourceData>(RESOURCE_ADDRESS);
        account::create_signer_with_capability(&resource_data.signer_cap)
    }
}
```
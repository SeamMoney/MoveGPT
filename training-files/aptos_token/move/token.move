module hotboice::token {

    use std::string::{Self, String};
    use std::vector;
    use std::signer;

    use aptos_token::token::{Self, TokenDataId};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::resource_account;

    const TOKEN_VERSION: u64 = 0;
    const AMOUNT_VALUE: u64 = 1;

    struct HotBoiceTokenData has key {
        signer_cap: SignerCapability,
        token_data_id: TokenDataId
    }

    fun init_module(resource_signer: &signer) {
        let collection_name = string::utf8(b"HotBoice Token Zero collection");
        let description = string::utf8(b"this token test version zero");
        let collection_uri = string::utf8(b"https://xxx/aptos/metadata/token_0_collection.png");
        let token_name = string::utf8(b"HBTZ");
        let token_uri = string::utf8(b"https://xxx/aptos/metadata/token_0_token.png");
        let maximum_supply = 0;
        let mutate_setting = vector<bool>[false, false, false];

        token::create_collection(resource_signer, collection_name, description, collection_uri, maximum_supply, mutate_setting);
        let token_data_id = token::create_tokendata(
            resource_signer,
            collection_name,
            token_name,
            description,
            maximum_supply,
            token_uri,
            signer::address_of(resource_signer),
            1,
            0,
            token::create_token_mutability_config(
                &vector<bool>[false, false, false, false, true]
            ),
            vector<String>[string::utf8(b"hotboice")],
            vector<vector<u8>>[b""],
            vector<String>[string::utf8(b"address")],
        );
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        move_to(resource_signer, HotBoiceTokenData {
            signer_cap: resource_signer_cap,
            token_data_id,
        });
    }

    public entry fun mint(account: &signer) acquires HotBoiceTokenData {
        let module_data = borrow_global_mut<HotBoiceTokenData>(@hotboice);
        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let token_id = token::mint_token(&resource_signer, module_data.token_data_id, AMOUNT_VALUE);
        token::direct_transfer(&resource_signer, account, token_id, AMOUNT_VALUE);

        let (creator_address, collection, name) = token::get_token_data_id_fields(&module_data.token_data_id);
        token::mutate_token_properties(
            &resource_signer,
            signer::address_of(account),
            creator_address,
            collection,
            name,
            TOKEN_VERSION,
            AMOUNT_VALUE,
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>(),
        );
    }
}
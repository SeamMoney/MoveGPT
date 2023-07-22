module nft_api::just_nfts {
    use std::string::{Self, String};
    use std::error;
    use std::signer;
    use std::bcs;
    use aptos_token::token;
    use aptos_framework::account::{Self, SignerCapability};

    use nft_api::utils;

    ////////////////////
    // Constants
    ////////////////////

    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    
    /// Seed used to create the resource account
    const SEED: vector<u8> = vector<u8>[6, 9, 4, 2, 0];

    ////////////////////
    // Error Constants
    ////////////////////
     
    /// Token ID is less than 0 or greater than 9
    const EINVALID_TOKEN_ID: u64 = 0;

    ////////////////////
    // Resource Structs
    ////////////////////
    
    /// @dev This struct stores the collection data and the resource signer capability
    /// @custom:ability Can be stored in the global storage
    struct CollectionData has key {
        collection_name: String,
        base_token_name: String,
        base_token_uri: String,
        token_description: String,
        minted: u128,
        resource_signer_cap: SignerCapability
    }

    ////////////////////
    // Functions
    ////////////////////
    
    /// @dev This function is called when the module is published
    /// @dev It creates the resource account and the collection
    /// @param The account that is publishing the module
    fun init_module(
        account: &signer
    ) {
        let collection_name = string::utf8(b"Just NFTs");
        let collection_description = string::utf8(b"This is just a NFT collection_name");
        let collection_uri = string::utf8(b"ipfs://QmY63wEzRuLseMptaNWo6hQuTaSSFJxGE5ft86BSU55cen/metadata.json");
        let max_supply = 10;
        let mutate_setting = vector<bool>[false, false, false];
        let base_token_name = string::utf8(b"Just NFT #");
        let base_token_uri = string::utf8(b"ipfs://QmY63wEzRuLseMptaNWo6hQuTaSSFJxGE5ft86BSU55cen/");
        let token_description = string::utf8(b"This is just a NFT");
        let minted = 0;

        let (
            resource_signer,
            resource_signer_cap
        ) = account::create_resource_account(
            account,
            SEED
        );

        token::create_collection(
            &resource_signer,
            collection_name,
            collection_description,
            collection_uri,
            max_supply,
            mutate_setting
        );

        move_to<CollectionData>(
            account,
            CollectionData {
                collection_name,
                base_token_name,
                base_token_uri,
                token_description,
                minted,
                resource_signer_cap
            }    
        );
    }

    /// @dev Mint a new token to the caller account
    /// @param The account that is calling the function
    public entry fun mint(
        caller: &signer
    ) acquires CollectionData {
        let collection_data = borrow_global_mut<CollectionData>(@nft_api);
        let collection_name = collection_data.collection_name;
        let token_name = collection_data.base_token_name;
        let token_uri = collection_data.base_token_uri;
        let token_description = collection_data.token_description;
        let minted = &mut collection_data.minted;
        let resource_signer_cap = &collection_data.resource_signer_cap;
        let resource_signer = account::create_signer_with_capability(resource_signer_cap);
        let token_mutability_settings = vector<bool>[false, false, false, false, false];
        let token_mutability_config = token::create_token_mutability_config(
            &token_mutability_settings
        );
        let amount = 1;

        string::append(
            &mut token_name,
            utils::to_string(*minted)
        );
        string::append(
            &mut token_uri,
            utils::to_string(*minted)
        );
        string::append(
            &mut token_uri,
            string::utf8(b".json")
        );

        let tokendata_id = token::create_tokendata(
            &resource_signer,
            collection_name,
            token_name,
            token_description,
            amount,
            token_uri,
            @nft_api,
            0,
            0,
            token_mutability_config,
            vector<String>[string::utf8(BURNABLE_BY_OWNER)],
            vector<vector<u8>>[bcs::to_bytes<bool>(&true)],
            vector<String>[string::utf8(b"bool")]
        );

        token::mint_token_to(
            &resource_signer,
            signer::address_of(caller),
            tokendata_id,
            amount
        );

        *minted = *minted + 1;
    }

    /// @dev Transfer a token to another account
    /// @param The account that is calling the function
    /// @param The address of the recipient
    public entry fun transfer(
        owner: &signer,
        recipient: address,
        token_id: u128
    ) acquires CollectionData {
        assert!(
            token_id >= 0 && token_id < 10,
            error::out_of_range(EINVALID_TOKEN_ID)
        );

        let collection_data = borrow_global_mut<CollectionData>(@nft_api);
        let collection_name = collection_data.collection_name;
        let token_name = collection_data.base_token_name;
        let token_property_version = 0;
        let resource_signer_cap = &collection_data.resource_signer_cap;
        let resource_signer = account::create_signer_with_capability(resource_signer_cap);
        let resource_addr = signer::address_of(&resource_signer);
        let amount = 1;

        string::append(
            &mut token_name,
            utils::to_string(token_id)
        );

        token::transfer_with_opt_in(
            owner,
            resource_addr,
            collection_name,
            token_name,
            token_property_version,
            recipient,
            amount
        );
    }

    /// @dev Burn a token
    /// @param The account that is calling the function
    public entry fun burn(
        owner: &signer,
        token_id: u128
    ) acquires CollectionData {
        assert!(
            token_id >= 0 && token_id < 10,
            error::out_of_range(EINVALID_TOKEN_ID)
        );

        let collection_data = borrow_global_mut<CollectionData>(@nft_api);
        let collection_name = collection_data.collection_name;
        let token_name = collection_data.base_token_name;
        let token_property_version = 0;
        let resource_signer_cap = &collection_data.resource_signer_cap;
        let resource_signer = account::create_signer_with_capability(resource_signer_cap);
        let resource_addr = signer::address_of(&resource_signer);
        let amount = 1;

        string::append(
            &mut token_name,
            utils::to_string(token_id)
        );

        token::burn(
            owner,
            resource_addr,
            collection_name,
            token_name,
            token_property_version,
            amount
        );
    }

    /// @dev Opt into direct transfer
    /// @param The account that is calling the function
    public entry fun opt_into_transfer(
        account: &signer
    ) {
        token::opt_in_direct_transfer(
            account,
            true
        );
    }

    /// @dev Register the token store
    /// @param The account that is calling the function
    public entry fun register_token_store(
        account: &signer
    ) {
        token::initialize_token_store(
            account,
        );
    }

    ////////////////////
    // TESTS
    ////////////////////
    
    /// @dev The tests aren't extensive, but they do test the basic functionality

    #[test_only]
    fun setup(
        deployer: &signer,
        minter: &signer
    ) {
        account::create_account_for_test(
            signer::address_of(deployer)
        );
        account::create_account_for_test(
            signer::address_of(minter)
        );

        init_module(deployer);
        register_token_store(minter);
        opt_into_transfer(minter);
    }

    #[test(deployer = @nft_api, minter = @0x3)]
    fun mint_token(
        deployer: signer,
        minter: signer
    ) acquires CollectionData {
        setup(
            &deployer,
            &minter
        );

        mint(&minter);
    }

    #[test(deployer = @nft_api, minter = @0x3, receiver = @0x4)]
    fun transfer_token(
        deployer: signer,
        minter: signer,
        receiver: signer
    ) acquires CollectionData {
        setup(
            &deployer,
            &minter
        );

        account::create_account_for_test(
            signer::address_of(&receiver)
        );

        register_token_store(&receiver);
        opt_into_transfer(&receiver);

        let receiver_addr = signer::address_of(&receiver);

        mint(&minter);
        transfer(&minter, receiver_addr, 0);
    }

    #[test(deployer = @nft_api, minter = @0x3)]
    fun burn_token(
        deployer: signer,
        minter: signer
    ) acquires CollectionData {
        setup(
            &deployer,
            &minter
        );

        mint(&minter);
        burn(&minter, 0);
    }
}
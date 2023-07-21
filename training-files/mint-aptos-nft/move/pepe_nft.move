module pepe_minter::pepe_nft {
    use std::error;
    use std::signer;
    use std::string;
    use std::vector;
    use std::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::resource_account;
    use aptos_token::token;


    // Errors
    const ENOT_ADMIN: u64 = 0;
    const EMINTING_DISABLED: u64 = 1;
    const ENO_SUFFICIENT_FUND: u64 = 2;

    // Constants
    const COLLECTION_NAME: vector<u8> = b"Pepes";
    const COLLECTION_URI: vector<u8> = b"https://ibb.co/t3ckz86";
    const COLLECTION_SUPPLY: u64 = 0;
    const TOKEN_NAME: vector<u8> = b"Pepe #";
    const TOKEN_URI: vector<u8> = b"ipfs://bafybeihnochxvsv6h43qvg4snenpeasoml66nwxhuiadfzkefix7vbetyq/";
    const TOKEN_SUPPLY: u64 = 1;
    const DESCRIPTION: vector<u8> = b"";

    // Resources
    struct TokenMintingEvent has drop, store {
        buyer_addr: address,
        token_data_id: vector<token::TokenDataId>,
    }

    struct PepeMinter has key {
        signer_cap: account::SignerCapability,
        admin_addr: address,
        minting_enabled: bool,
        minted_supply: u64,
        mint_price: u64,
        token_minting_events: event::EventHandle<TokenMintingEvent>,
    }


    fun assert_is_admin(addr: address) acquires PepeMinter {
        let admin = borrow_global<PepeMinter>(@pepe_minter).admin_addr;
        assert!(addr == admin, error::permission_denied(ENOT_ADMIN));
    }

    fun init_module(resource_acc: &signer) {
        // creates signer from resource account and store PepeMinter under Resource acc
        let signer_cap = resource_account::retrieve_resource_account_cap(resource_acc, @source);

        move_to(resource_acc, PepeMinter {
            signer_cap,
            admin_addr: @admin,
            minting_enabled: true,
            minted_supply: 0,
            mint_price: 20000000,
            token_minting_events: account::new_event_handle<TokenMintingEvent>(resource_acc),
        });
    }


    // Admin-only functions

    public entry fun issue_collection(creator: &signer) acquires PepeMinter {
        assert_is_admin(signer::address_of(creator));

        let minter_resource = borrow_global_mut<PepeMinter>(@pepe_minter);
        let resource_signer = account::create_signer_with_capability(&minter_resource.signer_cap);

        // creates and saves a collection under the Resource Account
        token::create_collection(
            &resource_signer,
            string::utf8(COLLECTION_NAME),
            string::utf8(DESCRIPTION),
            string::utf8(COLLECTION_URI),
            COLLECTION_SUPPLY,
            vector<bool>[ false, false, false ],
        );
    }

    public entry fun enable_minting(admin: &signer, status: bool) acquires PepeMinter {
        let addr = signer::address_of(admin);
        assert_is_admin(addr);
        borrow_global_mut<PepeMinter>(@pepe_minter).minting_enabled = status;
    }

    public entry fun set_admin(admin: &signer, admin_addr: address) acquires PepeMinter {
        let addr = signer::address_of(admin);
        assert_is_admin(addr);
        borrow_global_mut<PepeMinter>(@pepe_minter).admin_addr = admin_addr;
    }


    // public functions
    public entry fun mint_nft(buyer: &signer, amount: u64) acquires PepeMinter {
        let minter_resource = borrow_global_mut<PepeMinter>(@pepe_minter);
        assert!(minter_resource.minting_enabled, error::permission_denied(EMINTING_DISABLED));

        // check buyer has sufficient balance
        let buyer_addr = signer::address_of(buyer);
        let required_amount = minter_resource.mint_price * amount;
        assert!(
            coin::balance<AptosCoin>(buyer_addr) > required_amount, 
            error::invalid_argument(ENO_SUFFICIENT_FUND)
            );

        let resource_signer = account::create_signer_with_capability(&minter_resource.signer_cap);

        token::initialize_token_store(buyer);
        token::opt_in_direct_transfer(buyer, true);

        let mutate_config = token::create_token_mutability_config(
            &vector<bool>[ false, false, false, false, true ]
        );

        let ids = vector::empty<token::TokenDataId>();
        let final_supply = minter_resource.minted_supply + amount;
        while (minter_resource.minted_supply < final_supply) {

            minter_resource.minted_supply = minter_resource.minted_supply + 1;

            let name = string::utf8(TOKEN_NAME);
            string::append(&mut name, u64_to_string(minter_resource.minted_supply));
            
            let uri = string::utf8(TOKEN_URI);
            string::append(&mut uri, u64_to_string(minter_resource.minted_supply));
            string::append_utf8(&mut uri, b".json");

            let token_data_id = token::create_tokendata(
                &resource_signer,
                string::utf8(COLLECTION_NAME),
                name,
                string::utf8(DESCRIPTION),
                TOKEN_SUPPLY,
                uri,
                @admin,
                100,
                5,
                mutate_config,
                vector::empty<string::String>(),
                vector::empty<vector<u8>>(),
                vector::empty<string::String>(),
            );

            token::mint_token_to(&resource_signer, signer::address_of(buyer), token_data_id, TOKEN_SUPPLY);
            vector::push_back(&mut ids, token_data_id);
        };

        coin::transfer<AptosCoin>(buyer, @admin, required_amount);

        event::emit_event<TokenMintingEvent>(
            &mut minter_resource.token_minting_events,
            TokenMintingEvent {
                buyer_addr,
                token_data_id: ids,
            }
        );
    }

    fun u64_to_string(value: u64): string::String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    // ------------------------------------ tests ------------------------------------

    #[test_only]
    use aptos_framework::aptos_account::create_account;
    use aptos_framework::aptos_coin::initialize_for_test;

    #[test_only]
    public fun test_setup(source: &signer, resource_acc: &signer, framework: &signer, buyer: &signer) {
        create_account(signer::address_of(source));
        create_account(signer::address_of(buyer));
        resource_account::create_resource_account(source, vector::empty(), vector::empty());
        
        let (burn, mint) = initialize_for_test(framework);
        let coins = coin::mint<AptosCoin>(1000000000, &mint);
        coin::deposit(signer::address_of(buyer), coins);
        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);
        init_module(resource_acc);
    }

    #[test(framework = @0x1, admin = @admin, source = @source, resource_acc = @pepe_minter, buyer = @0x123)]
    public entry fun normal_process(framework: &signer, admin: &signer, source: &signer, resource_acc: &signer, buyer: &signer) acquires PepeMinter {
        test_setup(source, resource_acc, framework, buyer);
        assert!(exists<PepeMinter>(@pepe_minter), 22);
        create_account(signer::address_of(admin));
        issue_collection(admin);
        mint_nft(buyer, 2);
        aptos_std::debug::print<u64>(&coin::balance<AptosCoin>(signer::address_of(buyer)));
        aptos_std::debug::print<PepeMinter>(borrow_global<PepeMinter>(@pepe_minter));
    }

}
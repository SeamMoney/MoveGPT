module woolf_deployer::woolf {
    use std::error;
    use std::signer;
    use std::string;
    use std::vector;

    use aptos_framework::account;
    use aptos_framework::aptos_account;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event::EventHandle;
    // use aptos_framework::timestamp;
    use aptos_token::token::{Self, TokenDataId, Token};

    use woolf_deployer::barn;
    use woolf_deployer::wool;
    use woolf_deployer::token_helper;
    use woolf_deployer::config;
    use woolf_deployer::utf8_utils;
    use woolf_deployer::random;
    use woolf_deployer::traits;
    use woolf_deployer::wool_pouch;

    /// The Naming Service contract is not enabled
    const ENOT_ENABLED: u64 = 1;
    /// Action not authorized because the signer is not the owner of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;
    /// All minted
    const EALL_MINTED: u64 = 4;
    /// Invalid minting
    const EINVALID_MINTING: u64 = 5;
    /// INSUFFICIENT BALANCE
    const EINSUFFICIENT_APT_BALANCE: u64 = 6;
    const EINSUFFICIENT_WOOL_BALANCE: u64 = 7;

    //
    // constants
    //

    struct TokenMintingEvent has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
    }

    struct Events has key {
        token_minting_events: EventHandle<TokenMintingEvent>,
    }

    struct SheepWolf has drop, store, copy {
        is_sheep: bool,
        fur: u8,
        head: u8,
        ears: u8,
        eyes: u8,
        nose: u8,
        mouth: u8,
        neck: u8,
        feet: u8,
        alpha_index: u8,
    }

    // This struct stores an NFT collection's relevant information
    struct CollectionTokenMinting has key {
        minting_enabled: bool,
    }

    fun init_module(admin: &signer) {
        initialize_modules(admin);
    }

    fun initialize_modules(admin: &signer) {
        let admin_address: address = @woolf_deployer;

        if (!account::exists_at(admin_address)) {
            aptos_account::create_account(admin_address);
        };
        config::initialize(admin, admin_address);
        token_helper::initialize(admin);
        barn::initialize(admin);
        wool::initialize(admin);
        wool_pouch::initialize(admin);
        traits::initialize(admin);
        initialize(admin);
    }

    fun initialize(account: &signer) {
        move_to(account, CollectionTokenMinting {
            minting_enabled: false,
        });
        move_to(account, Events {
            token_minting_events: account::new_event_handle<TokenMintingEvent>(account)
        })
    }

    fun assert_enabled() acquires CollectionTokenMinting {
        let minting = borrow_global<CollectionTokenMinting>(@woolf_deployer);
        assert!(minting.minting_enabled, error::invalid_state(ENOT_ENABLED));
    }

    /// Set if minting is enabled for this collection token minter
    public entry fun set_minting_enabled(admin: &signer, minting_enabled: bool) acquires CollectionTokenMinting {
        assert!(signer::address_of(admin) == @woolf_deployer, error::permission_denied(ENOT_AUTHORIZED));
        let collection_token_minter = borrow_global_mut<CollectionTokenMinting>(@woolf_deployer);
        collection_token_minter.minting_enabled = minting_enabled;
    }

    public fun mint_cost(token_index: u64): u64 {
        if (token_index <= config::paid_tokens()) {
            return 0
        } else if (token_index <= config::max_tokens() * 2 / 5) {
            return 20000 * config::octas()
        } else if (token_index <= config::max_tokens() * 4 / 5) {
            return 40000 * config::octas()
        };
        80000 * config::octas()
    }

    fun issue_token(_receiver: &signer, token_index: u64, t: SheepWolf): Token {
        let SheepWolf {
            is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index
        } = t;
        let token_name = if (is_sheep) config::token_name_sheep_prefix() else config::token_name_wolf_prefix();
        string::append(&mut token_name, utf8_utils::to_string(token_index));
        // Create the token, and transfer it to the user
        let tokendata_id = token_helper::ensure_token_data(token_name);
        let token_id = token_helper::create_token(tokendata_id);

        let (property_keys, property_values, property_types) = traits::get_name_property_map(
            is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index
        );
        let creator_addr = token_helper::get_token_signer_address();
        token_id = token_helper::set_token_props(
            creator_addr,
            token_id,
            property_keys,
            property_values,
            property_types
        );

        traits::update_token_traits(token_id, is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index);

        let token_uri_string = config::tokendata_url_prefix();
        string::append(&mut token_uri_string, string::utf8(if (is_sheep) b"sheepdata/" else b"wolfdata/"));
        string::append(&mut token_uri_string, utf8_utils::to_string(token_index));
        string::append(&mut token_uri_string, string::utf8(b".json"));

        let creator = token_helper::get_token_signer();
        token_helper::set_token_uri(&creator, tokendata_id, token_uri_string);

        token::withdraw_token(&creator, token_id, 1)
    }

    /// Mint an NFT to the receiver.
    public entry fun mint(receiver: &signer, amount: u64, stake: bool) acquires CollectionTokenMinting {
        assert_enabled();
        // NOTE: make receiver op-in in order to random select and directly transfer token to receiver
        token::initialize_token_store(receiver);
        token::opt_in_direct_transfer(receiver, true);

        let receiver_addr = signer::address_of(receiver);
        assert!(config::is_enabled(), error::unavailable(ENOT_ENABLED));
        assert!(amount > 0 && amount <= config::max_single_mint(), error::out_of_range(EINVALID_MINTING));

        let token_supply = token_helper::collection_supply();
        assert!(token_supply + amount <= config::target_max_tokens(), error::out_of_range(EALL_MINTED));

        if (token_supply < config::paid_tokens()) {
            assert!(token_supply + amount <= config::paid_tokens(), error::out_of_range(EALL_MINTED));
            let price = config::mint_price() * amount;
            assert!(coin::balance<AptosCoin>(receiver_addr) >= price, error::invalid_state(EINSUFFICIENT_APT_BALANCE));
            coin::transfer<AptosCoin>(receiver, config::fund_destination_address(), price);
        };

        let total_wool_cost: u64 = 0;
        let tokens: vector<Token> = vector::empty<Token>();
        let seed: vector<u8>;
        let i = 0;
        while (i < amount) {
            seed = random::seed(&receiver_addr);
            let token_index = token_helper::collection_supply() + 1; // from 1
            let sheep_wolf_traits = generate_traits(seed);
            let token = issue_token(receiver, token_index, sheep_wolf_traits);
            // let token_id = token::get_token_id(&token);
            // debug::print(&token_id);
            let recipient: address = select_recipient(receiver_addr, seed, token_index);
            if (!stake || recipient != receiver_addr) {
                token::direct_deposit_with_opt_in(recipient, token);
            } else {
                vector::push_back(&mut tokens, token);
            };
            // wool cost
            total_wool_cost = total_wool_cost + mint_cost(token_index);
            i = i + 1;
        };
        if (total_wool_cost > 0) {
            // burn WOOL
            wool::register_coin(receiver);
            assert!(coin::balance<wool::Wool>(receiver_addr) >= total_wool_cost, error::invalid_state(EINSUFFICIENT_WOOL_BALANCE));
            wool::burn(receiver, total_wool_cost);
            // wool::transfer(receiver, @woolf_deployer, total_wool_cost);
        };

        if (stake) {
            barn::add_many_to_barn_and_pack_internal(receiver_addr, tokens);
        } else {
            vector::destroy_empty(tokens);
        }
    }

    fun generate_traits(seed: vector<u8>): SheepWolf {
        let (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index) = traits::generate_traits(seed);
        SheepWolf {
            is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index
        }
    }

    // the first 20% (ETH purchases) go to the minter
    // the remaining 80% have a 10% chance to be given to a random staked wolf
    fun select_recipient(sender: address, seed: vector<u8>, token_index: u64): address {
        let rand = random::rand_u64_range_with_seed(seed, 0, 10);
        if (token_index <= config::paid_tokens() || rand > 0)
            return sender; // top 10 bits haven't been used
        let thief = barn::random_wolf_owner(seed);
        if (thief == @0x0) return sender;
        return thief
    }

    //
    // test
    //

    #[test_only]
    use std::debug;
    #[test_only]
    use aptos_framework::block;
    #[test_only]
    use woolf_deployer::utils::setup_timestamp;

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1234, fund_address = @woolf_deployer_fund)]
    fun test_mint(
        aptos: &signer,
        admin: &signer,
        account: &signer,
        fund_address: &signer
    ) acquires CollectionTokenMinting {
        setup_timestamp(aptos);
        block::initialize_for_test(aptos, 2);
        initialize_modules(admin);

        let account_addr = signer::address_of(account);
        account::create_account_for_test(account_addr);
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(fund_address));
        set_minting_enabled(account, true);
        wool::register_coin(account);
        wool::register_coin(admin);
        wool::register_coin(fund_address);
        coin::register<AptosCoin>(account);
        coin::register<AptosCoin>(fund_address);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            aptos,
            string::utf8(b"TC"),
            string::utf8(b"TC"),
            8,
            false,
        );

        let coins = coin::mint<AptosCoin>(200000000, &mint_cap);
        coin::deposit(signer::address_of(account), coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);
        wool::mint_internal(account_addr, 10 * config::octas());

        assert!(config::is_enabled(), 0);
        mint(account, 1, false);
        let token_id = token_helper::build_token_id(string::utf8(b"Sheep #1"), 1);
        debug::print(&token_id);
        assert!(token_helper::collection_supply() == 1, 1);
        debug::print(&token::balance_of(signer::address_of(account), token_id));
        assert!(token::balance_of(signer::address_of(account), token_id) == 1, 2)
    }

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1234, fund_address = @woolf_deployer_fund)]
    fun test_mint_with_stake(
        aptos: &signer,
        admin: &signer,
        account: &signer,
        fund_address: &signer
    ) acquires CollectionTokenMinting {
        setup_timestamp(aptos);
        block::initialize_for_test(aptos, 2);
        initialize_modules(admin);


        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));
        account::create_account_for_test(signer::address_of(fund_address));
        set_minting_enabled(admin, true);
        wool::register_coin(account);
        wool::register_coin(admin);
        wool::register_coin(fund_address);

        coin::register<AptosCoin>(account);
        coin::register<AptosCoin>(fund_address);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            aptos,
            string::utf8(b"TC"),
            string::utf8(b"TC"),
            8,
            false,
        );

        let coins = coin::mint<AptosCoin>(200000000, &mint_cap);
        coin::deposit(signer::address_of(account), coins);
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);
        wool::mint_internal(signer::address_of(account), 10 * config::octas());

        token::initialize_token_store(admin);
        token::opt_in_direct_transfer(admin, true);

        assert!(config::is_enabled(), 0);
        mint(account, 1, true);

        let token_id = token_helper::build_token_id(string::utf8(b"Wolf #1"), 1);
        // debug::print(&token_id);
        assert!(token_helper::collection_supply() == 1, 1);
        // debug::print(&token::balance_of(signer::address_of(account), token_id));
        assert!(token::balance_of(signer::address_of(account), token_id) == 0, 2)
    }
}

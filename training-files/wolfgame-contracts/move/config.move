/*
Provides a singleton wrapper around PropertyMap to allow for easy and dynamic configurability of contract options.
This includes things like the maximum number of years that a name can be registered for, etc.

Anyone can read, but only admins can write, as all write methods are gated via permissions checks
*/

module woolf_deployer::config {
    friend woolf_deployer::woolf;
    #[test_only]
    friend woolf_deployer::barn;

    use aptos_std::ed25519::{Self, UnvalidatedPublicKey};
    use aptos_token::property_map::{Self, PropertyMap};
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use std::vector;

    const CONFIG_KEY_ENABLED: vector<u8> = b"enabled";
    const CONFIG_KEY_ADMIN_ADDRESS: vector<u8> = b"admin_address";
    const CONFIG_KEY_FUND_DESTINATION_ADDRESS: vector<u8> = b"fund_destination_address";
    const CONFIG_KEY_TOKENDATA_DESCRIPTION: vector<u8> = b"tokendata_description";
    const CONFIG_KEY_TOKENDATA_URL_PREFIX: vector<u8> = b"tokendata_url_prefix";

    const CONFIG_KEY_TOKEN_NAME_WOLF_PREFIX: vector<u8> = b"token_name_wolf_prefix";
    const CONFIG_KEY_TOKEN_NAME_SHEEP_PREFIX: vector<u8> = b"token_name_sheep_prefix";

    const COLLECTION_NAME: vector<u8> = b"Woolf Game NFT";
    const COLLECTION_DESCRIPTION: vector<u8> = b"Woolf game NFT from Alpha Woolf Game team";
    const COLLECTION_URI: vector<u8> = b"https://wolfgameaptos.xyz";

    const MINT_PRICE: u64 = 99000000; // 0.99 APT
    const MAX_TOKENS: u64 = 50000;
    const PAID_TOKENS: u64 = 10000;
    const MAX_SINGLE_MINT: u64 = 10;

    // TEST: testing config
    // const MINT_PRICE: u64 = 100000000;
    // const MAX_TOKENS: u64 = 200;
    // const PAID_TOKENS: u64 = 40;

    //
    // Errors
    //

    /// Raised if the signer is not authorized to perform an action
    const ENOT_AUTHORIZED: u64 = 1;
    /// Raised if there is an invalid value for a configuration
    const EINVALID_VALUE: u64 = 2;

    struct ConfigurationV1 has key, store {
        config: PropertyMap,
    }

    public(friend) fun initialize(framework: &signer, admin_address: address) acquires ConfigurationV1 {
        move_to(framework, ConfigurationV1 {
            config: property_map::empty(),
        });
        // Temporarily set this to framework to allow other methods below to be set with framework signer
        set_v1(@woolf_deployer, config_key_admin_address(), &signer::address_of(framework));

        set_is_enabled(framework, true);

        // TODO: SET THIS TO SOMETHING REAL
        set_tokendata_description(framework, string::utf8(b"Thousands of Sheep and Wolves compete on a farm in the metaverse. A tempting prize of $WOOL awaits, with deadly high stakes."));
        set_tokendata_url_prefix(framework, string::utf8(b"https://wolfgame.s3.amazonaws.com/"));
        set_token_name_wolf_prefix(framework, string::utf8(b"Wolf #"));
        set_token_name_sheep_prefix(framework, string::utf8(b"Sheep #"));

        // We set it directly here to allow boostrapping the other values
        set_v1(@woolf_deployer, config_key_fund_destination_address(), &@woolf_deployer_fund);
        set_v1(@woolf_deployer, config_key_admin_address(), &admin_address);
    }


    //
    // Configuration Shortcuts
    //

    public fun octas(): u64 {
        100000000
    }

    public fun is_enabled(): bool acquires ConfigurationV1 {
        read_bool_v1(@woolf_deployer, &config_key_enabled())
    }

    public fun fund_destination_address(): address acquires ConfigurationV1 {
        read_address_v1(@woolf_deployer, &config_key_fund_destination_address())
    }

    public fun tokendata_description(): String acquires ConfigurationV1 {
        read_string_v1(@woolf_deployer, &config_key_tokendata_description())
    }

    public fun tokendata_url_prefix(): String acquires ConfigurationV1 {
        read_string_v1(@woolf_deployer, &config_key_tokendata_url_prefix())
    }

    public fun token_name_wolf_prefix(): String acquires ConfigurationV1 {
        read_string_v1(@woolf_deployer, &config_key_token_name_wolf_prefix())
    }

    public fun token_name_sheep_prefix(): String acquires ConfigurationV1 {
        read_string_v1(@woolf_deployer, &config_key_token_name_sheep_prefix())
    }

    /// Admins will be able to intervene when necessary.
    /// The account will be used to manage names that are being used in a way that is harmful to others.
    /// Alternatively, the deployer can be used to perform admin actions.
    public fun signer_is_admin(sign: &signer): bool acquires ConfigurationV1 {
        signer::address_of(sign) == admin_address() || signer::address_of(sign) == @woolf_deployer
    }

    public fun assert_signer_is_admin(sign: &signer) acquires ConfigurationV1 {
        assert!(signer_is_admin(sign), error::permission_denied(ENOT_AUTHORIZED));
    }

    public fun collection_name(): String {
        string::utf8(COLLECTION_NAME)
    }

    public fun collection_description(): String {
        string::utf8(COLLECTION_DESCRIPTION)
    }

    public fun collection_uri(): String {
        string::utf8(COLLECTION_URI)
    }

    public fun max_tokens(): u64 {
        MAX_TOKENS
    }

    public fun target_max_tokens(): u64 {
        13809
    }

    public fun paid_tokens(): u64 {
        PAID_TOKENS
    }

    public fun max_single_mint(): u64 {
        MAX_SINGLE_MINT
    }

    public fun mint_price(): u64 {
        MINT_PRICE
    }

    //
    // Setters
    //

    public entry fun set_is_enabled(sign: &signer, enabled: bool) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_enabled(), &enabled)
    }

    public entry fun set_tokendata_description(sign: &signer, description: String) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_tokendata_description(), &description)
    }

    public entry fun set_tokendata_url_prefix(sign: &signer, description: String) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_tokendata_url_prefix(), &description)
    }

    public entry fun set_token_name_wolf_prefix(sign: &signer, description: String) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_token_name_wolf_prefix(), &description)
    }

    public entry fun set_token_name_sheep_prefix(sign: &signer, description: String) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_token_name_sheep_prefix(), &description)
    }

    public entry fun set_fund_destination_address(sign: &signer, description: address) acquires ConfigurationV1 {
        assert_signer_is_admin(sign);
        set_v1(@woolf_deployer, config_key_fund_destination_address(), &description)
    }

    //
    // Configuration Methods
    //

    public fun config_key_enabled(): String {
        string::utf8(CONFIG_KEY_ENABLED)
    }

    public fun config_key_admin_address(): String {
        string::utf8(CONFIG_KEY_ADMIN_ADDRESS)
    }

    public fun config_key_fund_destination_address(): String {
        string::utf8(CONFIG_KEY_FUND_DESTINATION_ADDRESS)
    }

    public fun admin_address(): address acquires ConfigurationV1 {
        read_address_v1(@woolf_deployer, &config_key_admin_address())
    }

    public fun config_key_tokendata_description(): String {
        string::utf8(CONFIG_KEY_TOKENDATA_DESCRIPTION)
    }

    public fun config_key_tokendata_url_prefix(): String {
        string::utf8(CONFIG_KEY_TOKENDATA_URL_PREFIX)
    }

    public fun config_key_token_name_wolf_prefix(): String {
        string::utf8(CONFIG_KEY_TOKEN_NAME_WOLF_PREFIX)
    }

    public fun config_key_token_name_sheep_prefix(): String {
        string::utf8(CONFIG_KEY_TOKEN_NAME_SHEEP_PREFIX)
    }


    //
    // basic methods
    //

    fun set_v1<T: copy>(addr: address, config_name: String, value: &T) acquires ConfigurationV1 {
        let map = &mut borrow_global_mut<ConfigurationV1>(addr).config;
        let value = property_map::create_property_value(value);
        if (property_map::contains_key(map, &config_name)) {
            property_map::update_property_value(map, &config_name, value);
        } else {
            property_map::add(map, config_name, value);
        };
    }

    public fun read_string_v1(addr: address, key: &String): String acquires ConfigurationV1 {
        property_map::read_string(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_u8_v1(addr: address, key: &String): u8 acquires ConfigurationV1 {
        property_map::read_u8(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_u64_v1(addr: address, key: &String): u64 acquires ConfigurationV1 {
        property_map::read_u64(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_address_v1(addr: address, key: &String): address acquires ConfigurationV1 {
        property_map::read_address(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_u128_v1(addr: address, key: &String): u128 acquires ConfigurationV1 {
        property_map::read_u128(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_bool_v1(addr: address, key: &String): bool acquires ConfigurationV1 {
        property_map::read_bool(&borrow_global<ConfigurationV1>(addr).config, key)
    }

    public fun read_unvalidated_public_key(addr: address, key: &String): UnvalidatedPublicKey acquires ConfigurationV1 {
        let value = property_map::borrow_value(property_map::borrow(&borrow_global<ConfigurationV1>(addr).config, key));
        // remove the length of this vector recorded at index 0
        vector::remove(&mut value, 0);
        ed25519::new_unvalidated_public_key_from_bytes(value)
    }
}

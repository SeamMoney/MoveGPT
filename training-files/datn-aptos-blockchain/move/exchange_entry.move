module ecommerce::exchange_entry {
    use std::error;
    use std::vector;
    use std::signer;
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use aptos_std::math64;
    use aptos_std::comparator;
    use aptos_std::table::{Self, Table};
    use aptos_std::type_info::{Self, TypeInfo};
    use aptos_std::ed25519::{Self, ValidatedPublicKey};
    use aptos_token::token::{Self, TokenId};
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_framework::resource_account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account::{Self, SignerCapability};
    use ecommerce::product;
    use ecommerce::order;
    use ecommerce::reward;
    use ecommerce::review;
    use ecommerce::proofs::{
        Self as proofs,
        ListingProductProof,
        OrderProductProof,
        CompleteOrderProductProof,
        ClaimRewardProof,
        ReviewProductProof,
        ClaimReviewProof,
        ClaimAllReviewProof
    };
    use ecommerce::events::{
        Self as events,
        ListingProductEvent,
        EditProductEvent,
        OrderEvent,
        CompleteOrderEvent,
        ClaimRewardEvent,
        ReviewEvent,
        ClaimReviewEvent,
        ClaimAllReviewEvent
    };

    struct Config has key {
        signer_cap: SignerCapability,
        verifier_pk: Option<ValidatedPublicKey>,
        collection_name: String,
        operators: vector<address>,
        paused: bool,
        fee_numerator: u64,
        fee_denominator: u64,
        reward_numerator: u64,
        reward_denominator: u64,
        min_time_orders_reward: u64,
        reviewing_fee: u64,
        reviewing_lock_time: u64,
        categories: vector<String>,
        colors: vector<String>,
        sizes: vector<String>,
    }

    struct Exchange has key {
        products: Table<TokenId, ProductInfo>,
        seller_by_product: Table<TokenId, address>,
        buyer_by_order: Table<String, address>,
        listing_product_event: EventHandle<ListingProductEvent>,
        edit_product_event: EventHandle<EditProductEvent>,
        order_event: EventHandle<OrderEvent>,
        complete_order_event: EventHandle<CompleteOrderEvent>,
        claim_reward_event: EventHandle<ClaimRewardEvent>,
        review_event: EventHandle<ReviewEvent>,
        claim_review_event: EventHandle<ClaimReviewEvent>,
        claim_all_review_event: EventHandle<ClaimAllReviewEvent>
    }

    struct ProductInfo has drop, store {
        token_id: TokenId,
        order_ids: vector<String>
    }

    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 0;

    /// The numerator or denominator is invalid
    const EINVALID_NUMERATOR_DENOMINATOR: u64 = 1;

    /// The argument must be non-zero
    const EINVALID_ARGUMENT_NON_ZERO: u64 = 2;

    /// The element is already existed
    const EELEMENT_ALREADY_EXISTED: u64 = 3;

    /// The element is not found
    const EELEMENT_NOT_FOUND: u64 = 4;

    /// The collection name is already existed
    const ECOLLECTION_NAME_ALREADY_EXISTED: u64 = 5;

    /// The system is temporary paused
    const EIS_PAUSED: u64 = 6;

    /// The coin type argument is invalid
    const EINVALID_COIN_TYPE_ARGUMENT: u64 = 7;

    ///  The signature is invalid
    const EINVALID_SIGNATURE: u64 = 8;

    /// The order is already existed
    const EORDER_ALREADY_EXISTED: u64 = 10;

    /// The order is not found
    const EORDER_NOT_FOUND: u64 = 11;

    fun init_module(resource_account: &signer) {
        initialize_ecommerce(resource_account);
    }

    fun initialize_ecommerce(account: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(account, @admin_addr);
        move_to(account, Config {
            signer_cap: resource_signer_cap,
            verifier_pk: option::none(),
            collection_name: string::utf8(b""),
            paused: false,
            fee_numerator: 0,
            fee_denominator: 0,
            reward_numerator: 0,
            reward_denominator: 0,
            min_time_orders_reward: 0,
            reviewing_fee: 0,
            reviewing_lock_time: 0,
            operators: vector[@admin_addr],
            categories: vector::empty<String>(),
            colors: vector::empty<String>(),
            sizes: vector::empty<String>()
        });
        move_to(account, Exchange {
            products: table::new(),
            seller_by_product: table::new(),
            buyer_by_order: table::new(),
            listing_product_event: account::new_event_handle<ListingProductEvent>(account),
            edit_product_event: account::new_event_handle<EditProductEvent>(account),
            order_event: account::new_event_handle<OrderEvent>(account),
            complete_order_event: account::new_event_handle<CompleteOrderEvent>(account),
            claim_reward_event: account::new_event_handle<ClaimRewardEvent>(account),
            review_event: account::new_event_handle<ReviewEvent>(account),
            claim_review_event: account::new_event_handle<ClaimReviewEvent>(account),
            claim_all_review_event: account::new_event_handle<ClaimAllReviewEvent>(account)
        });
        if (!coin::is_account_registered<AptosCoin>(@ecommerce)) {
            coin::register<AptosCoin>(account);
        };
    }

    public entry fun init_config(
        caller: &signer,
        verifier_pk: vector<u8>,
        fee_numerator: u64,
        fee_denominator: u64,
        reward_numerator: u64,
        reward_denominator: u64,
        min_time_orders_reward: u64,
        reviewing_fee: u64,
        reviewing_lock_time: u64,
        categories: vector<String>,
        colors: vector<String>,
        sizes: vector<String>
    ) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));
        assert!(
            0 < fee_numerator && fee_numerator <= fee_denominator,
            error::invalid_argument(EINVALID_NUMERATOR_DENOMINATOR)
        );
        assert!(
            0 < reward_numerator && reward_numerator <= reward_denominator,
            error::invalid_argument(EINVALID_NUMERATOR_DENOMINATOR)
        );
        assert!(
            min_time_orders_reward > 0 && reviewing_fee > 0 && reviewing_lock_time > 0,
            error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO)
        );
        config.verifier_pk = option::some(
            option::extract(&mut ed25519::new_validated_public_key_from_bytes(verifier_pk))
        );
        config.fee_numerator = fee_numerator;
        config.fee_denominator = fee_denominator;
        config.reward_numerator = reward_numerator;
        config.reward_denominator = reward_denominator;
        config.min_time_orders_reward = min_time_orders_reward;
        config.reviewing_fee = reviewing_fee;
        config.reviewing_lock_time = reviewing_lock_time;
        config.categories = categories;
        config.colors = colors;
        config.sizes = sizes;
    }

    public entry fun create_collection(
        caller: &signer,
        name: String,
        description: String,
        uri: String
    ) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        assert!(
            !comparator::is_equal(&comparator::compare(&name, &config.collection_name)),
            error::invalid_argument(ECOLLECTION_NAME_ALREADY_EXISTED)
        );
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        token::create_collection(
            &resource_signer,
            name,
            description,
            uri,
            1000000000000,
            vector<bool>[false, false, false]
        );
        config.collection_name = name;
    }

    public entry fun add_operator(caller: &signer, operator: address) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        assert!(!vector::contains(&config.operators, &operator), error::already_exists(EELEMENT_ALREADY_EXISTED));
        vector::push_back(&mut config.operators, operator);
    }

    public entry fun remove_operator(caller: &signer, operator: address) acquires Config {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let config = borrow_global_mut<Config>(@ecommerce);
        let (found, index) = vector::index_of(&config.operators, &operator);
        assert!(found, error::invalid_argument(EELEMENT_NOT_FOUND));
        vector::remove(&mut config.operators, index);
    }

    public entry fun set_fee(caller: &signer, fee_numerator: u64, fee_denominator: u64) acquires Config {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(
            0 < fee_numerator && fee_numerator <= fee_denominator,
            error::invalid_argument(EINVALID_NUMERATOR_DENOMINATOR)
        );
        config.fee_numerator = fee_numerator;
        config.fee_denominator = fee_denominator;
    }

    public entry fun set_reward(
        caller: &signer,
        reward_numerator: u64,
        reward_denominator: u64,
        min_time_orders_reward: u64
    ) acquires Config {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(
            0 < reward_numerator && reward_numerator <= reward_denominator,
            error::invalid_argument(EINVALID_NUMERATOR_DENOMINATOR)
        );
        assert!(min_time_orders_reward > 0, error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO));
        config.reward_numerator = reward_numerator;
        config.reward_denominator = reward_denominator;
        config.min_time_orders_reward = min_time_orders_reward;
    }

    public entry fun set_review(
        caller: &signer,
        reviewing_fee: u64,
        reviewing_lock_time: u64
    ) acquires Config {
        let caller_addr = signer::address_of(caller);
        assert!(caller_addr == @admin_addr, error::permission_denied(ENOT_AUTHORIZED));
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(
            reviewing_fee > 0 && reviewing_lock_time > 0,
            error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO)
        );
        config.reviewing_fee = reviewing_fee;
        config.reviewing_lock_time = reviewing_lock_time;
    }

    public entry fun set_verifier_pk(caller: &signer, verifier_pk: vector<u8>) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));
        config.verifier_pk = option::some(
            option::extract(&mut ed25519::new_validated_public_key_from_bytes(verifier_pk))
        );
    }

    public entry fun set_paused(caller: &signer, is_paused: bool) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));
        config.paused = is_paused;
    }

    public entry fun insert_categories(caller: &signer, categories: vector<String>) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));

        let idx = 0;
        while (idx < vector::length(&categories)) {
            let category = *vector::borrow(&categories, idx);
            if (!vector::contains(&categories, &category)) {
                vector::push_back(&mut config.categories, category);
            };
            idx = idx + 1;
        };
    }

    public entry fun insert_colors(caller: &signer, colors: vector<String>) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));

        let idx = 0;
        while (idx < vector::length(&colors)) {
            let color = *vector::borrow(&colors, idx);
            if (!vector::contains(&colors, &color)) {
                vector::push_back(&mut config.colors, color);
            };
            idx = idx + 1;
        };
    }

    public entry fun insert_sizes(caller: &signer, sizes: vector<String>) acquires Config {
        let caller_addr = signer::address_of(caller);
        let config = borrow_global_mut<Config>(@ecommerce);
        assert!(vector::contains(&config.operators, &caller_addr), error::permission_denied(ENOT_AUTHORIZED));

        let idx = 0;
        while (idx < vector::length(&sizes)) {
            let size = *vector::borrow(&sizes, idx);
            if (!vector::contains(&sizes, &size)) {
                vector::push_back(&mut config.sizes, size);
            };
            idx = idx + 1;
        };
    }

    public entry fun listing_product(
        caller: &signer,
        name: String,
        description: String,
        uri: String,
        quantity: u64,
        price: u64,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        assert!(quantity > 0, error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO));
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_listing_product_proof(
            caller_addr,
            name,
            description,
            uri,
            quantity,
            price
        );
        verify_signature<ListingProductProof>(signature, data);
        let config = borrow_global<Config>(@ecommerce);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        let token_data_id = token::create_tokendata(
            &resource_signer,
            config.collection_name,
            name,
            description,
            1000000000000,
            uri,
            @ecommerce,
            100,
            0,
            token::create_token_mutability_config(&vector<bool>[false, false, false, true, false]),
            vector::empty<String>(),
            vector::empty<vector<u8>>(),
            vector::empty<String>()
        );
        token::opt_in_direct_transfer(caller, true);
        token::mint_token_to(&resource_signer, caller_addr, token_data_id, quantity);
        let token_id = token::create_token_id_raw(@ecommerce, config.collection_name, name, 0);
        product::create_product_under_user_account(
            caller,
            token_id,
            quantity,
            price,
            timestamp::now_microseconds()
        );
        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        table::add(&mut exchange.products, token_id, ProductInfo {
            token_id,
            order_ids: vector::empty<String>()
        });
        table::add(&mut exchange.seller_by_product, token_id, caller_addr);
        event::emit_event<ListingProductEvent>(
            &mut exchange.listing_product_event,
            events::create_listing_product_event(
                token_id,
                caller_addr,
                quantity,
                price,
                timestamp::now_microseconds()
            )
        );
    }

    public entry fun order_product<CoinType>(
        caller: &signer,
        order_ids: vector<String>,
        product_titles: vector<String>,
        quantities: vector<u64>,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_order_product_proof(
            caller_addr,
            order_ids,
            product_titles,
            quantities
        );
        verify_signature<OrderProductProof>(signature, data);
        let config = borrow_global<Config>(@ecommerce);
        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        let idx = 0;
        let coins = 0;
        while (idx < vector::length(&order_ids)) {
            let order_id = *vector::borrow(&order_ids, idx);
            let product_title = *vector::borrow(&product_titles, idx);
            let quantity = *vector::borrow(&quantities, idx);
            let token_id = token::create_token_id_raw(@ecommerce, config.collection_name, product_title, 0);
            let product_info = table::borrow_mut(&mut exchange.products, token_id);
            assert!(quantity > 0, error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO));
            assert!(
                !vector::contains(&product_info.order_ids, &order_id) &&
                !table::contains(&exchange.buyer_by_order, order_id),
                error::invalid_argument(EORDER_ALREADY_EXISTED)
            );
            let (_, _, price) = product::get_product_info(
                *table::borrow(&exchange.seller_by_product, token_id),
                token_id
            );
            order::create_order_under_user_account(caller, order_id, token_id, quantity, price, timestamp::now_microseconds());
            vector::push_back(&mut product_info.order_ids, order_id);
            table::add(&mut exchange.buyer_by_order, order_id, caller_addr);
            coins = coins + price * quantity;
            idx = idx + 1;
        };

        event::emit_event<OrderEvent>(
            &mut exchange.order_event,
            events::create_order_event(
                order_ids,
                caller_addr,
                timestamp::now_microseconds()
            )
        );

        token::opt_in_direct_transfer(caller, true);
        reward::initialize_reward(caller);
        // Transfer APT coin
        coin::transfer<CoinType>(caller, @ecommerce, coins);
    }

    public entry fun complete_order_product<CoinType>(
        caller: &signer,
        order_id: String,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_complete_order_product_proof(
            caller_addr,
            order_id
        );
        verify_signature<CompleteOrderProductProof>(signature, data);
        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        let buyer_addr = *table::borrow(&exchange.buyer_by_order, order_id);
        let (token_id, quantity, price) = order::complete_order_status_under_user_account(buyer_addr, order_id);
        let product_info = table::borrow(&exchange.products, token_id);
        assert!(
            table::contains(&exchange.buyer_by_order, order_id),
            error::invalid_argument(EORDER_NOT_FOUND)
        );
        assert!(
            vector::contains(&product_info.order_ids, &order_id),
            error::invalid_argument(EORDER_NOT_FOUND)
        );
        product::complete_order_update_product_under_user_account(caller, token_id, quantity);

        event::emit_event<CompleteOrderEvent>(
            &mut exchange.complete_order_event,
            events::create_complete_order_event(
                order_id,
                token_id,
                buyer_addr,
                timestamp::now_microseconds()
            )
        );

        // Transfer APT coin
        let config = borrow_global<Config>(@ecommerce);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        let fee = if (config.fee_denominator == 0) {
            0
        } else {
            quantity * price * config.fee_numerator / config.fee_denominator
        };
        let amount = quantity * price - fee;
        coin::transfer<CoinType>(&resource_signer, caller_addr, amount);

        // Transfer NFT
        token::transfer(caller, token_id, buyer_addr, quantity);

        // Add reward for buyer
        reward::add_reward_under_user_account(
            buyer_addr,
            config.reward_numerator,
            config.reward_denominator,
            quantity * price,
            config.min_time_orders_reward
        );
    }

    public entry fun claim_reward<CoinType>(
        caller: &signer,
        claim_history_id: String,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_claim_reward_proof(caller_addr, claim_history_id);
        verify_signature<ClaimRewardProof>(signature, data);

        let balance = reward::claim_reward_under_user_account(caller);
        assert!(balance > 0, error::invalid_argument(EINVALID_ARGUMENT_NON_ZERO));
        // Transfer APT coin
        let config = borrow_global<Config>(@ecommerce);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        coin::transfer<CoinType>(&resource_signer, caller_addr, balance);

        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        event::emit_event<ClaimRewardEvent>(
            &mut exchange.claim_reward_event,
            events::create_claim_reward_event(
                claim_history_id,
                caller_addr,
                balance,
                timestamp::now_microseconds()
            )
        );
    }

    public entry fun review_product<CoinType>(
        caller: &signer,
        review_id: String,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_review_product_proof(caller_addr, review_id);
        verify_signature<ReviewProductProof>(signature, data);

        let config = borrow_global<Config>(@ecommerce);
        review::create_review_under_user_account(
            caller,
            review_id,
            config.reviewing_fee,
            timestamp::now_microseconds(),
            config.reviewing_lock_time
        );
        // Transfer APT coin
        coin::transfer<CoinType>(caller, @ecommerce, config.reviewing_fee);

        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        event::emit_event<ReviewEvent>(
            &mut exchange.review_event,
            events::create_review_event(
                review_id,
                caller_addr,
                config.reviewing_fee,
                timestamp::now_microseconds()
            )
        );
    }

    public entry fun claim_all_review_product<CoinType>(
        caller: &signer,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_claim_all_review_proof(caller_addr);
        verify_signature<ClaimAllReviewProof>(signature, data);

        let (amount, review_ids) = review::claim_all_review_product_under_user_account(caller);
        // Transfer APT coin
        let config = borrow_global<Config>(@ecommerce);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        coin::transfer<CoinType>(&resource_signer, caller_addr, amount);

        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        event::emit_event<ClaimAllReviewEvent>(
            &mut exchange.claim_all_review_event,
            events::create_claim_all_review_event(
                caller_addr,
                review_ids,
                amount,
                timestamp::now_microseconds()
            )
        );
    }

    public entry fun claim_review_product<CoinType>(
        caller: &signer,
        review_id: String,
        signature: vector<u8>
    ) acquires Config, Exchange {
        checking_when_not_paused();
        checking_coin_type<CoinType>();
        let caller_addr = signer::address_of(caller);
        let data = proofs::create_claim_review_proof(caller_addr, review_id);
        verify_signature<ClaimReviewProof>(signature, data);

        let amount = review::claim_review_under_user_account(caller, review_id);
        // Transfer APT coin
        let config = borrow_global<Config>(@ecommerce);
        let resource_signer = account::create_signer_with_capability(&config.signer_cap);
        coin::transfer<CoinType>(&resource_signer, caller_addr, amount);

        let exchange = borrow_global_mut<Exchange>(@ecommerce);
        event::emit_event<ClaimReviewEvent>(
            &mut exchange.claim_review_event,
            events::create_claim_review_event(
                review_id,
                caller_addr,
                amount,
                timestamp::now_microseconds()
            )
        );
    }

    fun checking_when_not_paused() acquires Config {
        let config = borrow_global<Config>(@ecommerce);
        assert!(!config.paused, error::unavailable(EIS_PAUSED));
    }

    fun checking_coin_type<CoinType>() acquires Config {
        let type_info = type_info::type_of<CoinType>();
        let type_info_aptos_coin = type_info::type_of<AptosCoin>();
        let config = borrow_global<Config>(@ecommerce);
        assert!(
            type_info::account_address(&type_info) == type_info::account_address(&type_info_aptos_coin) &&
            type_info::module_name(&type_info) == type_info::module_name(&type_info_aptos_coin) &&
            type_info::struct_name(&type_info) == type_info::struct_name(&type_info_aptos_coin),
            error::invalid_argument(EINVALID_COIN_TYPE_ARGUMENT)
        );
    }

    fun verify_signature<T: drop>(proof_signature: vector<u8>, data: T) acquires Config {
        let config = borrow_global<Config>(@ecommerce);
        let signature = ed25519::new_signature_from_bytes(proof_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(
            option::borrow<ValidatedPublicKey>(&config.verifier_pk)
        );
        assert!(
            ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, data),
            error::invalid_argument(EINVALID_SIGNATURE)
        );
    }
}

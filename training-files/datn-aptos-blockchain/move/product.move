module ecommerce::product {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenId};

    struct ProductRecords has key {
        records: Table<TokenId, Product>,
        product_ids: vector<TokenId>
    }

    struct Product has drop, store {
        token_id: TokenId,
        seller: address,
        quantity: u64,
        price: u64,
        timestamp: u64
    }

    /// The argument must be non-zero
    const EPRODUCT_ARGUMENT_NON_ZERO: u64 = 0;

    /// The product is already existed
    const EPRODUCT_ALREADY_EXISTED: u64 = 1;

    /// The product is not found
    const EPRODUCT_NOT_FOUND: u64 = 2;

    /// The product quantity is not enough
    const EPRODUCT_QUANTITY_NOT_ENOUGH: u64 = 3;

    public fun initialize_product_records(account: &signer) {
        if(!exists<ProductRecords>(signer::address_of(account))) {
            move_to(account, ProductRecords {
                records: table::new(),
                product_ids: vector::empty<TokenId>()
            });
        };
    }

    public fun create_product(
        owner: &signer,
        token_id: TokenId,
        quantity: u64,
        price: u64,
        timestamp: u64
    ): Product {
        let owner_addr = signer::address_of(owner);
        assert!(quantity > 0 && price > 0, error::invalid_argument(EPRODUCT_ARGUMENT_NON_ZERO));
        Product {
            token_id,
            seller: owner_addr,
            quantity,
            price,
            timestamp
        }
    }

    public fun create_product_under_user_account(
        owner: &signer,
        token_id: TokenId,
        quantity: u64,
        price: u64,
        timestamp: u64
    ) acquires ProductRecords {
        let owner_addr = signer::address_of(owner);
        initialize_product_records(owner);
        let product_records = borrow_global_mut<ProductRecords>(owner_addr);
        assert!(
            !table::contains(&product_records.records, token_id) &&
            !vector::contains(&product_records.product_ids, &token_id),
            error::invalid_argument(EPRODUCT_ALREADY_EXISTED)
        );
        let product = create_product(owner, token_id, quantity, price, timestamp);
        table::add(&mut product_records.records, token_id, product);
        vector::push_back(&mut product_records.product_ids, token_id);
    }

    public fun edit_product_under_user_account(
        owner: &signer,
        token_id: TokenId,
        newQuantity: u64,
        newPrice: u64
    ) acquires ProductRecords {
        let owner_addr = signer::address_of(owner);
        let product_records = borrow_global_mut<ProductRecords>(owner_addr);
        assert!(newQuantity > 0 && newPrice > 0, error::invalid_argument(EPRODUCT_ARGUMENT_NON_ZERO));
        assert!(
            table::contains(&product_records.records, token_id) &&
            vector::contains(&product_records.product_ids, &token_id),
            error::invalid_argument(EPRODUCT_NOT_FOUND)
        );
        let product = table::borrow_mut(&mut product_records.records, token_id);
        product.quantity = newQuantity;
        product.price = newPrice;
    }

    public fun complete_order_update_product_under_user_account(
        seller: &signer,
        token_id: TokenId,
        quantity: u64
    ) acquires ProductRecords {
        let seller_addr = signer::address_of(seller);
        let product_records = borrow_global_mut<ProductRecords>(seller_addr);
        assert!(
            table::contains(&product_records.records, token_id) &&
            vector::contains(&product_records.product_ids, &token_id),
            error::invalid_argument(EPRODUCT_NOT_FOUND)
        );
        let product = table::borrow_mut(&mut product_records.records, token_id);
        assert!(
            quantity <= product.quantity, error::invalid_argument(EPRODUCT_QUANTITY_NOT_ENOUGH)
        );
        product.quantity = product.quantity - quantity;
    }

    public fun get_product_info(
        seller_addr: address,
        token_id: TokenId
    ): (TokenId, u64, u64) acquires ProductRecords {
        let product_records = borrow_global_mut<ProductRecords>(seller_addr);
        assert!(
            table::contains(&product_records.records, token_id) &&
            vector::contains(&product_records.product_ids, &token_id),
            error::invalid_argument(EPRODUCT_NOT_FOUND)
        );
        let product = table::borrow(&product_records.records, token_id);
        (product.token_id, product.quantity, product.price)
    }
}

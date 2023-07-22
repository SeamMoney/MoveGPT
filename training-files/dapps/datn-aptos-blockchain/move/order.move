module ecommerce::order {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenId};

    struct OrderRecords has key {
        records: Table<String, Order>,
        order_ids: vector<String>
    }

    struct Order has drop, store {
        order_id: String,
        token_id: TokenId,
        buyer: address,
        quantity: u64,
        price: u64,
        timestamp: u64,
        /**
            status = 0: paid,
            status = 1: completed,
            status = 2: canceled
        **/
        status: u64
    }

    /// The argument must be non-zero
    const EORDER_ARGUMENT_NON_ZERO: u64 = 0;

    /// The order is already existed
    const EORDER_ALREADY_EXISTED: u64 = 1;

    /// The order is not found
    const EORDER_NOT_FOUND: u64 = 2;

    /// The order status must be paid
    const EORDER_NOT_PAID_STATUS: u64 = 3;

    public fun initialize_order_records(account: &signer) {
        if(!exists<OrderRecords>(signer::address_of(account))) {
            move_to(account, OrderRecords {
                records: table::new(),
                order_ids: vector::empty<String>()
            });
        };
    }

    public fun create_order(
        buyer: &signer,
        order_id: String,
        token_id: TokenId,
        quantity: u64,
        price: u64,
        timestamp: u64
    ): Order {
        let buyer_addr = signer::address_of(buyer);
        assert!(quantity > 0 && price > 0, error::invalid_argument(EORDER_ARGUMENT_NON_ZERO));
        Order {
            order_id,
            token_id,
            buyer: buyer_addr,
            quantity,
            price,
            timestamp,
            status: 0
        }
    }

    public fun create_order_under_user_account(
        buyer: &signer,
        order_id: String,
        token_id: TokenId,
        quantity: u64,
        price: u64,
        timestamp: u64
    ) acquires OrderRecords {
        let buyer_addr = signer::address_of(buyer);
        initialize_order_records(buyer);
        let order_records = borrow_global_mut<OrderRecords>(buyer_addr);
        assert!(
            !table::contains(&order_records.records, order_id) &&
            !vector::contains(&order_records.order_ids, &order_id),
            error::invalid_argument(EORDER_ALREADY_EXISTED)
        );
        let order = create_order(buyer, order_id, token_id, quantity, price, timestamp);
        table::add(&mut order_records.records, order_id, order);
        vector::push_back(&mut order_records.order_ids, order_id);
    }

    public fun complete_order_status_under_user_account(
        buyer_addr: address,
        order_id: String
    ): (TokenId, u64, u64) acquires OrderRecords {
        let order_records = borrow_global_mut<OrderRecords>(buyer_addr);
        assert!(
            table::contains(&order_records.records, order_id) &&
            vector::contains(&order_records.order_ids, &order_id),
            error::invalid_argument(EORDER_NOT_FOUND)
        );
        let order = table::borrow_mut(&mut order_records.records, order_id);
        assert!(order.status == 0, error::invalid_argument(EORDER_NOT_PAID_STATUS));
        order.status = 1;
        (order.token_id, order.quantity, order.price)
    }

    public fun cancel_order_status_under_user_account(
        buyer: &signer,
        order_id: String
    ): (TokenId, u64, u64) acquires OrderRecords {
        let buyer_addr = signer::address_of(buyer);
        let order_records = borrow_global_mut<OrderRecords>(buyer_addr);
        assert!(
            table::contains(&order_records.records, order_id) &&
            vector::contains(&order_records.order_ids, &order_id),
            error::invalid_argument(EORDER_NOT_FOUND)
        );
        let order = table::borrow_mut(&mut order_records.records, order_id);
        assert!(order.status == 0, error::invalid_argument(EORDER_NOT_PAID_STATUS));
        order.status = 2;
        (order.token_id, order.quantity, order.price)
    }
}

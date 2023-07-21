module ecommerce::events {
    use std::vector;
    use std::string::String;
    use std::option::Option;
    use aptos_token::token::{
        TokenId
    };

    struct ListingProductEvent has copy, drop, store {
        token_id: TokenId,
        seller: address,
        quantity: u64,
        price: u64,
        timestamp: u64
    }

    public fun create_listing_product_event(
        token_id: TokenId,
        seller: address,
        quantity: u64,
        price: u64,
        timestamp: u64
    ): ListingProductEvent {
        ListingProductEvent {
            token_id,
            seller,
            quantity,
            price,
            timestamp
        }
    }

    struct EditProductEvent has copy, drop, store {
        token_id: TokenId,
        newDescription: String,
        newQuantity: u64,
        newPrice: u64,
        timestamp: u64
    }

    public fun create_edit_product_event(
        token_id: TokenId,
        newDescription: String,
        newQuantity: u64,
        newPrice: u64,
        timestamp: u64
    ): EditProductEvent {
        EditProductEvent {
            token_id,
            newDescription,
            newQuantity,
            newPrice,
            timestamp
        }
    }

    struct OrderEvent has copy, drop, store {
        order_ids: vector<String>,
        buyer: address,
        timestamp: u64
    }

    public fun create_order_event(
        order_ids: vector<String>,
        buyer: address,
        timestamp: u64
    ): OrderEvent {
        OrderEvent {
            order_ids,
            buyer,
            timestamp
        }
    }

    struct CompleteOrderEvent has copy, drop, store {
        order_id: String,
        token_id: TokenId,
        buyer: address,
        timestamp: u64
    }

    public fun create_complete_order_event(
        order_id: String,
        token_id: TokenId,
        buyer: address,
        timestamp: u64
    ): CompleteOrderEvent {
        CompleteOrderEvent {
            order_id,
            token_id,
            buyer,
            timestamp
        }
    }

    struct ClaimRewardEvent has copy, drop, store {
        claim_history_id: String,
        user: address,
        amount: u64,
        timestamp: u64
    }

    public fun create_claim_reward_event(
        claim_history_id: String,
        user: address,
        amount: u64,
        timestamp: u64
    ): ClaimRewardEvent {
        ClaimRewardEvent {
            claim_history_id,
            user,
            amount,
            timestamp
        }
    }

    struct ReviewEvent has copy, drop, store {
        review_id: String,
        reviewer: address,
        fee: u64,
        timestamp: u64
    }

    public fun create_review_event(
        review_id: String,
        reviewer: address,
        fee: u64,
        timestamp: u64
    ): ReviewEvent {
        ReviewEvent {
            review_id,
            reviewer,
            fee,
            timestamp
        }
    }

    struct ClaimReviewEvent has copy, drop, store {
        review_id: String,
        reviewer: address,
        fee: u64,
        timestamp: u64
    }

    public fun create_claim_review_event(
        review_id: String,
        reviewer: address,
        fee: u64,
        timestamp: u64
    ): ClaimReviewEvent {
        ClaimReviewEvent {
            review_id,
            reviewer,
            fee,
            timestamp
        }
    }

    struct ClaimAllReviewEvent has copy, drop, store {
        reviewer: address,
        review_ids: vector<String>,
        fee: u64,
        timestamp: u64
    }

    public fun create_claim_all_review_event(
        reviewer: address,
        review_ids: vector<String>,
        fee: u64,
        timestamp: u64
    ): ClaimAllReviewEvent {
        ClaimAllReviewEvent {
            reviewer,
            review_ids,
            fee,
            timestamp
        }
    }
}

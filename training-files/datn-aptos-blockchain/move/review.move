module ecommerce::review {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenId};

    struct ReviewRecords has key {
        records: Table<String, Review>,
        review_ids: vector<String>
    }

    struct Review has drop, store {
        review_id: String,
        reviewer: address,
        amount: u64,
        start_time: u64,
        end_time: u64,
        is_claimed: bool
    }

    /// The review arguments must be non-zero
    const EREVIEW_ARGUMENT_NON_ZERO: u64 = 0;

    /// The review is already existed
    const EREVIEW_ALREADY_EXISTED: u64 = 1;

    /// The review is not found
    const EREVIERW_NOT_FOUND: u64 = 2;

    /// The review is already claimed
    const EREVIEW_ALREADY_CLAIMED: u64 = 3;

    /// The now timestamp is being in duration
    const EREVIEW_IN_DURATION: u64 = 4;

    public fun initialize_review_records(account: &signer) {
        if(!exists<ReviewRecords>(signer::address_of(account))) {
            move_to(account, ReviewRecords {
                records: table::new(),
                review_ids: vector::empty<String>()
            });
        };
    }

    public fun create_review(
        reviewer: &signer,
        review_id: String,
        amount: u64,
        start_time: u64,
        end_time: u64
    ): Review {
        let reviewer_addr = signer::address_of(reviewer);
        assert!(amount > 0, error::invalid_argument(EREVIEW_ARGUMENT_NON_ZERO));
        Review {
            review_id,
            reviewer: reviewer_addr,
            amount,
            start_time,
            end_time,
            is_claimed: false
        }
    }

    public fun create_review_under_user_account(
        reviewer: &signer,
        review_id: String,
        amount: u64,
        start_time: u64,
        duration: u64
    ) acquires ReviewRecords {
        let reviewer_addr = signer::address_of(reviewer);
        initialize_review_records(reviewer);
        let review_records = borrow_global_mut<ReviewRecords>(reviewer_addr);
        assert!(
            !table::contains(&review_records.records, review_id) &&
            !vector::contains(&review_records.review_ids, &review_id),
            error::invalid_argument(EREVIEW_ALREADY_EXISTED)
        );
        let review = create_review(reviewer, review_id, amount, start_time, start_time + duration);
        table::add(&mut review_records.records, review_id, review);
        vector::push_back(&mut review_records.review_ids, review_id);
    }

    public fun claim_review_under_user_account(
        reviewer: &signer,
        review_id: String,
    ): u64 acquires ReviewRecords {
        let reviewer_addr = signer::address_of(reviewer);
        let review_records = borrow_global_mut<ReviewRecords>(reviewer_addr);
        assert!(
            table::contains(&review_records.records, review_id) &&
            vector::contains(&review_records.review_ids, &review_id),
            error::invalid_argument(EREVIERW_NOT_FOUND)
        );
        let review = table::borrow_mut(&mut review_records.records, review_id);
        assert!(!review.is_claimed, error::invalid_argument(EREVIEW_ALREADY_CLAIMED));
        assert!(review.end_time < timestamp::now_microseconds(), error::invalid_argument(EREVIEW_IN_DURATION));
        review.is_claimed = true;
        review.amount
    }

    public fun claim_all_review_product_under_user_account(
        reviewer: &signer
    ): (u64, vector<String>) acquires ReviewRecords {
        let reviewer_addr = signer::address_of(reviewer);
        let review_records = borrow_global_mut<ReviewRecords>(reviewer_addr);
        let idx = 0;
        let reward_amount = 0;
        let review_ids = vector::empty<String>();
        while (idx < vector::length(&review_records.review_ids)) {
            let review_id = *vector::borrow(&review_records.review_ids, idx);
            let review = table::borrow_mut(&mut review_records.records, review_id);
            if (!review.is_claimed && review.end_time < timestamp::now_microseconds()) {
                reward_amount = reward_amount + review.amount;
                review.is_claimed = true;
                vector::push_back(&mut review_ids, review_id);
            };
            idx = idx + 1;
        };
        (reward_amount, review_ids)
    }
}

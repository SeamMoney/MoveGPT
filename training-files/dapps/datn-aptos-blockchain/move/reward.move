module ecommerce::reward {
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenId};

    struct Reward has key {
        balance: u64,
        time_orders: vector<u64>
    }

    /// The max time orders must be greater zero
    const EREWARD_MAX_TIME_ORDER_NON_ZERO: u64 = 0;

    public fun initialize_reward(account: &signer) {
        if(!exists<Reward>(signer::address_of(account))) {
            move_to(account, Reward {
                balance: 0,
                time_orders: vector::empty<u64>()
            });
        };
    }

    public fun add_reward_under_user_account(
        buyer_addr: address,
        reward_numerator: u64,
        reward_denominator: u64,
        amount: u64,
        max_time_orders: u64
    ) acquires Reward {
        assert!(max_time_orders > 0, error::invalid_argument(EREWARD_MAX_TIME_ORDER_NON_ZERO));
        let reward = borrow_global_mut<Reward>(buyer_addr);
        if (vector::length(&reward.time_orders) < max_time_orders) {
            vector::push_back(&mut reward.time_orders, amount);
        };
        if (vector::length(&reward.time_orders) >= max_time_orders) {
            let idx = 0;
            while (idx < vector::length(&reward.time_orders)) {
                reward.balance = reward.balance +
                                    *vector::borrow(&reward.time_orders, idx) *
                                    reward_numerator /
                                    reward_denominator;
                idx = idx + 1;
            };

            if (vector::length(&reward.time_orders) == max_time_orders) {
                reward.time_orders = vector::empty<u64>();
            } else {
                reward.time_orders = vector::singleton(amount);
            };
        };
    }

    public fun claim_reward_under_user_account(buyer: &signer): u64 acquires Reward {
        let buyer_addr = signer::address_of(buyer);
        let reward = borrow_global_mut<Reward>(buyer_addr);
        let balance = reward.balance;
        reward.balance = 0;
        balance
    }
}

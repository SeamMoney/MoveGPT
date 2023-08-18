```rust
// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapFee {
    use aptos_std::type_info::{Self, TypeInfo};
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;

    use bridge::asset::USDC;


    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::WrapperUtil;

    #[test_only]
    use aptos_std::math64;

    const ERROR_ROUTER_SWAP_FEE_MUST_NOT_NEGATIVE: u64 = 1031;
    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;

    /// Event emitted when token swap .
    struct SwapFeeEvent has drop, store {
        /// type info of X type
        x_type_info: TypeInfo,
        /// type info of X type
        y_type_info: TypeInfo,
        signer: address,
        fee_addree: address,
        swap_fee: u128,
        fee_out: u128,
    }

    struct TokenSwapFeeEvent has key, store {
        swap_fee_event: event::EventHandle<SwapFeeEvent>,
    }

    /// Initialize token swap fee
    public fun initialize_token_swap_fee(signer: &signer) {
        init_swap_oper_fee_config(signer);

        move_to(signer, TokenSwapFeeEvent {
            swap_fee_event: account::new_event_handle<SwapFeeEvent>(signer),
        });
    }

    /// init default operation fee config
    public fun init_swap_oper_fee_config(signer: &signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(signer, 10, 60);
    }

    public fun handle_token_swap_fee<X, Y>(signer_address: address, token_x: Coin<X>
    ) acquires TokenSwapFeeEvent {
        intra_handle_token_swap_fee<X, Y, USDC>(signer_address, token_x)
    }


    /// X is token to pay for fee
    fun intra_handle_token_swap_fee<X, Y, FeeToken>(signer_address: address, token_x: Coin<X>
    ) acquires TokenSwapFeeEvent {
        let fee_address = TokenSwapConfig::fee_address();
        let (fee_handle, swap_fee, fee_out);

        // Close fee auto converted to usdt logic
        let auto_convert_switch = TokenSwapConfig::get_fee_auto_convert_switch();
        // the token to pay for fee, is fee token
        if (!auto_convert_switch || WrapperUtil::is_same_token<X, FeeToken>()) {
            (fee_handle, swap_fee, fee_out) = swap_fee_direct_deposit<X, Y>(token_x);
        } else {
            // check [X, FeeToken] token pair exist
            let fee_token_pair_exist = TokenSwap::swap_pair_exists<X, FeeToken>();
            let fee_address_accept_fee_token = coin::is_account_registered<FeeToken>(fee_address);
            if (fee_token_pair_exist && fee_address_accept_fee_token) {
                (fee_handle, swap_fee, fee_out) = swap_fee_swap<X, FeeToken>(token_x);
            }else {
                // if fee address has not accept the token pay for fee, the swap fee will retention in LP pool
                (fee_handle, swap_fee, fee_out) = swap_fee_direct_deposit<X, Y>(token_x);
            };
        };
        if (fee_handle) {
            // fee token and the token to pay for fee compare
            let order = TokenSwap::compare_token<X, Y>();
            assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
            if (order == 1) {
                emit_swap_fee_event<X, Y>(signer_address, swap_fee, fee_out);
            }else {
                emit_swap_fee_event<Y, X>(signer_address, swap_fee, fee_out);
            };
        }
    }


    /// Emit swap fee event
    fun emit_swap_fee_event<X, Y>(
        signer_address: address,
        swap_fee: u128,
        fee_out: u128,
    ) acquires TokenSwapFeeEvent {
        let token_swap_fee_event = borrow_global_mut<TokenSwapFeeEvent>(TokenSwapConfig::admin_address());
        event::emit_event(&mut token_swap_fee_event.swap_fee_event, SwapFeeEvent {
            x_type_info: type_info::type_of<X>(),
            y_type_info: type_info::type_of<Y>(),
            signer: signer_address,
            fee_addree: TokenSwapConfig::fee_address(),
            swap_fee,
            fee_out,
        });
    }

    fun swap_fee_direct_deposit<X, Y>(token_x: Coin<X>): (bool, u128, u128) {
        let fee_address = TokenSwapConfig::fee_address();
        if (coin::is_account_registered<X>(fee_address)) {
            let x_value = WrapperUtil::coin_value(&token_x);
            coin::deposit(fee_address, token_x);
            (true, x_value, x_value)
            //if swap fee deposit to fee address fail, return back to lp pool
        } else {
            let order = TokenSwap::compare_token<X, Y>();
            assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
            if (order == 1) {
                TokenSwap::return_back_to_lp_pool<X, Y>(token_x, coin::zero());
            } else {
                TokenSwap::return_back_to_lp_pool<Y, X>(coin::zero(), token_x);
            };
            (false, 0, 0)
        }
    }

    fun swap_fee_swap<X, FeeToken>(token_x: Coin<X>): (bool, u128, u128) {
        let x_value = WrapperUtil::coin_value(&token_x);
        // just return, not assert error
        if (x_value == 0) {
            coin::destroy_zero(token_x);
            return (false, 0, 0)
        };

        let fee_address = TokenSwapConfig::fee_address();
        let order = TokenSwap::compare_token<X, FeeToken>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, FeeToken>();
        let (reserve_x, reserve_fee) = TokenSwap::get_reserves<X, FeeToken>();
        let fee_out = TokenSwapLibrary::get_amount_out(
            (x_value as u128),
            reserve_x,
            reserve_fee,
            fee_numberator,
            fee_denumerator
        );
        let (token_x_out, token_fee_out);
        let (token_x_fee, token_fee_fee);
        if (order == 1) {
            (token_x_out, token_fee_out, token_x_fee, token_fee_fee) = TokenSwap::swap<X, FeeToken>(
                token_x,
                fee_out,
                coin::zero(),
                0
            );
        } else {
            (token_fee_out, token_x_out, token_fee_fee, token_x_fee) = TokenSwap::swap<FeeToken, X>(
                coin::zero(),
                0,
                token_x,
                fee_out
            );
        };
        coin::destroy_zero(token_x_out);
        coin::deposit(fee_address, token_fee_out);
        coin::destroy_zero(token_fee_fee);
        swap_fee_direct_deposit<X, FeeToken>(token_x_fee);
        (true, x_value, fee_out)
    }

    #[test]
    fun test_get_amount_out_without_fee() {
        let precision_9: u8 = 9;
        let scaling_factor_9 = (math64::pow(10, (precision_9 as u64)) as u128);
        let amount_x: u128 = 1 * scaling_factor_9;
        let reserve_x: u128 = 10000000 * scaling_factor_9;
        let reserve_y: u128 = 100000000 * scaling_factor_9;

        let amount_y = TokenSwapLibrary::get_amount_out_without_fee(amount_x, reserve_x, reserve_y);
        let amount_y_k3_fee = TokenSwapLibrary::get_amount_out(amount_x, reserve_x, reserve_y, 3, 1000);
        assert!(amount_y == 9999999000, 10001);
        assert!(amount_y_k3_fee == 9969999005, 10002);
    }
}
```
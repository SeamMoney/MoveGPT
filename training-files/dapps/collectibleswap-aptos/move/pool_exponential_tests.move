#[test_only]
module collectibleswap::pool_exponential_tests {
    use std::signer;
    use collectibleswap::pool;
    use aptos_framework::coin;

    use std::option;
    use test_coin_admin::test_helpers;
    use test_coin_admin::test_helpers:: {CollectionType1, CollectionType2, CollectionType3, USDC};
    use liquidity_account::liquidity_coin::LiquidityCoin;

    use aptos_framework::genesis;
    const INITIAL_SPOT_PRICE: u64 = 900;
    const CURVE_TYPE: u8 = 1;
    const POOL_TYPE: u8 = 2;
   
    fun prepare(): (signer, signer, signer) {
        genesis::setup();
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();
        let coin_admin = test_helpers::create_admin_with_coins();
        let token_creator = test_helpers::create_token_creator();

        test_helpers::call_initialize_lp_account(&collectibleswap_admin);
        pool::initialize_script(&collectibleswap_admin);
        test_helpers::initialize_collection_registry(&collectibleswap_admin);
        (collectibleswap_admin, coin_admin, token_creator)
    }

    #[test]
    fun test_plus() {
        let admin = test_helpers::create_collectibleswap_admin();
        assert!(signer::address_of(&admin) == @collectibleswap, 1);
    }

    #[test]
    #[expected_failure(abort_code = 1018)]
    fun test_cannot_reinitialize_contract() {
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();

        test_helpers::call_initialize_lp_account(&collectibleswap_admin);
        pool::initialize_script(&collectibleswap_admin);
        pool::initialize_script(&collectibleswap_admin);
    }

    #[test]
    fun test_pool_cap_exist() {
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();

        test_helpers::call_initialize_lp_account(&collectibleswap_admin);
        pool::initialize_script(&collectibleswap_admin);
        assert!(pool::is_pool_cap_initialized(), 1);
        assert!(pool::get_pool_resource_account_address() == @liquidity_account, 2);
    }

    #[test]
    #[expected_failure(abort_code = 3005)]
    fun test_create_new_pool_not_register_collection_type() {
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();

        test_helpers::call_initialize_lp_account(&collectibleswap_admin);
        pool::initialize_script(&collectibleswap_admin);
        let coin_admin = test_helpers::create_admin_with_coins();
        assert!(signer::address_of(&coin_admin) == @test_coin_admin, 1);

        test_helpers::initialize_collection_registry(&collectibleswap_admin);
        test_helpers::create_new_pool<USDC, CollectionType1>(&coin_admin, b"collection1")
    }


    #[test]
    fun test_create_new_pool_success() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        test_helpers::create_new_pool_success<USDC, CollectionType2>(&coin_admin, &token_creator, b"collection2", CURVE_TYPE, POOL_TYPE);
        test_helpers::create_new_pool_success<USDC, CollectionType3>(&coin_admin, &token_creator, b"collection3", CURVE_TYPE, POOL_TYPE)
    }

    #[test]
    #[expected_failure]
    fun pool_already_exist() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        test_helpers::create_new_pool_success<CollectionType1, USDC>(&coin_admin, &token_creator, b"collection2", CURVE_TYPE, POOL_TYPE);
    }

    #[test]
    fun add_liquidity() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        let supply = coin::supply<LiquidityCoin<USDC, CollectionType1>>();
        let liquidity_coin_supply = option::extract(&mut supply);
        assert!(liquidity_coin_supply == 120, 4);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);
    }

    #[test]
    fun remove_liquidity_even() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 120, 4);

        let usdc_balance = coin::balance<USDC>(@test_coin_admin);

        pool::remove_liquidity<USDC, CollectionType1>(&coin_admin, 0, 0, 60);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 60, 4);    
        assert!(usdc_balance + 3600 == coin::balance<USDC>(@test_coin_admin), 4);    
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);
    }

    //withdraw 20% lp
    #[test]
    fun remove_liquidity_uneven1() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 120, 4);

        let usdc_balance = coin::balance<USDC>(@test_coin_admin);

        pool::remove_liquidity<USDC, CollectionType1>(&coin_admin, 0, 0, 24);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 96, 4);    
        assert!(usdc_balance + 1080 == coin::balance<USDC>(@test_coin_admin), 4);

        let  (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _ 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        assert!(reserve_amount == 7200 - 1080, 4);
        assert!(protocol_credit_coin_amount == 0, 4);
        assert!(token_count == 6, 4);
        assert!(spot_price == INITIAL_SPOT_PRICE, 4);  
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);
    }

    // remove 30% liq
    #[test]
    fun remove_liquidity_uneven2() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 120, 4);

        let usdc_balance = coin::balance<USDC>(@test_coin_admin);

        pool::remove_liquidity<USDC, CollectionType1>(&coin_admin, 0, 0, 36);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 84, 4);    
        assert!(usdc_balance + 1620 == coin::balance<USDC>(@test_coin_admin), 4);

        let  (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _ 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        assert!(reserve_amount == 7200 - 1620, 4);
        assert!(protocol_credit_coin_amount == 0, 4);
        assert!(token_count == 5, 4);
        assert!(spot_price == INITIAL_SPOT_PRICE, 4);  

        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);
    }

    // remove 40% liq
    #[test]
    fun remove_liquidity_uneven3() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 120, 4);

        let usdc_balance = coin::balance<USDC>(@test_coin_admin);

        pool::remove_liquidity<USDC, CollectionType1>(&coin_admin, 0, 0, 48);

        assert!(test_helpers::get_lp_supply<USDC, CollectionType1>() == 72, 4);    
        assert!(usdc_balance + 2160 == coin::balance<USDC>(@test_coin_admin), 4);

        let  (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _ 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        assert!(reserve_amount == 7200 - 2160, 4);
        assert!(protocol_credit_coin_amount == 0, 4);
        assert!(token_count == 4, 4);
        assert!(spot_price == INITIAL_SPOT_PRICE, 4);  
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);
    }

    #[test]
    fun test_buy_nfts_1() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_coin_to_any_tokens_script<USDC, CollectionType1>(&coin_admin, 1, 10000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 990 + 14, 4);
        assert!(reserve_amount == 7200 + 990 + 12, 4);
        assert!(token_count == 7, 4);
        assert!(spot_price == 991, 4);
        assert!(protocol_credit_coin_amount == 2, 4);
        assert!(unrealized_fee == 5, 4);
        assert!(accumulated_volume == 990, 4);
        assert!(accumulated_fees == 14, 4);

        balance_before = balance_after;
        // swap
        pool::swap_coin_to_any_tokens_script<USDC, CollectionType1>(&coin_admin, 1, 10000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 1106, 4);
        assert!(reserve_amount == 7200 + 990 + 12 + 1103, 4);
        assert!(token_count == 6, 4);
        assert!(spot_price == 1093, 4);
        assert!(protocol_credit_coin_amount == 5, 4);
        assert!(unrealized_fee == 0, 4);
        assert!(accumulated_volume == 2080, 4);
        assert!(accumulated_fees == 30, 4);
    }

    #[test]
    fun test_sell_nfts_1() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", test_helpers::get_token_names(9, 11));

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_tokens_to_coin_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(9, 10), 0, 0);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_after == balance_before + 887, 4);
        assert!(reserve_amount == 7200 - INITIAL_SPOT_PRICE + 11, 4);
        assert!(token_count == 9, 4);
        assert!(spot_price == 818 + 1, 4);
        assert!(protocol_credit_coin_amount == 2, 4);
        assert!(unrealized_fee == 2, 4);
        assert!(accumulated_volume == 900, 4);
        assert!(accumulated_fees == 13, 4);

        balance_before = balance_after;
        // swap
        pool::swap_tokens_to_coin_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(10, 11), 0, 0);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_after == balance_before + 807, 4);
        assert!(reserve_amount == 7200 - INITIAL_SPOT_PRICE + 11 - 819 + 10, 4);
        assert!(token_count == 10, 4);
        assert!(spot_price == 744 + 1, 4);
        assert!(protocol_credit_coin_amount == 4, 4);
        assert!(unrealized_fee == 2, 4);
        assert!(accumulated_volume == 900 + 819, 4);
        assert!(accumulated_fees == 25, 4);
    }

    #[test]
    fun test_buy_nfts_multi() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_coin_to_any_tokens_script<USDC, CollectionType1>(&coin_admin, 2, 10000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 2110, 4);
        assert!(reserve_amount == 7200 + 990 + 12 + 1103, 4);
        assert!(token_count == 6, 4);
        assert!(spot_price == 1093, 4);
        assert!(protocol_credit_coin_amount == 5, 4);
        assert!(unrealized_fee == 0, 4);
        assert!(accumulated_volume == 2080, 4);
        assert!(accumulated_fees == 30, 4);
    }

    #[test]
    fun test_sell_nfts_multi() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", test_helpers::get_token_names(9, 11));

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_tokens_to_coin_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(9, 11), 0, 0);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        
        assert!(balance_after == balance_before + 887 + 807, 4);
        assert!(reserve_amount == 7200 - INITIAL_SPOT_PRICE + 11 - 819 + 10, 4);
        assert!(token_count == 10, 4);
        assert!(spot_price == 744 + 1, 4);
        assert!(protocol_credit_coin_amount == 4, 4);
        assert!(unrealized_fee == 2, 4);
        assert!(accumulated_volume == 900 + 819, 4);
        assert!(accumulated_fees == 25, 4);
    }

    #[test]
    fun test_buy_nfts_specific_tokens_1() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_coin_to_specific_tokens_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(5, 6), 0, 1000000000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 990 + 14, 4);
        assert!(reserve_amount == 7200 + 990 + 12, 4);
        assert!(token_count == 7, 4);
        assert!(spot_price == 991, 4);
        assert!(protocol_credit_coin_amount == 2, 4);
        assert!(unrealized_fee == 5, 4);
        assert!(accumulated_volume == 990, 4);
        assert!(accumulated_fees == 14, 4);

        balance_before = balance_after;
        // swap
        pool::swap_coin_to_specific_tokens_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(6, 7), 0, 1000000000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 1106, 4);
        assert!(reserve_amount == 7200 + 990 + 12 + 1103, 4);
        assert!(token_count == 6, 4);
        assert!(spot_price == 1093, 4);
        assert!(protocol_credit_coin_amount == 5, 4);
        assert!(unrealized_fee == 0, 4);
        assert!(accumulated_volume == 2080, 4);
        assert!(accumulated_fees == 30, 4);
    }

    #[test]
    fun test_buy_nfts_specific_tokens_multi() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);

        let balance_before = coin::balance<USDC>(@test_coin_admin);
        // swap
        pool::swap_coin_to_specific_tokens_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(5, 7), 0, 10000000);
        assert!(pool::check_pool_valid<USDC, CollectionType1>(), 4);

        let (
            reserve_amount, 
            protocol_credit_coin_amount, 
            _, 
            _, 
            token_count, 
            _, 
            _,
            spot_price,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            accumulated_volume,
            accumulated_fees,
            unrealized_fee 
        ) = pool::get_pool_info<USDC, CollectionType1>();

        let balance_after = coin::balance<USDC>(@test_coin_admin);
        assert!(balance_before == balance_after + 2110, 4);
        assert!(reserve_amount == 7200 + 990 + 12 + 1103, 4);
        assert!(token_count == 6, 4);
        assert!(spot_price == 1093, 4);
        assert!(protocol_credit_coin_amount == 5, 4);
        assert!(unrealized_fee == 0, 4);
        assert!(accumulated_volume == 2080, 4);
        assert!(accumulated_fees == 30, 4);
    }

    #[test]
    #[expected_failure]
    fun test_swap_failed_with_invalid_token() {
        let (_, coin_admin, token_creator) = prepare();

        test_helpers::create_new_pool_success<USDC, CollectionType1>(&coin_admin, &token_creator, b"collection1", CURVE_TYPE, POOL_TYPE);
        
        let token_names = test_helpers::get_token_names(5, 9);
        test_helpers::mint_tokens(&token_creator, &coin_admin, b"collection1", token_names);

        pool::add_liquidity_script<USDC, CollectionType1>(&coin_admin, 1000000, token_names, 0);
        pool::swap_coin_to_specific_tokens_script<USDC, CollectionType1>(&coin_admin, test_helpers::get_token_names(9, 10), 0, 10000000);
    }
}

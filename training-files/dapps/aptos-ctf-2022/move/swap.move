/// Uniswap v2 like coin swap program
module ctfmovement::swap {
    use std::signer;
    use std::option;
    use std::string;

    use aptos_framework::coin;
    use aptos_framework::account;

    use ctfmovement::math;
    use ctfmovement::swap_utils;
    use ctfmovement::simple_coin::{Self, SimpleCoin, TestUSDC};
    
    friend ctfmovement::router;

    const ADMIN: address = @ctfmovement;
    const MINIMUM_LIQUIDITY: u128 = 1000;

    // List of errors
    const ERROR_ALREADY_INITIALIZED: u64 = 1;
    const ERROR_INSUFFICIENT_LIQUIDITY_MINTED: u64 = 2;
    const ERROR_INSUFFICIENT_AMOUNT: u64 = 3;
    const ERROR_INSUFFICIENT_LIQUIDITY: u64 = 4;
    const ERROR_INVALID_AMOUNT: u64 = 5;
    const ERROR_INSUFFICIENT_LIQUIDITY_BURNED: u64 = 6;
    const ERROR_INSUFFICIENT_OUTPUT_AMOUNT: u64 = 7;
    const ERROR_NOT_ADMIN: u64 = 8;
    const ERROR_NOT_FEE_TO: u64 = 9;

    /// The LP Coin type
    struct LPCoin<phantom X, phantom Y> has key {}

    /// Stores the metadata required for the coin pairs
    struct Pool<phantom X, phantom Y> has key {
        /// The admin of the coin pair
        creator: address,
        /// T0 coin balance
        reserve_x: coin::Coin<X>,
        /// T1 coin balance
        reserve_y: coin::Coin<Y>,
        /// T0 fee
        fee_x: coin::Coin<X>,
        /// T1 fee
        fee_y: coin::Coin<Y>,
        /// Mint capacity of LP Coin
        mint_cap: coin::MintCapability<LPCoin<X, Y>>,
        /// Burn capacity of LP Coin
        burn_cap: coin::BurnCapability<LPCoin<X, Y>>,
        /// Freeze capacity of LP Coin
        freeze_cap: coin::FreezeCapability<LPCoin<X, Y>>,
    }

    struct WithdrawFeeCap has key, store, copy, drop {}

    struct SwapMeta has key {
        signer_cap: account::SignerCapability,
        resource_address: address,
        admin: address,
    }

    fun init_module(sender: &signer)  acquires SwapMeta, Pool {
        assert!(signer::address_of(sender) == ADMIN, ERROR_NOT_ADMIN);
        let (_resource_signer, resource_signer_cap) = account::create_resource_account(sender, b"simple");
        let resource_address = account::get_signer_capability_address(&resource_signer_cap);
        move_to(sender, SwapMeta {
            signer_cap: resource_signer_cap,
            resource_address,
            admin: ADMIN,
        });
        move_to(sender, WithdrawFeeCap{});

        simple_coin::init(sender);
        let simple_coin = simple_coin::mint<SimpleCoin>((math::pow(10u128, 10u8) as u64));
        let test_usdc = simple_coin::mint<TestUSDC>((math::pow(10u128, 10u8) as u64));

        if (swap_utils::sort_token_type<SimpleCoin, TestUSDC>()) {
            create_pair<SimpleCoin, TestUSDC>(sender);
            let (_, _, lp, left_x, left_y) = add_liquidity_direct<SimpleCoin, TestUSDC>(simple_coin, test_usdc);
            coin::deposit(signer::address_of(sender), lp);
            coin::destroy_zero(left_x);
            coin::destroy_zero(left_y);
        } else {
            create_pair<TestUSDC, SimpleCoin>(sender);
            let (_, _, lp, left_x, left_y) = add_liquidity_direct<TestUSDC, SimpleCoin>(test_usdc, simple_coin);
            coin::deposit(signer::address_of(sender), lp);
            coin::destroy_zero(left_x);
            coin::destroy_zero(left_y);
        }
    }

    /// Create the specified coin pair
    public fun create_pair<X, Y>(
        sender: &signer,
    ) acquires SwapMeta {
        assert!(!is_pair_created<X, Y>(), ERROR_ALREADY_INITIALIZED);

        let sender_addr = signer::address_of(sender);
        let swap_info = borrow_global_mut<SwapMeta>(ADMIN);
        let resource_signer = account::create_signer_with_capability(&swap_info.signer_cap);

        // now we init the LP coin
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LPCoin<X, Y>>(
            sender,
            string::utf8(b"SimpleLP"),
            string::utf8(b"SimpleLP"),
            8,
            true
        );

        move_to<Pool<X, Y>>(
            &resource_signer,
            Pool {
                creator: sender_addr,
                reserve_x: coin::zero<X>(),
                reserve_y: coin::zero<Y>(),
                fee_x: coin::zero<X>(),
                fee_y: coin::zero<Y>(),
                mint_cap,
                burn_cap,
                freeze_cap,
            }
        );

        coin::register<LPCoin<X, Y>>(sender);
    }

    public fun resource_address(): address acquires SwapMeta {
        let swap_info = borrow_global_mut<SwapMeta>(ADMIN);
        let resource_addr = swap_info.resource_address;
        resource_addr
    }

    public fun is_pair_created<X, Y>(): bool acquires SwapMeta {
        let resource_addr = resource_address();
        exists<Pool<X, Y>>(resource_addr)
    }

    /// Get the total supply of LP Tokens
    public fun total_lp_supply<X, Y>(): u128 {
        option::get_with_default(
            &coin::supply<LPCoin<X, Y>>(),
            0u128
        )
    }

    /// Get the current reserves of T0 and T1 with the latest updated timestamp
    public fun pool_reserves<X, Y>(): (u64, u64) acquires Pool, SwapMeta {
        let pool = borrow_global<Pool<X, Y>>(resource_address());
        (
            coin::value(&pool.reserve_x),
            coin::value(&pool.reserve_y),
        )
    }

    public fun check_or_register_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            coin::register<X>(sender);
        };
    }

    public fun add_liquidity<X, Y>(
        sender: &signer,
        amount_x: u64,
        amount_y: u64
    ): (u64, u64, u64) acquires Pool, SwapMeta {
        let (a_x, a_y, coin_lp, coin_left_x, coin_left_y) = add_liquidity_direct(coin::withdraw<X>(sender, amount_x), coin::withdraw<Y>(sender, amount_y));
        let sender_addr = signer::address_of(sender);
        let lp_amount = coin::value(&coin_lp);
        assert!(lp_amount > 0, ERROR_INSUFFICIENT_LIQUIDITY);
        check_or_register_coin_store<LPCoin<X, Y>>(sender);
        coin::deposit(sender_addr, coin_lp);
        coin::deposit(sender_addr, coin_left_x);
        coin::deposit(sender_addr, coin_left_y);

        (a_x, a_y, lp_amount)
    }

    fun add_liquidity_direct<X, Y>(
        x: coin::Coin<X>,
        y: coin::Coin<Y>,
    ): (u64, u64, coin::Coin<LPCoin<X, Y>>, coin::Coin<X>, coin::Coin<Y>) acquires Pool, SwapMeta {
        let amount_x = coin::value(&x);
        let amount_y = coin::value(&y);
        let (reserve_x, reserve_y) = pool_reserves<X, Y>();
        let (a_x, a_y) = if (reserve_x == 0 && reserve_y == 0) {
            (amount_x, amount_y)
        } else {
            let amount_y_optimal = swap_utils::quote(amount_x, reserve_x, reserve_y);
            if (amount_y_optimal <= amount_y) {
                (amount_x, amount_y_optimal)
            } else {
                let amount_x_optimal = swap_utils::quote(amount_y, reserve_y, reserve_x);
                assert!(amount_x_optimal <= amount_x, ERROR_INVALID_AMOUNT);
                (amount_x_optimal, amount_y)
            }
        };

        assert!(a_x <= amount_x, ERROR_INSUFFICIENT_AMOUNT);
        assert!(a_y <= amount_y, ERROR_INSUFFICIENT_AMOUNT);

        let left_x = coin::extract(&mut x, amount_x - a_x);
        let left_y = coin::extract(&mut y, amount_y - a_y);
        deposit_x<X, Y>(x);
        deposit_y<X, Y>(y);
        let lp = mint<X, Y>(a_x, a_y);
        (a_x, a_y, lp, left_x, left_y)
    }

    /// Remove liquidity to coin types.
    public fun remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
    ): (u64, u64) acquires Pool, SwapMeta {
        let coins = coin::withdraw<LPCoin<X, Y>>(sender, liquidity);
        let (coins_x, coins_y) = remove_liquidity_direct<X, Y>(coins);
        let amount_x = coin::value(&coins_x);
        let amount_y = coin::value(&coins_y);
        check_or_register_coin_store<X>(sender);
        check_or_register_coin_store<Y>(sender);
        let sender_addr = signer::address_of(sender);
        coin::deposit<X>(sender_addr, coins_x);
        coin::deposit<Y>(sender_addr, coins_y);
        (amount_x, amount_y)
    }

    /// Remove liquidity to coin types.
    fun remove_liquidity_direct<X, Y>(
        liquidity: coin::Coin<LPCoin<X, Y>>,
    ): (coin::Coin<X>, coin::Coin<Y>) acquires Pool, SwapMeta {
        burn<X, Y>(liquidity)
    }

    /// Swap X to Y, X is in and Y is out. This method assumes amount_out_min is 0
    public fun swap_exact_x_to_y<X, Y>(
        sender: &signer,
        amount_in: u64,
        to: address
    ): u64 acquires Pool, SwapMeta {
        let (fee_num, fee_den) = swap_utils::fee();
        let coins = coin::withdraw<X>(sender, amount_in);
        let fee_amount = fee_num * (coin::value(&coins) as u128) / fee_den;
        let fee_x = coin::extract(&mut coins, (fee_amount as u64));
        deposit_fee_x<X, Y>(fee_x);
        let (coins_y_out, reward) = swap_exact_x_to_y_direct<X, Y>(coins);
        let fee_amount = fee_num * (coin::value(&coins_y_out) as u128) / fee_den;
        let fee_y = coin::extract(&mut coins_y_out, (fee_amount as u64));
        deposit_fee_y<X, Y>(fee_y);
        let amount_out = coin::value(&coins_y_out);
        check_or_register_coin_store<Y>(sender);
        coin::deposit(to, coins_y_out);
        if (coin::value(&reward) > 0) {
            check_or_register_coin_store<SimpleCoin>(sender);
            coin::deposit(signer::address_of(sender), reward);
        } else {
            coin::destroy_zero(reward);
        };
        amount_out
    }

    /// Swap X to Y, X is in and Y is out. This method assumes amount_out_min is 0
    public fun swap_exact_x_to_y_direct<X, Y>(
        coins_in: coin::Coin<X>
    ): (coin::Coin<Y>, coin::Coin<SimpleCoin>) acquires Pool, SwapMeta {
        let amount_in = coin::value<X>(&coins_in);
        deposit_x<X, Y>(coins_in);
        let (rin, rout) = pool_reserves<X, Y>();
        let amount_out = swap_utils::get_amount_out_no_fee(amount_in, rin, rout);
        let (coins_x_out, coins_y_out) = swap<X, Y>(0, amount_out);
        assert!(coin::value<X>(&coins_x_out) == 0, ERROR_INSUFFICIENT_OUTPUT_AMOUNT);
        coin::destroy_zero(coins_x_out);

        let reward = if (swap_utils::is_simple_coin<Y>()) {
            let (reward_num, reward_den) = swap_utils::reward();
            simple_coin::mint<SimpleCoin>((((amount_out as u128) * reward_num / reward_den) as u64))
        } else {
            coin::zero<SimpleCoin>()
        };
        (coins_y_out, reward)
    }

    /// Swap Y to X, Y is in and X is out. This method assumes amount_out_min is 0
    public fun swap_exact_y_to_x<X, Y>(
        sender: &signer,
        amount_in: u64,
        to: address
    ): u64 acquires Pool, SwapMeta {
        let (fee_num, fee_den) = swap_utils::fee();
        let coins = coin::withdraw<Y>(sender, amount_in);
        let fee_amount = ((fee_num * (coin::value(&coins) as u128) / fee_den) as u64);
        let fee_y = coin::extract(&mut coins, fee_amount);
        deposit_fee_y<X, Y>(fee_y);
        let (coins_x_out, reward) = swap_exact_y_to_x_direct<X, Y>(coins);
        let fee_amount = ((fee_num * (coin::value(&coins_x_out) as u128) / fee_den) as u64);
        let fee_x = coin::extract(&mut coins_x_out, (fee_amount as u64));
        deposit_fee_x<X, Y>(fee_x);
        let amount_out = coin::value<X>(&coins_x_out);
        check_or_register_coin_store<X>(sender);
        coin::deposit(to, coins_x_out);
        if (coin::value(&reward) > 0) {
            check_or_register_coin_store<SimpleCoin>(sender);
            coin::deposit(signer::address_of(sender), reward);
        } else {
            coin::destroy_zero(reward);
        };
        amount_out
    }

    /// Swap Y to X, Y is in and X is out. This method assumes amount_out_min is 0
    public fun swap_exact_y_to_x_direct<X, Y>(
        coins_in: coin::Coin<Y>,
    ): (coin::Coin<X>, coin::Coin<SimpleCoin>) acquires Pool, SwapMeta {
        let amount_in = coin::value<Y>(&coins_in);
        deposit_y<X, Y>(coins_in);
        let (rout, rin) = pool_reserves<X, Y>();
        let amount_out = swap_utils::get_amount_out_no_fee(amount_in, rin, rout);
        let (coins_x_out, coins_y_out) = swap<X, Y>(amount_out, 0);
        assert!(coin::value<Y>(&coins_y_out) == 0, ERROR_INSUFFICIENT_OUTPUT_AMOUNT);
        coin::destroy_zero(coins_y_out);
        let reward = if (swap_utils::is_simple_coin<X>()) {
            let (reward_num, reward_den) = swap_utils::reward();
            simple_coin::mint<SimpleCoin>((((amount_out as u128) * reward_num / reward_den) as u64))
        } else {
            coin::zero<SimpleCoin>()
        };
        (coins_x_out, reward)
    }

    fun swap<X, Y>(
        amount_x_out: u64,
        amount_y_out: u64
    ): (coin::Coin<X>, coin::Coin<Y>) acquires Pool, SwapMeta {
        assert!(amount_x_out > 0 || amount_y_out > 0, ERROR_INSUFFICIENT_OUTPUT_AMOUNT);

        let (reserve_x, reserve_y) = pool_reserves<X, Y>();
        assert!(amount_x_out < reserve_x && amount_y_out < reserve_y, ERROR_INSUFFICIENT_LIQUIDITY);

        let metadata = borrow_global_mut<Pool<X, Y>>(resource_address());

        let coins_x_out = coin::zero<X>();
        let coins_y_out = coin::zero<Y>();
        if (amount_x_out > 0) coin::merge(&mut coins_x_out, extract_x(amount_x_out, metadata));
        if (amount_y_out > 0) coin::merge(&mut coins_y_out, extract_y(amount_y_out, metadata));

        (coins_x_out, coins_y_out)
    }

    /// Mint LP Coin.
    /// This low-level function should be called from a contract which performs important safety checks
    fun mint<X, Y>(amount_x: u64, amount_y: u64): coin::Coin<LPCoin<X, Y>> acquires Pool, SwapMeta {
        let pool = borrow_global_mut<Pool<X, Y>>(resource_address());
        let (reserve_x, reserve_y) = (coin::value(&pool.reserve_x), coin::value(&pool.reserve_y));

        let amount_x = (amount_x as u128);
        let amount_y = (amount_y as u128);
        //Need to add fee amount which have not been mint.
        let total_supply = total_lp_supply<X, Y>();
        let liquidity = if (total_supply == 0u128) {
            let liquidity = math::sqrt(amount_x * amount_y);
            assert!(liquidity > 0u128, ERROR_INSUFFICIENT_LIQUIDITY_MINTED);
            liquidity
        } else {
            let liquidity = math::min(amount_x * total_supply / (reserve_x as u128), amount_y * total_supply / (reserve_y as u128));
            assert!(liquidity > 0u128, ERROR_INSUFFICIENT_LIQUIDITY_MINTED);
            liquidity
        };


        let lp = mint_lp<X, Y>((liquidity as u64), &pool.mint_cap);
        lp
    }

    fun burn<X, Y>(lp_tokens: coin::Coin<LPCoin<X, Y>>): (coin::Coin<X>, coin::Coin<Y>) acquires Pool, SwapMeta {
        let metadata = borrow_global_mut<Pool<X, Y>>(resource_address());
        let (reserve_x, reserve_y) = (coin::value(&metadata.reserve_x), coin::value(&metadata.reserve_y));
        let liquidity = coin::value(&lp_tokens);

        //Need to add fee amount which have not been mint.
        let total_lp_supply = total_lp_supply<X, Y>();
        let amount_x = ((reserve_x as u128) * (liquidity as u128) / (total_lp_supply as u128) as u64);
        let amount_y = ((reserve_y as u128) * (liquidity as u128) / (total_lp_supply as u128) as u64);
        assert!(amount_x > 0 && amount_y > 0, ERROR_INSUFFICIENT_LIQUIDITY_BURNED);

        coin::burn<LPCoin<X, Y>>(lp_tokens, &metadata.burn_cap);

        let w_x = extract_x((amount_x as u64), metadata);
        let w_y = extract_y((amount_y as u64), metadata);

        (w_x, w_y)
    }

    /// Mint LP Tokens to account
    fun mint_lp<X, Y>(amount: u64, mint_cap: &coin::MintCapability<LPCoin<X, Y>>): coin::Coin<LPCoin<X, Y>> {
        coin::mint<LPCoin<X, Y>>(amount, mint_cap)
    }

    public fun deposit_x<X, Y>(amount: coin::Coin<X>) acquires Pool, SwapMeta {
        let metadata =
            borrow_global_mut<Pool<X, Y>>(resource_address());
        coin::merge(&mut metadata.reserve_x, amount);
    }

    public fun deposit_y<X, Y>(amount: coin::Coin<Y>) acquires Pool, SwapMeta {
        let metadata =
            borrow_global_mut<Pool<X, Y>>(resource_address());
        coin::merge(&mut metadata.reserve_y, amount);
    }

    public fun deposit_fee_x<X, Y>(fee: coin::Coin<X>) acquires Pool, SwapMeta {
        let metadata =
            borrow_global_mut<Pool<X, Y>>(resource_address());
        coin::merge(&mut metadata.fee_x, fee);
    }

    public fun deposit_fee_y<X, Y>(fee: coin::Coin<Y>) acquires Pool, SwapMeta {
        let metadata =
            borrow_global_mut<Pool<X, Y>>(resource_address());
        coin::merge(&mut metadata.fee_y, fee);
    }

    /// Extract `amount` from this contract
    fun extract_x<X, Y>(amount: u64, metadata: &mut Pool<X, Y>): coin::Coin<X> {
        assert!(coin::value<X>(&metadata.reserve_x) > amount, ERROR_INSUFFICIENT_AMOUNT);
        coin::extract(&mut metadata.reserve_x, amount)
    }

    /// Extract `amount` from this contract
    fun extract_y<X, Y>(amount: u64, metadata: &mut Pool<X, Y>): coin::Coin<Y> {
        assert!(coin::value<Y>(&metadata.reserve_y) > amount, ERROR_INSUFFICIENT_AMOUNT);
        coin::extract(&mut metadata.reserve_y, amount)
    }

    public entry fun set_admin(sender: &signer, new_admin: address) acquires SwapMeta {
        let sender_addr = signer::address_of(sender);
        let swap_info = borrow_global_mut<SwapMeta>(ADMIN);
        assert!(sender_addr == swap_info.admin, ERROR_NOT_ADMIN);
        swap_info.admin = new_admin;
    }

    public fun fee_amount<X, Y>(): (u64, u64) acquires Pool, SwapMeta {
        let pool = borrow_global_mut<Pool<X, Y>>(resource_address());
        (coin::value(&pool.fee_x), coin::value(&pool.fee_y))
    }

    public entry fun withdraw_fee<X, Y>(sender: &signer) acquires Pool, SwapMeta {
        let sender_addr = signer::address_of(sender);
        assert!(exists<WithdrawFeeCap>(sender_addr), ERROR_NOT_FEE_TO);
        if (swap_utils::sort_token_type<X, Y>()) {
            let pool = borrow_global_mut<Pool<X, Y>>(resource_address());
            if (coin::value(&pool.fee_x) > 0) {
                let coin = coin::extract_all(&mut pool.fee_x);
                check_or_register_coin_store<X>(sender);
                coin::deposit(sender_addr, coin);
            };
            if (coin::value(&pool.fee_y) > 0) {
                let coin = coin::extract_all(&mut pool.fee_y);
                check_or_register_coin_store<Y>(sender);
                coin::deposit(sender_addr, coin);
            };
        } else {
            let pool = borrow_global_mut<Pool<Y, X>>(resource_address());
            if (coin::value(&pool.fee_x) > 0) {
                let coin = coin::extract_all(&mut pool.fee_x);
                check_or_register_coin_store<X>(sender);
                coin::deposit(sender_addr, coin);
            };
            if (coin::value(&pool.fee_y) > 0) {
                let coin = coin::extract_all(&mut pool.fee_y);
                check_or_register_coin_store<Y>(sender);
                coin::deposit(sender_addr, coin);
            };
        };
    }

    #[test_only]
    public fun initialize(sender: &signer) acquires SwapMeta, Pool {
        init_module(sender);
    }
}

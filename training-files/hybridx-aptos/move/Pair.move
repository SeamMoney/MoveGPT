module HybridX::Pair {
    use aptos_framework::coin;
    use aptos_std::type_info::{TypeInfo, type_of};
    use aptos_std::event;
    use HybridX::Config;
    use aptos_std::comparator::{compare, is_equal, is_smaller_than};
    use std::string;
    use std::signer;
    use aptos_framework::managed_coin::register;
    use HybridX::OpenTable::{Self, OpenTable};

    const EQUAL: u8 = 0;
    const SMALLER: u8 = 1;
    const GREATER: u8 = 2;

    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;
    const ERROR_SWAP_INVALID_PARAMETER: u64 = 2001;
    const ERROR_SWAP_TOKEN_INSUFFICIENT: u64 = 2002;
    const ERROR_SWAP_DUPLICATE_TOKEN: u64 = 2003;
    const ERROR_SWAP_BURN_CALC_INVALID: u64 = 2004;
    const ERROR_SWAP_SWAPOUT_CALC_INVALID: u64 = 2005;
    const ERROR_SWAP_PRIVILEGE_INSUFFICIENT: u64 = 2006;
    const ERROR_SWAP_ADDLIQUIDITY_INVALID: u64 = 2007;
    const ERROR_SWAP_TOKEN_NOT_EXISTS: u64 = 2008;
    const ERROR_SWAP_TOKEN_FEE_INVALID: u64 = 2009;
    const ERROR_SWAP_ADMIN_NOT_INIT: u64 = 2010;
    const ERROR_SWAP_PAIR_NOT_REGISTER: u64 = 2011;
    const ERROR_SWAP_PAIR_ALREADY_REGISTER: u64 = 2012;

    const LIQUIDITY_COIN_SCALE: u64 = 9;
    const LIQUIDITY_COIN_NAME: vector<u8> = b"hybridx liquidity coin";
    const LIQUIDITY_COIN_SYMBOL: vector<u8> = b"LPC";

    struct LiquidityCoin<phantom coin_x, phantom coin_y> has key, store, copy, drop {}

    struct LiquidityCoinCapability<phantom coin_x, phantom coin_y> has key, store {
        mint: coin::MintCapability<LiquidityCoin<coin_x, coin_y>>,
        burn: coin::BurnCapability<LiquidityCoin<coin_x, coin_y>>
    }

    struct Pair has key, store {
        creater: address,
        coin_x_reserve: u64,
        coin_y_reserve: u64,
        last_block_timestamp: u64,
        last_price_x_cumulative: u128,
        last_price_y_cumulative: u128,
        last_k: u128
    }

    struct PairRegisterEvent has drop, store {
        coin_x_type: TypeInfo,
        coin_y_type: TypeInfo,
        signer: address
    }

    struct AddLiquidityEvent has drop, store {
        liquidity: u64,
        coin_x_type: TypeInfo,
        coin_y_type: TypeInfo,
        signer: address,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64
    }

    struct RemoveLiquidityEvent has drop, store {
        liquidity: u64,
        coin_x_type: TypeInfo,
        coin_y_type: TypeInfo,
        signer: address,
        amount_x_min: u64,
        amount_y_min: u64
    }

    struct SwapEvent has drop, store {
        coin_in: TypeInfo,
        coin_out: TypeInfo,
        signer: address,
        amount_in: u64,
        amount_out: u64
    }

    struct LiquidityEventHandle has key, store {
        register_pair_event: event::EventHandle<PairRegisterEvent>,
        add_liquidity_event: event::EventHandle<AddLiquidityEvent>,
        remove_liquidity_event: event::EventHandle<RemoveLiquidityEvent>,
        swap_event: event::EventHandle<SwapEvent>
    }

    struct PairKey has key, copy, store, drop {
        x_type: TypeInfo,
        y_type: TypeInfo
    }

    struct PairTable has key, store {
        pairs: OpenTable<PairKey, Pair>
    }

    public fun assert_is_coin<TypeInfo: store>(): bool {
        assert!(coin::is_coin_initialized<TypeInfo>(), ERROR_SWAP_TOKEN_NOT_EXISTS);
        true
    }

    public fun compare_coin<X: copy + drop + store, Y: copy + drop + store>(): u8 {
        let x_type = type_of<X>();
        let y_type = type_of<Y>();
        let result = compare<TypeInfo>(&x_type, &y_type);
        if (is_equal(&result)) {
            EQUAL
        } else if (is_smaller_than(&result)) {
            SMALLER
        } else {
            GREATER
        }
    }

    public fun admin_init(signer: &signer) {
        Config::assert_admin(signer);
        let admin = signer::address_of(signer);
        if (!exists<LiquidityEventHandle>(admin)) {
            move_to(signer, LiquidityEventHandle {
                add_liquidity_event: event::new_event_handle<AddLiquidityEvent>(signer),
                remove_liquidity_event: event::new_event_handle<RemoveLiquidityEvent>(signer),
                swap_event: event::new_event_handle<SwapEvent>(signer),
                register_pair_event: event::new_event_handle<PairRegisterEvent>(signer),
            });
        };
    }

    public fun is_admin_init() : bool {
        let admin = Config::admin_address();
        exists<LiquidityEventHandle>(admin) && exists<PairTable>(admin)
    }

    public fun init_pair_map<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) acquires PairTable {
        let admin = Config::admin_address();
        assert!(is_admin_init(), ERROR_SWAP_ADMIN_NOT_INIT);

        let pair_key = PairKey{
            x_type: type_of<X>(),
            y_type: type_of<Y>()
        };

        let pair_table = borrow_global_mut<PairTable>(admin);
        if (OpenTable::contains(&pair_table.pairs, pair_key)) {
            OpenTable::add(&mut pair_table.pairs, pair_key, new_pair(signer::address_of(signer)));
        };
    }

    public entry fun user_register_pair<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) {
        register<X>(signer);
        register<Y>(signer);
        register<LiquidityCoin<X, Y>>(signer);
    }

    fun new_pair(creater: address): Pair {
        Pair {
            creater,
            coin_x_reserve: 0u64,
            coin_y_reserve: 0u64,
            last_block_timestamp: 0u64,
            last_price_x_cumulative: 0u128,
            last_price_y_cumulative: 0u128,
            last_k: 0u128
        }
    }

    fun register_liquidity_coin<X: copy + drop + store, Y: copy + drop + store>(account: &signer) {
        user_register_pair<X, Y>(account);
        let (mint_capability, burn_capability) =
            coin::initialize<LiquidityCoin<X, Y>>(
                account,
                string::utf8(LIQUIDITY_COIN_NAME),
                string::utf8(LIQUIDITY_COIN_SYMBOL),
                LIQUIDITY_COIN_SCALE,
                false
            );

        move_to(account, LiquidityCoinCapability<X, Y>{mint: mint_capability, burn: burn_capability});
    }

    public fun register_pair<X: copy + drop + store, Y: copy + drop + store>(signer: &signer)
    acquires LiquidityEventHandle, PairTable {
        assert_is_coin<X>();
        assert_is_coin<Y>();

        let result = compare_coin<X, Y>();
        assert!(result == SMALLER, ERROR_SWAP_INVALID_TOKEN_PAIR);

        register_liquidity_coin<X, Y>(signer);

        init_pair_map<X, Y>(signer);

        let event_handle = borrow_global_mut<LiquidityEventHandle>(Config::admin_address());
        event::emit_event(&mut event_handle.register_pair_event, PairRegisterEvent {
            coin_x_type: type_of<X>(),
            coin_y_type: type_of<Y>(),
            signer: signer::address_of(signer)
        });
    }
}

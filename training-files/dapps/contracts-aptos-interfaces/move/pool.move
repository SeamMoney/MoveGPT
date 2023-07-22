
module samm::pool {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::timestamp;
    use aptos_std::type_info;

    use std::vector;
    use std::bcs;

    use samm::i64::{Self, I64};

    /// ERROR CODE
    const ERR_WRONG_PAIR_ORDERING: u64 = 100;
    const ERR_POOL_EXISTS_FOR_PAIR: u64 = 101;
    const ERR_NOT_ENOUGH_INITIAL_LIQUIDITY: u64 = 102;
    const ERR_NOT_ENOUGH_LIQUIDITY: u64 = 103;
    const ERR_EMPTY_COIN_IN: u64 = 104;
    const ERR_INCORRECT_SWAP: u64 = 105;
    const ERR_INCORRECT_BURN_VALUES: u64 = 106;
    const ERR_POOL_DOES_NOT_EXIST: u64 = 107;
    const ERR_INVALID_CURVE: u64 = 108;
    const ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE: u64 = 109;
    const ERR_EMPTY_COIN_LOAN: u64 = 110;
    /// When pool is locked.
    const ERR_POOL_IS_LOCKED: u64 = 111;
    const ERR_INSUFFICIENT_PERMISSION: u64 = 112;
    const ERR_INSUFFICIENT_0_AMOUNT: u64 = 113;
    const ERR_INSUFFICIENT_1_AMOUNT: u64 = 114;
    const ERR_WRONG_AMOUNT: u64 = 115;
    const ERR_WRONG_RESERVE: u64 = 116;
    const ERR_OVERLIMIT_0: u64 = 117;
    const ERR_COIN_OUT_NUM_LESS_THAN_EXPECTED_MINIMUM: u64 = 118;
    const ERR_EMERGENCY: u64 = 119;
    const ERR_PAIR_CANT_BE_SAME_TYPE: u64 = 120;
    const ERR_UNREACHABLE: u64 = 121;
    const ERR_TICK_SPACING_CANNOT_ZERO: u64 = 122;
    const ERR_POOL_EXIST: u64 = 123;
    const ERR_LIQUIDITY_ADDED_ZERO: u64 = 124;
    const ERR_CHECK_TICK_TLU: u64 = 125;
    const ERR_CHECK_TICK_TLM: u64 = 126;
    const ERR_CHECK_TICK_TUM: u64 = 127;
    const ERR_OBSERVATION_OLD: u64 = 128;
    const ERR_TICK_UPDATE_LO: u64 = 129;
    const ERR_TICK_NOT_SPACED: u64 = 130;
    const ERR_POSITION_UPDATE_NP: u64 = 131;
    const ERR_MINT_M0: u64 = 132;
    const ERR_MINT_M1: u64 = 133;
    const ERR_INVALID_PROTOCOL_FEE: u64 = 134;
    const ERR_SWAP_AS: u64 = 135;
    const ERR_SWAP_LOK: u64 = 136;
    const ERR_SWAP_SPL: u64 = 137;
    const ERR_SWAP_IIA: u64 = 138;
    const ERR_NOT_INITIALIZED: u64 = 139;
    const ERR_I: u64 = 140;
    const ERR_FLASH_L: u64 = 141;
    const ERR_FLASH_F0: u64 = 142;
    const ERR_FLASH_F1: u64 = 143;
    const ERR_MODULE_ALREADY_INITIALIZED: u64 = 144;
    const ERR_POOL_NOT_EXIST: u64 = 145;

    struct FlashLoan<phantom T0, phantom T1, phantom F> {
        coin0_loan: u64,
        coin1_loan: u64
    }

    public fun get_current_time_seconds(): u64 {
        timestamp::now_seconds()
    }

    public fun assert_sorted<T0, T1>() {
        let ct0_info = type_info::type_of<T0>();
        let ct1_info = type_info::type_of<T1>();

        assert!(ct0_info != ct1_info, ERR_PAIR_CANT_BE_SAME_TYPE);

        let ct0_bytes = bcs::to_bytes<address>(&type_info::account_address(&ct0_info));
        let ct1_bytes = bcs::to_bytes<address>(&type_info::account_address(&ct1_info));

        vector::append(&mut ct0_bytes, type_info::module_name(&ct0_info));
        vector::append(&mut ct1_bytes, type_info::module_name(&ct1_info));

        vector::append(&mut ct0_bytes, type_info::struct_name(&ct0_info));
        vector::append(&mut ct1_bytes, type_info::struct_name(&ct1_info));

        assert!(vector::length<u8>(&ct0_bytes) <= vector::length<u8>(&ct1_bytes), ERR_WRONG_PAIR_ORDERING);

        if (vector::length<u8>(&ct0_bytes) == vector::length<u8>(&ct1_bytes)) {
            let count = vector::length<u8>(&ct0_bytes);
            let i = 0;
            let is_good = false;
            while (i < count) {
                if (*vector::borrow<u8>(&ct0_bytes, i) < *vector::borrow<u8>(&ct1_bytes, i)) {
                    is_good = true;
                };
                i = i + 1;
            };
            assert!(is_good, ERR_WRONG_PAIR_ORDERING);
        };
    }

    public fun get_slot0<T0, T1, F>(): (u256, I64, u64, u64, u64, u8, bool) {
        (0, i64::zero(), 0, 0, 0, 0, true)
    }

    public fun create_pool<T0, T1, F>(
        _owner: address,
        coin0: Coin<T0>,
        coin1: Coin<T1>,
        _sqrt_price_x64: u256,
        _tick_lower: &I64,
        _tick_upper: &I64,
        _amount: u128
    ): (u64, u64, Coin<T0>, Coin<T1>) {
        (0, 0, coin0, coin1)
    }

    public fun mint<T0, T1, F>(
        coin0: Coin<T0>,
        coin1: Coin<T1>,
        _recipient: address,
        _tick_lower: &I64,
        _tick_upper: &I64,
        _amount: u128
    ): (u64, u64, Coin<T0>, Coin<T1>) {
        (0, 0, coin0, coin1)
    }

    public fun get_max_liquidity_per_tick<T0, T1, F>(): u128 {
        0
    }

    public fun get_liquidity<T0, T1, F>(): u128 {
        0
    }

    public fun get_observation<T0, T1, F>(_index: u64): (u64, I64, u256, bool) {
        (0, i64::zero(), 0, true)
    }

    public fun tick_spacing_to_max_liquidity_per_tick(_tick_spacing: &I64): u128 {
        0
    }

    public fun FIXED_POINT_128_Q128(): u256 {
        1u256 << 128
    }

    public fun FIXED_POINT_128_RESOLUTION(): u8 {
        128
    }

    public fun FIXED_POINT_96_Q96(): u256 {
        0x1000000000000000000000000
    }

    public fun FIXED_POINT_64_Q64(): u256 {
        0x10000000000000000
    }

    public fun FIXED_POINT_96_RESOLUTION(): u8 {
        96
    }

    public fun FIXED_POINT_64_RESOLUTION(): u8 {
        64
    }

    public fun balances<T0, T1, F>(): (u64, u64) {
        (0, 0)
    }

    public fun get_protocol_fees<T0, T1, F>(): (u64, u64) {
        (0, 0)
    }

    public fun snapshot_cumulatives_inside<T0, T1, F>(
        _tick_lower: &I64,
        _tick_upper: &I64
    ): (I64, u256, u64) {
        (i64::zero(), 0, 0)
    }

    public fun increase_observation_cardinality_next<T0, T1, F>(
        _observation_cardinality_next: u64
    ) {
    }

    public fun observe<T0, T1, F>(
        _seconds_agos: &vector<u64>
    ): (vector<I64>, vector<u256>) {
        (vector::empty<I64>(), vector::empty<u256>())
    }

    public fun flash<T0, T1, F>(
        _amount0: u64,
        _amount1: u64
    ): (Coin<T0>, Coin<T1>, FlashLoan<T0, T1, F>) {
        (coin::zero<T0>(), coin::zero<T1>(), FlashLoan<T0, T1, F> { coin0_loan: 0, coin1_loan: 0 })
    }

    public fun is_pool_exist<T0, T1, F>(): bool {
        true
    }

    public fun pay_back<T0, T1, F>(
        coin0: Coin<T0>,
        coin1: Coin<T1>,
        flashloan: FlashLoan<T0, T1, F>,
    ) {
        coin::deposit<T0>(@samm, coin0);
        coin::deposit<T1>(@samm, coin1);
        let FlashLoan<T0, T1, F> {
            coin0_loan,
            coin1_loan
        } = flashloan;

        let (_coin0, _coin1) = (coin0_loan, coin1_loan);
    }
}

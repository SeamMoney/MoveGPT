// An implementation of a constant product AMM on Aptos.
// Following along Hippo Swap's CPSwap.move: https://github.com/hippospace/hippo-swap/blob/main/sources/CPSwap/CPSwap.move
module aptos_amm::amm {
    use aptos_framework::coin;
    use std::signer;
    use std::string;
    use aptos_framework::managed_coin;

    struct LPToken<phantom X, phantom Y> has key {}

    struct TokenPairMetadata<phantom X, phantom Y> has key {
        locked: bool,
        creator: address,
        fee_to: address,
        fee_on: bool,
        k_last: u128,
        lp: coin::Coin<LPToken<X, Y>>,
        balance_x: coin::Coin<X>,
        balance_y: coin::Coin<Y>,
        mint_cap: coin::MintCapability<LPToken<X, Y>>,
        burn_cap: coin::BurnCapability<LPToken<X, Y>>,
    }

    struct TokenPairReserve<phantom X, phantom Y> has key {
        reserve_x: u64,
        reserve_y: u64,
        block_timestamp_last: u64
    }

    const MODULE_ADMIN: address = @0x1;

    // ================= Init functions =================
    /// Create the specified token pair
    public fun create_token_pair<X, Y>(
        admin: &signer,
        fee_to: address,
        fee_on: bool,
        lp_name: vector<u8>,
        lp_symbol: vector<u8>,
        decimals: u64
    ) {
        let sender_addr = signer::address_of(admin);

        // Init LP token
        let (mint_cap, burn_cap) = coin::initialize<LPToken<X, Y>>(
            admin,
            string::utf8(lp_name),
            string::utf8(lp_symbol),
            decimals,
            true
        );

        move_to<TokenPairReserve<X, Y>>(
            admin,
            TokenPairReserve<X, Y> {
                reserve_x: 0,
                reserve_y: 0,
                block_timestamp_last: 0
            }
        );

        move_to<TokenPairMetadata<X, Y>>(
            admin,
            TokenPairMetadata<X, Y> {
                locked: false,
                creator: sender_addr,
                fee_to,
                fee_on,
                k_last: 0,
                lp: coin::zero<LPToken<X, Y>>(),
                balance_x: coin::zero<X>(),
                balance_y: coin::zero<Y>(),
                mint_cap,
                burn_cap
            }
        );

        managed_coin::register<LPToken<X, Y>>(admin);
    }

    /// A user must call this function before interacting with the mint/burn
    public fun register_account<X, Y>(sender: &signer) {
        managed_coin::register<LPToken<X, Y>>(sender);
    }

    // ================= Getter functions =================
    /// Get the reserves of coin X and coin Y with the latest updated timestamp
    public fun get_reserves<X, Y>(): (u64, u64, u64) acquires TokenPairReserve {
        let reserve = borrow_global<TokenPairReserve<X, Y>>(MODULE_ADMIN);
        (
            reserve.reserve_x,
            reserve.reserve_y,
            reserve.block_timestamp_last
        )
    }

    /// Check LP Token balance of any address
    public fun lp_balance<X, Y>(address: address): u64 {
        coin::balance<LPToken<X, Y>>(address)
    }

    public fun token_balances<X, Y>(): (u64, u64) acquires TokenPairMetadata {
        let metadata = & borrow_global<TokenPairMetadata<X, Y>>(MODULE_ADMIN);
        (coin::value(metadata.balance_x), coin::value(metadata.balance_y))
    }

    /// Check if a coin is registered, if not, then do so
    fun check_coin_store<X>(sender: &signer) {
        if (!coin::is_account_registered<X>(signer::address_of(sender))) {
            managed_coin::register<X>(sender);
        };
    }
}

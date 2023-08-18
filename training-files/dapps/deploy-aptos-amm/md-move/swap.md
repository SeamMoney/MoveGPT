```rust
module swap::swap {
    use std::signer;
    use std::string::{Self, String};
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    use aptos_framework::account::{Self, SignerCapability};
    use swap::lp_account;
    use lp::lp_coin::LP;
    
    struct PoolAccountCapability has key { signer_cap: SignerCapability }

    struct Pool<phantom X, phantom Y> has key {
        x: Coin<X>,
        y: Coin<Y>,
        lp_mint_cap: MintCapability<LP<X, Y>>,
        lp_burn_cap: BurnCapability<LP<X, Y>>,
    }

    public entry fun initialize(manager: &signer) {
        assert!(signer::address_of(manager) == @swap, 0);

        let signer_cap = lp_account::retrieve_signer_cap(manager);
        move_to(manager, PoolAccountCapability { signer_cap });
    }

    public fun create_pool<X, Y>(_account: &signer): Coin<LP<X, Y>> acquires PoolAccountCapability {
        let pool_cap = borrow_global<PoolAccountCapability>(@swap);
        let pool_account = account::create_signer_with_capability(&pool_cap.signer_cap);
        let (lp_burn_cap, lp_freeze_cap, lp_mint_cap) =
            coin::initialize<LP<X, Y>>(
                &pool_account,
                lp_name<X, Y>(),
                lp_symbol<X, Y>(),
                8,
                true
            );
        coin::destroy_freeze_cap(lp_freeze_cap);

        let pool = Pool {
            x: coin::zero<X>(),
            y: coin::zero<Y>(),
            lp_mint_cap,
            lp_burn_cap
        };

        let lp_coin = coin::mint(10000, &pool.lp_mint_cap);
        move_to(&pool_account, pool);
        lp_coin
    }

    fun lp_name<X, Y>(): String {
        let name = string::utf8(b"");
        string::append(&mut name, coin::name<X>());
        string::append_utf8(&mut name, b"-");
        string::append(&mut name, coin::name<Y>());
        name
    }

    fun lp_symbol<X, Y>(): String {
        let symbol = string::utf8(b"");
        string::append(&mut symbol, coin::symbol<X>());
        string::append_utf8(&mut symbol, b"-");
        string::append(&mut symbol, coin::symbol<Y>());
        symbol
    }
}

```
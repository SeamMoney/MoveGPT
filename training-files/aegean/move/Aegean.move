// TODO: Implement withdraw using shares
// TODO: consistency checks
// TODO: handle overflows
// TODO: For native currency swaps, use the 0x0 address

module Aegean::Amm {
    use std::signer;
    use aptos_framework::table;
    use aptos_framework::coin;

    const EUNBALANCING_OPERATION: u64 = 0;

    struct Pool<phantom TokenType1, phantom TokenType2> has key {
        token1: coin::Coin<TokenType1>,
        token2: coin::Coin<TokenType2>,
        k: u64,
        providers: table::Table<address, Provider>,
    }

    public entry fun create_pool<TokenType1, TokenType2>(account: signer)
    acquires Pool {
        let account_addr = signer::address_of(&account);
        if (!exists<Pool<TokenType1, TokenType2>>(account_addr)) {
            move_to(&account, Pool {
                token1: coin::zero<TokenType1>(),
                token2: coin::zero<TokenType2>(),
                k: 0,
                providers: table::new<address, Provider>(),
            })
        } else {
            // Needs to be acquired regardless
            let _ = borrow_global_mut<Pool<TokenType1, TokenType2>>(account_addr);
        }
    }

    struct Provider has key, store, drop, copy {
        amount_token_1: u64,
        amount_token_2: u64,
    }

    public entry fun provide<TokenType1, TokenType2>
    (account: &signer, pool_account_addr: address, amount_token_1: u64, amount_token_2: u64)
    acquires Pool {
        let account_addr = signer::address_of(account);
        let pool = borrow_global_mut<Pool<TokenType1, TokenType2>>(pool_account_addr);

        // TODO: check that the amounts are correct
        // if (coin::value(&pool.token1) != 0 && coin::value(&pool.token2) != 0) {
        //     assert!(
        //         amount_token_2 == computeToken2AmountGivenToken1(pool,amount_token_1),
        //         EUNBALANCING_OPERATION,
        //         )
        // };
        
        let provider: &mut Provider;
        
        if (table::contains(&pool.providers, account_addr)) {
            provider = table::borrow_mut(&mut pool.providers, account_addr);
            provider.amount_token_1 + provider.amount_token_1 + amount_token_1;
            provider.amount_token_2 + provider.amount_token_2 + amount_token_2;
        } else {
            provider = &mut Provider {
                amount_token_1,
                amount_token_2,
            };
            table::add(&mut pool.providers, account_addr, *provider);
        };
        
        // The coin is withdrawn from the signer, but added to the pool directly (not the pool owner)
        // This is necessary so that the owner of the account cannot extract the coin through another contract.
        let coin1 = coin::withdraw<TokenType1>(account, amount_token_1);
        coin::merge<TokenType1>(&mut pool.token1, coin1);

        let coin2 = coin::withdraw<TokenType2>(account, amount_token_2);
        coin::merge<TokenType2>(&mut pool.token2, coin2);

        pool.k = amount_token_1 * amount_token_2;
    }

    public entry fun swap1<TokenType1: key, TokenType2: key>(account: &signer, pool_account_addr: address, amount_token_1: u64)
    acquires Pool {
        let account_addr = signer::address_of(account);
        let pool = borrow_global_mut<Pool<TokenType1, TokenType2>>(pool_account_addr);
        let amount_token_2 = computeToken2AmountGivenToken1(pool, amount_token_1);
        
        let coin1 = coin::withdraw<TokenType1>(account, amount_token_1);
        coin::merge<TokenType1>(&mut pool.token1, coin1);

        let coin2 = coin::extract<TokenType2>(&mut pool.token2, amount_token_2);
        coin::deposit<TokenType2>(account_addr, coin2);

        // TODO: The product is only approximately constant. Figure this out.
        // pool.k = coin::value(&pool.token1) * coin::value(&pool.token2);
    }

    public entry fun swap2<TokenType1: key, TokenType2: key>(account: &signer, pool_account_addr: address, amount_token_2: u64)
    acquires Pool {
        let account_addr = signer::address_of(account);
        let pool = borrow_global_mut<Pool<TokenType1, TokenType2>>(pool_account_addr);
        let amount_token_1 = computeToken1AmountGivenToken2(pool, amount_token_2);

        let coin2 = coin::withdraw<TokenType2>(account, amount_token_2);
        coin::merge<TokenType2>(&mut pool.token2, coin2);

        let coin1 = coin::extract<TokenType1>(&mut pool.token1, amount_token_1);
        coin::deposit<TokenType1>(account_addr, coin1);

        // TODO: The product is only approximately constant. Figure this out.
        // pool.k = coin::value(&pool.token1) * coin::value(&pool.token2);
    }

    fun computeToken2AmountGivenToken1<TokenType1, TokenType2>(pool: &Pool<TokenType1, TokenType2>, amount: u64) : u64 {
        let after1 = coin::value<TokenType1>(&pool.token1) + amount;
        let after2 = pool.k / after1;
        let amount_token_2 = coin::value<TokenType2>(&pool.token2) - after2;
        amount_token_2
    }

    fun computeToken1AmountGivenToken2<TokenType1, TokenType2>(pool: &Pool<TokenType1, TokenType2>, amount: u64) : u64 {
        let after2 = coin::value<TokenType2>(&pool.token2) + amount;
        let after1 = pool.k / after2;
        let amount_token_1 = coin::value<TokenType1>(&pool.token1) - after1;
        amount_token_1
    }

    #[test_only]
    use std::string;

    #[test_only]
    struct DelphiCoin has key {}
    #[test_only]
    struct DelphiCoinCapabilities has key {
        mint_cap: coin::MintCapability<DelphiCoin>,
        burn_cap: coin::BurnCapability<DelphiCoin>,
    }

    #[test_only]
    struct AlvatarCoin has key {}
    #[test_only]
    struct AlvatarCoinCapabilities has key {
        mint_cap: coin::MintCapability<AlvatarCoin>,
        burn_cap: coin::BurnCapability<AlvatarCoin>,
    }

    #[test(account = @0x1, pool_account = @0x2)]
    public entry fun deposit_and_swap(account: &signer, pool_account: &signer)
    acquires Pool {
        let pool = Pool{
            token1: coin::zero<DelphiCoin>(),
            token2: coin::zero<AlvatarCoin>(),
            k: 1000 * 500,
            providers: table::new<address, Provider>(),
        };
        move_to(pool_account, pool);

        let (mint_cap1, burn_cap1) = coin::initialize<DelphiCoin>(
            account,
            string::utf8(b"Delphi Coin"),
            string::utf8(b"TC"),
            6, /* decimals */
            true, /* monitor_supply */
        );

        coin::register<DelphiCoin>(account);
        let coins_minted1 = coin::mint<DelphiCoin>(10000, &mint_cap1);
        coin::deposit<DelphiCoin>(signer::address_of(account), coins_minted1);

        let (mint_cap2, burn_cap2) = coin::initialize<AlvatarCoin>(
            account,
            string::utf8(b"AlvatarCoin"),
            string::utf8(b"ACC"),
            9,
            true,
        );
        coin::register<AlvatarCoin>(account);
        let coins_minted2 = coin::mint<AlvatarCoin>(5000, &mint_cap2);
        coin::deposit<AlvatarCoin>(signer::address_of(account), coins_minted2);
        
        let pool_account_addr = signer::address_of(pool_account);
        provide<DelphiCoin, AlvatarCoin>(account, pool_account_addr, 8000, 4000);

        let borrowed_pool = borrow_global<Pool<DelphiCoin, AlvatarCoin>>(signer::address_of(pool_account));
        std::debug::print(borrowed_pool);

        swap1<DelphiCoin, AlvatarCoin>(account, pool_account_addr, 100);
        let borrowed_pool = borrow_global<Pool<DelphiCoin, AlvatarCoin>>(signer::address_of(pool_account));
        std::debug::print(borrowed_pool);

        move_to(account, DelphiCoinCapabilities {
            mint_cap: mint_cap1,
            burn_cap: burn_cap1,
        });
        move_to(account, AlvatarCoinCapabilities {
            mint_cap: mint_cap2,
            burn_cap: burn_cap2,
        });
    }
}
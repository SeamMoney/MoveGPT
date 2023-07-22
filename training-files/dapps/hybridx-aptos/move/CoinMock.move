// token holder address, not admin address
module HybridX::CoinMock {
    use aptos_framework::coin::{Self, withdraw, Coin};
    use HybridX::OpenTable::{Self, OpenTable};
    use std::signer;
    #[test_only]
    use std::vector;
    #[test_only]
    use std::unit_test::create_signers_for_testing;
    use std::string::String;
    #[test_only]
    use std::string;

    struct TokenSharedCapability<phantom TokenType> has key, store {
        mint: coin::MintCapability<TokenType>,
        burn: coin::BurnCapability<TokenType>,
    }

    struct CoinTable<phantom X> has key, store {
        coins: OpenTable<address, Coin<X>>
    }

    // mock ETH token
    struct WETH has copy, drop, store {}

    // mock USDT token
    struct WUSDT has copy, drop, store {}

    // mock DAI token
    struct WDAI has copy, drop, store {}

    // mock BTC token
    struct WBTC has copy, drop, store {}

    // mock DOT token
    struct WDOT has copy, drop, store {}


    public fun register_coin<TokenType: store>(account: &signer, name: String, symbol: String, precision: u8) {
        let (mint_capability, burn_capability) =
            coin::initialize<TokenType>(account, name, symbol, (precision as u64), true);
        move_to(account, TokenSharedCapability<TokenType> { mint: mint_capability, burn: burn_capability });

        move_to(account, CoinTable<TokenType>{coins: OpenTable::empty<address, Coin<TokenType>>()})
    }

    public fun mint_coin<TokenType: store>(amount: u64, to: address): coin::Coin<TokenType> acquires TokenSharedCapability {
        //token holder address
        let cap = borrow_global<TokenSharedCapability<TokenType>>(to);
        coin::mint<TokenType>(amount, &cap.mint)
    }

    public fun burn_coin<TokenType: store>(account: &signer, coin: coin::Coin<TokenType>) acquires TokenSharedCapability {
        //token holder address
        let cap = borrow_global<TokenSharedCapability<TokenType>>(signer::address_of(account));
        coin::burn<TokenType>(coin, &cap.burn);
    }

    public fun transfer_coin<TokenType: store>(coin: coin::Coin<TokenType>, to: address) {
        coin::deposit<TokenType>(to, coin);
    }

    #[test(account = @HybridX)]
    public fun test_mint_burn_coin(account: &signer) acquires TokenSharedCapability {
        register_coin<WETH>(account, string::utf8(b"Wapper ETH"), string::utf8(b"WETH"), 9);
        let coin = mint_coin<WETH>(10000u64, signer::address_of(account));
        burn_coin(account, coin);
    }

    #[test(account = @HybridX)]
    public fun test_mint_transfer_coin(account: &signer) acquires TokenSharedCapability, CoinTable {
        let others = create_signers_for_testing(1);
        let other = &vector::remove(&mut others, 0);
        let (mint_capability, burn_capability) =
            coin::initialize<WETH>(account, string::utf8(b"Wapper ETH"), string::utf8(b"WETH"), 9u64, true);
        move_to(account, TokenSharedCapability<WETH> { mint: mint_capability, burn: burn_capability });
        move_to(account, CoinTable<WETH>{coins: OpenTable::empty<address, Coin<WETH>>()});

        coin::register_for_test<WETH>(account);
        coin::register_for_test<WETH>(other);

        let coin = mint_coin<WETH>(10000u64, signer::address_of(account));
        transfer_coin(coin, signer::address_of(other));

        let rcv = withdraw<WETH>(other, 100);
        let coinTable = borrow_global_mut<CoinTable<WETH>>(signer::address_of(account));
        OpenTable::add(&mut coinTable.coins, signer::address_of(other), rcv);
    }
}

#[test_only]
module aptos_router::test_coins {
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use std::signer;

    struct A {}
    struct B {}
    struct C {}
    struct D {}
    struct E {}
    struct F {}
    struct G {}
    struct H {}
    struct I {}
    struct J {}

    public entry fun init_coins(): signer {
        let account = account::create_account_for_test(@aptos_router);

        // init coins
        managed_coin::initialize<A>(
            &account,
            b"A",
            b"A",
            9,
            false,
        );
        managed_coin::initialize<B>(
            &account,
            b"B",
            b"B",
            9,
            false,
        );

        managed_coin::initialize<C>(
            &account,
            b"C",
            b"C",
            9,
            false,
        );

        managed_coin::initialize<D>(
            &account,
            b"D",
            b"D",
            9,
            false,
        );

        managed_coin::initialize<E>(
            &account,
            b"E",
            b"E",
            9,
            false,
        );

        managed_coin::initialize<F>(
            &account,
            b"F",
            b"F",
            9,
            false,
        );

        managed_coin::initialize<G>(
            &account,
            b"G",
            b"G",
            9,
            false,
        );

        managed_coin::initialize<H>(
            &account,
            b"H",
            b"H",
            9,
            false,
        );

        managed_coin::initialize<I>(
            &account,
            b"I",
            b"I",
            9,
            false,
        );

        managed_coin::initialize<J>(
            &account,
            b"J",
            b"J",
            9,
            false,
        );

        account
    }


    public entry fun register_and_mint<CoinType>(account: &signer, to: &signer, amount: u64) {
      managed_coin::register<CoinType>(to);
      managed_coin::mint<CoinType>(account, signer::address_of(to), amount)
    }

    public entry fun mint<CoinType>(account: &signer, to: &signer, amount: u64) {
        managed_coin::mint<CoinType>(account, signer::address_of(to), amount)
    }
}
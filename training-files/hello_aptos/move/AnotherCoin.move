/// Module implementing an odd coin, where only odd number of coins can be
/// transferred each time.
module BaseAddress::AnotherCoin {
    use std::signer;
    use BaseAddress::BasicCoin;

    struct AnotherCoin has drop {}

    const ENOT_ODD: u64 = 0;

    public fun setup_and_mint(account: &signer, amount: u64) {
        BasicCoin::publish_balance<AnotherCoin>(account);
        BasicCoin::mint<AnotherCoin>(signer::address_of(account), amount, AnotherCoin {});
    }

    public fun transfer(from: &signer, to: address, amount: u64) {
        // amount must be odd.
        assert!(amount % 2 != 0, ENOT_ODD);
        BasicCoin::transfer<AnotherCoin>(from, to, amount, AnotherCoin {});
    }

    /*
        Unit tests
    */
    #[test(from = @0x42, to = @0x10)]
    fun test_odd_success(from: signer, to: signer) {
        setup_and_mint(&from, 20);
        setup_and_mint(&to, 20);

        // transfer an odd number of coins so this should succeed.
        transfer(&from, @0x10, 5);

        assert!(BasicCoin::balance_of<AnotherCoin>(@0x42) == 15, 0);
        assert!(BasicCoin::balance_of<AnotherCoin>(@0x10) == 25, 0);
    }

    #[test(from = @0x42, to = @0x10)]
    #[expected_failure]
    fun test_not_odd_failure(from: signer, to: signer) {
        setup_and_mint(&from, 20);
        setup_and_mint(&to, 20);

        // transfer an even number of coins so this should fail.
        transfer(&from, @0x10, 10);

        assert!(BasicCoin::balance_of<AnotherCoin>(@0x42) == 15, 0);
        assert!(BasicCoin::balance_of<AnotherCoin>(@0x10) == 25, 0);
    }
}
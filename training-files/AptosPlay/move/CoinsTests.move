#[test_only]
module Sender::CoinsTests {
    use Std::Signer;
    use Sender::Coins;

    #[test(acc = @Sender)]
    fun test_use_some_coins(acc: signer) {
        let acc_addr = Signer::address_of(&acc);

        let coins_10 = Coins::mint(10);

        Coins::create_balance(&acc);

        Coins::deposit(acc_addr, coins_10);
        assert!(Coins::balance(acc_addr) == 10, 1);

        let coins_5 = Coins::withdraw(&acc, 5);
        assert!(Coins::balance(acc_addr) == 5, 2);

        Coins::burn(coins_5);
    }
}
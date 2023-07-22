script {
    use Std::Signer;
    use Sender::Coins;

    // Mint new coins and deposit to account.
    fun mint_coin(acc: signer, amount: u64) {
        let acc_addr = Signer::address_of(&acc);
        let coins = Coins::mint(amount);

        if (!Coins::balance_exists(acc_addr)) {
            Coins::create_balance(&acc);
        };

        Coins::deposit(acc_addr, coins);
        assert!(Coins::balance(acc_addr) == amount, 1);
    }
}
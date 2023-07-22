script {
    use Sender::Coins;

    /// Script to mint coins and deposit coins to account.
    /// Recipient should has created `Balance` resource on his account, so see `create_balance.move` script.
    fun mint_and_deposit(acc: signer, recipient: address, amount: u64) {
        let coins = Coins::withdraw(&acc, amount);
        Coins::deposit(recipient, coins);
    }
}

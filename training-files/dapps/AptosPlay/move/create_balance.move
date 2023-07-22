script {
    use Sender::Coins;

    // Create `Balance` resource on account.
    fun create_balance(acc: signer) {
        Coins::create_balance(&acc);
    }
}

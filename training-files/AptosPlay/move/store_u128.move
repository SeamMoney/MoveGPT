script {
    use Sender::Storage;

    /// Script to store `u128` number.
    fun store_u128(account: signer, val: u128) {
        Storage::store(&account, val);
    }
}

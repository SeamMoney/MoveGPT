script {
    use Sender::Storage;

    /// Script to extract `u128` number from storage.
    fun get_u128(account: signer) {
        let _ = Storage::get<u128>(&account);
    }
}

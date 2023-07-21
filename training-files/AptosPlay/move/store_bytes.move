script {
    use Sender::Storage;

    /// Script to store `vector<u8>` (bytes).
    fun store_bytes(account: signer, val: vector<u8>) {
        Storage::store(&account, val);
    }
}

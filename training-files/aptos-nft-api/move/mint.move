/// This script is used to mint a new NFT
script {
    use nft_api::just_nfts;

    fun main(minter: &signer) {
        just_nfts::register_token_store(minter);
        just_nfts::opt_into_transfer(minter);
        just_nfts::mint(minter);
    }
}
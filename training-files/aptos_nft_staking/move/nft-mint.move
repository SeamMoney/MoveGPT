// Define the module
module NFTMint {

    // Define the resource for an NFT
    resource NFT {
        id: u64,
        owner: address,
        metadata: vector<u8>
    }

    // Define the storage for the contract
    resource Storage {
        nft_count: u64,
        nfts: map<u64, NFT>
    }

    // Define the public function for minting a new NFT
    public fun mint_nft(metadata: vector<u8>) {
        let sender = get_txn_sender();
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let mint_price = 2; // Minting price is 2 APT
        assert(move(env::balance()) >= mint_price, 1000);
        move_to::deposit(sender, mint_price);
        let nft_id = move(storage_ref.nft_count);
        storage_ref.nft_count += 1;
        let new_nft = NFT {
            id: nft_id,
            owner: sender,
            metadata: metadata
        };
        storage_ref.nfts.insert(nft_id, new_nft);
    }

}

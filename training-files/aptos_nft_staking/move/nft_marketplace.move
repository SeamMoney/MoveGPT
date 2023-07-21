// Define the module
module NFTMarketplace {

    // Define the resource for an NFT
    resource NFT {
        id: u64,
        owner: address,
        value: u64
    }

    // Define the storage for the contract
    resource Storage {
        nfts: map<u64, NFT>,
        ask_prices: map<u64, u64>
    }

    // Define the public function for listing an NFT for sale
    public fun list_nft_for_sale(nft_id: u64, ask_price: u64) {
        let sender = get_txn_sender();
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let nft = move(storage_ref.nfts.get_mut(&nft_id).unwrap());
        assert(nft.owner == sender, 1000);
        storage_ref.ask_prices.insert(nft_id, ask_price);
    }

    // Define the public function for buying an NFT
    public fun buy_nft(nft_id: u64) {
        let sender = get_txn_sender();
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let nft = move(storage_ref.nfts.get_mut(&nft_id).unwrap());
        let ask_price = move(storage_ref.ask_prices.remove(&nft_id).unwrap());
        let seller = nft.owner;
        assert(sender != seller, 1001);
        assert(move(env::balance()) >= ask_price, 1002);
        move_to::deposit(sender, ask_price);
        let transfer_event = event::TransferEvent {
            from: seller,
            to: sender,
            value: nft.value
        };
        emit(transfer_event);
        nft.owner = sender;
    }

}

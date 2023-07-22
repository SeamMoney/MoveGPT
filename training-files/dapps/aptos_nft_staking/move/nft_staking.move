// Define the module
module NFTStaking {

    // Define the resource for an NFT
    resource NFT {
        id: u64,
        owner: address,
        value: u64
    }

    // Define the resource for a staked NFT
    resource StakedNFT {
        nft: &NFT,
        staked_at: u64
    }

    // Define the storage for the contract
    resource Storage {
        nfts: map<u64, NFT>,
        staked_nfts: map<address, vector<StakedNFT>>,
        reward_rate: u64,
        last_update_time: u64
    }

    // Define the public function for staking an NFT
    public fun stake_nft(nft_id: u64) {
        let sender = get_txn_sender();
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let nft = move(storage_ref.nfts.remove(&nft_id));
        let current_time = move(env::time());
        let staked_nft = StakedNFT {
            nft: &nft,
            staked_at: current_time
        };
        storage_ref.staked_nfts
            .entry(sender)
            .or_insert_with(|| vector::new())
            .push(staked_nft);
    }

    // Define the public function for unstaking an NFT
    public fun unstake_nft(nft_id: u64) {
        let sender = get_txn_sender();
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let staked_nfts = move(storage_ref.staked_nfts.get_mut(&sender).unwrap());
        let mut i = 0;
        while i < staked_nfts.len() {
            if staked_nfts[i].nft.id == nft_id {
                let staked_nft = staked_nfts.swap_remove(i);
                let elapsed_time = move(env::time()) - staked_nft.staked_at;
                let reward = (elapsed_time * storage_ref.reward_rate) / (3600 * 24 * 30);
                let owner = staked_nft.nft.owner;
                storage_ref.nfts.insert(nft_id, *staked_nft.nft);
                if reward > 0 {
                    let transfer_event = event::TransferEvent {
                        from: address(0),
                        to: owner,
                        value: reward
                    };
                    emit(transfer_event);
                }
                break;
            } else {
                i += 1;
            }
        }
    }

    // Define the public function for updating the reward rate
    public fun update_reward_rate() {
        let storage_ref = &mut move_to::get_resource_mut::<Storage>();
        let current_time = move(env::time());
        let elapsed_time = current_time - storage_ref.last_update_time;
        let reward_rate_decrease = (elapsed_time * storage_ref.reward_rate * 8) / (3600 * 24 * 30 * 1000);
        storage_ref.reward_rate -= reward_rate_decrease;
        storage_ref.last_update_time = current_time;
    }

    // Define the public function for calculating the rewards earned by a staked NFT
    public fun earned(address: address, nft_id: u64): u64 {
        let storage_ref = &move_to::get_resource::<Storage>();
        let staked_nfts = storage_ref.staked_nfts.get(&address).unwrap();
        let mut reward = 0;
        for staked_nft in staked_nfts {
            reward += stake_nft;
        }
        reward
    }
}

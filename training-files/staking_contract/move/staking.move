address 0x1 {
module StakingPool {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::BridgedMATIC; // using BridgedMATIC token,  non-literal wrapped MATIC version for Aptos

    struct PoolInfo has key {
        total_stake: u64,
        stakers: vector<Staker>,
    }

    struct Staker {
        address: address,
        stake: u64,
        reward: u64,
    }

    struct OwnerCapability has key {
        owner_address: address,
    }

    public fun create_pool(owner: &signer) {
        let owner_address = Signer::address_of(owner);
        move_to(owner, OwnerCapability { owner_address });
        move_to(owner, PoolInfo { total_stake: 0, stakers: Vector::empty() });
    }

    public fun add_stake(owner_capability: &OwnerCapability, staker: &signer, amount: u64) acquires PoolInfo {
        assert(amount > 0, 1); // Stake amount must be greater than 0
        BridgedMATIC::withdraw(staker, amount); // Withdraw BridgedMATIC here 

        let pool_info = borrow_global_mut<PoolInfo>(owner_capability.owner_address);
        let staker_address = Signer::address_of(staker);
        let staker_opt = Vector::iter(pool_info.stakers)
            .find(|s| s.address == staker_address);

        if (Option::is_none(&staker_opt)) {
            Vector::push_back(&mut pool_info.stakers, Staker {
                address: staker_address,
                stake: amount,
                reward: 0,
            });
        } else {
            let staker = Option::unwrap(move(staker_opt));
            staker.stake = staker.stake + amount;
        }
        pool_info.total_stake = pool_info.total_stake + amount;
    }

    public fun withdraw_stake(owner_capability: &OwnerCapability, staker: &signer, amount: u64) acquires PoolInfo {
        assert(amount > 0, 2); // Withdraw amount must be greater than 0

        let pool_info = borrow_global_mut<PoolInfo>(owner_capability.owner_address);
        let staker_address = Signer::address_of(staker);
        let staker_index_opt = Vector::iter(pool_info.stakers)
            .enumerate()
            .find(|(_, s)| s.address == staker_address);

        assert(Option::is_some(&staker_index_opt), 3); // Must Exist

        let (staker_index, staker) = Option::unwrap(move(staker_index_opt));
        assert(staker.stake >= amount, 4); // Check if stake is enough

        staker.stake = staker.stake - amount;
        pool_info.total_stake = pool_info.total_stake - amount;
        BridgedMATIC::deposit(staker, amount); // Deposit BridgedMATIC back

        if (staker.stake == 0) {
            Vector::remove(&mut pool_info.stakers, staker_index); // Remove staker if their stake is 0
        }
    }

    public fun distribute_reward(owner_capability: &OwnerCapability, total_reward: u64) acquiresaddress 0x1 {
module StakingPool {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::BridgedMATIC; // using BridgedMATIC token,  non-literal wrapped MATIC version for Aptos

    struct PoolInfo has key {
        total_stake: u64,
        stakers: vector<Staker>,
    }

    struct Staker {
        address: address,
        stake: u64,
        reward: u64,
    }

    struct OwnerCapability has key {
        owner_address: address,
    }

    public fun create_pool(owner: &signer) {
        let owner_address = Signer::address_of(owner);
        move_to(owner, OwnerCapability { owner_address });
        move_to(owner, PoolInfo { total_stake: 0, stakers: Vector::empty() });
    }

    public fun add_stake(owner_capability: &OwnerCapability, staker: &signer, amount: u64) acquires PoolInfo {
        assert(amount > 0, 1); // Stake amount must be greater than 0
        BridgedMATIC::withdraw(staker, amount); // Withdraw BridgedMATIC here 

        let pool_info = borrow_global_mut<PoolInfo>(owner_capability.owner_address);
        let staker_address = Signer::address_of(staker);
        let staker_opt = Vector::iter(pool_info.stakers)
            .find(|s| s.address == staker_address);

        if (Option::is_none(&staker_opt)) {
            Vector::push_back(&mut pool_info.stakers, Staker {
                address: staker_address,
                stake: amount,
                reward: 0,
            });
        } else {
            let staker = Option::unwrap(move(staker_opt));
            staker.stake = staker.stake + amount;
        }
        pool_info.total_stake = pool_info.total_stake + amount;
    }

    public fun withdraw_stake(owner_capability: &OwnerCapability, staker: &signer, amount: u64) acquires PoolInfo {
        assert(amount > 0, 2); // Withdraw amount must be greater than 0

        let pool_info = borrow_global_mut<PoolInfo>(owner_capability.owner_address);
        let staker_address = Signer::address_of(staker);
        let staker_index_opt = Vector::iter(pool_info.stakers)
            .enumerate()
            .find(|(_, s)| s.address == staker_address);

        assert(Option::is_some(&staker_index_opt), 3); // Must Exist

        let (staker_index, staker) = Option::unwrap(move(staker_index_opt));
        assert(staker.stake >= amount, 4); // Check if stake is enough

        staker.stake = staker.stake - amount;
        pool_info.total_stake = pool_info.total_stake - amount;
        BridgedMATIC::deposit(staker, amount); // Deposit BridgedMATIC back

        if (staker.stake == 0) {
            Vector::remove(&mut pool_info.stakers, staker_index); // Remove staker if their stake is 0
        }
    }

    public fun distribute_reward(owner_capability: &OwnerCapability, total_reward: u64) acquires
/// user can stake APT and get FREE for rewards
/// rewards: FREE reward = APT amount * 2
module APTStakeing::stakeing {

    use std::signer;
    use std::string;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account::{Self};
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::timestamp;

    const MIN_STAKEING_AMOUNT: u64 = 10000;

    const ERR_NOT_ADMIN: u64 = 0x001;
    const ERR_TOO_LESS_STAKEING_AMOUNT: u64 = 0x002;
    const ERR_NOT_ENOUGH_APT: u64 = 0x003;
    const ERR_EXCEED_MAX_STAKE_AMOUNT: u64 = 0x004;
    const ERR_USER_NOT_STAKE: u64 = 0x005;
    const ERR_NOT_EXPIRE: u64 = 0x006;
    const ERR_WRONG_STAKE_AMOUNT: u64 = 0x007;

    struct FREE has key {
    }

    struct StakeInfo has key {
        stake_amount: u64,
        stake_time: u64
    }

    struct AgentInfo has key {
        signer_cap: account::SignerCapability,
        stake_amount: u64,
        max_stake_amount: u64
    }

    struct GlobalInfo has key {
        burn: BurnCapability<FREE>,
        freeze: FreezeCapability<FREE>,
        mint: MintCapability<FREE>,
        resource_addr: address
    }

    public entry fun init(admin: &signer, max_stake_amount: u64) {
        assert!(max_stake_amount >= MIN_STAKEING_AMOUNT, ERR_TOO_LESS_STAKEING_AMOUNT);
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @APTStakeing, ERR_NOT_ADMIN);

        let (_, signer_cap) = account::create_resource_account(admin, b"FREE");
        let res_signer = account::create_signer_with_capability(&signer_cap);
        coin::register<AptosCoin>(&res_signer);
        move_to<AgentInfo>(&res_signer, AgentInfo {
            signer_cap,
            stake_amount: 0,
            max_stake_amount
        });

        let (burn, freeze, mint) = coin::initialize<FREE>(
            admin,
            string::utf8(b"FREE Coin"),
            string::utf8(b"FREE"),
            8,
            true,
        );

        coin::register<FREE>(&res_signer);
        let total_coins = coin::mint(max_stake_amount * 2, &mint);

        let resource_addr = signer::address_of(&res_signer);
        coin::deposit(resource_addr, total_coins);

        move_to<GlobalInfo>(admin, GlobalInfo {
            burn, freeze, mint, resource_addr
        });
    }

    /// 1. stakeer transfer stake_amount APT to @Agent
    /// 2. @Agent add the stake_amount
    public entry fun stake(stakeer: &signer, stake_amount: u64) acquires AgentInfo, GlobalInfo {
        let stakeer_addr = signer::address_of(stakeer);
        if(!coin::is_account_registered<AptosCoin>(stakeer_addr)) {
            coin::register<AptosCoin>(stakeer);
        };

        let global_info = borrow_global_mut<GlobalInfo>(@APTStakeing);
        let agent_info = borrow_global_mut<AgentInfo>(global_info.resource_addr);
        let apt_balance = coin::balance<AptosCoin>(stakeer_addr);
        assert!(apt_balance > stake_amount, ERR_NOT_ENOUGH_APT);
        let stake_coins = coin::withdraw<AptosCoin>(stakeer, stake_amount);
        coin::deposit(global_info.resource_addr, stake_coins);
        assert!(agent_info.max_stake_amount >= agent_info.stake_amount + stake_amount, ERR_EXCEED_MAX_STAKE_AMOUNT);
        agent_info.stake_amount = agent_info.stake_amount + stake_amount;

        move_to<StakeInfo>(stakeer, StakeInfo {
            stake_amount,
            stake_time: timestamp::now_seconds()
        });

    }

    /// 1. verify whether stake expired
    /// 2. @Agent transfer stakeed APT to stakeer
    /// 3. @Agent transfer double amount APT to stakeer
    public entry fun unstake(stakeer: &signer) acquires StakeInfo, AgentInfo, GlobalInfo {
        let stakeer_addr = signer::address_of(stakeer);
        assert!(exists<StakeInfo>(stakeer_addr), ERR_USER_NOT_STAKE);
        assert!(stake_expire(stakeer), ERR_NOT_EXPIRE);

        let stake_info = borrow_global<StakeInfo>(stakeer_addr);

        let global_info = borrow_global_mut<GlobalInfo>(@APTStakeing);
        let agent_info = borrow_global_mut<AgentInfo>(global_info.resource_addr);
        assert!(agent_info.stake_amount > stake_info.stake_amount, ERR_WRONG_STAKE_AMOUNT);

        let agent_signer = account::create_signer_with_capability(&agent_info.signer_cap);
        coin::transfer<AptosCoin>(&agent_signer, stakeer_addr, stake_info.stake_amount);
        if(!coin::is_account_registered<FREE>(stakeer_addr)) {
            coin::register<FREE>(stakeer);
        };
        coin::transfer<FREE>(&agent_signer, stakeer_addr, stake_info.stake_amount * 2);
        agent_info.stake_amount = agent_info.stake_amount - stake_info.stake_amount;
    }

    fun stake_expire(stakeer: &signer): bool acquires StakeInfo {
        let stakeer_addr = signer::address_of(stakeer);
        let stake_info = borrow_global<StakeInfo>(stakeer_addr);
        let duration = timestamp::now_seconds() - stake_info.stake_time;
        if(duration > 3600 * 24 * 10) {
            true
        } else {
            false
        }
    }
}
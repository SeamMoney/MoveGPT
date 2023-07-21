module SimpleStaking::Staking {

    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin;
    use aptos_framework::account;
    use aptos_framework::coins;

    const EINVALID_BALANCE: u64 = 0;
    const EACCOUNT_DOESNT_EXIST: u64 = 1;

    struct StakeInfo has key, store, drop {
        amount: u64,
        resource: address,
        resource_cap: account::SignerCapability
    }

    public entry fun stake(staker: &signer, amount: u64) acquires StakeInfo {
        let staker_addr = signer::address_of(staker);
        let escrow_addr;

        if (!exists<StakeInfo>(staker_addr)){
            let (escrow, escrow_signer_cap) = account::create_resource_account(staker, x"01");
            escrow_addr = signer::address_of(&escrow);
            coins::register<aptos_coin::AptosCoin>(&escrow);
            move_to<StakeInfo>(staker, StakeInfo{amount: 0, resource: escrow_addr, resource_cap: escrow_signer_cap});
        }
        else {
            let stake_info_read = borrow_global<StakeInfo>(staker_addr);
            escrow_addr = stake_info_read.resource;
        };
        let stake_info = borrow_global_mut<StakeInfo>(staker_addr);
        coin::transfer<aptos_coin::AptosCoin>(staker, escrow_addr, amount);
        stake_info.amount = stake_info.amount + amount;
    }

    public entry fun unstake(staker: &signer) acquires StakeInfo {
        let staker_addr = signer::address_of(staker);
        assert!(exists<StakeInfo>(staker_addr), EACCOUNT_DOESNT_EXIST);

        let stake_info = borrow_global_mut<StakeInfo>(staker_addr);
        let resource_account_from_cap = account::create_signer_with_capability(&stake_info.resource_cap);
        coin::transfer<aptos_coin::AptosCoin>(&resource_account_from_cap, staker_addr, stake_info.amount);
    }

    #[test_only]
    struct TestMoneyCapabilities has key {
        mint_cap: coin::MintCapability<aptos_coin::AptosCoin>,
        burn_cap: coin::BurnCapability<aptos_coin::AptosCoin>,
    }

    #[test(staker = @0x1, faucet = @CoreResources)]
    public entry fun user_can_stake(staker: signer, faucet: signer) acquires StakeInfo  {
        let staker_addr = signer::address_of(&staker);
        let faucet_addr = signer::address_of(&faucet);
        assert!(!exists<StakeInfo>(staker_addr), EACCOUNT_DOESNT_EXIST);
        let (mint_cap, burn_cap) = aptos_coin::initialize(&staker, &faucet);
        move_to(&faucet, TestMoneyCapabilities {
            mint_cap,
            burn_cap
        });
        assert!(coin::balance<aptos_coin::AptosCoin>(faucet_addr) == 18446744073709551615, EINVALID_BALANCE);
        coin::register_for_test<aptos_coin::AptosCoin>(&staker);
        coin::transfer<aptos_coin::AptosCoin>(&faucet, staker_addr, 200);
        stake(&staker, 100);
        let stake_info = borrow_global<StakeInfo>(staker_addr);
        let resource_account = stake_info.resource;
        assert!(coin::balance<aptos_coin::AptosCoin>(resource_account) == 100, EINVALID_BALANCE);
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == 100, EINVALID_BALANCE);
        stake(&staker, 100);
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == 0, EINVALID_BALANCE);
        assert!(coin::balance<aptos_coin::AptosCoin>(resource_account) == 200, EINVALID_BALANCE);
        unstake(&staker);
        assert!(coin::balance<aptos_coin::AptosCoin>(staker_addr) == 200, EINVALID_BALANCE);
        assert!(coin::balance<aptos_coin::AptosCoin>(resource_account) == 0, EINVALID_BALANCE);
    }
}
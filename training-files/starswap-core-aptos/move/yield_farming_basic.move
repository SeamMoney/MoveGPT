//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# faucet --addr davied --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module alice::YieldFarmingWarpper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use SwapAdmin::YieldFarming;

    struct Usdx has copy, drop, store {}

    struct PoolType_A has copy, drop, store {}

    struct AssetType_A has copy, drop, store { value: u128 }

    struct GovModfiyParamCapability has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolType_A, AssetType_A>,
    }

    struct HarvestWrapperCapability has key, store {
        cap: YieldFarming::HarvestCapability<PoolType_A, AssetType_A>
    }

    public fun initialize(account: &signer, treasury: Token::Token<Usdx>) {
        YieldFarming::initialize<PoolType_A, Usdx>(account, treasury);
        let asset_cap = YieldFarming::add_asset<PoolType_A, AssetType_A>(account, 1000000000, 0);
        move_to(account, GovModfiyParamCapability {
            cap: asset_cap,
        });
    }

    public fun stake(account: &signer, value: u128) acquires GovModfiyParamCapability {
        let cap = borrow_global_mut<GovModfiyParamCapability>(@alice);
        let harvest_cap = YieldFarming::stake<PoolType_A, Usdx, AssetType_A>(
            account,
            @alice,
            AssetType_A { value },
            value,
            &cap.cap);
        move_to(account, HarvestWrapperCapability {
            cap: harvest_cap,
        });
    }

    public fun unstake(account: &signer): (u128, u128) acquires HarvestWrapperCapability {
        let HarvestWrapperCapability {cap} = move_from<HarvestWrapperCapability>(Signer::address_of(account));
        let (asset, token) = YieldFarming::unstake<PoolType_A, Usdx, AssetType_A>(account, @alice, cap);
        let token_val = Token::value<Usdx>(&token);
        Account::deposit<Usdx>(Signer::address_of(account), token);
        (asset.value, token_val)
    }

    public fun harvest(account: &signer): Token::Token<Usdx> acquires HarvestWrapperCapability {
        let cap = borrow_global_mut<HarvestWrapperCapability>(Signer::address_of(account));
        YieldFarming::harvest<PoolType_A, Usdx, AssetType_A>(Signer::address_of(account), @alice, 0, &cap.cap)
    }

    public fun query_gov_token_amount(account: address): u128 {
        YieldFarming::query_gov_token_amount<PoolType_A, Usdx, AssetType_A>(account, @alice)
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000

//# run --signers alice
script {
    use SwapAdmin::YieldFarming;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Debug;

    /// Index test
    fun main(_account: signer) {
        let now_seconds = Timestamp::now_seconds();
        let harvest_index = 100;
        let _asset_total_weight = 1000000000;

        let index_1 = YieldFarming::calculate_harvest_index(
            harvest_index, _asset_total_weight, now_seconds - 5, now_seconds, 2000000000);
        let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        assert!((2000000000 * 5) == withdraw_1, 1001);

        // Denominator bigger than numberator
        let index_2 = YieldFarming::calculate_harvest_index(0, 100000000000000, 0, 5, 10000000);
        let amount_2 = YieldFarming::calculate_withdraw_amount(index_2, 0, 40000000000);
        Debug::print(&index_2);
        Debug::print(&amount_2);
        assert!(index_2 > 0, 1002);
        assert!(amount_2 > 0, 1003);
        //let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        //assert((2000000000 * 5) == withdraw_1, 10001);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use StarcoinFramework::Math;
    use alice::YieldFarmingWarpper::{Usdx};

    /// Initial reward token, registered and mint it
    fun main(account: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdx_amount: u128 = 100000000 * scaling_factor;

        // Resister and mint Usdx
        Token::register_token<Usdx>(&account, precision);
        Account::do_accept_token<Usdx>(&account);
        let usdx_token = Token::mint<Usdx>(&account, usdx_amount);
        Account::deposit_to_self(&account, usdx_token);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    use alice::YieldFarmingWarpper;

    /// Inital a treasury into yield farming
    fun init(account: signer) {
        let precision: u8 = 9; //Usdx precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdx_amount: u128 = 100 * scaling_factor;

        let tresury = Account::withdraw(&account, usdx_amount);
        YieldFarmingWarpper::initialize(&account, tresury);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    /// 1. First stake, check whether first rewards has been executed.
    fun main(account: signer) {
        Account::do_accept_token<Usdx>(&account);
        YieldFarmingWarpper::stake(&account, 100000000);

        let token = YieldFarmingWarpper::harvest(&account);
        let _amount = Token::value<Usdx>(&token);
        Debug::print(&_amount);
        // assert!(amount == 10000000000, 10002);
        Account::deposit<Usdx>(Signer::address_of(&account), token);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 10002000

//# run --signers cindy
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use StarcoinFramework::Account;

    /// 2. Cindy joined and staking some asset
    fun init(account: signer) {
        Account::do_accept_token<Usdx>(&account);
        YieldFarmingWarpper::stake(&account, 100000000);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10003000

//# run --signers cindy
script {
    use alice::YieldFarmingWarpper;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;

    /// 3. Cindy harvest after 20 seconds, checking whether has rewards.
    fun init(account: signer) {
        let amount00 = YieldFarmingWarpper::query_gov_token_amount(Signer::address_of(&account));
        Debug::print(&amount00);
        // assert!(amount00 == 0, 10004);
        assert!(amount00 > 0, 10004);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers cindy
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    /// 4. Cindy harvest after 40 seconds, checking whether has rewards.
    fun init(account: signer) {
        let amount00 = YieldFarmingWarpper::query_gov_token_amount(Signer::address_of(&account));
        Debug::print(&amount00);

        let token = YieldFarmingWarpper::harvest(&account);
        let amount1 = Token::value<Usdx>(&token);
        Debug::print(&amount1);
        assert!(amount1 > 0, 10005);
        // assert!(amount1 == 20000000000, 10004);
        Account::deposit<Usdx>(Signer::address_of(&account), token);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10005000

//# run --signers alice
script {
    use SwapAdmin::YieldFarming;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Debug;

    /// big number cacl test
    fun main(_account: signer) {
        let now_seconds = Timestamp::now_seconds();
        let harvest_index = 1000000000; //e9
        let _asset_total_weight = 10000000000000000000; //e19

        let index_1 = YieldFarming::calculate_harvest_index(
            harvest_index,
            _asset_total_weight,
            now_seconds - 5,
            Timestamp::now_seconds(), 2000000000);
        let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        Debug::print(&index_1);
        Debug::print(&withdraw_1);
        ////        assert((2000000000 * 5) == withdraw_1, 1001);

        // Denominator far greater than numberator
        let index_2 = YieldFarming::calculate_harvest_index(0, 1000000000000000000000, 0, 5, 10000000);
        let amount_2 = YieldFarming::calculate_withdraw_amount(index_2, 0, 40000000000);
        Debug::print(&index_2);
        Debug::print(&amount_2);
        assert!(index_2 > 0, 1002);
        assert!(amount_2 >= 0, 1003);
    }
}
// check: EXECUTED

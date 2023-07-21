/// The module used to create user resource account for Liquidswap and deploy LP coins under that account.
module collectibleswap::collectibleswap_lp_account {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    /// When called from wrong account.
    const ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE: u64 = 1701;
    const MARKET_ALREADY_INITIALIZED: u64 = 1018;

    /// Temporary storage for user resource account signer capability.
    struct PoolAccountCap has key { signer_cap: SignerCapability }

    public entry fun initialize_lp_account(collectibleswap_admin: &signer, liquidity_coin_metadata_serialized: vector<u8>, liquidity_coin_code: vector<u8>) {
        assert!(signer::address_of(collectibleswap_admin) == @collectibleswap, ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE);
        assert!(!exists<PoolAccountCap>(@collectibleswap), MARKET_ALREADY_INITIALIZED);
        let (pool_account, signer_cap) =
            account::create_resource_account(collectibleswap_admin, b"collectibleswap_resource_account_seed");

        aptos_framework::code::publish_package_txn(
            &pool_account,
            liquidity_coin_metadata_serialized,
            vector[liquidity_coin_code]
        );
        move_to(collectibleswap_admin, PoolAccountCap { signer_cap });
    }

    /// Destroys temporary storage for resource account signer capability and returns signer capability.
    /// It needs for initialization of liquidswap.
    public fun retrieve_signer_cap(collectibleswap_admin: &signer): SignerCapability acquires PoolAccountCap {
        assert!(signer::address_of(collectibleswap_admin) == @collectibleswap, ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE);
        let PoolAccountCap { signer_cap } =
            move_from<PoolAccountCap>(signer::address_of(collectibleswap_admin));
        signer_cap
    }
}

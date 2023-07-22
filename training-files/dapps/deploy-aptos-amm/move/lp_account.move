module init::lp_account {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    /// Temporary storage for resource account signer capability.
    struct CapabilityStorage has key { signer_cap: SignerCapability }

    /// Creates new resource account, puts signer capability into storage
    public entry fun initialize_lp_account(
        manager: &signer,
        lp_coin_metadata_serialized: vector<u8>,
        lp_coin_code: vector<u8>
    ) {
        assert!(signer::address_of(manager) == @init, 0);

        let (lp_acc, signer_cap) =
            account::create_resource_account(manager, b"my_seed");
        aptos_framework::code::publish_package_txn(
            &lp_acc,
            lp_coin_metadata_serialized,
            vector[lp_coin_code]
        );
        move_to(manager, CapabilityStorage { signer_cap });
    }

    /// Destroys temporary storage for resource account signer capability and returns signer capability.
    /// It needs for initialization of Thala AMM.
    public fun retrieve_signer_cap(manager: &signer): SignerCapability acquires CapabilityStorage {
        assert!(signer::address_of(manager) == @init, 0);
        let CapabilityStorage { signer_cap } =
            move_from<CapabilityStorage>(signer::address_of(manager));
        signer_cap
    }

    #[test]
    fun test_resource_account() {
        account::create_account_for_test(@init);
        let addr = account::create_resource_address(&@init, b"my_seed");
        std::debug::print(&addr);
    }
}
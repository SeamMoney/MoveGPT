```rust
/// Initializes resource account to deploy the SatayCoins package
/// Temporarily stores the SignerCapability for the resource account in the satay account
/// Signer cap is later extracted by the Satay package
module satay::satay_account {
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};

    /// when the protected functions are called by an invalid signer
    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1;

    /// temporary storage for deployer resource account SignerCapability
    /// @field signer_cap - SignerCapability for VaultCoin resource account
    struct CapabilityStorage has key { signer_cap: SignerCapability }

    /// creates a resource account for Satay, deploys the SatayCoins package, and stores the SignerCapability
    /// @param satay - the transaction signer; must be the deployer account
    /// @param satay_coins_metadata_serialized - serialized metadata for the SatayCoins package
    /// @param satay_coins_code - compiled code for the SatayCoins package
    public entry fun initialize_satay_account(
        satay: &signer,
        satay_coins_metadata_serialized: vector<u8>,
        satay_coins_code: vector<vector<u8>>
    ) {
        assert!(signer::address_of(satay) == @satay, ERR_NOT_ENOUGH_PERMISSIONS);

        // this function will abort if initialize_satay_account is called twice
        let (satay_acc, signer_cap) = account::create_resource_account(satay, b"satay");

        aptos_framework::code::publish_package_txn(
            &satay_acc,
            satay_coins_metadata_serialized,
            satay_coins_code
        );

        move_to(satay, CapabilityStorage { signer_cap });
    }

    /// destroys temporary storage for resource account SignerCapability and returns SignerCapability; called by satay::initialize
    /// @param satay - the transaction signer; must be the deployer account
    public fun retrieve_signer_cap(satay: &signer): SignerCapability
    acquires CapabilityStorage {
        assert!(signer::address_of(satay) == @satay, ERR_NOT_ENOUGH_PERMISSIONS);
        let CapabilityStorage {
            signer_cap
        } = move_from<CapabilityStorage>(signer::address_of(satay));
        signer_cap
    }
}
```
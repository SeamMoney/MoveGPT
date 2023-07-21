/// A coin faucet for the Aptos devnet.
/// 
/// # Setup
/// 
/// To update this repo, run `cargo run --bin setup && ./scripts/init_tokens.sh`.

module faucet::faucet {
    use aptos_framework::account::{Self, SignerCapability};
    use deployer::deployer;

    friend faucet::dev_coin;

    /// Faucet configuration.
    struct FaucetConfiguration has key {
        /// Signer capability of the Faucet address.
        signer_cap: SignerCapability,
        /// Address which will become the Mint Wrapper Minter.
        minter: address
    }

    /// Initializes the [Faucet].
    public entry fun initialize(faucet: &signer, minter: address) {
        let signer_cap = deployer::retrieve_resource_account_cap(faucet);
        move_to(faucet, FaucetConfiguration {
            signer_cap,
            minter
        });
    }

    /// Gets the signer of the module.
    public(friend) fun get_signer(): signer acquires FaucetConfiguration {
        let signer_cap = &borrow_global<FaucetConfiguration>(@faucet).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    /// Gets the minter which will mint coins in this faucet.
    public fun get_minter(): address acquires FaucetConfiguration {
        borrow_global<FaucetConfiguration>(@faucet).minter
    }
}

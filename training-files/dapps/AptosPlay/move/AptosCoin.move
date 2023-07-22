/// The module to show how to create a new coin on Aptos network.
module Sender::AptosCoin {
    use Std::ASCII::string;
    use AptosFramework::Coin::Self;
    use Std::Signer;

    // Errors.

    /// When capability is missed on account.
    const ERR_CAP_MISSED: u64 = 100;

    /// When capability already exists on account.
    const ERR_CAP_EXISTS: u64 = 101;

    /// Represents new user coin.
    /// Indeeed this type will be used as CoinType for your new coin.
    struct MyCoin {}

    /// The struct to store capability: mint and burn.
    struct Capability<CapType: store> has key {
        cap: CapType
    }

    /// Initializing `MyCoin` as coin in Aptos network.
    public fun initialize_internal(account: &signer) {
        // Initialize `MyCoin` as coin type using Aptos Framework.
        let (mint_cap, burn_cap) = Coin::initialize<MyCoin>(
            account,
            string(b"MyCoin"),
            string(b"MC"),
            10,
            true,
        );

        // Store mint and burn capabilities under user account.
        move_to(account, Capability { cap: mint_cap });
        move_to(account, Capability { cap: burn_cap });
    }

    /// Similar to `initialize_internal` but can be executed as script.
    public(script) fun initialize(account: &signer) {
        initialize(account);
    }

    /// Extract mint or burn capability from user account.
    /// Returns extracted capability.
    public fun extract_capability<CapType: store>(account: &signer): CapType acquires Capability {
        let account_addr = Signer::address_of(account);

        // Check if capability stored under account.
        assert!(exists<Capability<CapType>>(account_addr), ERR_CAP_MISSED);

        // Get capability stored under account.
        let Capability { cap } =  move_from<Capability<CapType>>(account_addr);
        cap
    }

    /// Put mint or burn `capability` under user account.
    public fun put_capability<CapType: store>(account: &signer, capability: CapType) {
        let account_addr = Signer::address_of(account);

        // Check if capability doesn't exist under account so we can store.
        assert!(!exists<Capability<CapType>>(account_addr), ERR_CAP_EXISTS);

        // Store capability.
        move_to(account, Capability<CapType> {
            cap: capability
        });
    }
}
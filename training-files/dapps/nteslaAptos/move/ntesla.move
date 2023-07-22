address admin {

module nteslatoken {
    use aptos_framework::coin;
    use std::signer;
    use std::string;
    use std::error;
    use std::option::{Self, Option};

    //use aptos_framework::account;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_framework::optional_aggregator::{Self, OptionalAggregator};
    use aptos_framework::system_addresses;

    use aptos_std::type_info;

    //friend aptos_framework::aptos_coin;
    //friend aptos_framework::genesis;

        //
    // Errors.
    //

    /// Address of account which is used to initialize a coin `NTesla` doesn't match the deployer of module
    const ECOIN_INFO_ADDRESS_MISMATCH: u64 = 1;

    /// `NTesla` is already initialized as a coin
    const ECOIN_INFO_ALREADY_PUBLISHED: u64 = 2;

    /// `NTesla` hasn't been initialized as a coin
    const ECOIN_INFO_NOT_PUBLISHED: u64 = 3;

    /// Account already has `CoinStore` registered for `NTesla`
    const ECOIN_STORE_ALREADY_PUBLISHED: u64 = 4;

    /// Account hasn't registered `CoinStore` for `NTesla`
    const ECOIN_STORE_NOT_PUBLISHED: u64 = 5;

    /// Not enough coins to complete transaction
    const EINSUFFICIENT_BALANCE: u64 = 6;

    /// Cannot destroy non-zero coins
    const EDESTRUCTION_OF_NONZERO_TOKEN: u64 = 7;

    /// Coin amount cannot be zero
    const EZERO_COIN_AMOUNT: u64 = 9;

    /// CoinStore is frozen. Coins cannot be deposited or withdrawn
    const EFROZEN: u64 = 10;

    /// Cannot upgrade the total supply of coins to different implementation.
    const ECOIN_SUPPLY_UPGRADE_NOT_SUPPORTED: u64 = 11;

    /// Name of the coin is too long
    const ECOIN_NAME_TOO_LONG: u64 = 12;

    /// Symbol of the coin is too long
    const ECOIN_SYMBOL_TOO_LONG: u64 = 13;

    const E_NO_ADMIN: u64 = 14;
    const E_NO_CAPABILITIES: u64 = 15;
    const E_HAS_CAPABILITIES: u64 = 16;

    //
    // Constants
    //

    const MAX_COIN_NAME_LENGTH: u64 = 32;
    const MAX_COIN_SYMBOL_LENGTH: u64 = 10;

    /// Core data structures

    /// Main structure representing a coin/token in an account's custody.
    struct Coin<phantom NTesla> has store {
        /// Amount of coin this address has.
        value: u64,
    }

    /// A holder of a specific coin types and associated event handles.
    /// These are kept in a single resource to ensure locality of data.
    struct CoinStore<phantom NTesla> has key {
        coin: Coin<NTesla>,
        frozen: bool,
        deposit_events: EventHandle<DepositEvent>,
        withdraw_events: EventHandle<WithdrawEvent>,
    }

    /// Maximum possible coin supply.
    const MAX_U128: u128 = 340282366920938463463374607431768211455;

    /// Configuration that controls the behavior of total coin supply. If the field
    /// is set, coin creators are allowed to upgrade to parallelizable implementations.
    struct SupplyConfig has key {
        allow_upgrades: bool,
    }

    /// Information about a specific coin type. Stored on the creator of the coin's account.
    struct CoinInfo<phantom NTesla> has key {
        name: string::String,
        /// Symbol of the coin, usually a shorter version of the name.
        /// For example, Singapore Dollar is SGD.
        symbol: string::String,
        /// Number of decimals used to get its user representation.
        /// For example, if `decimals` equals `2`, a balance of `505` coins should
        /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
        decimals: u8,
        /// Amount of this coin type in existence.
        supply: Option<OptionalAggregator>,
    }

    /// Event emitted when some amount of a coin is deposited into an account.
    struct DepositEvent has drop, store {
        amount: u64,
    }

    /// Event emitted when some amount of a coin is withdrawn from an account.
    struct WithdrawEvent has drop, store {
        amount: u64,
    }

    /// Capability required to mint coins.
    struct MintCapability<phantom NTesla> has copy, store {}

    /// Capability required to freeze a coin store.
    struct FreezeCapability<phantom NTesla> has copy, store {}

    /// Capability required to burn coins.
    struct BurnCapability<phantom NTesla> has copy, store {}


    struct NTesla{}

    struct CoinCapabilities<phantom NTesla> has key {
        mint_capability: coin::MintCapability<NTesla>,
        burn_capability: coin::BurnCapability<NTesla>,
        freeze_capability: coin::FreezeCapability<NTesla>,
    }

    /// Publishes supply configuration. Initially, upgrading is not allowed.
    /*
    public(friend) fun initialize_supply_config(aptos_framework: &signer) {
        system_addresses::assert_aptos_framework(aptos_framework);
        move_to(aptos_framework, SupplyConfig { allow_upgrades: false });
    }
    */

    /// This should be called by on-chain governance to update the config and allow
    // or disallow upgradability of total supply.
    public fun allow_supply_upgrades(aptos_framework: &signer, allowed: bool) acquires SupplyConfig {
        system_addresses::assert_aptos_framework(aptos_framework);
        let allow_upgrades = &mut borrow_global_mut<SupplyConfig>(@aptos_framework).allow_upgrades;
        *allow_upgrades = allowed;
    }

    public entry fun init_ntesla(account: &signer) {
        let (burn_capability, freeze_capability, mint_capability) = coin::initialize<NTesla>(
            account,
            string::utf8(b"NTesla"),
            string::utf8(b"NTesla"),
            18,
            true,
        );

        assert!(signer::address_of(account) == @admin, E_NO_ADMIN);
        assert!(!exists<CoinCapabilities<NTesla>>(@admin), E_HAS_CAPABILITIES);

        move_to<CoinCapabilities<NTesla>>(account, CoinCapabilities<NTesla>{mint_capability, burn_capability, freeze_capability});
    }

    //
    // Getter functions
    //

    /// A helper function that returns the address of NTesla.
    fun coin_address<NTesla>(): address {
        let type_info = type_info::type_of<NTesla>();
        type_info::account_address(&type_info)
    }

    /// Returns the balance of `owner` for provided `NTesla`.
    public fun balance<NTesla>(owner: address): u64 acquires CoinStore {
        assert!(
            is_account_registered<NTesla>(owner),
            error::not_found(ECOIN_STORE_NOT_PUBLISHED),
        );
        borrow_global<CoinStore<NTesla>>(owner).coin.value
    }

    /// Returns `true` if the type `NTesla` is an initialized coin.
    public fun is_coin_initialized<NTesla>(): bool {
        exists<CoinInfo<NTesla>>(coin_address<NTesla>())
    }

    /// Returns `true` if `account_addr` is registered to receive `NTesla`.
    public fun is_account_registered<NTesla>(account_addr: address): bool {
        exists<CoinStore<NTesla>>(account_addr)
    }

    /// Returns the name of the coin.
    public fun name<NTesla>(): string::String acquires CoinInfo {
        borrow_global<CoinInfo<NTesla>>(coin_address<NTesla>()).name
    }

    /// Returns the symbol of the coin, usually a shorter version of the name.
    public fun symbol<NTesla>(): string::String acquires CoinInfo {
        borrow_global<CoinInfo<NTesla>>(coin_address<NTesla>()).symbol
    }

    /// Returns the number of decimals used to get its user representation.
    /// For example, if `decimals` equals `2`, a balance of `505` coins should
    /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
    public fun decimals<NTesla>(): u8 acquires CoinInfo {
        borrow_global<CoinInfo<NTesla>>(coin_address<NTesla>()).decimals
    }

    /// Returns the amount of coin in existence.
    public fun supply<NTesla>(): Option<u128> acquires CoinInfo {
        let maybe_supply = &borrow_global<CoinInfo<NTesla>>(coin_address<NTesla>()).supply;
        if (option::is_some(maybe_supply)) {
            // We do track supply, in this case read from optional aggregator.
            let supply = option::borrow(maybe_supply);
            let value = optional_aggregator::read(supply);
            option::some(value)
        } else {
            option::none()
        }
    }

    /*

    /// Burn `coin` from the specified `account` with capability.
    /// The capability `burn_cap` should be passed as a reference to `BurnCapability<NTesla>`.
    /// This function shouldn't fail as it's called as part of transaction fee burning.
    ///
    /// Note: This bypasses CoinStore::frozen -- coins within a frozen CoinStore can be burned.
    public fun burn_from<NTesla>(
        account_addr: address,
        amount: u64,
        burn_cap: &BurnCapability<NTesla>,
    ) acquires CoinInfo, CoinStore {
        // Skip burning if amount is zero. This shouldn't error out as it's called as part of transaction fee burning.
        if (amount == 0) {
            return
        };

        let coin_store = borrow_global_mut<CoinStore<NTesla>>(account_addr);
        let coin_to_burn = extract(&mut coin_store.coin, amount);
        burn(coin_to_burn, burn_cap);
    }

    // Public functions
    /// Burn `coin` with capability.
    /// The capability `_cap` should be passed as a reference to `BurnCapability<NTesla>`.
    public fun burn<NTesla>(
        coin: Coin<NTesla>,
        _cap: &BurnCapability<NTesla>,
    ) acquires CoinInfo {
        let Coin { value: amount } = coin;
        assert!(amount > 0, error::invalid_argument(EZERO_COIN_AMOUNT));

        let maybe_supply = &mut borrow_global_mut<CoinInfo<NTesla>>(coin_address<NTesla>()).supply;
        if (option::is_some(maybe_supply)) {
            let supply = option::borrow_mut(maybe_supply);
            optional_aggregator::sub(supply, (amount as u128));
        }
    }
    */

    public entry fun burn<NTesla>(coins: coin::Coin<NTesla>) acquires CoinCapabilities {
        let burn_capability = &borrow_global<CoinCapabilities<NTesla>>(@admin).burn_capability;
        coin::burn<NTesla>(coins, burn_capability);
    }


    /// Deposit the coin balance into the recipient's account and emit an event.
    public fun deposit<NTesla>(account_addr: address, coin: Coin<NTesla>) acquires CoinStore {
        assert!(
            is_account_registered<NTesla>(account_addr),
            error::not_found(ECOIN_STORE_NOT_PUBLISHED),
        );

        let coin_store = borrow_global_mut<CoinStore<NTesla>>(account_addr);
        assert!(
            !coin_store.frozen,
            error::permission_denied(EFROZEN),
        );

        event::emit_event<DepositEvent>(
            &mut coin_store.deposit_events,
            DepositEvent { amount: coin.value },
        );

        merge(&mut coin_store.coin, coin);
    }

    /// Destroys a zero-value coin. Calls will fail if the `value` in the passed-in `token` is non-zero
    /// so it is impossible to "burn" any non-zero amount of `Coin` without having
    /// a `BurnCapability` for the specific `NTesla`.
    public fun destroy_zero<NTesla>(zero_coin: Coin<NTesla>) {
        let Coin { value } = zero_coin;
        assert!(value == 0, error::invalid_argument(EDESTRUCTION_OF_NONZERO_TOKEN))
    }

    /// Extracts `amount` from the passed-in `coin`, where the original token is modified in place.
    public fun extract<NTesla>(coin: &mut Coin<NTesla>, amount: u64): Coin<NTesla> {
        assert!(coin.value >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
        coin.value = coin.value - amount;
        Coin { value: amount }
    }

    /// Extracts the entire amount from the passed-in `coin`, where the original token is modified in place.
    public fun extract_all<NTesla>(coin: &mut Coin<NTesla>): Coin<NTesla> {
        let total_value = coin.value;
        coin.value = 0;
        Coin { value: total_value }
    }

    /// Freeze a CoinStore to prevent transfers
    public entry fun freeze_coin_store<NTesla>(
        account_addr: address,
        _freeze_cap: &FreezeCapability<NTesla>,
    ) acquires CoinStore {
        let coin_store = borrow_global_mut<CoinStore<NTesla>>(account_addr);
        coin_store.frozen = true;
    }

    /// Unfreeze a CoinStore to allow transfers
    public entry fun unfreeze_coin_store<NTesla>(
        account_addr: address,
        _freeze_cap: &FreezeCapability<NTesla>,
    ) acquires CoinStore {
        let coin_store = borrow_global_mut<CoinStore<NTesla>>(account_addr);
        coin_store.frozen = false;
    }

    /// Upgrade total supply to use a parallelizable implementation if it is
    /// available.
    public entry fun upgrade_supply<NTesla>(account: &signer) acquires CoinInfo, SupplyConfig {
        let account_addr = signer::address_of(account);

        // Only coin creators can upgrade total supply.
        assert!(
            coin_address<NTesla>() == account_addr,
            error::invalid_argument(ECOIN_INFO_ADDRESS_MISMATCH),
        );

        // Can only succeed once on-chain governance agreed on the upgrade.
        assert!(
            borrow_global_mut<SupplyConfig>(@aptos_framework).allow_upgrades,
            error::permission_denied(ECOIN_SUPPLY_UPGRADE_NOT_SUPPORTED)
        );

        let maybe_supply = &mut borrow_global_mut<CoinInfo<NTesla>>(account_addr).supply;
        if (option::is_some(maybe_supply)) {
            let supply = option::borrow_mut(maybe_supply);

            // If supply is tracked and the current implementation uses an integer - upgrade.
            if (!optional_aggregator::is_parallelizable(supply)) {
                optional_aggregator::switch(supply);
            }
        }
    }

    /// "Merges" the two given coins.  The coin passed in as `dst_coin` will have a value equal
    /// to the sum of the two tokens (`dst_coin` and `source_coin`).
    public entry fun merge<NTesla>(dst_coin: &mut Coin<NTesla>, source_coin: Coin<NTesla>) {
        spec {
            assume dst_coin.value + source_coin.value <= MAX_U64;
        };
        dst_coin.value = dst_coin.value + source_coin.value;
        let Coin { value: _ } = source_coin;
    }

    public entry fun mint<NTesla>(account: &signer, user: address, amount: u64) acquires CoinCapabilities {
        let account_address = signer::address_of(account);
        assert!(account_address == @admin, E_NO_ADMIN);
        assert!(exists<CoinCapabilities<NTesla>>(account_address), E_NO_CAPABILITIES);
        let mint_capability = &borrow_global<CoinCapabilities<NTesla>>(account_address).mint_capability;
        let coins = coin::mint<NTesla>(amount, mint_capability);
        coin::deposit(user, coins)
    }

    /*
    /// Mint new `Coin` with capability.
    /// The capability `_cap` should be passed as reference to `MintCapability<CoinType>`.
    /// Returns minted `Coin`.
    public entry fun mint<NTesla>(
        account: &signer,
        amount: u64,
        _cap: &MintCapability<NTesla>,
    ): Coin<NTesla> acquires CoinInfo {
        if (amount == 0) {
            return zero<NTesla>()
        };
        
        let account_address = signer::address_of(account);
        assert!(account_address == @admin, E_NO_ADMIN);
        assert!(exists<CoinCapabilities<NTesla>>(account_address), E_NO_CAPABILITIES);

        let maybe_supply = &mut borrow_global_mut<CoinInfo<NTesla>>(coin_address<NTesla>()).supply;
        if (option::is_some(maybe_supply)) {
            let supply = option::borrow_mut(maybe_supply);
            optional_aggregator::add(supply, (amount as u128));
        };

        Coin<NTesla> { value: amount }
    }
    */

    /// Transfers `amount` of coins `NTesla` from `from` to `to`.
    public entry fun transfer<NTesla>(
        from: &signer,
        to: address,
        amount: u64,
    ) acquires CoinStore {
        let coin = withdraw<NTesla>(from, amount);
        deposit(to, coin);
    }

    /// Returns the `value` passed in `coin`.
    public fun value<NTesla>(coin: &Coin<NTesla>): u64 {
        coin.value
    }

    /// Withdraw specifed `amount` of coin `NTesla` from the signing account.
    public fun withdraw<NTesla>(
        account: &signer,
        amount: u64,
    ): Coin<NTesla> acquires CoinStore {
        let account_addr = signer::address_of(account);
        assert!(
            is_account_registered<NTesla>(account_addr),
            error::not_found(ECOIN_STORE_NOT_PUBLISHED),
        );

        let coin_store = borrow_global_mut<CoinStore<NTesla>>(account_addr);
        assert!(
            !coin_store.frozen,
            error::permission_denied(EFROZEN),
        );

        event::emit_event<WithdrawEvent>(
            &mut coin_store.withdraw_events,
            WithdrawEvent { amount },
        );

        extract(&mut coin_store.coin, amount)
    }

    /// Create a new `Coin<NTesla>` with a value of `0`.
    public fun zero<NTesla>(): Coin<NTesla> {
        Coin<NTesla> {
            value: 0
        }
    }

    /// Destroy a freeze capability. Freeze capability is dangerous and therefore should be destroyed if not used.
    public fun destroy_freeze_cap<NTesla>(freeze_cap: FreezeCapability<NTesla>) {
        let FreezeCapability<NTesla> {} = freeze_cap;
    }

    /// Destroy a mint capability.
    public fun destroy_mint_cap<NTesla>(mint_cap: MintCapability<NTesla>) {
        let MintCapability<NTesla> {} = mint_cap;
    }

    /// Destroy a burn capability.
    public fun destroy_burn_cap<NTesla>(burn_cap: BurnCapability<NTesla>) {
        let BurnCapability<NTesla> {} = burn_cap;
    }
}
}

/// This module supports functionality related to code management.
module aptos_framework::code {
    use std::string::String;
    use std::error;
    use std::signer;
    use std::vector;

    // ----------------------------------------------------------------------
    // Code Publishing

    /// The package registry at the given address.
    struct PackageRegistry has key {
        /// Packages installed at this address.
        packages: vector<PackageMetadata>,
    }

    /// Metadata for a package.
    struct PackageMetadata has store, copy, drop {
        /// Name of this package.
        name: String,
        /// The upgrade policy of this package.
        upgrade_policy: UpgradePolicy,
        /// The package manifest, in the Move.toml format.
        manifest: String,
        /// The list of modules installed by this package.
        modules: vector<ModuleMetadata>,
    }

    /// Metadata about a module in a package.
    struct ModuleMetadata has store, copy, drop {
        /// Name of the module.
        name: String,
        /// Source text.
        source: String,
        /// Source map, in internal encoding
        source_map: vector<u8>,
        /// ABI, in JSON byte encoding.
        abi: vector<u8>,
    }

    /// Describes an upgrade policy
    struct UpgradePolicy has store, copy, drop {
        policy: u8
    }

    /// A package is attempted to publish with module names clashing with modules published by other packages on this
    /// address.
    const EMODULE_NAME_CLASH: u64 = 0x1;

    /// A package is attempted to upgrade which is marked as immutable.
    const EUPGRADE_IMMUTABLE: u64 = 0x2;

    /// A package is attempted to upgrade with a weaker policy than previously.
    const EUPGRADE_WEAKER_POLICY: u64 = 0x3;

    /// Whether unconditional code upgrade with no compatibility check is allowed. This
    /// publication mode should only be used for modules which aren't shared with user others.
    /// The developer is responsible for not breaking memory layout of any resources he already
    /// stored on chain.
    public fun upgrade_policy_no_compat(): UpgradePolicy {
        UpgradePolicy{policy: 0}
    }

    /// Whether a compatibility check should be performed for upgrades. The check only passes if
    /// a new module has (a) the same public functions (b) for existing resources, no layout change.
    public fun upgrade_policy_compat(): UpgradePolicy {
        UpgradePolicy{policy: 1}
    }

    /// Whether the modules in the package are immutable and cannot be upgraded.
    public fun upgrade_policy_immutable(): UpgradePolicy {
        UpgradePolicy{policy: 2}
    }

    /// Whether the upgrade policy can be changed. In general, the policy can be only
    /// strengthened but not weakened.
    public fun can_change_upgrade_policy_to(from: UpgradePolicy, to: UpgradePolicy): bool {
        from.policy <= to.policy
    }

    /// Publishes a package at the given signer's address. The caller must provide package metadata describing the
    /// package.
    public fun publish_package(owner: &signer, pack: PackageMetadata, code: vector<vector<u8>>) acquires PackageRegistry {
        let addr = signer::address_of(owner);
        if (!exists<PackageRegistry>(addr)) {
            move_to(owner, PackageRegistry{packages: vector::empty()})
        };

        // Check package
        let module_names = get_module_names(&pack);
        let packages = &mut borrow_global_mut<PackageRegistry>(addr).packages;
        let len = vector::length(packages);
        let index = len;
        let i = 0;
        while (i < len) {
            let old = vector::borrow(packages, i);
            if (old.name == pack.name) {
                check_upgradability(old, &pack);
                index = i;
            } else {
                check_coexistence(old, &module_names)
            };
            i = i + 1;
        };

        // Update registry
        if (index < len) {
            *vector::borrow_mut(packages, index) = pack
        } else {
            vector::push_back(packages, pack)
        };

        // Request publish
        request_publish(addr, module_names, code, pack.upgrade_policy.policy)
    }

    /// Same as `publish_package` but as an entry function which can be called as a transaction. Because
    /// of current restrictions for txn parameters, the metadata needs to be passed in serialized form.
    public entry fun publish_package_txn(owner: &signer, pack_serialized: vector<u8>, code: vector<vector<u8>>)
    acquires PackageRegistry {
        publish_package(owner, from_bytes<PackageMetadata>(pack_serialized), code)
    }

    // Helpers
    // -------

    /// Checks whether the given package is upgradable, and returns true if a compatibility check is needed.
    fun check_upgradability(old_pack: &PackageMetadata, new_pack: &PackageMetadata) {
        assert!(old_pack.upgrade_policy.policy < upgrade_policy_immutable().policy,
            error::invalid_argument(EUPGRADE_IMMUTABLE));
        assert!(can_change_upgrade_policy_to( old_pack.upgrade_policy, new_pack.upgrade_policy),
            error::invalid_argument(EUPGRADE_WEAKER_POLICY));
    }

    /// Checks whether a new package with given names can co-exist with old package.
    fun check_coexistence(old_pack: &PackageMetadata, new_modules: &vector<String>) {
        // The modules introduced by each package must not overlap with `names`.
        let i = 0;
        while (i < vector::length(&old_pack.modules)) {
            let old_mod = vector::borrow(&old_pack.modules, i);
            let j = 0;
            while (j < vector::length(new_modules)) {
                let name = vector::borrow(new_modules, j);
                assert!(&old_mod.name != name, error::already_exists(EMODULE_NAME_CLASH))
            }
        }
    }

    /// Get the names of the modules in a package.
    fun get_module_names(pack: &PackageMetadata): vector<String> {
        let module_names = vector::empty();
        let i = 0;
        while (i < vector::length(&pack.modules)) {
            vector::push_back(&mut module_names, vector::borrow(&pack.modules, i).name);
            i = i + 1
        };
        module_names
    }

    /// Native function to initiate module loading
    native fun request_publish(
        owner: address,
        expected_modules: vector<String>,
        bundle: vector<vector<u8>>,
        policy: u8
    );

    /// Native function to deserialize a type T.
    /// TODO: may want to move it in extra module if needed also in other places inside of the Fx.
    /// However, should not make this function public outside of the Fx.
    native fun from_bytes<T: copy+drop>(bytes: vector<u8>): PackageMetadata;
}

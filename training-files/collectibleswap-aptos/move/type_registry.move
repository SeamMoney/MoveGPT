module collectibleswap::type_registry {
    use std::table;
    use std::signer;
    use std::string::String;
    use std::vector;
    use aptos_std::type_info:: {Self, TypeInfo};
    use std::account;
    use std::event;

    const ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE: u64 = 3000;
    const REGISTRY_ALREADY_INITIALIZED: u64 = 3001;
    const REGISTRY_NOT_INITIALIZED: u64 = 3002;
    const COLLECTION_ALREADY_REGISTERED: u64 = 3003;
    const COINTYPE_ALREADY_REGISTERED: u64 = 3004;
    const INVALID_REGISTRATION: u64 = 3005;
    const INVALID_COIN_OWNER: u64 = 3006;

    struct CollectionCoinType has store, copy, drop {
        collection: String,
        creator: address
    }

    struct TypeRegistry has key {
        collection_to_cointype: table::Table<CollectionCoinType, TypeInfo>,
        cointype_to_collection: table::Table<TypeInfo, CollectionCoinType>,
        collection_list: vector<CollectionCoinType>
    }

    struct RegisterEventStore has key {
        register_handle: event::EventHandle<RegisterEvent>
    }

    struct RegisterEvent has store, drop {
        coin_type_info: type_info::TypeInfo,
        collection: String,
        creator: address
    }
    public entry fun initialize_script(collectibleswap_admin: &signer) {
        assert!(signer::address_of(collectibleswap_admin) == @collectibleswap, ERR_NOT_ENOUGH_PERMISSIONS_TO_INITIALIZE);
        assert!(!exists<TypeRegistry>(@collectibleswap), REGISTRY_ALREADY_INITIALIZED);
        move_to(collectibleswap_admin, TypeRegistry { collection_to_cointype: table::new(), cointype_to_collection: table::new(), collection_list: vector::empty() });
        move_to(collectibleswap_admin, RegisterEventStore {
                register_handle: account::new_event_handle<RegisterEvent>(collectibleswap_admin),
            });
    }

    public fun register<CoinType>(collection: String, creator: address) acquires TypeRegistry, RegisterEventStore {
        assert!(exists<TypeRegistry>(@collectibleswap), REGISTRY_NOT_INITIALIZED);
        let registry = borrow_global_mut<TypeRegistry>(@collectibleswap);
        let collection_type = CollectionCoinType { collection: collection, creator: creator };
        assert!(!table::contains(&registry.collection_to_cointype, collection_type), COLLECTION_ALREADY_REGISTERED);

        vector::push_back(&mut registry.collection_list, collection_type);

        let ti = type_info::type_of<CoinType>();
        assert!(!table::contains(&registry.cointype_to_collection, ti), COINTYPE_ALREADY_REGISTERED);

        table::add(&mut registry.collection_to_cointype, collection_type, ti);
        table::add(&mut registry.cointype_to_collection, ti, collection_type);

        let event_store = borrow_global_mut<RegisterEventStore>(@collectibleswap);
        event::emit_event(
            &mut event_store.register_handle,
            RegisterEvent {
                coin_type_info: type_info::type_of<CoinType>(),
                collection,
                creator
            }
        )
    }

    // collection type metadata and code must be compiled under the sender account 
    public entry fun publish_collection_type_entry(account: &signer, collection_type_metadata_serialized: vector<u8>, collection_type_code: vector<u8>) {
        publish_collection_type(account, collection_type_metadata_serialized, collection_type_code);
    }

    public fun publish_collection_type(account: &signer, collection_type_metadata_serialized: vector<u8>, collection_type_code: vector<u8>) {
        aptos_framework::code::publish_package_txn(
            account,
            collection_type_metadata_serialized,
            vector[collection_type_code]
        );
    }

    public entry fun register_script<CoinType>(account: &signer, collection: String, creator: address) acquires TypeRegistry, RegisterEventStore {
        assert!(type_info::account_address(&type_info::type_of<CoinType>()) == signer::address_of(account), INVALID_COIN_OWNER);
        register<CoinType>(collection, creator)
    }

    public fun get_registered_cointype(collection: String, creator: address): TypeInfo acquires TypeRegistry {
        let registry = borrow_global<TypeRegistry>(@collectibleswap);
        let collection_type = CollectionCoinType { collection: collection, creator: creator };
        let ti = table::borrow(&registry.collection_to_cointype, collection_type);
        return *ti
    }

    public fun get_collection_cointype<CoinType>(): CollectionCoinType acquires TypeRegistry {
        let registry = borrow_global<TypeRegistry>(@collectibleswap);
        let ti = type_info::type_of<CoinType>();
        let collection_cointype = table::borrow(&registry.cointype_to_collection, ti);
        return *collection_cointype
    }

    public fun is_valid_registration<CoinType>(collection: String, creator: address): bool acquires TypeRegistry {
        let registry = borrow_global<TypeRegistry>(@collectibleswap);
        let collection_type = CollectionCoinType { collection: collection, creator: creator };
        if (!table::contains(&registry.collection_to_cointype, collection_type)) {
            return false
        };
        let registered_ti = table::borrow(&registry.collection_to_cointype, collection_type);
        return *registered_ti == type_info::type_of<CoinType>()
    }

    public fun assert_valid_cointype<CoinType>(collection: String, creator: address) acquires TypeRegistry {
        assert!(is_valid_registration<CoinType>(collection, creator), INVALID_REGISTRATION);
    }

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }
}
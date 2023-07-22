#[test_only]
module collectibleswap::type_registry_tests {
    use std::string::utf8;
    use collectibleswap::type_registry;
    use test_coin_admin::test_helpers;
    use test_coin_admin::test_helpers:: {CollectionType1};
    use aptos_std::type_info;

    fun initialize_collection_registry(admin: &signer) {
        type_registry::initialize_script(admin)
    }

    #[test]
    fun test_register_collection_type_success() {
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();
        initialize_collection_registry(&collectibleswap_admin);
        let collection = utf8(b"collection1");
        type_registry::register<CollectionType1>(collection, @test_token_creator);

        let ti = type_registry::get_registered_cointype(collection, @test_token_creator);
        assert!(ti == type_info::type_of<CollectionType1>(), 1);
        type_registry::assert_valid_cointype<CollectionType1>(collection, @test_token_creator)
    }

    #[test]
    #[expected_failure(abort_code=3003)]
    fun test_register_collection_type_failed() {
        let collectibleswap_admin = test_helpers::create_collectibleswap_admin();
        initialize_collection_registry(&collectibleswap_admin);
        type_registry::register<CollectionType1>(utf8(b"collection1"), @test_token_creator);
        type_registry::register<CollectionType1>(utf8(b"collection1"), @test_token_creator)
    }
}

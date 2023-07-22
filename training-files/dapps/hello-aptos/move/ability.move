module hello_aptos::resource {
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::coin;
    #[test_only]
    use aptos_framework::managed_coin;

    struct Aranoverse {}


    #[test(manager = @hello_aptos)]
    fun test_mint(manager: address){
        let signer = account::create_account_for_test(manager);
        managed_coin::initialize<Aranoverse>(&signer, b"Aranoverse", b"AVT", 18, true);

        coin::register<Aranoverse>(&signer);
        assert!(coin::is_coin_initialized<Aranoverse>(), 1);

        managed_coin::mint<Aranoverse>(&signer, manager, 100000000000);
        assert!(coin::balance<Aranoverse>(manager) == 100000000000, 2);

        // Could not compile , Cannot ignore values without the 'drop' ability. The value must be used
        // let _coin_resource = coin::withdraw<Aranoverse>(&signer, 100);
    }
}
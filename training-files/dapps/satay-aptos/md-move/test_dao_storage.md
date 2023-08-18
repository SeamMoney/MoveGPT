```rust
#[test_only]
module satay::test_dao_storage {

    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::account;

    use satay::global_config;
    use satay::dao_storage;
    use satay::test_coin::{Self, USDC};
    use satay::setup_tests;

    const ENO_STORAGE: u64 = 401;
    const ERR_DEPOSIT: u64 = 402;
    const ERR_WITHDRAW: u64 = 403;

    fun setup_tests(satay: &signer, vault: &signer) {
        setup_tests::setup_satay(satay);
        test_coin::register_coin<USDC>(satay);
        account::create_account_for_test(signer::address_of(vault));
        dao_storage::register<USDC>(vault);
    }

    #[test(satay=@satay, vault=@65)]
    fun test_register(satay: &signer, vault: &signer) {
        setup_tests(satay, vault);
        assert!(dao_storage::has_storage<USDC>(signer::address_of(vault)), ENO_STORAGE);
    }

    #[test(satay=@satay, vault=@65)]
    fun test_deposit(satay: &signer, vault: &signer) {
        setup_tests(satay, vault);
        let amount = 100;
        let vault_address = signer::address_of(vault);
        dao_storage::deposit<USDC>(vault_address, test_coin::mint<USDC>(satay, amount));
        assert!(dao_storage::balance<USDC>(vault_address) == amount, ERR_DEPOSIT);
    }

    #[test(satay=@satay, vault=@0x63, dao_admin=@0x64)]
    fun test_withdraw(satay: &signer, vault: &signer, dao_admin: &signer) {
        setup_tests(satay, vault);

        let amount = 100;
        let vault_address = signer::address_of(vault);
        dao_storage::deposit<USDC>(vault_address, test_coin::mint<USDC>(satay, amount));

        account::create_account_for_test(signer::address_of(dao_admin));
        global_config::set_dao_admin(satay, signer::address_of(dao_admin));
        global_config::accept_dao_admin(dao_admin);

        coin::register<USDC>(dao_admin);
        let witdraw_amount = 40;
        dao_storage::withdraw<USDC>(dao_admin, vault_address, witdraw_amount);

        assert!(coin::balance<USDC>(signer::address_of(dao_admin)) == witdraw_amount, ERR_WITHDRAW);
        assert!(dao_storage::balance<USDC>(vault_address) == amount - witdraw_amount, ERR_WITHDRAW);
    }

    #[test(satay=@satay, vault=@0x63, dao_admin=@0x64)]
    #[expected_failure]
    fun test_withdraw_non_dao_admin(satay: &signer, vault: &signer, dao_admin: &signer) {
        setup_tests(satay, vault);

        let vault_address = signer::address_of(vault);
        dao_storage::deposit<USDC>(vault_address, test_coin::mint<USDC>(satay, 100));

        account::create_account_for_test(signer::address_of(dao_admin));
        coin::register<USDC>(dao_admin);
        dao_storage::withdraw<USDC>(dao_admin, vault_address, 40);
    }
}

```
#[test_only]
module publisher::AptosCoin_Test {

    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::debug;
    use publisher::AptosCoin;

    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    #[test (account = @0x1)]
    #[expected_failure]
    public entry fun test_mint_coin_non_owner(account: &signer) {
        AptosCoin::publish_balance(account);
        AptosCoin::mint(account, @0x1, 100);
    }

    #[test (account = @0x0001000)]
    public entry fun test_mint_coin_owner(account: &signer) {
        let addr = signer::address_of(account);
        AptosCoin::publish_balance(account);
        // debug::print(&AptosCoin::get_balance(addr));
        AptosCoin::mint(account,@0x1000,100);
        // debug::print(&AptosCoin::get_balance(addr));
        assert!(AptosCoin::get_balance(addr) == 100, 0);
    }

    #[test (account = @0x1000)]
    public entry fun withdrawing_coins(account: &signer) {
        let addr = signer::address_of(account);
        let account_recv = get_account();
        let account_recv_addr = signer::address_of(&account_recv);
        debug::print(&addr);
        debug::print(&account_recv_addr);

        AptosCoin::publish_balance(account);
        AptosCoin::publish_balance(&account_recv);

        AptosCoin::mint(account, addr, 100);
        AptosCoin::transfer(account, account_recv_addr, 50);

        let balanceOfReciever = AptosCoin::get_balance(account_recv_addr);
        assert!(balanceOfReciever == 50,0);

        let balanceOfOwner = AptosCoin::get_balance(addr);
        assert!(balanceOfOwner == 50,0);
    }

}
module faucet::faucet_tests {
    use std::vector;
    use aptos_framework::account;
    use deployer::deployer;
    use faucet::faucet;

    use aptest::check;

    #[test(
        faucet_deployer = @faucet_deployer,
        faucet = @faucet,
    )]
    public entry fun test_faucet(
        faucet_deployer: signer,
        faucet: signer,
    ) {
        account::create_account(@faucet_deployer);
        deployer::create_resource_account(
            &faucet_deployer,
            b"faucet",
            vector::empty(),
        );
        faucet::initialize(&faucet, @0x12);
        check::eq(faucet::get_minter(), @0x12);
    }
}
#[test_only]
module test_vault::EscrowTests {
    use std::string;
    use std::signer;
    use std::unit_test;
    use std::vector;
    use aptos_framework::coin as Coin;

    use test_vault::Escrow;

    struct TestCoin1{}
    struct TestCoin2{}
    
    struct CoinCapabilities has key {
        mint_cap: Coin::MintCapability<TestCoin1>,
        burn_cap: Coin::BurnCapability<TestCoin1>,
    }
    
    struct CoinCapabilities2 has key {
        mint_cap: Coin::MintCapability<TestCoin2>,
        burn_cap: Coin::BurnCapability<TestCoin2>,
    }

    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    #[test(coin_owner = @test_vault)]
    public entry fun init_deposit_withdraw_escrow(coin_owner: signer) {
        let admin = get_account();
        let addr = signer::address_of(&admin);

        let name = string::utf8(b"Fake money");
        let symbol = string::utf8(b"FMD");

        let (mint_cap, burn_cap) = Coin::initialize<TestCoin1>(
            &coin_owner,
            name,
            symbol,
            18,
            true
        );
        Coin::register<TestCoin1>(&coin_owner);
        let coins_minted = Coin::mint<TestCoin1>(100000, &mint_cap);
        Coin::deposit(signer::address_of(&coin_owner), coins_minted);
        move_to(&coin_owner, CoinCapabilities {
            mint_cap,
            burn_cap
        });

        if (!Escrow::is_initialized_valut<TestCoin1>(addr)) {
            Escrow::init_escrow<TestCoin1>(&admin);
        };

        assert!(
          Escrow::get_vault_status<TestCoin1>(addr) == false,
          0
        );
        
        Escrow::pause_escrow<TestCoin1>(&admin);
        assert!(
          Escrow::get_vault_status<TestCoin1>(addr) == true,
          0
        );
        
        Escrow::resume_escrow<TestCoin1>(&admin);
        assert!(
          Escrow::get_vault_status<TestCoin1>(addr) == false,
          0
        );
        
        let user = get_account();
        let user_addr = signer::address_of(&user);

        if (!Coin::is_account_registered<TestCoin1>(user_addr)) {
            Coin::register<TestCoin1>(&user);
        };


        Coin::transfer<TestCoin1>(&coin_owner, user_addr, 10);

        Escrow::deposit<TestCoin1>(&user, 10, addr);
        assert!(
          Escrow::get_user_info<TestCoin1>(user_addr) == 10,
          1
        );

        Escrow::withdraw<TestCoin1>(&user, 10, addr);
        assert!(
          Escrow::get_user_info<TestCoin1>(user_addr) == 0,
          1
        );

        // ================================

        
        let name = string::utf8(b"Fake money2");
        let symbol = string::utf8(b"FMD2");

        let (mint_cap, burn_cap) = Coin::initialize<TestCoin2>(
            &coin_owner,
            name,
            symbol,
            18,
            true
        );
        Coin::register<TestCoin2>(&coin_owner);
        let coins_minted = Coin::mint<TestCoin2>(100000, &mint_cap);
        Coin::deposit(signer::address_of(&coin_owner), coins_minted);
        move_to(&coin_owner, CoinCapabilities2 {
            mint_cap,
            burn_cap
        });

        if (!Escrow::is_initialized_valut<TestCoin2>(addr)) {
            Escrow::init_escrow<TestCoin2>(&admin);
        };

        assert!(
          Escrow::get_vault_status<TestCoin2>(addr) == false,
          0
        );
        
        Escrow::pause_escrow<TestCoin2>(&admin);
        assert!(
          Escrow::get_vault_status<TestCoin2>(addr) == true,
          0
        );
        
        Escrow::resume_escrow<TestCoin2>(&admin);
        assert!(
          Escrow::get_vault_status<TestCoin2>(addr) == false,
          0
        );
        
        let user = get_account();
        let user_addr = signer::address_of(&user);

        if (!Coin::is_account_registered<TestCoin2>(user_addr)) {
            Coin::register<TestCoin2>(&user);
        };


        Coin::transfer<TestCoin2>(&coin_owner, user_addr, 10);

        Escrow::deposit<TestCoin2>(&user, 10, addr);
        assert!(
          Escrow::get_user_info<TestCoin2>(user_addr) == 10,
          1
        );

        Escrow::withdraw<TestCoin2>(&user, 10, addr);
        assert!(
          Escrow::get_user_info<TestCoin2>(user_addr) == 0,
          1
        );
    }
}

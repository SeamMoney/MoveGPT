// initialize
module my_address::MyCoin{
    use aptos_framework::coin;
    use aptos_framework::coin::{MintCapability, BurnCapability};
    use std::signer::address_of;
    use std::string;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

    struct USDT {}

    struct Cap<phantom CoinType> has key {
        mint:MintCapability<USDT>,
        burn:BurnCapability<USDT>,
    }

    public entry fun issue(sender:&signer)acquires Cap {
        let (b_cap,f_cap,m_cap) = coin::initialize<USDT>(
            sender,
            string::utf8(b"USDT Token"),
            string::utf8(b"USDT"),
            8,
            true
        );
        coin::destroy_freeze_cap(f_cap);

        move_to(sender,Cap<USDT>{
            mint:m_cap,
            burn:b_cap
        });

        coin::register<USDT>(sender);

        let cap = borrow_global_mut<Cap<USDT>>(address_of(sender));
        let mint_usdt = coin::mint(1000000000,&cap.mint);
        coin::deposit(address_of(sender),mint_usdt);
    }

    public entry fun register(sender:&signer){
        coin::register<USDT>(sender)
    }

    #[test(sender = @my_address)]
    fun issue_should_work(sender:&signer)acquires Cap {
        create_account_for_test(@my_address);
        issue(sender);
        assert!(coin::symbol<USDT>()==string::utf8(b"USDT"),0);
        assert!(coin::balance<USDT>(@my_address)==1000000000,0);
    }
}
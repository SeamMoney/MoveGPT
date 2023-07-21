#[test_only]
module swap_account::Coins{
    use aptos_framework::coin::{MintCapability, BurnCapability};
    use aptos_framework::coin;
    use std::string;
    use std::signer::address_of;
    use swap_account::SimplpSwap::{generate_lp_name_symbol, create_pool, pair_exist, add_liquiduty, LP, get_coin, remove_liquidity, swap_x_to_y, get_amount_out};
    use aptos_framework::account::create_account_for_test;
    use swap_account::Math::sqrt;
    use std::option;

    struct NB {}
    struct USDT {}

    struct Caps<phantom CoinType> has key {
        mint:MintCapability<CoinType>,
        burn:BurnCapability<CoinType>
    }

    public fun initialize_register_mint(sender:&signer) acquires Caps {
        let (burn_nb,freeze_nb,mint_nb) = coin::initialize<NB>(
            sender,
            string::utf8(b"nb token"),
            string::utf8(b"NB"),
            8,
            true
        );

        let (burn_usdt,freeze_usdt,mint_usdt) = coin::initialize<USDT>(
            sender,
            string::utf8(b"usdt token"),
            string::utf8(b"USDT"),
            6,
            true
        );

        coin::destroy_freeze_cap(freeze_nb);
        coin::destroy_freeze_cap(freeze_usdt);

        move_to(sender,Caps<NB>{
            mint:mint_nb,
            burn:burn_nb
        });

        move_to(sender,Caps<USDT>{
            mint:mint_usdt,
            burn:burn_usdt
        });

        coin::register<NB>(sender);
        coin::register<USDT>(sender);

        let caps = borrow_global<Caps<NB>>(address_of(sender));
        let nb = coin::mint(1000000000,&caps.mint);
        coin::deposit(address_of(sender),nb);

        let caps = borrow_global<Caps<USDT>>(address_of(sender));
        let usdt = coin::mint(1000000000,&caps.mint);
        coin::deposit(address_of(sender),usdt);

    }

    #[test(sender=@swap_account)]
    public fun test_should_work(sender:&signer) acquires Caps {
        create_account_for_test(@swap_account);
        initialize_register_mint(sender);
        assert!(coin::is_account_registered<NB>(address_of(sender)),0);
        assert!(coin::is_account_registered<USDT>(address_of(sender)),0);
        assert!(coin::balance<NB>(address_of(sender))==1000000000,0);
        assert!(coin::balance<USDT>(address_of(sender))==1000000000,0);
        assert!(coin::symbol<NB>() == string::utf8(b"NB"),0);
    }

    #[test(sender=@swap_account)]
    fun generate_lp_name_symbol_should_work(sender:&signer) acquires Caps {
        create_account_for_test(address_of(sender));
        initialize_register_mint(sender);
        let lp_name_symbol = generate_lp_name_symbol<NB,USDT>();
        assert!(string::utf8(b"LP-NB-USDT") == lp_name_symbol,0);
    }

    #[test(sender=@swap_account)]
    fun create_pool_should_work(sender:&signer) acquires Caps {
        create_account_for_test(@swap_account);
        initialize_register_mint(sender);
        create_pool<NB,USDT>(sender);
        assert!(pair_exist<NB,USDT>(@swap_account),0);
    }

    #[test(sender=@swap_account)]
    fun add_liquidity_should_work(sender:&signer) acquires Caps {
        create_account_for_test(@swap_account);
        initialize_register_mint(sender);
        assert!(coin::balance<NB>(@swap_account)==1000000000,0);
        assert!(coin::balance<USDT>(@swap_account)==1000000000,0);

        create_pool<NB,USDT>(sender);
        add_liquiduty<NB,USDT>(sender,1000000,1000000);

        assert!(coin::balance<NB>(@swap_account)==1000000000 - 1000000,0);
        assert!(coin::balance<USDT>(@swap_account)==1000000000 - 1000000,0);
        let (x_coin,y_coin) = get_coin<NB,USDT>();

        assert!(x_coin==1000000,0);
        assert!(y_coin==1000000,0);

        let estimate_liquidity1 = sqrt(1000000u128 * 1000000) - 1000;
        assert!(coin::balance<LP<NB,USDT>>(address_of(sender))== estimate_liquidity1,0);

        add_liquiduty<NB,USDT>(sender,1000,1000);
        let estimate_liquidity2 = 1000 * sqrt(1000000u128 * 1000000) / 1000000;
        assert!(coin::balance<LP<NB,USDT>>(address_of(sender))== estimate_liquidity1+estimate_liquidity2,0);
    }

    #[test(sender=@swap_account)]
    fun remove_liquidity_should_work(sender:&signer) acquires Caps {
        create_account_for_test(@swap_account);
        initialize_register_mint(sender);
        create_pool<NB,USDT>(sender);
        add_liquiduty<NB,USDT>(sender,1000000,1000000);

        let estimate_liquidity1 = sqrt(1000000u128 * 1000000) - 1000;
        assert!(coin::balance<LP<NB,USDT>>(address_of(sender))== estimate_liquidity1,0);

        add_liquiduty<NB,USDT>(sender,1000,1000);
        let estimate_liquidity2 = 1000 * sqrt(1000000u128 * 1000000) / 1000000;
        assert!(coin::balance<LP<NB,USDT>>(@swap_account)== estimate_liquidity1+estimate_liquidity2,0);

        let total_supply = *option::borrow(&coin::supply<LP<NB,USDT>>());
        let x_remove = 10 * (1000000u128+1000) / total_supply;
        let y_remove = 10 * (1000000u128+1000) / total_supply;

        remove_liquidity<NB,USDT>(sender,10);

        assert!(coin::balance<LP<NB,USDT>>(@swap_account) == estimate_liquidity1+estimate_liquidity2-10,0);
        assert!((coin::balance<NB>(@swap_account) as u128) == 1000000000 - 1000000 - 1000 + x_remove,0);
        assert!((coin::balance<USDT>(@swap_account) as u128) == 1000000000 - 1000000 - 1000 + y_remove,0);
    }

    #[test(sender=@swap_account)]
    fun swap_should_work(sender:&signer) acquires Caps {
        create_account_for_test(@swap_account);
        initialize_register_mint(sender);
        create_pool<NB,USDT>(sender);
        add_liquiduty<NB,USDT>(sender,1000000,1000000);

        swap_x_to_y<NB,USDT>(sender,100);
        let (in_reserve,out_reserve) = get_coin<NB,USDT>();
        let amount_out  = get_amount_out(100,(in_reserve as u128),(out_reserve as u128));

        assert!((coin::balance<NB>(@swap_account) as u128) == 1000000000 - 1000000 - 100,0);
        assert!((coin::balance<USDT>(@swap_account) as u128) == 1000000000 - 1000000 + amount_out,0);
    }

}

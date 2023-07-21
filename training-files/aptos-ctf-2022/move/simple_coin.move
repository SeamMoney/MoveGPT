module ctfmovement::simple_coin {
    use std::string;
    use std::signer;

    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability, FreezeCapability, Coin};
    use ctfmovement::math;
    friend ctfmovement::swap;

    const ENotAdmin: u64 = 1;
    const EInsufficientAmount: u64 = 2;

    struct SimpleCoin {}

    struct TestUSDC {}

    struct CoinCap<phantom X> has key {
        burn: BurnCapability<X>,
        mint: MintCapability<X>,
        freeze: FreezeCapability<X>,
    }

    /// Event emitted when user get the flag.
    struct Flag has drop, store {
        user: address,
        flag: bool
    }

    struct FlagHolder has key {
        event_set: event::EventHandle<Flag>,
    }

    public(friend) fun init(sender: &signer) {
        assert!(signer::address_of(sender) == @ctfmovement, ENotAdmin);
        let (burn, freeze, mint) = coin::initialize<SimpleCoin>(
            sender,
            string::utf8(b"SimpleCoin"),
            string::utf8(b"Simple"),
            6,
            true,
        );

        move_to(sender, CoinCap<SimpleCoin> {
            burn,
            mint,
            freeze,
        });

        let (burn, freeze, mint) = coin::initialize<TestUSDC>(
            sender,
            string::utf8(b"TestUSDC"),
            string::utf8(b"TestUSDC"),
            6,
            true,
        );

        move_to(sender, CoinCap<TestUSDC> {
            burn,
            mint,
            freeze,
        });
    }

    public(friend) fun mint<X>(amount: u64): Coin<X> acquires CoinCap {
        let cap = borrow_global<CoinCap<X>>(@ctfmovement);
        coin::mint(amount, &cap.mint)
    }


    public(friend) fun burn<X>(burn_coin: Coin<X>)  acquires CoinCap {
        let cap = borrow_global_mut<CoinCap<X>>(@ctfmovement);
        coin::burn(burn_coin, &cap.burn);
    }

    public fun claim_faucet(sender: &signer, amount: u64) acquires CoinCap {
        let coins = mint<TestUSDC>(amount);
        if (!coin::is_account_registered<TestUSDC>(signer::address_of(sender))) {
            coin::register<TestUSDC>(sender);
        };
        coin::deposit(signer::address_of(sender), coins);
    }

    public fun get_flag(sender: &signer) acquires FlagHolder {
        let simple_coin_balance = coin::balance<SimpleCoin>(signer::address_of(sender));
        if (simple_coin_balance > (math::pow(10u128, 10u8) as u64)) {
            let account_addr = signer::address_of(sender);
            if (!exists<FlagHolder>(account_addr)) {
                move_to(sender, FlagHolder {
                    event_set: account::new_event_handle<Flag>(sender),
                });
            };

            let flag_holder = borrow_global_mut<FlagHolder>(account_addr);
            event::emit_event(&mut flag_holder.event_set, Flag {
                user: account_addr,
                flag: true
            });
        } else {
            abort EInsufficientAmount
        }
    }
}
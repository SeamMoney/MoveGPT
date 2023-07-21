module coin_creator::liq {
    use std::signer;
    use std::string;

    use aptos_framework::coin::{Self, BurnCapability, MintCapability, Coin};

    // coin does not exist
    const ERR_NO_COIN: u64 = 100;

    struct LIQCoin {}

    struct LIQCoinCapabilities has key {
        burn_cap: BurnCapability<LIQCoin>,
        mint_cap: MintCapability<LIQCoin>,
    }

    public fun initialize(sender: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<LIQCoin>(
            sender,
            string::utf8(b"LIQCoin"),
            string::utf8(b"LIQ"),
            6,
            true
        );
        coin::destroy_freeze_cap(freeze_cap);

        move_to(sender, LIQCoinCapabilities {
            burn_cap,
            mint_cap,
        });
    }

    public fun mint(owner: &signer, amount: u64): Coin<LIQCoin> acquires LIQCoinCapabilities {
        let owner_address = signer::address_of(owner);
        assert!(exists<LIQCoinCapabilities>(owner_address), ERR_NO_COIN);

        let cap = borrow_global<LIQCoinCapabilities>(owner_address);

        coin::mint(amount, &cap.mint_cap)
    }

    public fun burn(owner: &signer, coins: Coin<LIQCoin>): u64 acquires LIQCoinCapabilities {
        let owner_address = signer::address_of(owner);
        assert!(exists<LIQCoinCapabilities>(owner_address), ERR_NO_COIN);

        let amount = coin::value<LIQCoin>(&coins);
        let cap = borrow_global<LIQCoinCapabilities>(owner_address);

        coin::burn<LIQCoin>(coins, &cap.burn_cap);
        amount
    }
}

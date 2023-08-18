```rust
module 0x1::football {
    use std::signer;

    // error code
    const STAR_AREADY_EXISTS: u64 = 100;
    const STAR_NOT_EXISTS: u64 = 101;

    struct FootBallStar has key {
        name: vector<u8>,
        country: vector<u8>,
        position: u8,
        value: u64,
    }

    public fun new_star(name: vector<u8>, country: vector<u8>, position: u8) : FootBallStar {
        FootBallStar {
            name,
            country,
            position,
            value: 0
        }
    }

    public fun mint(to: &signer, star: FootBallStar) {
        assert!(!exists<FootBallStar>(signer::address_of(to)), STAR_AREADY_EXISTS);

        move_to<FootBallStar>(to, star);
    }

    public fun get(owner:address): (vector<u8>, u64) acquires FootBallStar {
        let star = borrow_global<FootBallStar>(owner);

        (star.name, star.value)
    }

    public fun set_price(owner: address, price: u64) acquires FootBallStar {
        assert!(exists<FootBallStar>(owner), STAR_NOT_EXISTS);

        let star = borrow_global_mut<FootBallStar>(owner);

        star.value = price;
    }

    public fun transfer(owner: &signer, to: &signer) acquires FootBallStar {
        let owner_addr = signer::address_of(owner);
        assert!(exists<FootBallStar>(owner_addr), STAR_NOT_EXISTS);

        // nachulai move_from
        let star = move_from<FootBallStar>(owner_addr);
        star.value = star.value + 20;

        let to_addr = signer::address_of(to);
        assert!(exists<FootBallStar>(to_addr), STAR_NOT_EXISTS);

        move_to<FootBallStar>(to, star);
    }
}
```
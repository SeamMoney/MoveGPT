script {
    use std::signer;
    use 0x1::football;
    use std::debug;
    use aptos_framework::coin::{Self, Coin};

    fun test_football(owner: signer, to: signer) {
        let star = football::new_star(b"Yekai", b"Chain", 9);

        football::mint(&owner, star);

        let (name,val) = football::get(signer::address_of(&owner));
        debug::print(&name);
        debug::print(&val);

        football::set_price(signer::address_of(&owner), 100);

        let coins = Coin::mint(200);
        // chuangjian zhangben to
        Coin::register(&to);
        Coin::deposit(signer::address_of(&to), coins);

        coins = Coin::withdraw(signer::address_of(&to),100);

        // chuangjian zhangben owner
        Coin::create_balance(&owner);
        Coin::deposit(signer::address_of(&owner), coins);
        football::transfer(&owner, &to);

        (name,val) = football::get(signer::address_of(&to));
        debug::print(&name);
        debug::print(&val);
    }
}
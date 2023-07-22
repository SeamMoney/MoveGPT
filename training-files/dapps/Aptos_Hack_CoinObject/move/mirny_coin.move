module coin_objects::mirny_coin {
    use std::string::{Self, String};
    use coin_objects::coin;
    use coin_objects::mirny_token;

    use aptos_framework::object::{Self, CreatorRef, ObjectId};

    const SELLER:address = @0x225751338aaf9466d5571683c8a6fe311223aae83a06c2e302368b2ba997dfcb;
    const BUYER:address = @0x6177a48e9afacee44f652ccf5bb3a8b41799ed359782f591480e53737e6e8eb5;

    const MIRNY_OBJ:address = @0x5589e05915fca9a234fa87f07c311091f16c743d858803958284e982a5356759;
    const SELLER_OBJ:address = @0xccfde9839b2618d61ead7bb81ea1046dccbcc9c564f318d5be625a473603c824;
    const BUYER_OBJ:address = @0xbd0411797f1f8ff708136bb9238971d14ad251fd5245497db7f99fd4d369f6cd;

    const SELLER_INITIAL_BALANCE: u64 = 400;
    const BUYER_INITIAL_BALANCE: u64 = 3200;
    const SWAP_AMOUNT:u64 = 200;

    struct MirnyCoin {} 

    // struct CoinObjectCreateEvent has drop, store {
    //     objectId: ObjectId
    // }

    public entry fun mint(account: &signer) {
        // create seller coin object (balance : 0)
        let seller_coins_object_id = coin::mint_to<MirnyCoin>(
            account,
            SELLER,
            string::utf8(b"Mirny Coin"),
            string::utf8(b"MIR"),
            SELLER_INITIAL_BALANCE
        ); 
        mirny_token::mint_to(account, SELLER);

        let seller_coins_object_addr = object::object_id_address(&seller_coins_object_id);
        // objectId -> Event store
        // let seller_coins_obj = borrow_global<Coins<MirnyCoin>>(object::object_id_address(&seller_coins_object_id));

        // create mirny market coin object (balance : 0)
        let buyer_coins_object_id = coin::mint_to<MirnyCoin>(
            account,
            BUYER,
            string::utf8(b"Mirny Coin"),
            string::utf8(b"MIR"),
            BUYER_INITIAL_BALANCE
        );
        let buyer_coins_object_addr = object::object_id_address(&buyer_coins_object_id);

        // create buyer coin object (balance : 0)
        let mirny_coins_object_id = coin::mint<MirnyCoin>(
            account,
            string::utf8(b"Mirny Coin"),
            string::utf8(b"MIR"),
            0
        );
        let mirny_coins_object_addr = object::object_id_address(&mirny_coins_object_id);
    }

    public entry fun swap_middle(account: &signer) {
        swap(account, BUYER_OBJ, MIRNY_OBJ, SWAP_AMOUNT);
    }
    public entry fun swap_final (account: &signer) {
        swap(account, MIRNY_OBJ, SELLER_OBJ, SWAP_AMOUNT);
    }

    public fun swap(account: &signer, from: address, to: address, amount: u64) {
        // event -> objectId
        let coin_object = coin::withdraw<MirnyCoin>(account, amount, from);
        coin::deposit<MirnyCoin>(to, coin_object);
    }
}
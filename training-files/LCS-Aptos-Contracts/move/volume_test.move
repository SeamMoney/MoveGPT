#[test_only]
module lcs_aggregator::volume_test {

    use lcs_aggregator::volume;
    use std::signer;
    use std::vector;
    use aptos_std::type_info::type_of;
    use aptos_framework::coin::Coin;
    use coin_list::devnet_coins::{DevnetUSDC, DevnetUSDT};
    use aptos_std::type_info;

    fun initialize(admin: &signer, poster: &signer){
        volume::initialize(admin, signer::address_of(poster))
    }
    #[test(
        admin = @lcs_aggregator,
        poster = @poster
    )]
    fun test_initialize(admin: &signer, poster: &signer){
        initialize(admin, poster)
    }

    #[test(
        admin = @lcs_aggregator,
        poster = @poster,
        new_poster = @0x3
    )]
    fun test_set_poster(admin: &signer, poster: &signer, new_poster: &signer){
        initialize(admin, poster);
        volume::set_poster(admin, signer::address_of(new_poster))
    }
    fun post(poster: &signer){
        let coin_x = vector::empty<vector<u8>>();
        let coin_y = vector::empty<vector<u8>>();
        let amout = vector::empty<u64>();
        vector::push_back(&mut coin_x, type_info::struct_name(&type_of<Coin<DevnetUSDC>>()));
        vector::push_back(&mut coin_y, type_info::struct_name(&type_of<Coin<DevnetUSDT>>()));
        vector::push_back(&mut amout, 100);
        volume::post(
            poster,
            100,
            2000,
            2000,
            20000,
            10000,
            20000 + 60*60*1,
            100,
            coin_x,
            coin_y,
            amout,
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>()
        );
        volume::post(
            poster,
            120,
            2000,
            2000,
            20000,
            10000,
            20000 + 60*60*2,
            120,
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            vector::empty<u64>(),
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>()
        );
        volume::post(
            poster,
            150,
            2000,
            2000,
            21000,
            10000,
            21000 + 60*60,
            140,
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            vector::empty<u64>(),
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>(),
            vector::empty<u8>(),
            vector::empty<u64>()
        )
    }

    #[test(
        admin = @lcs_aggregator,
        poster = @poster
    )]
    fun test_post(admin: &signer, poster: &signer){
        initialize(admin, poster);
        post(poster)
    }
    #[test(
        admin = @lcs_aggregator,
        poster = @poster,
        poster_2 = @poster_2
    )]
    #[expected_failure(abort_code = 2)]
    fun test_post_fail(admin: &signer, poster: &signer, poster_2: &signer){
        initialize(admin, poster);
        post(poster_2)
    }


}

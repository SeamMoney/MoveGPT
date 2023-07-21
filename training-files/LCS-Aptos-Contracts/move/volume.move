module lcs_aggregator::volume {

    use std::signer;
    use std::vector;
    use std::string::String;
    use std::string;


    const E_NOT_ADMIN: u64 = 1;
    const E_NOT_POSTER: u64 = 2;
    const E_REPEAT_POST: u64 = 3;
    const E_VERCTOR_LENGT_NOT_EQUAL: u64 = 4;

    const VOLUME_HISTORY_LENGTH: u64 = 30;
    struct TotalVolume has drop, store, copy{
        start_time: u64,
        amount: u64
    }

    struct TradingPair has drop, store, copy{
        coin_x: String,
        coin_y: String,
        amount: u64
    }

    struct PoolProvider has drop, store, copy{
        dex_type: u8,
        amount: u64
    }
    struct Volume has key, copy{
        poster: address,
        total_volume: u128,
        last_24h_volume: u64,
        last_7d_volume: u64,
        // sequence number of data end
        data_end_sequence_number: u64,
        // time of data end
        data_end_time: u64,
        volume_decimals: u64,
        total_volume_history_24h:vector<TotalVolume>,
        total_volume_history_7d:vector<TotalVolume>,
        top_trading_pairs_24h:vector<TradingPair>,
        top_trading_pairs_7d:vector<TradingPair>,
        top_pool_provider_24h:vector<PoolProvider>,
        top_pool_provider_7d:vector<PoolProvider>,
    }


    #[cmd]
    public entry fun initialize(admin: &signer, poster: address){
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lcs_aggregator, E_NOT_ADMIN);
        move_to(admin, Volume{
            poster,
            total_volume: 0,
            last_24h_volume: 0,
            last_7d_volume: 0,
            data_end_sequence_number: 0,
            data_end_time: 0,
            volume_decimals: 4,
            total_volume_history_24h:vector::empty(),
            total_volume_history_7d:vector::empty(),
            top_trading_pairs_24h:vector::empty(),
            top_trading_pairs_7d:vector::empty(),
            top_pool_provider_24h:vector::empty(),
            top_pool_provider_7d:vector::empty()
        })
    }

    #[cmd]
    public entry fun set_poster(admin: &signer, new_poster: address) acquires Volume {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @lcs_aggregator, E_NOT_ADMIN);
        let volume = borrow_global_mut<Volume>(admin_addr);
        volume.poster = new_poster
    }
    public entry fun post_v2(
        poster: &signer,
        total_volume: u128,
        last_24_volume: u64,
        last_7d_volume: u64,
        data_end_time: u64,
        data_end_seauence_number: u64,

        total_volume_history_24h_start_time: vector<u64>,
        total_volume_history_24h_volume: vector<u64>,

        total_volume_history_7d_start_time: vector<u64>,
        total_volume_history_7d_volume: vector<u64>,

        trading_pairs_24h_coin_x: vector<vector<u8>>,
        trading_pairs_24h_coin_y: vector<vector<u8>>,
        trading_pairs_24h_amount: vector<u64>,

        trading_pairs_7d_coin_x: vector<vector<u8>>,
        trading_pairs_7d_coin_y: vector<vector<u8>>,
        trading_pairs_7d_amount: vector<u64>,

        pool_provider_24h_dex_type: vector<u8>,
        pool_provider_24h_amount: vector<u64>,

        pool_provider_7d_dex_type: vector<u8>,
        pool_provider_7d_amount: vector<u64>,
    ) acquires Volume{
        let volume = borrow_global_mut<Volume>(@lcs_aggregator);
        assert!(signer::address_of(poster) == volume.poster, E_NOT_POSTER);

        volume.total_volume = total_volume;
        volume.last_24h_volume = last_24_volume;
        volume.last_7d_volume = last_7d_volume;
        volume.data_end_time = data_end_time;
        volume.data_end_sequence_number = data_end_seauence_number;

        volume.top_trading_pairs_24h = parse_trading_pairs_vector(&trading_pairs_24h_coin_x, &trading_pairs_24h_coin_y, &trading_pairs_24h_amount);
        volume.top_trading_pairs_7d = parse_trading_pairs_vector(&trading_pairs_7d_coin_x, &trading_pairs_7d_coin_y, &trading_pairs_7d_amount);
        volume.top_pool_provider_24h = parse_pool_provider_vector(&pool_provider_24h_dex_type, &pool_provider_24h_amount);
        volume.top_pool_provider_7d = parse_pool_provider_vector(&pool_provider_7d_dex_type, &pool_provider_7d_amount);
        volume.total_volume_history_24h = parse_volume_history_vector(&total_volume_history_24h_start_time,&total_volume_history_24h_volume);
        volume.total_volume_history_7d = parse_volume_history_vector(&total_volume_history_7d_start_time,&total_volume_history_7d_volume);
    }
    public entry fun post(
        _poster: &signer,
        _amount: u64,
        _last_24_volume: u64,
        _last_7d_volume: u64,
        _round_start_time_24h: u64,
        _round_start_time_7d: u64,
        _new_data_end_time: u64,
        _new_data_end_seauence_number: u64,
        _trading_pairs_24h_coin_x: vector<vector<u8>>,
        _trading_pairs_24h_coin_y: vector<vector<u8>>,
        _trading_pairs_24h_amount: vector<u64>,
        _trading_pairs_7d_coin_x: vector<vector<u8>>,
        _trading_pairs_7d_coin_y: vector<vector<u8>>,
        _trading_pairs_7d_amount: vector<u64>,
        _pool_provider_24h_dex_type: vector<u8>,
        _pool_provider_24h_amount: vector<u64>,
        _pool_provider_7d_dex_type: vector<u8>,
        _pool_provider_7d_amount: vector<u64>
    ){
    }
    #[cmd]
    public entry fun clean(poster: &signer) acquires Volume{
        let volume = borrow_global_mut<Volume>(@lcs_aggregator);
        assert!(signer::address_of(poster) == volume.poster, E_NOT_POSTER);
        volume.total_volume = 0;
        volume.data_end_sequence_number = 0;
        volume.data_end_time = 0;
        volume.last_24h_volume = 0;
        volume.last_7d_volume = 0;
        volume.total_volume_history_24h = vector::empty();
        volume.total_volume_history_7d = vector::empty();
        volume.top_trading_pairs_24h = vector::empty();
        volume.top_trading_pairs_7d = vector::empty();
        volume.top_pool_provider_24h = vector::empty();
        volume.top_pool_provider_7d = vector::empty();
    }

    fun parse_trading_pairs_vector(
        coin_x_vector: &vector<vector<u8>>,
        coin_y_vector: &vector<vector<u8>>,
        amount_vector: &vector<u64>,
    ):vector<TradingPair>{
        let trading_pairs = vector::empty<TradingPair>();
        let i = 0;
        while (i < vector::length(coin_x_vector)){
            vector::push_back(&mut trading_pairs, TradingPair{
                coin_x: string::utf8(*vector::borrow(coin_x_vector, i)),
                coin_y: string::utf8(*vector::borrow(coin_y_vector, i)),
                amount:  *vector::borrow(amount_vector, i)
            });
            i = i+1;
        };
        trading_pairs
    }

    fun parse_volume_history_vector(
        start_time_vector: &vector<u64>,
        amount_vector: &vector<u64>,
    ):vector<TotalVolume>{
        let volume_history = vector::empty<TotalVolume>();
        let i = 0;
        while (i < vector::length(start_time_vector)){
            vector::push_back(&mut volume_history, TotalVolume{
                start_time: *vector::borrow(start_time_vector, i),
                amount: *vector::borrow(amount_vector, i)
            });
            i = i+1;
        };
        volume_history
    }

    fun parse_pool_provider_vector(
        dex_type_vector: &vector<u8>,
        amount_vector: &vector<u64>,
    ):vector<PoolProvider>{
        let pool_provider = vector::empty<PoolProvider>();
        let i = 0;
        while (i < vector::length(dex_type_vector)){
            vector::push_back(&mut pool_provider, PoolProvider{
                dex_type: *vector::borrow(dex_type_vector, i),
                amount: *vector::borrow(amount_vector, i)
            });
            i = i+1;
        };
        pool_provider
    }

    fun add_volume(total_volume_array: &mut vector<TotalVolume>, round_start_time: u64, amount: u64){
        let array_length = vector::length(total_volume_array);
        if (array_length == 0){
            vector::push_back(total_volume_array,TotalVolume{
                start_time: round_start_time,
                amount
            });
            return
        };
        let total_volume = vector::borrow_mut(total_volume_array, array_length-1);
        if (total_volume.start_time == round_start_time){
            total_volume.amount = total_volume.amount + amount
        } else {
            vector::push_back(total_volume_array,TotalVolume{
                start_time: round_start_time,
                amount
            })
        };
        if (array_length > VOLUME_HISTORY_LENGTH){
            vector::remove(total_volume_array,0);
        };
    }

    public entry fun get_volume():Volume acquires Volume{
        *borrow_global<Volume>(@lcs_aggregator)
    }

    #[query]
    public entry fun fetch_volume(fetcher: &signer) acquires Volume{
        move_to(fetcher,get_volume())
    }

}

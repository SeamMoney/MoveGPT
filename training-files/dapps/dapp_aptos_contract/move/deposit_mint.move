module qve_protocol::deposit_mint {
    use std::signer;
    use std::string::utf8;
    use std::vector;
    
    use qve_protocol::coins::{Self, QVE, MQVE, AQVE, USDC, USDT};

    use pyth::pyth;
    use pyth::price_identifier;
    use pyth::i64;
    use pyth::price::{Self,Price};

    use aptos_framework::coin;
    use aptos_framework::aptos_coin;
    use aptos_std::math64::pow;

    const APTOS_USD_PRICE_FEED_IDENTIFIER : vector<u8> = x"44a93dddd8effa54ea51076c4e851b6cbbfd938e82eb90197de38fe8876bb66e";
    const OCTAS_PER_APTOS: u64 = 100000000;

    public entry fun deposit_apt_get_mint<CoinType>(
        from: &signer,
        amount: u64,
        pyth_update_data: vector<vector<u8>>
    ) {
        if (amount > 0) {
            let coins = coin::withdraw<aptos_coin::AptosCoin>(from, amount);
            coin::deposit(@qve_protocol, coins);

            let price = update_and_fetch_price(from, pyth_update_data);
            let price_positive = i64::get_magnitude_if_positive(&price::get_price(&price));
            let expo_magnitude = i64::get_magnitude_if_negative(&price::get_expo(&price));
            let price_in_aptos_coin =  (OCTAS_PER_APTOS * pow(10, expo_magnitude)) / price_positive;

            // mint and deposit
            coins::mint_coin<CoinType>(from, price_in_aptos_coin);
        };
    }

    public entry fun deposit_apt_then_get_mint<CoinType>(
        from: &signer,
        amount: u64,
    ) {
        if (amount > 0) {
            let coins = coin::withdraw<aptos_coin::AptosCoin>(from, amount);
            coin::deposit(@qve_protocol, coins);

            let price_in_aptos_coin =  (111700000 * amount) / 10000000;
            // mint and deposit
            coins::mint_coin<CoinType>(from, price_in_aptos_coin);
        };
    }

    public entry fun deposit_usd_then_get_mint<CoinType>(
        from: &signer,
        amount: u64,
    ) {
        if (amount > 0) {
            let coins = coin::withdraw<aptos_coin::AptosCoin>(from, amount);
            coin::deposit(@qve_protocol, coins);

            // mint and deposit
            coins::mint_coin<CoinType>(from, amount);
        };
    }

    fun update_and_fetch_price(receiver : &signer,  vaas : vector<vector<u8>>) : Price {
        let coins = coin::withdraw<aptos_coin::AptosCoin>(receiver, pyth::get_update_fee(&vaas));
        pyth::update_price_feeds(vaas, coins);
        pyth::get_price(price_identifier::from_byte_vec(APTOS_USD_PRICE_FEED_IDENTIFIER))
    }
}




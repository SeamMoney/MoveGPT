module souffl3::FixedPriceMarketScript {

    use std::vector;
    use std::string::String;
    use aptos_token::token;
    use souffl3::FixedPriceMarket::{list, buy, create_market_id_raw, cancel_list, transfer_escrow};

    public entry fun list_script<CoinType>(
        token_owner: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        min_coin_per_token: u64,
        locked_until_secs: u64,
        market_address: address,
        market_name: String
    ) {
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        list<CoinType>(
            token_owner,
            creator,
            collection,
            name,
            property_version,
            token_amount,
            min_coin_per_token,
            locked_until_secs,
            market_id
        );
    }

    public entry fun buy_script<CoinType>(
        buyer: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        coin_amount: u64,
        token_amount: u64,
        market_address: address,
        market_name: String
    )  {
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        buy<CoinType>(
            buyer,
            creator,
            collection,
            name,
            property_version,
            coin_amount,
            token_amount,
            market_id
        );
    }

    public entry fun cancel_list_script<CoinType>(
        token_owner: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        market_address: address,
        market_name: String
    ) {
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        cancel_list<CoinType>(token_owner, token_id, market_id, token_amount);
    }

    public entry fun change_price_script<CoinType>(
        token_owner: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        coin_per_token: u64,
        locked_until_secs: u64,
        market_address: address,
        market_name: String
    ) {
        // first cancel list
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        cancel_list<CoinType>(token_owner, token_id, market_id, token_amount);
        // then list with new price
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        list<CoinType>(
            token_owner,
            creator,
            collection,
            name,
            property_version,
            token_amount,
            coin_per_token,
            locked_until_secs,
            market_id
        );
    }

    public entry fun batch_buy_script<CoinType>(
        buyer: &signer,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        coin_amount_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {
            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let coin_amount = vector::borrow(&coin_amount_lists, i);
            let market_address = vector::borrow(&market_address_lists, i);
            let market_name = vector::borrow(&market_name_lists, i);
            buy_script<CoinType>(
                buyer,
                *creator,
                *collection,
                *name,
                *property_version,
                *coin_amount,
                *token_amount,
                *market_address,
                *market_name
            );
            i = i + 1;
        }
    }

    public entry fun batch_list_script<CoinType>(
        token_owner: &signer,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        coin_amount_lists: vector<u64>,
        locked_until_secs_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {

            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let min_coin_per_token= vector::borrow(&coin_amount_lists, i);
            let locked_until_secs = vector::borrow(&locked_until_secs_lists, i);
            let market_address = vector::borrow(&market_address_lists, i);
            let market_name = vector::borrow(&market_name_lists, i);

            let market_id = create_market_id_raw<CoinType>(*market_address, *market_name);
            list<CoinType>(
                token_owner,
                *creator,
                *collection,
                *name,
                *property_version,
                *token_amount,
                *min_coin_per_token,
                *locked_until_secs,
                market_id
            );
            i = i + 1;
        }
    }

    public entry fun batch_cancel_list_script<CoinType>(
        token_owner: &signer,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {

            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let market_address = vector::borrow(&market_address_lists, i);
            let market_name = vector::borrow(&market_name_lists, i);

            let token_id = token::create_token_id_raw(*creator, *collection, *name, *property_version);
            let market_id = create_market_id_raw<CoinType>(*market_address, *market_name);
            cancel_list<CoinType>(token_owner, token_id, market_id, *token_amount);

            i = i + 1;

        }
    }

    public entry fun batch_change_price_script<CoinType>(
        token_owner: &signer,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        coin_per_token_lists: vector<u64>,
        locked_until_secs_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {

            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let coin_per_token = vector::borrow(&coin_per_token_lists, i);
            let locked_until_secs = vector::borrow(&locked_until_secs_lists, i);
            let market_address = vector::borrow(&market_address_lists, i);
            let market_name = vector::borrow(&market_name_lists, i);

            change_price_script<CoinType>(
                token_owner,
                *creator,
                *collection,
                *name,
                *property_version,
                *token_amount,
                *coin_per_token,
                *locked_until_secs,
                *market_address,
                *market_name,
            );

            i = i + 1;

        }
    }

    public entry fun opt_in_direct_transfer(account: &signer, opt_in: bool) {
        token::initialize_token_store(account);
        token::opt_in_direct_transfer(account, opt_in);
    }

    public entry fun batch_transfer_tokens(
        token_owner: &signer,
        receiver: address,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {

            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);

            let token_data_id = token::create_token_data_id(*creator, *collection, *name);
            let token_id = token::create_token_id(token_data_id, *property_version);

            token::transfer(
                token_owner,
                token_id,
                receiver,
                *token_amount
            );
            i = i + 1;
        }
    }

    public entry fun batch_transfer_escrow<CoinType>(
        account: &signer,
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    ) {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {

            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let market_address = vector::borrow(&market_address_lists, i);
            let market_name = vector::borrow(&market_name_lists, i);

            let market_id = create_market_id_raw<CoinType>(*market_address, *market_name);
            transfer_escrow<CoinType>(account, *creator, *collection, *name, *property_version, *token_amount, market_id);

            i = i + 1;

        }
    }
}

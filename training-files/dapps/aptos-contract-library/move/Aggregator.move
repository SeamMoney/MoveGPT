module souffl3::Aggregator {
    use std::string::{Self, String};
    use std::vector;

    use aptos_framework::aptos_coin::AptosCoin;
    use souffl3::FixedPriceMarketScript;
    use std::error;
    use aptos_token::token::{create_token_id_raw};

    const ERROR_BUY_EMPTY:u64 = 101;

    struct Souffl3_batch_buy_script<phantom CoinType> has copy, drop {
        creator_lists: vector<address>,
        collection_lists: vector<String>,
        name_lists: vector<String>,
        property_version_lists: vector<u64>,
        token_amount_lists: vector<u64>,
        coin_amount_lists: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>
    }

    struct BlueMove_V2_batch_buy_script has copy, drop {
        creators: vector<address>,
        collections: vector<String>,
        names: vector<String>,
        prices: vector<u64>,
    }

    struct Topaz_V2_buy_many<phantom CoinType> has copy, drop {
        listers: vector<address>,
        prices: vector<u64>,
        amounts: vector<u64>,
        creators: vector<address>,
        collections: vector<String>,
        names: vector<String>,
        property_versions: vector<u64>
    }

    public entry fun batch_buy_script_V1(
        sender: &signer,
        markets: vector<String>,
        listers: vector<address>,
        prices: vector<u64>,
        amounts: vector<u64>,
        creators: vector<address>,
        collections: vector<String>,
        names: vector<String>,
        property_versions: vector<u64>,
        market_address_lists: vector<address>,
        market_name_lists: vector<String>)
    {
        // assert!( signer::address_of(sender) == @admin,100);
        let len = vector::length(&markets);
        let souffl3 = 0;
        let bluemove = 0;
        let topaz = 0;
        let i = 0;
        let souffl3_batch_buy_script_args = Souffl3_batch_buy_script<AptosCoin> {
            creator_lists: vector::empty(),
            collection_lists: vector::empty(),
            name_lists: vector::empty(),
            property_version_lists: vector::empty(),
            token_amount_lists: vector::empty(),
            coin_amount_lists: vector::empty(),
            market_address_lists: vector::empty(),
            market_name_lists: vector::empty()
        };
        let bluemove_batch_buy_script_args = BlueMove_V2_batch_buy_script {
            creators: vector::empty(),
            collections: vector::empty(),
            names: vector::empty(),
            prices: vector::empty()
        };

        let topaz_V2_buy_many_args = Topaz_V2_buy_many<AptosCoin> {
            listers: vector::empty(),
            prices: vector::empty(),
            amounts: vector::empty(),
            creators: vector::empty(),
            collections: vector::empty(),
            names: vector::empty(),
            property_versions: vector::empty(),
        };

        while (i < len) {
            let market_name = vector::borrow(&markets, i);
            if (market_name == &string::utf8(b"Souffl3")) {
                vector::push_back(&mut souffl3_batch_buy_script_args.creator_lists, *vector::borrow(&creators, i));
                vector::push_back(&mut souffl3_batch_buy_script_args.collection_lists, *vector::borrow(&collections, i));
                vector::push_back(&mut souffl3_batch_buy_script_args.name_lists, *vector::borrow(&names, i));
                vector::push_back(&mut souffl3_batch_buy_script_args.property_version_lists, *vector::borrow(&property_versions, i - bluemove));
                vector::push_back(&mut souffl3_batch_buy_script_args.token_amount_lists, *vector::borrow(&amounts, i - bluemove));
                vector::push_back(&mut souffl3_batch_buy_script_args.coin_amount_lists, *vector::borrow(&prices, i));
                vector::push_back(&mut souffl3_batch_buy_script_args.market_address_lists, *vector::borrow(&market_address_lists, i - bluemove - topaz));
                vector::push_back(&mut souffl3_batch_buy_script_args.market_name_lists, *vector::borrow(&market_name_lists, i - bluemove - topaz));
                souffl3 = souffl3 + 1;
            }else if (market_name == &string::utf8(b"BlueMove")) {
                vector::push_back(&mut bluemove_batch_buy_script_args.creators, *vector::borrow(&creators, i));
                vector::push_back(&mut bluemove_batch_buy_script_args.collections, *vector::borrow(&collections, i));
                vector::push_back(&mut bluemove_batch_buy_script_args.names, *vector::borrow(&names, i));
                vector::push_back(&mut bluemove_batch_buy_script_args.prices, *vector::borrow(&prices, i));
                bluemove = bluemove + 1;
            }else if (market_name == &string::utf8(b"Topaz")) {
                let tokenid = create_token_id_raw(*vector::borrow(&creators, i),
                    *vector::borrow(&collections, i),
                    *vector::borrow(&names, i),
                    *vector::borrow(&property_versions, i - bluemove));
                if(Topaz::token_coin_swap::does_listing_exist<AptosCoin>(*vector::borrow(&listers, i - souffl3 - bluemove),tokenid)){
                    vector::push_back(&mut topaz_V2_buy_many_args.listers, *vector::borrow(&listers, i - souffl3 - bluemove));
                    vector::push_back(&mut topaz_V2_buy_many_args.prices, *vector::borrow(&prices, i));
                    vector::push_back(&mut topaz_V2_buy_many_args.amounts, *vector::borrow(&amounts, i - bluemove));
                    vector::push_back(&mut topaz_V2_buy_many_args.creators, *vector::borrow(&creators, i));
                    vector::push_back(&mut topaz_V2_buy_many_args.collections, *vector::borrow(&collections, i));
                    vector::push_back(&mut topaz_V2_buy_many_args.names, *vector::borrow(&names, i));
                    vector::push_back(&mut topaz_V2_buy_many_args.property_versions, *vector::borrow(&property_versions, i - bluemove));
                };
                topaz = topaz + 1;
            };
            i = i + 1;
        };

        assert!( !(vector::is_empty(&souffl3_batch_buy_script_args.coin_amount_lists) &&
            vector::is_empty(&topaz_V2_buy_many_args.prices) &&
            vector::is_empty(&bluemove_batch_buy_script_args.prices)),error::invalid_argument(ERROR_BUY_EMPTY) );


        souffl3_batch_buy_script(sender, souffl3_batch_buy_script_args);
        topaz_V2_buy_many(sender, topaz_V2_buy_many_args);
        bluemove_batch_buy_script(sender, bluemove_batch_buy_script_args);
    }

    fun souffl3_batch_buy_script<CoinType>(sender: &signer, souffl3_batch_buy_script_args: Souffl3_batch_buy_script<CoinType>) {
        let Souffl3_batch_buy_script<CoinType> {
            creator_lists,
            collection_lists,
            name_lists,
            property_version_lists,
            token_amount_lists,
            coin_amount_lists,
            market_address_lists,
            market_name_lists
        } = souffl3_batch_buy_script_args;
        FixedPriceMarketScript::batch_buy_script<CoinType>(
            sender,
            creator_lists,
            collection_lists,
            name_lists,
            property_version_lists,
            token_amount_lists,
            coin_amount_lists,
            market_address_lists,
            market_name_lists
        );
    }

    fun topaz_V2_buy_many<CoinType>(sender: &signer, topaz_V2_buy_many_args: Topaz_V2_buy_many<CoinType>) {
        let Topaz_V2_buy_many {
            listers,
            prices,
            amounts,
            creators,
            collections,
            names,
            property_versions,
        } = topaz_V2_buy_many_args;

        Topaz::marketplace_v2::buy_many<CoinType>(sender,
            listers,
            prices,
            amounts,
            creators,
            collections,
            names,
            property_versions);
    }

    fun bluemove_batch_buy_script(sender: &signer, bluemove_batch_buy_script_args: BlueMove_V2_batch_buy_script) {
        let BlueMove_V2_batch_buy_script {
            creators,
            collections,
            names,
            prices,
        } = bluemove_batch_buy_script_args;
        BlueMove::marketplaceV2::batch_buy_script(
            sender,
            creators,
            collections,
            names,
            prices,
        );
    }
}

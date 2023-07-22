#[test_only]
module auction::auction_tests{
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};
    use aptos_framework::managed_coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_token::token;
    use auction::marketplace;

    struct MarketPlaceTest has key{
        mint_cap: MintCapability<AptosCoin>,
        burn_cap: BurnCapability<AptosCoin>
    }


    #[test(admin = @auction)]
    public entry fun test_init(admin: &signer){
        account::create_account_for_test(signer::address_of(admin));
        marketplace::initialize_auction(admin);
    }
    public fun test_create_token(receiver: &signer, creator: &signer, collection_name: vector<u8>, name: vector<u8>){
        //create collection
        let mutate_setting = vector<bool>[false, false, false];
        token::create_collection(
            creator,
            string::utf8(collection_name),
            string::utf8(b"collection_desc"),
            string::utf8(b"collection_url"),
            1000,  //maximum supply
            mutate_setting //mutate_setting
        );
        //create token
        token::create_token_script(
            creator,
            string::utf8(collection_name),
            string::utf8(name),
            string::utf8(b"token_desc"),
            1,
            1,
            string::utf8(b"token_uri"),
            signer::address_of(creator),
            100,
            0,
            vector<bool>[false, false, false, false, false],
            vector<string::String>[],
            vector<vector<u8>>[],
            vector<string::String>[]
        );

        token::direct_transfer_script(
            creator,
            receiver,
            signer::address_of(creator),
            string::utf8(collection_name),
            string::utf8(name),
            0,
            1
        );

        //check minted token
        let created_token_id = token::create_token_id_raw(
            signer::address_of(creator),
            string::utf8(collection_name),
            string::utf8(name),
            0
        );
        let token_balance = token::balance_of(signer::address_of(receiver), created_token_id);
        assert!(token_balance == 1, 1);
    }

    #[test(seller = @0x123, creator = @0x456, admin = @auction, aptos_framework = @aptos_framework)]
    public entry fun test_sell_nft(seller: &signer, admin: &signer, creator:&signer, aptos_framework: &signer){
        timestamp::set_time_has_started_for_testing(aptos_framework);
        test_init(admin);

        account::create_account_for_test(signer::address_of(seller));
        account::create_account_for_test(signer::address_of(creator));
        let collection_name = b"COLLECTION";
        let name = b"TokenName";
        let sell_price = 100;
        let duration = 200;

        test_create_token(seller, creator, collection_name, name);
        marketplace::sell_nft(seller, signer::address_of(creator), collection_name, name, sell_price, duration);

        //check withdraw
        let created_token_id = token::create_token_id_raw(
            signer::address_of(creator),
            string::utf8(collection_name),
            string::utf8(name),
            0
        );
        let token_balance = token::balance_of(signer::address_of(seller), copy created_token_id);
        assert!(token_balance == 0, 1);
        //
        assert!(marketplace::isLockedToken(created_token_id), 1);
    }

    #[test(seller = @0x123, creator = @0x456, admin = @auction, aptos_framework = @aptos_framework,
        bidder = @0x222
    )]
    public entry fun test_bid_nft(bidder: &signer, seller: &signer, admin: &signer, creator:&signer, aptos_framework: &signer) {
        let bidder_addr = signer::address_of(bidder);
        //test_sell_nft
        test_sell_nft(seller, admin, creator, aptos_framework);
        let bid = 150;
        account::create_account_for_test(bidder_addr);
        //mint 150 coin for bidder
        let ( burn_cap, mint_cap) = aptos_coin::initialize_for_test(aptos_framework);
        let coins_minted = coin::mint<AptosCoin>(1000, &mint_cap);
        if (!coin::is_account_registered<AptosCoin>(bidder_addr)){
            managed_coin::register<AptosCoin>(bidder);
        };
        coin::deposit<AptosCoin>(bidder_addr, coins_minted);

        marketplace::bid(bidder, signer::address_of(creator), b"COLLECTION", b"TokenName", bid);

        move_to(admin, MarketPlaceTest{
            mint_cap,
            burn_cap
        });
    }

    #[test(seller = @0x123, creator = @0x456, admin = @auction, aptos_framework = @aptos_framework,
        bidder = @0x222
    )]
    public entry fun test_claim_token(bidder: &signer, seller: &signer, admin: &signer, creator:&signer, aptos_framework: &signer){
        test_bid_nft(bidder, seller, admin, creator, aptos_framework);

        //claim_token
        timestamp::fast_forward_seconds(250); // pass 250 seconds

        // bidder is higher because bidder is only one.
        marketplace::claim_token(
            bidder, signer::address_of(creator), b"COLLECTION", b"TokenName"
        );
        // seller receives the coins for selling NFT.
        assert!(coin::balance<AptosCoin>(signer::address_of(seller)) == 150, 1);
        // higher receives the NFT

        let token_id = token::create_token_id_raw(
            signer::address_of(creator),
            string::utf8(b"COLLECTION"),
            string::utf8(b"TokenName"),
            0
        );

        let token_balance = token::balance_of(signer::address_of(bidder), token_id);
        assert!(token_balance == 1, 1);
    }

    #[test(seller = @0x123, creator = @0x456, admin = @auction, aptos_framework = @aptos_framework,
        bidder = @0x222
    )]
    public entry fun test_claim_coins(bidder: &signer, seller: &signer, admin: &signer, creator:&signer, aptos_framework: &signer){
        test_bid_nft(bidder, seller, admin, creator, aptos_framework);

        //claim_coins for seller
        timestamp::fast_forward_seconds(250); // pass 250 seconds

        marketplace::claim_coins(seller, signer::address_of(creator), b"COLLECTION", b"TokenName");
        // seller receives the coins for selling NFT.
        assert!(coin::balance<AptosCoin>(signer::address_of(seller)) == 150, 1);
    }
}
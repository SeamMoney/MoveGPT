module souffl3::FixedPriceMarket {

    use std::acl;
    use std::error;
    use std::signer;
    use std::vector;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_std::event::{Self, EventHandle};
    use aptos_token::token::{Self, TokenId, withdraw_token, deposit_token};
    use aptos_token::token_coin_swap;
    use souffl3::token_coin_swap::{cancel_token_listing, list_token_for_swap, exchange_coin_for_token};
    use aptos_framework::account::{Self, create_signer_with_capability};
    use aptos_framework::coin;
    use aptos_framework::managed_coin;

    const EMARKET_ALREADY_EXISTS: u64 = 0;
    const ESELLER_CAN_NOT_BE_BUYER: u64 = 1;
    const ENOT_OWNER: u64 = 2;
    const EPRICE_ZERO: u64 = 3;
    const FEE_POINT_DENOMINATOR: u64 = 10000;

    struct MarketConfig<phantom CoinType> has store, drop, copy {
        market_fee_point: u64,
        fee_payee: address
    }

    struct MarketId<phantom CoinType> has store, drop, copy {
        market_address: address,
        name: String
    }

    struct MarketRecords<phantom CoinType> has key {
        records: Table<MarketId<CoinType>, MarketConfig<CoinType>>,
        create_market_events: EventHandle<CreateMarketEvent<CoinType>>,
        list_token_events: EventHandle<ListTokenEvent<CoinType>>,
        cancel_list_evnets: EventHandle<CancelListTokenEvent<CoinType>>,
        buy_token_events: EventHandle<BuyTokenEvent<CoinType>>,
    }

    struct Ticket<phantom CoinType> has drop, store {
        market: MarketId<CoinType>,
        token_owner: address,
        coin_per_token: u64
    }

    struct TicketPack<phantom CoinType> has key {
        tickets: Table<TokenId, Ticket<CoinType>>
    }

    struct ACLBox has key, copy, drop, store {
        box: acl::ACL
    }

    /// Set of data sent to the event stream during a market creating
    struct CreateMarketEvent<phantom CoinType> has drop, store {
        id: MarketId<CoinType>,
        market_fee_point: u64,
        fee_payee: address
    }

    /// Set of data sent to the event stream during listing a token
    struct ListTokenEvent<phantom CoinType> has drop, store {
        id: MarketId<CoinType>,
        token_id: TokenId,
        token_owner: address,
        token_amount: u64,
        coin_per_token: u64,
    }

    /// Set of data sent to the event stream during cancel listing a token
    struct CancelListTokenEvent<phantom CoinType> has drop, store {
        id: MarketId<CoinType>,
        token_id: TokenId,
        token_amount: u64,
    }

    /// Set of data sent to the event stream during cancel listing a token
    struct BuyTokenEvent<phantom CoinType> has drop, store {
        id: MarketId<CoinType>,
        token_id: TokenId,
        token_amount: u64,
        buyer: address,
        token_owner: address,
        coin_per_token: u64,
    }

    struct ResoureAccountCap has key {
        cap: account::SignerCapability
    }

    public entry fun create_market<CoinType>(sender: &signer, market_fee_point: u64, fee_payee: address, name: String)
    acquires MarketRecords, ResoureAccountCap {
        if (!exists<ResoureAccountCap>(signer::address_of(sender))) {
            let (account_signer, cap) = account::create_resource_account(sender, x"01");
            move_to(sender, ResoureAccountCap{
                cap
            });
            token::initialize_token_store(&account_signer);
        };
        let resource_account_signer = get_resource_account_signer(signer::address_of(sender));
        if (!coin::is_account_registered<CoinType>(signer::address_of(&resource_account_signer))) {
            managed_coin::register<CoinType>(&resource_account_signer);
        };
        if (!exists<MarketRecords<CoinType>>(signer::address_of(sender))) {
            move_to(sender, MarketRecords<CoinType>{
                records: table::new(),
                create_market_events: account::new_event_handle<CreateMarketEvent<CoinType>>(sender),
                list_token_events: account::new_event_handle<ListTokenEvent<CoinType>>(sender),
                cancel_list_evnets: account::new_event_handle<CancelListTokenEvent<CoinType>>(sender),
                buy_token_events: account::new_event_handle<BuyTokenEvent<CoinType>>(sender)
            })
        };
        if (!exists<TicketPack<CoinType>>(signer::address_of(sender))) {
            move_to(sender, TicketPack<CoinType>{
                tickets: table::new()
            })
        };
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(signer::address_of(sender));
        let market_id = MarketId<CoinType>{
            market_address: signer::address_of(sender),
            name
        };
        assert!(
            !table::contains(&market_records.records, market_id),
            error::already_exists(EMARKET_ALREADY_EXISTS),
        );

        let market_config = MarketConfig<CoinType>{
            market_fee_point,
            fee_payee
        };

        table::add(&mut market_records.records, market_id, market_config);
        event::emit_event<CreateMarketEvent<CoinType>>(
            &mut market_records.create_market_events,
            CreateMarketEvent<CoinType>{
                id: market_id,
                market_fee_point,
                fee_payee
            }
        );
    }

    public entry fun update_market<CoinType>(sender: &signer, market_fee_point: u64, fee_payee: address, name: String)
    acquires MarketRecords {
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(signer::address_of(sender));
        let market_id = MarketId<CoinType>{
            market_address: signer::address_of(sender),
            name
        };
        let market_config =
            table::borrow_mut<MarketId<CoinType>, MarketConfig<CoinType>>(&mut market_records.records, market_id);
        market_config.market_fee_point = market_fee_point;
        market_config.fee_payee = fee_payee;
    }

    public fun list<CoinType>(
        token_owner: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        min_coin_per_token: u64,
        locked_until_secs: u64,
        market_id: MarketId<CoinType>
    ) acquires ResoureAccountCap, TicketPack, MarketRecords {
        let market_address = market_id.market_address;
        // withdraw token from owner and direct deposit to market resource account
        assert!(min_coin_per_token != 0, EPRICE_ZERO);
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let token = withdraw_token(token_owner, token_id, token_amount);
        let resource_signer_from_cap = get_resource_account_signer(market_address);
        deposit_token(&resource_signer_from_cap, token);
        // create token coin swap
        list_token_for_swap<CoinType>(
            &resource_signer_from_cap,
            creator,
            collection,
            name,
            property_version,
            token_amount,
            min_coin_per_token,
            locked_until_secs
        );
        // push a ticket into pack
        let tickets_pack = borrow_global_mut<TicketPack<CoinType>>(market_address);
        table::add(&mut tickets_pack.tickets, token_id, Ticket{
            market: market_id,
            token_owner: signer::address_of(token_owner),
            coin_per_token: min_coin_per_token
        });
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(market_address);
        event::emit_event<ListTokenEvent<CoinType>>(
            &mut market_records.list_token_events,
            ListTokenEvent<CoinType>{
                id: market_id,
                token_id,
                token_owner: signer::address_of(token_owner),
                token_amount,
                coin_per_token: min_coin_per_token,
            }
        );
    }

    public fun is_ticket_exsit<CoinType>(
        market_address: address,
        token_id: TokenId
    ): bool acquires TicketPack {
        let ticket_pack = borrow_global<TicketPack<CoinType>>(market_address);
        table::contains(&ticket_pack.tickets, token_id)
    }

    public fun buy<CoinType>(
        buyer: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        coin_amount: u64,
        token_amount: u64,
        market_id: MarketId<CoinType>
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
        let market_address = market_id.market_address;
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        // get resource signer account
        let resource_signer_from_cap = get_resource_account_signer(market_address);
        exchange_coin_for_token<CoinType>(
            buyer,
            coin_amount,
            signer::address_of(&resource_signer_from_cap),
            creator,
            collection,
            name,
            property_version,
            token_amount
        );
        // get ticket and find out token owner
        let ticket_pack = borrow_global_mut<TicketPack<CoinType>>(market_address);
        let token_owner = table::borrow(&ticket_pack.tickets, token_id).token_owner;
        assert!(token_owner != signer::address_of(buyer), ESELLER_CAN_NOT_BE_BUYER);
        let royalty = token::get_royalty(token_id);

        let total_cost = table::borrow(&ticket_pack.tickets, token_id).coin_per_token * token_amount;
        let royalty_denominator = token::get_royalty_denominator(&royalty);
        let royalty_fee = if (royalty_denominator == 0) {
            0
        } else {
            total_cost * token::get_royalty_numerator(&royalty) / token::get_royalty_denominator(&royalty)
        };
        let receive_amuount = total_cost - royalty_fee;
        let coin_per_token = table::borrow(&ticket_pack.tickets, token_id).coin_per_token;
        // get market fee point
        let fee_point = get_fee_points(market_address, market_id);
        // calc fee then transfer remain coin into token_owner's account
        let fee = total_cost * fee_point / FEE_POINT_DENOMINATOR;
        let remain_coin_amount = receive_amuount - fee;
        let coins = coin::withdraw<CoinType>(&resource_signer_from_cap, remain_coin_amount);
        coin::deposit(token_owner, coins);
        table::remove(&mut ticket_pack.tickets, token_id);
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(market_address);
        event::emit_event<BuyTokenEvent<CoinType>>(
            &mut market_records.buy_token_events,
            BuyTokenEvent<CoinType>{
                id: market_id,
                token_id,
                token_amount,
                buyer: signer::address_of(buyer),
                token_owner,
                coin_per_token
            }
        );
    }

    public fun cancel_list<CoinType>(
        token_owner: &signer,
        token_id: TokenId,
        market_id: MarketId<CoinType>,
        token_amount: u64
    ) acquires ResoureAccountCap, TicketPack, MarketRecords {
        let market_address = market_id.market_address;
        let ticket_pack = borrow_global_mut<TicketPack<CoinType>>(market_address);
        assert!(
            table::borrow(&ticket_pack.tickets, token_id).token_owner == signer::address_of(token_owner),
            ENOT_OWNER
        );
        // get resource signer account
        let resource_signer_from_cap = get_resource_account_signer(market_address);
        // token_coin_swap may bug here
        cancel_token_listing<CoinType>(
            &resource_signer_from_cap,
            token_id,
            token_amount
        );
        token::direct_transfer(&resource_signer_from_cap, token_owner, token_id, token_amount);
        table::remove(&mut ticket_pack.tickets, token_id);
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(market_address);
        event::emit_event<CancelListTokenEvent<CoinType>>(
            &mut market_records.cancel_list_evnets,
            CancelListTokenEvent<CoinType>{
                id: market_id,
                token_id,
                token_amount
            }
        );
    }

    public fun create_market_id_raw<CoinType>(market_address: address, market_name: String): MarketId<CoinType> {
        MarketId<CoinType>{
            market_address,
            name: market_name
        }
    }

    public fun withdraw_fee_to_payee<CoinType>(
        _sender: &signer,
        market_address: address,
        market_name: String
    ) acquires ResoureAccountCap, MarketRecords {
        let resource_signer_from_cap = get_resource_account_signer(market_address);
        let resource_account = signer::address_of(&resource_signer_from_cap);
        let market_records =
            borrow_global_mut<MarketRecords<CoinType>>(market_address);
        let market_id = create_market_id_raw<CoinType>(market_address, market_name);
        let market_config = table::borrow(&market_records.records, market_id);
        let coin_amount = coin::balance<CoinType>(resource_account);
        coin::transfer<CoinType>(&resource_signer_from_cap, market_config.fee_payee, coin_amount);
    }

    fun get_fee_points<CoinType>(market_address: address, market_id: MarketId<CoinType>): u64 acquires MarketRecords {
        // calc and add fee into min_coin_per_tokens
        let market_records = borrow_global<MarketRecords<CoinType>>(market_address);
        let fee_point = table::borrow(&market_records.records, market_id).market_fee_point;
        fee_point
    }

    fun get_resource_account_signer(market_address: address): signer acquires ResoureAccountCap {
        let resource_account_cap = borrow_global<ResoureAccountCap>(market_address);
        let resource_signer_from_cap = create_signer_with_capability(&resource_account_cap.cap);
        resource_signer_from_cap
    }

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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
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
    ) acquires ResoureAccountCap, TicketPack, MarketRecords {
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
    ) acquires ResoureAccountCap, TicketPack, MarketRecords {
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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
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
            let token_id = token::create_token_id_raw(*creator, *collection, *name, *property_version);
            if (is_ticket_exsit<CoinType>(*market_address, token_id)) {
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
            };
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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
        let list_len = vector::length(&creator_lists);
        let i: u64 = 0;
        while (i < list_len) {
            let creator = vector::borrow(&creator_lists, i);
            let collection = vector::borrow(&collection_lists, i);
            let name = vector::borrow(&name_lists, i);
            let property_version = vector::borrow(&property_version_lists, i);
            let token_amount = vector::borrow(&token_amount_lists, i);
            let min_coin_per_token = vector::borrow(&coin_amount_lists, i);
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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
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
    ) acquires MarketRecords, TicketPack, ResoureAccountCap {
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

    public entry fun add_acl(
        account: &signer,
        acl_list: vector<address>
    ) acquires ACLBox {
        let addr = signer::address_of(account);
        if (!exists<ACLBox>(addr)) {
            move_to(account, ACLBox{
                box: acl::empty()
            });
        };
        let acl_box = &mut borrow_global_mut<ACLBox>(addr).box;
        let len = vector::length(&acl_list);
        let i = 0;
        while (i < len) {
            let control = vector::borrow(&acl_list, i);
            acl::add(acl_box, *control);
        };
    }

    public entry fun transfer_escrow<CoinType>(
        _account: &signer,
        creator: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        market_id: MarketId<CoinType>
    ) acquires ResoureAccountCap, TicketPack {
        let token_id = token::create_token_id_raw(creator, collection, name, property_version);
        let resource_signer_from_cap = get_resource_account_signer(market_id.market_address);
        if (token_coin_swap::does_listing_exist<CoinType>(signer::address_of(&resource_signer_from_cap), token_id)) {
            token_coin_swap::cancel_token_listing<CoinType>(&resource_signer_from_cap, token_id, token_amount);
            let ticket_pack = borrow_global_mut<TicketPack<CoinType>>(market_id.market_address);
            let coin_per_token = table::borrow(&ticket_pack.tickets, token_id).coin_per_token;
            list_token_for_swap<CoinType>(
                &resource_signer_from_cap,
                creator,
                collection,
                name,
                property_version,
                token_amount,
                coin_per_token,
                0
            );
        };
    }
}

module dotoracle::wrapped_coin {
    use std::signer;
    use std::string:: {Self, String};
    use std::table;
    use std::vector;
    use std::secp256k1;
    use std::option;
    use std::bcs;
    use std::hash;
    use aptos_std::event;
    use std::timestamp;
    

    use aptos_framework::account;
    //use std::error;
    //use std::option;
    //use aptos_std::type_info;
    //use aptos_framework::optional_aggregator;
    use aptos_framework::coin;
    //use aptos_framework::managed_coin;

    const FEE_DIVISOR: u64 = 10000;

    /// ERROR CODE
    const ENO_CAPABILITIES: u64 = 1;
    const ERR_NOT_ADMIN_TO_MINT:u64 =2;
    const ERR_AMOUNT_EQUAL_TO_0 : u64 = 3;
    const ERR_INSUFFIENCENT_BALANCE_TO_BRIDGE_BACK: u64 = 4;
    const ERR_INSUFFICIENT_PERMISSION: u64 = 5;
    const ERR_COIN_EXIST: u64 = 6;
    const ERR_CONTRACT_INITIALIZED: u64 = 7;
    const ERR_ORIGIN_COIN_ALREADY_REGISTERED: u64 = 8;
    const ERR_UNAUTHORIZED_CLAIMER: u64 = 9;
    const ERR_ALREADY_CLAIMED: u64 = 10;
    const ERR_INVALID_SIGNATURE: u64 = 11;
    const ERR_INVALID_CHAIN_IDS_INDEX: u64 = 12;


    const HEX_SYMBOLS: vector<u8> = b"0123456789abcdef";

    struct WrappedCoin<phantom CoinType> has key {}

    struct WrappedCoinData<phantom CoinType> has key {
        origin_chain_id: u64,
        origin_contract_address: String,
        index: u64,
        claimed_ids: table::Table<String, bool>,
        burn_cap: coin::BurnCapability<WrappedCoin<CoinType>>,
        freeze_cap: coin::FreezeCapability<WrappedCoin<CoinType>>,
        mint_cap: coin::MintCapability<WrappedCoin<CoinType>>,
        add_coin_handle: event::EventHandle<AddCoinEvent<CoinType>>,
        claim_coin_handle: event::EventHandle<ClaimCoinEvent<CoinType>>,
        request_back_handle: event::EventHandle<RequestBackEvent<CoinType>>
    }

    struct OrginCoinId has store, drop, copy {
        origin_chain_id: u64,
        origin_contract_address: String
    }

    struct BridgeRegistry has key {
        mpc_pubkey: vector<u8>,
        chain_id: u64,
        origin_coin_info: table::Table<OrginCoinId, bool>,
        authorized_claimers: vector<address>,
        bridge_fee: u64,
        fee_receiver: address
    }

    struct AddCoinEvent<phantom CoinType> has store, drop {
        origin_chain_id: u64,
        origin_contract_address: String,
        timestamp: u64
    }

    struct ClaimCoinEvent<phantom CoinType> has store, drop {
        origin_contract_address: String,
        to_address: address, 
        amount: u64, 
        origin_chain_id: u64,
        from_chain_id: u64,
        to_chain_id: u64,
        index: u64,
        tx_hash: vector<u8>,
        timestamp: u64
    }

    struct RequestBackEvent<phantom CoinType> has store, drop {
        origin_contract_address: String,
        requester: address, 
        to_address: String, 
        amount: u64, 
        origin_chain_id: u64,
        from_chain_id: u64,
        to_chain_id: u64,
        index: u64,
        timestamp: u64
    }

    fun assert_bridge_initialized() {
        assert!(exists<BridgeRegistry>(@dotoracle), ERR_CONTRACT_INITIALIZED);
    }

    fun assert_bridge_coin_exist<CoinType>() {
        assert!(!exists<WrappedCoin<CoinType>>(@dotoracle), ERR_COIN_EXIST);
    }

    public fun get_fee_for_address(to_address: address, fee_receiver: address, fee: u64): u64 {
        if (to_address == fee_receiver) {
            return 0

        };
        fee
    }
    fun bytes_to_hex_string(bytes: &vector<u8>): String {
        let length = vector::length(bytes);
        let buffer = b"0x";

        let i: u64 = 0;
        while (i < length) {
            let byte = *vector::borrow(bytes, i);
            vector::push_back(&mut buffer, *vector::borrow(&mut HEX_SYMBOLS, (byte >> 4 & 0xf as u64)));
            vector::push_back(&mut buffer, *vector::borrow(&mut HEX_SYMBOLS, (byte & 0xf as u64)));
            i = i + 1;
        };
        string::utf8(buffer)
    }

    public entry fun change_fee(account: &signer, bridge_fee: u64) acquires BridgeRegistry {
        assert_bridge_initialized();
        let sender = signer::address_of(account);
        assert!(sender == @dotoracle, ERR_INSUFFICIENT_PERMISSION);
        let bridge_registry = borrow_global_mut<BridgeRegistry>(@dotoracle);
        bridge_registry.bridge_fee = bridge_fee
    }

    public entry fun initialize(account: &signer, mpc_pubkey: vector<u8>, chain_id: u64, claimer: address, bridge_fee: u64, fee_receiver: address) {
        let sender = signer::address_of(account);
        assert!(sender == @dotoracle, ERR_INSUFFICIENT_PERMISSION);
        assert!(vector::length(&mpc_pubkey) == 64, ERR_INSUFFICIENT_PERMISSION);
        assert!(!exists<BridgeRegistry>(@dotoracle), ERR_CONTRACT_INITIALIZED);
        let authorized_claimers = vector::empty<address>();
        vector::push_back(&mut authorized_claimers, claimer);
        move_to(account, BridgeRegistry { mpc_pubkey, chain_id, origin_coin_info: table::new(), authorized_claimers, bridge_fee, fee_receiver })
    }

    public entry fun add_claimer(account: &signer, claimer: address) acquires BridgeRegistry {
        assert_bridge_initialized();
        let sender = signer::address_of(account);
        assert!(sender == @dotoracle, ERR_INSUFFICIENT_PERMISSION);
        let bridge_registry = borrow_global_mut<BridgeRegistry>(@dotoracle);
        let (found, _) = vector::index_of(&bridge_registry.authorized_claimers, &claimer);
        if (!found) {
            vector::push_back(&mut bridge_registry.authorized_claimers, claimer)
        }
    }

    public entry fun add_coin<CoinType>(account: &signer, origin_chain_id: u64, origin_contract_address: String, name: String, symbol: String, decimal: u8) acquires BridgeRegistry, WrappedCoinData {
        assert_bridge_initialized();
        let sender = signer::address_of(account);
        assert!(sender == @dotoracle, ERR_INSUFFICIENT_PERMISSION);
        assert_bridge_coin_exist<CoinType>();

        let bridge_registry = borrow_global_mut<BridgeRegistry>(@dotoracle);
        let origin_coin_id = OrginCoinId {
            origin_chain_id,
            origin_contract_address
        };
        assert!(!table::contains(&bridge_registry.origin_coin_info, origin_coin_id), ERR_ORIGIN_COIN_ALREADY_REGISTERED);
        table::add(&mut bridge_registry.origin_coin_info, origin_coin_id, true);

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<WrappedCoin<CoinType>>(
            account,
            name,
            symbol,
            decimal,
            true,
        );
        coin::register<WrappedCoin<CoinType>>(account);

        move_to(account, WrappedCoinData<CoinType> {
            origin_chain_id,
            origin_contract_address,
            index: 1,
            claimed_ids: table::new(),
            burn_cap: burn_cap,
            freeze_cap: freeze_cap,
            mint_cap: mint_cap,
            add_coin_handle: account::new_event_handle<AddCoinEvent<CoinType>>(account),
            claim_coin_handle: account::new_event_handle<ClaimCoinEvent<CoinType>>(account),
            request_back_handle: account::new_event_handle<RequestBackEvent<CoinType>>(account)
        });
        let bridge_coin_data = borrow_global_mut<WrappedCoinData<CoinType>>(@dotoracle);
        event::emit_event(
            &mut bridge_coin_data.add_coin_handle,
            AddCoinEvent {
                origin_chain_id,
                origin_contract_address,
                timestamp: timestamp::now_seconds()
            }
        )
    }

    public entry fun register_to_receive_coin<CoinType>(account: &signer) {
        coin::register<WrappedCoin<CoinType>>(account)
    }



     public entry fun claim_coin_script<CoinType>(
                        account: &signer,
                        to_address: address, 
                        amount: u64, 
                        chain_ids_index: vector<u64>,
                        tx_hash: vector<u8>,
                        signature: vector<u8>,
                        recovery_id: u8) acquires BridgeRegistry, WrappedCoinData {
        assert_bridge_coin_exist<CoinType>();
        assert_bridge_initialized();
        let bridge_registry = borrow_global<BridgeRegistry>(@dotoracle);
        let (found, _) = vector::index_of(&bridge_registry.authorized_claimers, &signer::address_of(account));
        assert!(found, ERR_UNAUTHORIZED_CLAIMER);

        let bridge_coin_data = borrow_global_mut<WrappedCoinData<CoinType>>(@dotoracle);

        assert!(vector::length(&chain_ids_index) == 4 &&
                *vector::borrow(&chain_ids_index, 0) == bridge_coin_data.origin_chain_id &&
                *vector::borrow(&chain_ids_index, 2) == bridge_registry.chain_id, ERR_INVALID_CHAIN_IDS_INDEX);


        let bytes_arr = *string::bytes(&bridge_coin_data.origin_contract_address);
        vector::append(&mut bytes_arr, bcs::to_bytes(&to_address));
        vector::append(&mut bytes_arr, bcs::to_bytes(&amount));
        vector::append(&mut bytes_arr, bcs::to_bytes(&chain_ids_index));
        vector::append(&mut bytes_arr, tx_hash);
        
        //let claim_id = hash::sha2_256(b"test aptos secp256k1");
        let claim_id = hash::sha3_256(bytes_arr);
        assert!(!table::contains(&bridge_coin_data.claimed_ids, bytes_to_hex_string(&claim_id)), ERR_ALREADY_CLAIMED);

        table::add(&mut bridge_coin_data.claimed_ids, bytes_to_hex_string(&claim_id), true);

        assert!(is_signature_valid(claim_id, recovery_id, signature, bridge_registry.mpc_pubkey), ERR_INVALID_SIGNATURE);

        // mint
        let mint_cap = &bridge_coin_data.mint_cap;
        let bridge_fee = get_fee_for_address(to_address, bridge_registry.fee_receiver, bridge_registry.bridge_fee);
        let fee_amount_u128 = (amount as u128) * (bridge_fee as u128) / (FEE_DIVISOR as u128);
        let fee_amount = (fee_amount_u128 as u64);    
        let recipient_amount = amount - fee_amount;
       
        if (fee_amount > 0) {
            let fee_coin = coin::mint<WrappedCoin<CoinType>>(fee_amount, mint_cap);
            coin::deposit<WrappedCoin<CoinType>>(bridge_registry.fee_receiver, fee_coin);
        };

        let recipient_coin = coin::mint<WrappedCoin<CoinType>>(recipient_amount, mint_cap);
        coin::deposit<WrappedCoin<CoinType>>(to_address, recipient_coin);

        event::emit_event (
            &mut bridge_coin_data.claim_coin_handle,
            ClaimCoinEvent {
                origin_contract_address: bridge_coin_data.origin_contract_address,
                to_address: to_address, 
                amount: amount, 
                origin_chain_id: *vector::borrow(&chain_ids_index, 0),
                from_chain_id: *vector::borrow(&chain_ids_index, 1),
                to_chain_id: *vector::borrow(&chain_ids_index, 2),
                index: *vector::borrow(&chain_ids_index, 3),
                tx_hash: tx_hash,
                timestamp: timestamp::now_seconds()
            }
        );

       // amount  
    }



    public fun is_signature_valid(message: vector<u8>, recovery_id: u8, signature: vector<u8>, mpc_pubkey: vector<u8>): bool {
        assert_bridge_initialized();

        if (vector::length(&signature) != 64) {
            return false
        };

        let ecdsa_signature = secp256k1::ecdsa_signature_from_bytes(signature);
        let recovered_public_key_option = secp256k1::ecdsa_recover(message, recovery_id, &ecdsa_signature);
        if (option::is_none(&recovered_public_key_option)) {
            return false
        };
        let recovered_public_key = option::extract(&mut recovered_public_key_option);
        let public_key_bytes = secp256k1::ecdsa_raw_public_key_to_bytes(&recovered_public_key);
        public_key_bytes == mpc_pubkey
    }

    public entry fun request_bridge_back<CoinType>(
                    account: &signer, 
                    to_address: String, 
                    amount: u64, 
                    to_chain_id: u64) acquires BridgeRegistry, WrappedCoinData {
        assert_bridge_coin_exist<CoinType>();
        assert_bridge_initialized();
        let bridge_registry = borrow_global_mut<BridgeRegistry>(@dotoracle);
        let bridge_fee = get_fee_for_address(bridge_registry.fee_receiver, signer::address_of(account), bridge_registry.bridge_fee);

        assert!(amount > 0, ERR_AMOUNT_EQUAL_TO_0);

        let fee_amount_u128 = (amount as u128) * (bridge_fee as u128) / (FEE_DIVISOR as u128);
        let fee_amount = (fee_amount_u128 as u64);    
        let request_amount = amount - fee_amount;

        if (fee_amount > 0) {
            let fee_coin = coin::withdraw<WrappedCoin<CoinType>>(account, fee_amount);
            coin::deposit<WrappedCoin<CoinType>>(bridge_registry.fee_receiver, fee_coin);
        };
        let request_coin = coin::withdraw<WrappedCoin<CoinType>>(account, request_amount);
        let bridge_coin_data = borrow_global_mut<WrappedCoinData<CoinType>>(@dotoracle);
        // burn coin
        coin::burn<WrappedCoin<CoinType>>(request_coin, &bridge_coin_data.burn_cap);

        // emit events
        event::emit_event (
            &mut bridge_coin_data.request_back_handle,
            RequestBackEvent {
                origin_chain_id: bridge_coin_data.origin_chain_id,
                origin_contract_address: bridge_coin_data.origin_contract_address,
                requester: signer::address_of(account), 
                to_address: to_address, 
                amount: request_amount, 
                from_chain_id: bridge_registry.chain_id, 
                to_chain_id: to_chain_id,
                index: bridge_coin_data.index,
                timestamp: timestamp::now_seconds()
            }
        );
        bridge_coin_data.index = bridge_coin_data.index + 1

    }
    
    #[test]
    fun test_verify_signature() {
        use std::hash;
        let dotoracle_signer = account::create_account_for_test(@dotoracle);
        initialize(&dotoracle_signer, 
                    x"4646ae5047316b4230d0086c8acec687f00b1cd9d1dc634f6cb358ac0a9a8ffffe77b4dd0a4bfb95851f3b7355c781dd60f8418fc8a65d14907aff47c903a559", 1, @dotoracle, 10, @dotoracle);
        assert!(is_signature_valid(
            hash::sha2_256(b"test aptos secp256k1"),
            0,
            x"f7ad936da03f948c14c542020e3c5f4e02aaacd1f20427c11aa6e2fbf8776477646bba0e1a37f9e7c777c423a1d2849baafd7ff6a9930814a43c3f80d59db56f",
            x"4646ae5047316b4230d0086c8acec687f00b1cd9d1dc634f6cb358ac0a9a8ffffe77b4dd0a4bfb95851f3b7355c781dd60f8418fc8a65d14907aff47c903a559"
        ), 2)
    }
}
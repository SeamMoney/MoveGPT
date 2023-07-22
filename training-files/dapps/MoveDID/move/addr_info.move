module my_addr::addr_info {
    use std::string::{Self, String};
    use std::vector;
    use my_addr::utils;
    use aptos_framework::block;
    use aptos_framework::timestamp;

    friend my_addr::addr_aggregator;
    friend my_addr::addr_aptos;
    friend my_addr::addr_eth;

    // Err enum.
    const ERR_ADDR_INFO_MSG_EMPTY: u64 = 1001;
    const ERR_SIGNATURE_VERIFY_FAIL: u64 = 1002;
    const ERR_TIMESTAMP_EXCEED: u64 = 1003;
    const ERR_ADDR_INVALID_PREFIX: u64 = 1004;
    const ERR_INVALID_ADR_TYPE: u64 = 1005;
    const ERR_ADDR_NO_FIRST_VERIFY: u64 = 1006;
    const ERR_ADDR_MUST_NO_VERIFY: u64 = 1007;

    //:!:>resource
    struct AddrInfo has store, copy, drop {
        id: u64,
        addr_type: u64,
        addr: String,
        pubkey: String,
        description: String,
        chains: vector<String>,
        msg: String,
        signature: vector<u8>,
        spec_fields: String, // for the expand. 
        created_at: u64,
        updated_at: u64,
        expired_at: u64
    }
    //<:!:resource

    // Err pack.
    public fun err_addr_info_empty(): u64 { ERR_ADDR_INFO_MSG_EMPTY }

    public fun err_invalid_addr_type(): u64 { ERR_INVALID_ADR_TYPE }

    public fun err_signature_verify_fail(): u64 { ERR_SIGNATURE_VERIFY_FAIL }

    public fun err_timestamp_exceed(): u64 { ERR_TIMESTAMP_EXCEED }

    // Get attr.
    public fun get_msg(addr_info: &AddrInfo): String { addr_info.msg }
   
    public fun get_addr(addr_info: &AddrInfo): String { addr_info.addr }
   
    public fun get_addr_type(addr_info: &AddrInfo): u64 { addr_info.addr_type }
    
    public fun get_created_at(addr_info: &AddrInfo): u64 { addr_info.created_at }
   
    public fun get_updated_at(addr_info: &AddrInfo): u64 { addr_info.updated_at }
   
    public fun get_pubkey(addr_info: &AddrInfo): String { addr_info.pubkey }

    // Init.
    public(friend) fun init_addr_info(
        send_addr: address,
        id: u64,
        addr_type: u64,
        addr: String,
        pubkey: String,
        chains: &vector<String>,
        description: String,
        spec_fields: String,
        expired_at : u64,
        modified_counter: u64): AddrInfo {
        // Gen Msg Format = {{height.chain_id.send_addr.id_increased_after_modified_op.nonce_geek}} .
        let height = block::get_current_block_height();
        let msg = utils::u64_to_vec_u8_string(height);

        let chain_id_address = @chain_id;
        let chain_id = utils::address_to_u64(chain_id_address);
        let chain_id_vec = utils::u64_to_vec_u8_string(chain_id);
        vector::append(&mut msg, b".");
        vector::append(&mut msg, chain_id_vec);

        let send_addr_vec = utils::address_to_ascii_u8_vec(send_addr);
        vector::append(&mut msg, b".");
        vector::append(&mut msg, send_addr_vec);

        let modified_counter_vec = utils::u64_to_vec_u8_string(modified_counter);
        vector::append(&mut msg, b".");
        vector::append(&mut msg, modified_counter_vec);

        let msg_suffix = b".nonce_geek";
        vector::append(&mut msg, msg_suffix);

        let now = timestamp::now_seconds();

        AddrInfo {
            id: id,
            addr_type: addr_type,
            addr: addr,
            pubkey: pubkey,
            description: description,
            chains: *chains,
            msg: string::utf8(msg),
            signature: b"",
            spec_fields: spec_fields,
            created_at: now,
            updated_at: 0,
            expired_at: expired_at
        }
    }

    // Check addr is 0x prefix.
    public fun check_addr_prefix(addr: String) {
        assert!(string::sub_string(&addr, 0, 2) == string::utf8(b"0x"), ERR_ADDR_INVALID_PREFIX);
    }

    public fun equal_addr(addr_info: &AddrInfo, addr: String): bool {
        let flag = false;
        if (addr_info.addr == addr) {
            flag = true;
        };
        flag
    }

    // Set attr.
    public(friend) fun set_sign_and_updated_at(addr_info: &mut AddrInfo, sig: vector<u8>, updated_at: u64) {
        addr_info.signature = sig;
        addr_info.updated_at = updated_at;
    }

     // Update addr info for addr that verficated, you should resign after you update info.
     public(friend) fun update_addr_info(
        addr_info: &mut AddrInfo, 
        chains: vector<String>, 
        description: String,
        spec_fields: String,
        expired_at: u64,
        send_addr: address,
        modified_counter: u64,
        ) {
        // Check addr_info's signature has verified.
        assert!(vector::length(&addr_info.signature) != 0, ERR_ADDR_NO_FIRST_VERIFY);

        // Gen Msg Format = {{height.chain_id.send_addr.id_increased_after_modified_op.nonce_geek}} .
        // Msg format : block_height.chain_id.nonce_geek.chains.description.
        let height = block::get_current_block_height();
        let msg = utils::u64_to_vec_u8_string(height);

        let chain_id_address = @chain_id;
        let chain_id = utils::address_to_u64(chain_id_address);
        let chain_id_vec = utils::u64_to_vec_u8_string(chain_id);
        vector::append(&mut msg, b".");
        vector::append(&mut msg, chain_id_vec);

         let send_addr_vec = utils::address_to_ascii_u8_vec(send_addr);
         vector::append(&mut msg, b".");
         vector::append(&mut msg, send_addr_vec);

         let modified_counter_vec = utils::u64_to_vec_u8_string(modified_counter);
         vector::append(&mut msg, b".");
         vector::append(&mut msg, modified_counter_vec);

        let msg_suffix = b".nonce_geek";
        vector::append(&mut msg, msg_suffix);

        addr_info.msg = string::utf8(msg);
        addr_info.chains = chains;
        addr_info.description = description;
        addr_info.spec_fields = spec_fields;
        addr_info.expired_at = expired_at;
        addr_info.updated_at = timestamp::now_seconds();
        // reset the signature.
        addr_info.signature = b"";
    }

    // Update addr info for non verification.
    public(friend) fun update_addr_info_for_non_verification(
        addr_info: &mut AddrInfo, 
        chains: vector<String>, 
        description: String,
        spec_fields: String,
        expired_at: u64
        ) {
        // Check addr_info's signature must no verified.
        assert!(vector::length(&addr_info.signature) == 0, ERR_ADDR_MUST_NO_VERIFY);

        addr_info.chains = chains;
        addr_info.description = description;
        addr_info.spec_fields = spec_fields;
        addr_info.expired_at = expired_at;
        addr_info.updated_at = timestamp::now_seconds();
    }

    #[test_only]
    public fun set_addr_info_init_for_testing(
        addr_type: u64,
        addr: String,
        pubkey: String,
        chains: vector<String>,
        description: String,
        spec_fields: String) : AddrInfo{
        AddrInfo{
            addr,
            chains,
            description,
            spec_fields,
            signature: b"",
            msg: string::utf8(b""),
            created_at: 0,
            updated_at: 0,
            id:0,
            addr_type,
            expired_at:0,
            pubkey,
        }
    }
}
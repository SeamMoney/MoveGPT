module starcoin_utils::starcoin_event {
    use starcoin_utils::bcs_deserializer;
    use std::vector;

    const ERROR_INVALID_CONTRACT_EVENT_VERSION: u64 = 101;
    const ERROR_INDEX_OUT_OF_RANGE: u64 = 102;

    struct ContractEvent has store, drop, copy {
        variant_index: u64,
        value: ContractEventV0,
    }

    struct ContractEventV0 has store, drop, copy {
        key: vector<u8>,
        sequence_number: u64,
        type_tag_data: vector<u8>,
        event_data: vector<u8>,
    }

    //    struct TypeTag {
    //        variant_index: u64,
    //        struct_tag: option::Option<StructTag>,
    //    }
    //
    //    struct StructTag {
    //        address: starcoin_address::Address,
    //        module_name: string::String,
    //        name: string::String,
    //        type_params: vector<TypeTag>,
    //    }

    public fun get_contract_event_key(event: ContractEvent): vector<u8> {
        event.value.key
    }

    public fun get_contract_event_sequence_number(event: ContractEvent): u64 {
        event.value.sequence_number
    }

    public fun get_contract_event_type_tag_data(event: ContractEvent): vector<u8> {
        event.value.type_tag_data
    }

    public fun get_contract_event_event_data(event: ContractEvent): vector<u8> {
        event.value.event_data
    }

    public fun bcs_deserialize_contract_event(input: &vector<u8>): ContractEvent {
        let offset = 0;
        let (contract_event_var_idx, offset) = bcs_deserializer::deserialize_variant_index(input, offset);
        assert!(contract_event_var_idx == 0, ERROR_INVALID_CONTRACT_EVENT_VERSION);
        let (key, offset) = bcs_deserializer::deserialize_bytes(input, offset);
        let (sequence_number, offset) = bcs_deserializer::deserialize_u64(input, offset);
        //debug::print(&offset);

        let type_tag_start = offset;
        offset = bcs_bytes_skip_type_tag(input, offset);
        //debug::print(&offset);
        let type_tag_data = sub_u8_vector(input, type_tag_start, offset);

        let (event_data, offset) = bcs_deserializer::deserialize_bytes(input, offset);
        _ = offset;
        ContractEvent {
            variant_index: contract_event_var_idx,
            value: ContractEventV0 {
                key,
                sequence_number,
                type_tag_data,
                event_data,
            }
        }
    }

    public fun bcs_bytes_skip_type_tag(input: &vector<u8>, offset: u64): u64 {
        let (variant_idx, new_offset) = bcs_deserializer::deserialize_variant_index(input, offset);
        if (variant_idx == 6) {
            // vector tag
            new_offset = bcs_bytes_skip_type_tag(input, new_offset);
        } else if (variant_idx == 7) {
            // struct tag
            new_offset = bcs_bytes_skip_stuct_tag(input, new_offset);
        };
        new_offset
    }

    fun bcs_bytes_skip_stuct_tag(input: &vector<u8>, offset: u64): u64 {
        let new_offset = offset;
        let (_address, new_offset) = bcs_deserializer::deserialize_starcoin_address(input, new_offset);
        let (_address, new_offset) = bcs_deserializer::deserialize_string(input, new_offset);
        let (_name, new_offset) = bcs_deserializer::deserialize_string(input, new_offset);

        let (len, new_offset) = bcs_deserializer::deserialize_len(input, new_offset);
        let i = 0;
        while (i < len) {
            new_offset = bcs_bytes_skip_type_tag(input, new_offset);
            i = i + 1;
        };
        new_offset
    }

    fun sub_u8_vector(vec: &vector<u8>, start: u64, end: u64): vector<u8> {
        let i = start;
        let result = vector::empty<u8>();
        assert!(end <= vector::length(vec), ERROR_INDEX_OUT_OF_RANGE);
        while (i < end) {
            vector::push_back(&mut result, *vector::borrow(vec, i));
            i = i + 1;
        };
        result
    }
}
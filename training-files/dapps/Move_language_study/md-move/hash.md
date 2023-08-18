```rust
module std::hash {
    //SHA2와 3계열 해시함수
    native public fun sha2_256(data: vector<u8>): vector<v8>;
    // fn native_sha2_256(
    //     gas_params: &Sha2_256GasParameters,
    //     _context: &mut NativeContext,
    //     _ty_args: Vec<Type>,
    //     mut arguments: VecDeque<Value>,
    // ) -> PartialVMResult<NativeResult> {
    //     debug_assert!(_ty_args.is_empty());
    //     debug_assert!(arguments.len() == 1);

    //     let hash_arg = pop_arg!(arguments, Vec<u8>);

    //     let cost = gas_params.base
    //         + gas_params.per_byte
    //             * std::cmp::max(
    //                 NumBytes::new(hash_arg.len() as u64),
    //                 gas_params.legacy_min_input_len,
    //             );

    //     let hash_vec = Sha256::digest(hash_arg.as_slice()).to_vec();
    //     Ok(NativeResult::ok(cost, smallvec![Value::vector_u8(
    //         hash_vec
    //     )]))
    // }

    native public fun sha3_256(data: vector<u8>): vector<v8>;
    // fn native_sha3_256(
    //     gas_params: &Sha3_256GasParameters,
    //     _context: &mut NativeContext,
    //     _ty_args: Vec<Type>,
    //     mut arguments: VecDeque<Value>,
    // ) -> PartialVMResult<NativeResult> {
    //     debug_assert!(_ty_args.is_empty());
    //     debug_assert!(arguments.len() == 1);

    //     let hash_arg = pop_arg!(arguments, Vec<u8>);

    //     let cost = gas_params.base
    //         + gas_params.per_byte
    //             * std::cmp::max(
    //                 NumBytes::new(hash_arg.len() as u64),
    //                 gas_params.legacy_min_input_len,
    //             );

    //     let hash_vec = Sha3_256::digest(hash_arg.as_slice()).to_vec();
    //     Ok(NativeResult::ok(cost, smallvec![Value::vector_u8(
    //         hash_vec
    //     )]))
    // }
}
```
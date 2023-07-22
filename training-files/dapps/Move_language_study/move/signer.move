module std::signer {
    // signer의 소유권을 빌리는 함수
    native public fun borrow_address(s: &signer): &address;
    // -- rust code --
    // #[inline]
    // fn native_borrow_address(
    //     gas_params: &BorrowAddressGasParameters,
    //     _context: &mut NativeContext,
    //     _ty_args: Vec<Type>,
    //     mut arguments: VecDeque<Value>,
    // ) -> PartialVMResult<NativeResult> {
    //     debug_assert!(_ty_args.is_empty());
    //     debug_assert!(arguments.len() == 1);

    //     let signer_reference = pop_arg!(arguments, SignerRef);

    //     Ok(NativeResult::ok(gas_params.base, smallvec![
    //         signer_reference.borrow_signer()?
    //     ]))
    // }

    // 소유권을 빌리는 함수를 실행하면 address의 reference를 리턴하는데
    // 이 함수에서는 *를 붙여 값에 직접 접근하여 리턴한다
    public fun address_of(s: &signer): address {
        *borrow_address(s)
    }

    // native는 interface선언과 같은 역할로 함수명 인수타입, 리턴타입만을 미리 선언해둔 것
    spec native fun is_txn_signer(s: signer): bool;

    spec native fun is_tx_signer_address(a: address): bool;
}
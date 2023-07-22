// 테스트 환경에서만 사용된다는 attribute
#[test_only]
module hello_blockchain::message_tests {
    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::string;
    // hello_blockchain.move에서 작성했던 message모듈 가져오기 
    use hello_blockchain::message

    fun get_aacount(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1)
    }

    #[test]
    public entry fun sender_can_set_message {
        let account = get_account();
        let addr = signer::address_of(&account);
        // 입력받은 주소의 signer 생성
        aptos_framework::acount::create_account_for_test(addr);
        // account에 string저장
        message::set_message(account, string::utf8(b"Hello, Blockchain"));
        // 저장한 string과 동일한지 테스트
        assert!(message::get_message(addr) == string::utf8(b"Hello, Blockchain"), 0);
    }
    // fn native_create_signers_for_testing(
    //     gas_params: &CreateSignersForTestingGasParameters,
    //     _context: &mut NativeContext,
    //     ty_args: Vec<Type>,
    // mut args: VecDeque<Value>,
    // ) -> PartialVMResult<NativeResult> {
    //     // ty_args는 비어있어야하고, args는 차있어야한다  
    //     debug_assert!(ty_args.is_empty());
    //     debug_assert!(args.len() == 1);
    //     // uint64 타입으로 args 꺼내기
    //     let num_signers = pop_arg!(args, u64);
    //     // 개수만큼 account 생성
    //     let signers = Value::vector_for_testing_only(
    //         (0..num_signers).map(|i| Value::signer(AccountAddress::new(to_le_bytes(i)))),
    //     );
    //     // 가스비 계산
    //     let cost = gas_params.base_cost + gas_params.unit_cost * NumArgs::new(num_signers);
    //     // account vector 리턴
    //     Ok(NativeResult::ok(cost, smallvec![signers]))
    // }
}
```rust
//
module std::vector {
    //에러코드 선언
    const EINDEX_OUT_OF_BOUNDS: u64 = 0x20000;
    const EINVALID_RANGE: u64 = 0x20001;
    const EVECTORS_LENGTH_MISMATCH: u64 = 0x20002;
    //bytecode 명령어로 처리
    //rust 코드에서 로직을 가져와서 처리
    #[bytecode_instruction]
    native public fun empty<Element>(): vector<Element>;

    // pub fn native_empty(
    //     gas_params: &EmptyGasParameters,
    //     _context: &mut NativeContext,
    //     ty_args: Vec<Type>,
    //     args: VecDeque<Value>,
    // ) -> PartialVMResult<NativeResult> {
    //     //하나의 vec
    //     debug_assert!(ty_args.len() == 1);
    //     //vec의 원소는 없어야함
    //     debug_assert!(args.is_empty());

    //     NativeResult::map_partial_vm_result_one(gas_params.base, Vector::empty(&ty_args[0]))
    // }

    //vector 길이 계산
    #[bytecode_instruction]
    native public fun length<Element>(v: &vector<Element>): u64;
    //vector 원소의 소유권 빌리기
    #[bytecode_instruction]
    native public fun borrow<Element>(v: &vector<Element>, i: u64): &Element;
    //vector 맨 뒤에 원소 추가
    #[bytecode_instruction]
    native public fun push_back<Element>(v: &mut vector<Element>, e: Element);
    //수정가능한 상태로 소유권 빌리기
    #[bytecode_instruction]
    native public fun borrow_mut<Element>(v: &mut vector<Element>, i: u64): &mut Element;
    //vector 맨 뒤에서 원소 꺼내기
    #[bytecode_instruction]
    native public fun pop_back<Element>(v: vector<Element>);
    //빈 vector 제거
    #[bytecode_instruction]
    native public fun destroy_empty<Element>(v: vector<Element>);
    //두 원소의 위치 변경
    #[bytecode_instruction]
    native public fun swap<Element>(v: &mut vector<Element>, i: u64, j: u64);

    //인수로 제공한 한 개의 원소만을 갖는 vector를 리턴 
    public fun singleton<Element>(e: Element): vector<Element> {
        let v = empty();
        push_back(&mut v, e);
        v
    }
    //singleton 함수가 지켜야하는 규칙 명시 
    spec singleton {
        //예외가 일어나서는 안된다
        aborts_if false;
        //함수 실행 후 결과값이 vec(e)와 동일해야한다
        ensures result == vec(e);
    }
    //일정 부분 vector 원소 전체 반대로 정렬
    public fun reverse_slice<Element>(v: &mut vector<Element>, left: u64, right: u64) {
        //왼쪽 인덱스가 오른쪽 인덱스보다 크면 에러
        assert!(left <= right, EINVALID_RANGE);
        if (left == right) return;
        right = right - 1;
        while (left < right) {
            swap(v, left, right);
            left = left + 1;
            right = right - 1;
        }
    }
    spec reverse_slice {
        //reverse_slice는 내장 함수로 처리
        pragma intrinsic = true;
    }
    //vector 전체 뒤집기
    public fun reverse<Element>(v: &mut vector<Element>) {
        let len = length(v);
        reverse_slice(v, 0, len);
    }
    spec reverse_slice {
        pragma intrinsic = true;
    }

    //...

    //inline은 함수를 불러오지 않고 해당 함수 내용을 코드에 직접 넣게 만드는 키워드
    //solidity의 modifier과 유사한 것으로 보임
    public inline fun for_each<Element>(v: vector<Element>, f: |Element|) {
        reverse(&mut v);
        for_each_reverse(v, |e| f(e));
    }
    
    //....
}

```
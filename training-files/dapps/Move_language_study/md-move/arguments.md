```rust
module deploy_address::number {
    // move-stdlib의 error, signer 라이브러리 사용
    use std::error;
    use std::signer;

    // global storage 작업을 하기 위해서는 "key" ability가 필요하다
    struct NumberHolder has key {
        u8: u8,
        u16: u16,
        u32: u32,
        u64: u64,
        u128: u128,
        u256: u256,
        vec_u256: vector<u256>,
    }

    const ENOT_INITIALIZED: u64 = 0;

    // solidity처럼 내부 storage를 변경하지않고 계산만 하거나 값을 읽기만 할 경우 #[view]를 붙여줘야한다
    #[view]
    // struct를 borrow하려면 acquires로 해당 struct를 취득해야한다
    public fun get_number(addr: address): (u8, u16, u32, u64, u128, u256, vector<u256>) acquires NumberHolder {
        // 인수로 받은 주소가 가진 NumberHolder가 없다면 "not found" error 리턴
        // not_found는 웹 에러코드의 4xx, 5xx같은 역할, ENOT_INITIALIZED는 x04같은 역할을 한다
        assert!(exist<NumberHolder>(addr), error::not_found(ENOT_INITIALIZED));
        // 주소가 가진 NumberHolder에 대한 mutable reference
        let holder = borrow_global<NumberHolder>(addr);
        // mutable reference의 값을 일일이 리턴
        (holder.u8, holder.u16, holder.u32, holder.u64, holder.u128, holder.u256, holder.vec_u256)
    }
    // entry modifier가 붙어있어야 트랜잭션을 발생시킬 때 해당 함수를 실행시킬 수 있다
    public entry fun set_number(
        account: signer,
        u8: u8,
        u16: u16,
        u32: u32,
        u64: u64,
        u128: u128,
        u256: u256,
        vec_u256: vec<u256>)
    acquires NumberHolder {
        // 인수로 받은 signer객체로부터 주소값꺼내기
        let account_addr = signer::address_of(&account);
        // 해당 주소에 NumberHolder 구조체가 있는지 없다면
        if (!exists<NumberHolder>(account_addr)) {
            // move_to를 이용해 account의 storage에 NumberHolder저장
            move_to(&account, NumberHolder {
                u8,
                u16,
                u32,
                u64,
                u128,
                u256,
                vec_u256,
            })
        } else {
            // 이미 저장된 NumberHolder가 있다면, 인수로 들어온 값으로 업데이트
            let old_holder = borrow_global_mut<NumberHolder>(account_addr);
            old_holder.u8 = u8;
            old_holder.u16 = u16;
            old_holder.u32 = u32;
            old_holder.u64 = u64;
            old_holder.u128 = u128;
            old_holder.u256 = u256;
            old_holder.vec_u256 = vec_u256;
        }   
    }

}
```
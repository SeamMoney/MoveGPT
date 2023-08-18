```rust
module 0x42::prove {
    // 인수에 1을 더해서 리턴하는 함수 선언
    fun plus1(x: u64) {
        x+1
    }
    // 함수의 결과가 항상 x+1과 일치하는지 체크
    spec plus1 {
        ensures result == x+1
    }
    // 인수가 0이면 abort시키는 함수 선언
    fun abortsIf0(x: u64) {
        if (x == 0) {
            abort(0)
        };
    }
    // 실제로 인수가 0일 때 abort가 일어나는지 체크
    spec abortsIf0 {
        aborts_if x == 0;
    }
}
```
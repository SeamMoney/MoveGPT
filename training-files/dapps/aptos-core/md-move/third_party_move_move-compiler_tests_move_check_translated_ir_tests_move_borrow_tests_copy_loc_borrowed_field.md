```rust
module 0x8675309::Tester {
    struct T has copy, drop { f: u64 }

    fun t() {
        let x = T { f: 0 };
        let r1 = &x.f;
        let r2 = &x.f;
        copy x;
        r1;
        r2;
    }
}

```
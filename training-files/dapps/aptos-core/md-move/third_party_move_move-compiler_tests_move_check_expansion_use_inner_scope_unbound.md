```rust
address 0x2 {
module M {
    struct S1 { b: bool }
    struct S2 { u: u64 }
    fun check(): bool {
        false
    }
    fun num(): u64 {
        0
    }

    fun t() {
        use 0x2::N;
        use 0x2::M::foo;

    }
}
}

```
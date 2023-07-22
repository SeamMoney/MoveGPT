module Viper::Math {

    use 0x1::Debug;

    public fun sum(a: u64, b: u64): u64 {
        a + b
//        return a + b
    }

    public fun sum_2(a: u64, b: u8): u64 {
        a + (b as u64)
//        return a + b
    }
    
    public fun max(a:u64, b:u64) :u64 {
        if (a >= b) {
            a
        } else {
            b
        }
    }

    public fun sum_to_a(a: u64) :u64 {
        let i:u64 = 1;
        let sum:u64 = 0;
        while(i <= a) {
            sum = sum + i;
            i = i + 1;
        };
        sum
    }

    public fun sum_99() :u64 {
        let i:u64 = 0;
        let sum:u64 = 0;

        while(i <= 99) {
            i = i + 1;
            if (i % 2 == 0) {
                continue;
            };
            sum = sum + i;
        };
        sum
    }

    const PI:u64 = 314;
    public fun get_area(r: u64) :u64 {
        r * r * PI
    }
    /*
    public fun swap(a:u64, b:u64) {
        let temp = a;
        a = b;
        b = temp;
    }
    */

    public fun swap(a:&mut u64, b:&mut u64) {
        let temp = *a;
        *a = *b;
        *b = temp;
    }

    public fun show<T:drop>(x:T) {
        Debug::print(&x);
    }

}
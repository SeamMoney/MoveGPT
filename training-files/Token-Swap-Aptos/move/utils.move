module Aptoswap::utils {

    const TIME_INTERVAL_DAY: u64 = 86400;

    struct WeeklySmaU128 has drop, store {
        start_time: u64,
        current_time: u64,

        a0: u128, a1: u128,  a2: u128,  a3: u128,  a4: u128,  a5: u128,  a6: u128,
        c0: u64, c1: u64,  c2: u64,  c3: u64,  c4: u64,  c5: u64,  c6: u64,
    }

    public fun create_sma128(): WeeklySmaU128 {
        WeeklySmaU128 {
            start_time: 0,
            current_time: 0,
            a0: 0, a1: 0, a2: 0, a3: 0, a4: 0, a5: 0, a6: 0,
            c0: 0, c1: 0, c2: 0, c3: 0, c4: 0, c5: 0, c6: 0,
        }
    }

    public fun add_sma128(sma: &mut WeeklySmaU128, time: u64, value: u128) {
        sma.current_time = time;

        if (sma.start_time == 0) {
            sma.start_time = time - (TIME_INTERVAL_DAY * 1);
            sma.a0 = value;
            sma.a1 = 0;
            sma.a2 = 0;
            sma.a3 = 0;
            sma.a4 = 0;
            sma.a5 = 0;
            sma.a6 = 0;

            sma.c0 = 1;
            sma.c1 = 0;
            sma.c2 = 0;
            sma.c3 = 0;
            sma.c4 = 0;
            sma.c5 = 0;
            sma.c6 = 0;
        } else {
            while (sma.start_time + (TIME_INTERVAL_DAY * 7) <= time) {
                sma.start_time = sma.start_time + TIME_INTERVAL_DAY;
                sma.a0 = sma.a1;
                sma.a1 = sma.a2;
                sma.a2 = sma.a3;
                sma.a3 = sma.a4;
                sma.a4 = sma.a5;
                sma.a5 = sma.a6;
                sma.a6 = 0;

                sma.c0 = sma.c1;
                sma.c1 = sma.c2;
                sma.c2 = sma.c3;
                sma.c3 = sma.c4;
                sma.c4 = sma.c5;
                sma.c5 = sma.c6;
                sma.c6 = 0;
            };
        };

        let index = (time - sma.start_time) / TIME_INTERVAL_DAY;
        if (index == 0) {
            sma.a6 = sma.a6 + value;
            sma.c6 = sma.c6 + 1;
        }
        else if (index == 1) {
            sma.a1 = sma.a1 + value;
            sma.c1 = sma.c1 + 1;
        }
        else if (index == 2) {
            sma.a2 = sma.a2 + value;
            sma.c2 = sma.c2 + 1;
        }
        else if (index == 3) {
            sma.a3 = sma.a3 + value;
            sma.c3 = sma.c3 + 1;
        }
        else if (index == 4) {
            sma.a4 = sma.a4 + value;
            sma.c4 = sma.c4 + 1;
        }
        else if (index == 5) {
            sma.a5 = sma.a5 + value;
            sma.c5 = sma.c5 + 1;
        }
        else {
            sma.a6 = sma.a6 + value;
            sma.c6 = sma.c6 + 1;
        }
    }

    public fun pow10(num: u8): u64 {
        // Naive implementation, we can refine with quick pow, but currently it is not necessary
        let value: u64 = 1;
        let i: u8 = 0;

        while (i < num) {
            value = value * 10;
            i = i + 1;
        };

        value
    }

    #[test]
    fun test_pow10() {
        assert!(pow10(0) == 1, 0);
        assert!(pow10(1) == 10, 1);
        assert!(pow10(2) == 100, 2);
        assert!(pow10(3) == 1000, 3);
        assert!(pow10(4) == 10000, 4);
        assert!(pow10(5) == 100000, 5);
        assert!(pow10(6) == 1000000, 6);
        assert!(pow10(7) == 10000000, 7);
        assert!(pow10(8) == 100000000, 8);
        assert!(pow10(9) == 1000000000, 9);
        assert!(pow10(10) == 10000000000, 10);
        assert!(pow10(11) == 100000000000, 11);
        assert!(pow10(12) == 1000000000000, 12);
        assert!(pow10(13) == 10000000000000, 13);
        assert!(pow10(14) == 100000000000000, 14);
        assert!(pow10(15) == 1000000000000000, 15);
        assert!(pow10(16) == 10000000000000000, 16);
        assert!(pow10(17) == 100000000000000000, 17);
        assert!(pow10(18) == 1000000000000000000, 18);
        assert!(pow10(19) == 10000000000000000000, 19);
    }
}
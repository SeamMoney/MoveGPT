module samm::fee_spacing {
    use aptos_std::type_info;
    use samm::i64:: {Self, I64};
    struct Fee100 {

    }
    
    struct Fee500 {

    }

    struct Fee3000 {

    }

    struct Fee10000 {

    }

    struct F3000S12 {

    }

    struct F3000S1 {

    }

    public fun get_tick_spacing<FeeType>(): (u64, I64) {
        if (type_info::type_of<FeeType>() == type_info::type_of<Fee100>()) {
            return (100, i64::from(1))
        };
        if (type_info::type_of<FeeType>() == type_info::type_of<Fee500>()) {
            return (500, i64::from(10))
        };
        if (type_info::type_of<FeeType>() == type_info::type_of<Fee3000>()) {
            return (3000, i64::from(60))
        };
        if (type_info::type_of<FeeType>() == type_info::type_of<Fee10000>()) {
            return (10000, i64::from(200))
        };
        if (type_info::type_of<FeeType>() == type_info::type_of<F3000S12>()) {
            return (3000, i64::from(12))
        };
        if (type_info::type_of<FeeType>() == type_info::type_of<F3000S1>()) {
            return (3000, i64::from(1))
        };
        (0, i64::from(0))
    }
}
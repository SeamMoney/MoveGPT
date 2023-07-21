module switchboard_feed_parser::switchboard_feed_parser {
    use std::signer;
    
    use switchboard::aggregator; // For reading aggregators
    use switchboard::math;

    const EAGGREGATOR_INFO_EXISTS:u64 = 0;
    const ENO_AGGREGATOR_INFO_EXISTS:u64 = 1;

    /*
      Num 
      {
        neg: bool,   // sign
        dec: u8,     // scaling factor
        value: u128, // value
      }

      where decimal = neg * value * 10^(-1 * dec) 
    */
    struct AggregatorInfo has copy, drop, store, key {
        aggregator_addr: address,
        latest_result: u128,
        latest_result_scaling_factor: u8,
    }

    // add AggregatorInfo resource with latest value + aggregator address
    public entry fun log_aggregator_info(
        account: &signer,
        aggregator_addr: address, 
    ) {       
      assert!(!exists<AggregatorInfo>(signer::address_of(account)), EAGGREGATOR_INFO_EXISTS);

        // get latest value 
        let (value, scaling_factor, _neg) = math::unpack(aggregator::latest_value(aggregator_addr)); 
        move_to(account, AggregatorInfo {
            aggregator_addr: aggregator_addr,
            latest_result: value,
            latest_result_scaling_factor: scaling_factor
        });
    }

    public entry fun get_latest_price(aggregator_addr:address) acquires AggregatorInfo
    {
        let (value, scaling_factor, _neg) = math::unpack(aggregator::latest_value(aggregator_addr));
        let vec = &mut borrow_global_mut<AggregatorInfo>(@switchboard_feed_parser).latest_result;
        *vec=value;
         std::debug::print(&value);
    }

    #[test(account = @switchboard_feed_parser)]
    public entry fun test_aggregator(account: &signer) {

        // creates test aggregator with data
        aggregator::new_test(account, 100, 0, false);

        // print out value
        std::debug::print(&aggregator::latest_value(signer::address_of(account)));
    }


//     use switchboard::aggregator;
// use switchboard::math;

// // store latest value
// struct AggregatorInfo has copy, drop, store, key {
//     aggregator_addr: address,
//     latest_result: u128,
//     latest_result_scaling_factor: u8,
//     latest_result_neg: bool,
// }

// // get latest value
// public entry fun save_latest_value(account:&signer,aggregator_addr: address) {
//     // get latest value
//     let latest_value = aggregator::latest_value(aggregator_addr);
//     let (value, scaling_factor, neg) = math::unpack(latest_value);
//     move_to(account, AggregatorInfo {
//         aggregator_addr: aggregator_addr,
//         latest_result: value,
//         latest_result_scaling_factor: scaling_factor,
//         latest_result_neg: neg,
//     });
//     std::debug::print(&aggregator::latest_value(signer::address_of(account)));
// }

// // some testing that uses aggregator test utility functions
// //#[test(account = @0x1)]
// public entry fun test_aggregator(account: &signer) {

//     // creates test aggregator with data
//     //saggregator::new_test(account, 100, 0, false);

//     // print out value
//     std::debug::print(&aggregator::latest_value(signer::address_of(account)));
// }
}

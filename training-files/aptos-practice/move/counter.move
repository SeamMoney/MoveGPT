module project::counter {

  struct Counter has key, copy { value: u64 }

  public entry fun publish(account: signer) {
    move_to(&account, Counter { value: 0 })
  }

  #[view]
  public fun get_value(addr: address): u64 acquires Counter {
    borrow_global<Counter>(addr).value
  }

  public entry fun increase(addr: address) acquires Counter {
    let c = borrow_global_mut<Counter>(addr);
    c.value = c.value + 1;
  }

  #[test(account = @0xACC)]
  fun test_publish_happy_case(account: signer) {
    publish(account);
  }

  #[test(account = @0xACC)]
  fun test_get_value(account: signer) acquires Counter {
    let addr = signer::address_of(&account);
    test_publish_happy_case(account);
    let value = get_value(addr);
    assert!(value == 0, 0);
  }

  #[test(account = @0xACC)]
  fun test_increase(account: signer) acquires Counter {
    let addr = signer::address_of(&account);
    test_publish_happy_case(account);
    let value = get_value(addr);
    assert!(value == 0, 0);
    increase(addr);
    value = get_value(addr);
    assert!(value == 1, 1);
  }
}

module source_addr::the_3rd {
  use std::signer;
  use std::error;

  use aptos_framework::account;
  use aptos_framework::coin;
  use aptos_framework::resource_account;
  use aptos_framework::aptos_coin::{AptosCoin};

  const EINSUFFICIENT_BALANCE: u64 = 1;

  struct ModuleData has key {
    resource_signer_cap: account::SignerCapability,
    counter: u8,
  }

  // `init_module` is automatically called when publishing the module.
  // `resource_signer` resource account when call aptos move create-resource-account-and-publish-package
  fun init_module(resource_signer: &signer) {
    let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @deployer);

    move_to(resource_signer, ModuleData {
      resource_signer_cap,
      counter: 0,
    });

    coin::register<AptosCoin>(resource_signer);
  }

  public entry fun bet(from: &signer, amount: u64) acquires ModuleData {
    let module_data = borrow_global_mut<ModuleData>(@source_addr);
    let counter = &mut module_data.counter;
    *counter = *counter + 1;
    if (*counter == 3) {
      let pot = coin::balance<AptosCoin>(@source_addr);
      let resource_signer = account::create_signer_with_capability(&module_data.resource_signer_cap);
      coin::transfer<AptosCoin>(&resource_signer, signer::address_of(from), pot);
      *counter = 0;
    } else {
      coin::transfer<AptosCoin>(from, @source_addr, amount);
    };
  }

  spec bet {
    aborts_if amount == 0 with error::invalid_argument(EINSUFFICIENT_BALANCE);
  }

  #[test_only]
  public entry fun set_up_test(resource_account: &signer, acc1: &signer, acc2: &signer, acc3: &signer) {
    account::create_account_for_test(signer::address_of(acc1));
    account::create_account_for_test(signer::address_of(acc2));
    account::create_account_for_test(signer::address_of(acc3));

    init_module(resource_account);
  }

  #[test(
    resource_account = @source_addr,
    framework = @aptos_framework,
    acc1 = @0x101,
    acc2 = @0x102,
    acc3 = @0x103
  )]
  fun test_bet(resource_account: signer, framework: signer, acc1: signer, acc2: signer, acc3: signer) acquires ModuleData {
    use aptos_framework::aptos_coin;

    set_up_test(&resource_account, &acc1, &acc2, &acc3);
    let (aptos_coin_burn_cap, aptos_coin_mint_cap) = aptos_coin::initialize_for_test(&framework);

    // funding test accounts
    let acc1Coins = coin::mint<AptosCoin>(100, &aptos_coin_mint_cap);
    coin::register<AptosCoin>(&acc1);
    coin::deposit(signer::address_of(&acc1), acc1Coins);

    let acc2Coins = coin::mint<AptosCoin>(100, &aptos_coin_mint_cap);
    coin::register<AptosCoin>(&acc2);
    coin::deposit(signer::address_of(&acc2), acc2Coins);

    let acc3Coins = coin::mint<AptosCoin>(100, &aptos_coin_mint_cap);
    coin::register<AptosCoin>(&acc3);
    coin::deposit(signer::address_of(&acc3), acc3Coins);

    // users betting
    bet(&acc1, 50);
    bet(&acc2, 50);
    bet(&acc3, 50);

    assert!(coin::balance<AptosCoin>(signer::address_of(&acc1)) == 50, 1000);
    assert!(coin::balance<AptosCoin>(signer::address_of(&acc2)) == 50, 2000);
    assert!(coin::balance<AptosCoin>(signer::address_of(&acc3)) == 200, 3000);

    coin::destroy_mint_cap<AptosCoin>(aptos_coin_mint_cap);
    coin::destroy_burn_cap<AptosCoin>(aptos_coin_burn_cap);
  }
}

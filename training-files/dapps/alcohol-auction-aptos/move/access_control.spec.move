spec alcohol_auction::access_control {
  spec module {
    pragma verify = true;
    pragma aborts_if_is_strict;
  }

  spec init_module {
    pragma verify = false;
  }

  spec get_signer {
    aborts_if !exists<AccessControl>(@alcohol_auction);
  }

  spec get_admin {
    aborts_if !exists<AccessControl>(@alcohol_auction);
  }

  spec admin_only {
    aborts_if !exists<AccessControl>(@alcohol_auction);
    aborts_if signer::address_of(account) != global<AccessControl>(@alcohol_auction).admin;
  }

  spec change_admin {
    aborts_if !exists<AccessControl>(@alcohol_auction);
    aborts_if signer::address_of(account) != global<AccessControl>(@alcohol_auction).admin;
    ensures global<AccessControl>(@alcohol_auction).admin == new_admin;
  }
}

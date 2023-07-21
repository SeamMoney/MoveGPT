address Quantum {

module QBITSTeamTreasury {

    use std::signer;

    use aptos_framework::coin;

    use Quantum::Treasury;
    use Quantum::QBITS::{Self, QBITS};

    const LOCK_TIME: u64 = 3 * 365 * 86400; // 3 years
    const LOCK_PERCENT: u64 = 20;          // 20%

    struct Capabilities<phantom CoinType> has key {
        burn_cap: coin::BurnCapability<CoinType>,
        freeze_cap: coin::FreezeCapability<CoinType>,
        mint_cap: coin::MintCapability<CoinType>,
    }

    public entry fun initialize(account: signer) acquires Capabilities {
        let user = signer::address_of(&account);
        let amount = QBITS::get_max_supply() * LOCK_PERCENT / 100;
        let capabilities = borrow_global<Capabilities<QBITS>>(user);
        let token = coin::mint<QBITS>(amount, &capabilities.mint_cap);
        let cap = Treasury::initialize<QBITS>(&account, token);
        let linear_cap = Treasury::issue_linear_withdraw_capability<QBITS>(
            &mut cap,
            amount,
            LOCK_TIME,
        );
        Treasury::add_linear_withdraw_capability<QBITS>(&account, linear_cap);
        Treasury::destroy_withdraw_capability<QBITS>(cap);
    }

    public entry fun withdraw(account: signer, to: address) {
        coin::deposit<QBITS>(to, Treasury::withdraw_by_linear<QBITS>(&account));
    }

    public fun balance(): u64 { Treasury::balance<QBITS>() }
}
}
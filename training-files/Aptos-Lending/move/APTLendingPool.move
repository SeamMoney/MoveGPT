address Quantum {

module APTLendingPool {
    use std::signer;
    use aptos_framework::aptos_coin::AptosCoin;  // Collateral
    use Quantum::QUSD::{Self, QUSD};    // Stable Coin
    use Quantum::LendingPool;

    // Pool Type
    struct APT_POOL has store {}

    const ORACLE_NAME: vector<u8> = b"APT_POOL";
    const COLLATERIZATION_RATE: u64 = 67500;       // 67.5%
    const LIQUIDATION_THRESHOLD: u64 = 80000;      // 80%
    const LIQUIDATION_MULTIPLIER: u64 = 107500;    // 107.5%
    const BORROW_OPENING_FEE: u64 = 500;           // 0.5%
    const INTEREST: u64 = 1000;                    // 1%
    const TOKEN_AMOUNT: u64 = 10 * 10000 * 1000 * 1000 * 1000;
    const BORROW_LIMIT: u64 = 0;

    public entry fun initialize(account: signer) {
        QUSD::mint_to(&account, signer::address_of(&account), TOKEN_AMOUNT);
        LendingPool::initialize<APT_POOL, AptosCoin, QUSD>(
            &account,
            COLLATERIZATION_RATE,
            LIQUIDATION_THRESHOLD,
            LIQUIDATION_MULTIPLIER,
            BORROW_OPENING_FEE,
            INTEREST,
            TOKEN_AMOUNT,
            ORACLE_NAME,
        );
        LendingPool::init_min_borrow<APT_POOL>(&account, BORROW_LIMIT);
    }
    // for withdrawer
    public fun do_deposit(account: &signer, amount: u64) {
        LendingPool::deposit<APT_POOL, QUSD>(account, amount);
    }
    public entry fun deposit(account: signer, amount: u64) {
        do_deposit(&account, amount);
    }
    public entry fun init_min_borrow(account: signer) {
        LendingPool::init_min_borrow<APT_POOL>(&account, BORROW_LIMIT);
    }
    public entry fun set_min_borrow(account: signer) {
        LendingPool::set_min_borrow<APT_POOL>(&account, BORROW_LIMIT);
    }
    public fun get_min_borrow(): u64 { LendingPool::get_min_borrow<APT_POOL>() }

    // fee
    public entry fun set_fee_to(account: signer, new_fee_to: address) {
        LendingPool::set_fee_to<APT_POOL>(&account, new_fee_to);
    }
    // for withdrawer
    public fun do_withdraw() { LendingPool::withdraw<APT_POOL, QUSD>(); }

    public entry fun withdraw() { do_withdraw(); }

    public entry fun accrue() { LendingPool::accrue<APT_POOL, QUSD>(); }

    // oracle
    public entry fun update_exchange_rate() { LendingPool::update_exchange_rate<APT_POOL>(); }

    public fun get_exchange_rate(): (u64, u64) { LendingPool::get_exchange_rate<APT_POOL>() }

    public fun latest_exchange_rate(): (u64, u64) { LendingPool::latest_exchange_rate<APT_POOL>() }

    // config
    public fun settings(): (u64, u64, u64, u64, u64) {
        (
            COLLATERIZATION_RATE,
            LIQUIDATION_THRESHOLD,
            LIQUIDATION_MULTIPLIER,
            BORROW_OPENING_FEE,
            INTEREST,
        )
    }
    public fun is_deprecated(): bool { LendingPool::is_deprecated<APT_POOL>() }

    public fun collateral_info(): u64 { LendingPool::collateral_info<APT_POOL, AptosCoin>() }

    // (part, amount, left)
    public fun borrow_info(): (u64, u64, u64) { LendingPool::borrow_info<APT_POOL, QUSD>() }

    public fun fee_info(): (address, u64, u64) { LendingPool::fee_info<APT_POOL>() }

    public fun position(addr: address): (u64, u64, u64) {
        let (collateral, part) = LendingPool::position<APT_POOL>(addr);
        let amount = LendingPool::toAmount<APT_POOL, QUSD>(part, true);
        (collateral, part, amount)
    }

    // collateral
    public entry fun add_collateral(account: signer, amount: u64) {
        LendingPool::add_collateral<APT_POOL, AptosCoin>(&account, amount);
    }

    public entry fun remove_collateral(account: signer, receiver: address, amount: u64) {
        LendingPool::remove_collateral<APT_POOL, AptosCoin, QUSD>(&account, receiver, amount);
    }

    // borrow
    public entry fun borrow(account: signer, receiver: address, amount: u64) {
        LendingPool::borrow<APT_POOL, QUSD>(&account, receiver, amount);
    }
    public entry fun repay(account: signer, receiver: address, part: u64) {
        LendingPool::repay<APT_POOL, QUSD>(&account, receiver, part);
    }

    // liquidate
    public fun is_solvent(addr: address, exchange_rate: u64): bool {
        LendingPool::is_solvent<APT_POOL, QUSD>(addr, exchange_rate)
    }
    public entry fun liquidate(
        account: signer,
        users: vector<address>,
        max_parts: vector<u64>,
        to: address,
    ) {
        LendingPool::liquidate<APT_POOL, AptosCoin, QUSD>(&account, &users, &max_parts, to);
    }

    // cook
    public entry fun cook(
        account: signer,
        actions: vector<u8>,
        collateral_amount: u64,
        remove_collateral_amount: u64,
        remove_collateral_to: address,
        borrow_amount: u64,
        borrow_to: address,
        repay_part: u64,
        repay_to: address
    ) {
        LendingPool::cook<APT_POOL, AptosCoin, QUSD>(
            &account,
            &actions,
            collateral_amount,
            remove_collateral_amount,
            remove_collateral_to,
            borrow_amount,
            borrow_to,
            repay_part,
            repay_to,
        );
    }

    // deprecated
    public entry fun deprecated(
        account: signer,
        to: address,
        collateral_amount: u64,
        borrow_amount: u64,
    ) {
        LendingPool::deprecated<APT_POOL, AptosCoin, QUSD>(&account, to, collateral_amount, borrow_amount);
    }
}
}

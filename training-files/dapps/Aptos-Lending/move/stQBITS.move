address Quantum {
module stQBITS {

    use std::signer;
    use std::event;
    use std::string;
    use std::option;

    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::type_info;

    use Quantum::SafeMathU64;
    use Quantum::QBITS::{QBITS};

    // token
    struct STQBITS has copy, drop, store {}

    // cap
    struct SharedMintCapability has key, store { mint_cap: coin::MintCapability<STQBITS> }
    struct SharedBurnCapability has key, store { burn_cap: coin::BurnCapability<STQBITS> }
    struct SharedFreezeCapability has key, store { freeze_cap: coin::FreezeCapability<STQBITS> }

    // share treasury
    struct DepositEvent has drop, store { account: address, amount: u64 }
    struct MintEvent has drop, store { account: address, amount: u64 }
    struct BurnEvent has drop, store { account: address, amount: u64 }

    struct Treasury has key, store {
        token: coin::Coin<QBITS>,
        locked: u64,    // total locked stQBITS
        deposit_events: event::EventHandle<DepositEvent>,
        mint_events: event::EventHandle<MintEvent>,
        burn_events: event::EventHandle<BurnEvent>,

    }

    // error code
    const ERR_NOT_EXIST: u64 = 100;
    const ERR_ZERO_AMOUNT: u64 = 101;
    const ERR_LOCKED: u64 = 102;

    // user lock
    const LOCK_TIME: u64 = 24 * 3600;

    const BASE_COIN_NAME: vector<u8> = b"Staked Quantum Bits";

    const BASE_COIN_SYMBOL: vector<u8> = b"stQBITS";

    const BASE_COIN_DECIMALS: u8 = 9;

    struct Balance has key, store {
        token: coin::Coin<STQBITS>,
        locked_until: u64,
    }

    /// A helper function that returns the address of CoinType.
    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    fun assert_treasury(): address {
        let owner = coin_address<STQBITS>();
        assert!(exists<Treasury>(owner), ERR_NOT_EXIST);
        owner
    }

    /// Initialize new coin `CoinType` in Aptos Blockchain.
    /// Mint and Burn Capabilities will be stored under `account` in `Capabilities` resource.
    fun init_coin<CoinType>(
        account: &signer,
        name: vector<u8>,
        symbol: vector<u8>,
        decimals: u8,
        monitor_supply: bool,
    ) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<STQBITS>(
            account,
            string::utf8(name),
            string::utf8(symbol),
            decimals,
            monitor_supply,
        );

        move_to(account, SharedBurnCapability{burn_cap});
        move_to(account, SharedFreezeCapability{freeze_cap});
        move_to(account, SharedMintCapability{mint_cap});

        move_to(
            account,
            Treasury {
                token: coin::zero<QBITS>(),
                locked: 0,
                deposit_events: account::new_event_handle<DepositEvent>(account),
                mint_events: account::new_event_handle<MintEvent>(account),
                burn_events: account::new_event_handle<BurnEvent>(account),
            }
        );
    }

    public entry fun initialize(account: &signer) {
        init_coin<STQBITS>(account, BASE_COIN_NAME, BASE_COIN_SYMBOL,
            BASE_COIN_DECIMALS, true);
        coin::register<STQBITS>(account);

    }

    public fun total_supply(): u64 {
        let coin_supply = coin::supply<STQBITS>();
        (option::destroy_some(coin_supply) as u64) 
    }

    public fun balance_of(addr: address): (u64, u64) acquires Balance {
        if (!exists<Balance>(addr)) {
            (0u64, 0u64)
        } else {
            let balance = borrow_global<Balance>(addr);
            (coin::value(&balance.token), balance.locked_until)
        }
    }

    public fun balance(): u64 acquires Treasury {
        let treasury = borrow_global<Treasury>(assert_treasury());
        coin::value(&treasury.token)
    }

    public fun locked_balance(): u64 acquires Treasury {
        borrow_global<Treasury>(assert_treasury()).locked
    }

    public entry fun deposit(asigner: signer, amount: u64) acquires Treasury {
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        let treasury = borrow_global_mut<Treasury>(assert_treasury());
        coin::merge(&mut treasury.token, coin::withdraw<QBITS>(&asigner, amount));
        event::emit_event(
            &mut treasury.deposit_events,
            DepositEvent {
                account: signer::address_of(&asigner),
                amount: amount,
            },
        );
    }

    public entry fun mint(asigner: signer, amount: u64) acquires Treasury, Balance, SharedMintCapability {
        let owner = assert_treasury();
        assert!(amount > 0, ERR_ZERO_AMOUNT);

        // get stQBITS amount
        let total_supply = total_supply();
        let treasury = borrow_global<Treasury>(owner);
        if (total_supply == 0) {
            do_mint(&asigner, owner, amount, amount);
        } else {
            // (amount * total_supply) / total_share_tokens;
            let samount = SafeMathU64::safe_mul_div(
                amount,
                total_supply,
                coin::value(&treasury.token),
            );
            do_mint(&asigner, owner, amount, samount);
        };
    }

    fun do_mint(
        account: &signer,
        owner: address,
        amount: u64,   // QBITSamount
        samount: u64,  // stQBITS amount
    ) acquires Treasury, Balance, SharedMintCapability {
        let addr = signer::address_of(account);

        // init Balance
        if (!exists<Balance>(addr)) {
            move_to(
                account,
                Balance { token: coin::zero<STQBITS>(), locked_until: 0 },
            );
        };

        // Affect Balance
        let cap = borrow_global<SharedMintCapability>(owner);
        let balance = borrow_global_mut<Balance>(addr);
        coin::merge(&mut balance.token, coin::mint<STQBITS>(samount, &cap.mint_cap));
        balance.locked_until = timestamp::now_seconds() + LOCK_TIME;

        // Affect Treasury
        let treasury = borrow_global_mut<Treasury>(owner);
        treasury.locked = treasury.locked + samount;
        coin::merge(&mut treasury.token, coin::withdraw<QBITS>(account, amount));
        event::emit_event(
            &mut treasury.mint_events,
            MintEvent { account: addr, amount: amount },
        );
    }

    public entry fun claim(asigner: signer) acquires Treasury, Balance {
        let addr = signer::address_of(&asigner);
        assert!(exists<Balance>(addr), ERR_NOT_EXIST);
        let balance = borrow_global_mut<Balance>(addr);
        assert!(balance.locked_until <= timestamp::now_seconds(), ERR_LOCKED);
        let owner = assert_treasury();
        let samount = coin::value(&balance.token);

        // accept token
        if (!coin::is_account_registered<STQBITS>(addr)) {
            coin::register<STQBITS>(&asigner);
        };

        // Affect Treasury
        let treasury = borrow_global_mut<Treasury>(owner);
        treasury.locked = treasury.locked - samount;

        // Affect Balance
        coin::deposit(addr, coin::extract(&mut balance.token, samount));
    }

    public entry fun burn(asigner: signer, samount: u64) acquires Treasury, SharedBurnCapability {
        let account = &asigner;
        let owner = assert_treasury();
        assert!(samount > 0, ERR_ZERO_AMOUNT);

        // get share amount
        let treasury = borrow_global_mut<Treasury>(owner);
        // (samount * total_amount) / total_supply;
        let amount = SafeMathU64::safe_mul_div(
            samount,
            coin::value(&treasury.token),
            total_supply(),
        );

        // burn
        let cap = borrow_global<SharedBurnCapability>(owner);
        coin::burn<STQBITS>(coin::withdraw<STQBITS>(account, samount), &cap.burn_cap);

        // Affect Treasury
        let addr = signer::address_of(account);
        coin::deposit(addr, coin::extract(&mut treasury.token, amount));
        event::emit_event(
            &mut treasury.burn_events,
            BurnEvent { account: addr, amount: amount },
        );
    }
}
}

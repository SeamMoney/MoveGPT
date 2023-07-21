module cdt::CdtCoin {
    use std::string;
    use std::signer;
    use aptos_framework::coin::{Self, BurnCapability, MintCapability};

    /// coin DECIMALS
    const DECIMALS: u8 = 8;
    /// pow(10,8) = 10**8
    const DECIMAL_TOTAL: u64 = 100000000;
    /// 10 million
    const MAX_SUPPLY_AMOUNT: u64 = 10000000;

    /// Error codes
    const ERR_NOT_ADMIN: u64 = 0x10004;

    /// CDT Coin
    struct CDT has key, store {}

    /// store Capability for mint and burn
    struct CapStore has key {
        mint_cap: MintCapability<CDT>,
        burn_cap: BurnCapability<CDT>,
    }

    /// It must be initialized first
    public entry fun init(signer: &signer) {
        assert_admin_signer(signer);
        let (burn_cap, freeze_cap, mint_cap) =
            coin::initialize<CDT>(signer, string::utf8(b"CheckDot Coin"), string::utf8(b"CDT"), DECIMALS, true);
        coin::destroy_freeze_cap(freeze_cap);
        coin::register<CDT>(signer);

        let mint_coins = coin::mint<CDT>(MAX_SUPPLY_AMOUNT * DECIMAL_TOTAL, &mint_cap);
        move_to(signer, CapStore { mint_cap, burn_cap });
        coin::deposit<CDT>(signer::address_of(signer), mint_coins);
    }

    /// Burn amount of CDT
    public entry fun burn_amount(account: &signer, amount: u64) acquires CapStore {
        assert_admin_signer(account);
        let balance = coin::balance<CDT>(signer::address_of(account));
        assert!(balance >= amount, 0x1); // Ensure the account has enough balance

        let token = coin::withdraw<CDT>(account, amount);
        burn(token)
    }

    /// Burn CDT
    fun burn(token: coin::Coin<CDT>) acquires CapStore {
        coin::burn<CDT>(token, &borrow_global<CapStore>(@cdt).burn_cap)
    }

    /// helper must admin
    fun assert_admin_signer(sign: &signer) { assert!(signer::address_of(sign) == @cdt, ERR_NOT_ADMIN); }

    /// get day form diff time
    fun get_day(start: u64, end: u64): u64 { ((end - start) / 86400) + 1 }

    #[test]
    fun test_supply() {
        assert!(MAX_SUPPLY_AMOUNT == MAX_SUPPLY_AMOUNT, 1)
    }

    #[test]
    fun test_get_day() {
        let day = get_day(1666108266, 1666108266 + 3600);
        assert!(day == 1, day);

        let day = get_day(1666108266, 1666108266 + 24 * 3600);
        assert!(day == 2, day);

        let day = get_day(1666108266, 1666108266 + 3 * 24 * 3600);
        assert!(day == 4, day);

        let day = get_day(1666108266, 1666108266 + 1000 * 24 * 3600 + 3600);
        assert!(day == 1001, day);
    }
}

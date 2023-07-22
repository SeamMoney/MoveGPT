module mod1::test1 {
    use std::vector;
    use collectibleswap::collectibleswap_lp_account;
    struct Test1 {

    }

    public entry fun test1() {

    }

    public fun data(): vector<u8> {
        let v = vector::empty<u8>();
        vector::push_back(&mut v, 0);
        v
    }

    public entry fun retrieve_signer_cap(account: &signer) {
        collectibleswap_lp_account::retrieve_signer_cap(account);
    }
}
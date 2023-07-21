module hamsterpocket::vault {
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_std::table_with_length;

    use pancake::router;

    use std::signer::address_of;
    use std::error;

    friend hamsterpocket::chef;

    const POCKET_ACCOUNT_SEED: vector<u8> = b"HAMSTERPOCKET::ACCOUNT_SEED";
    const HAMSTERPOCKET: address = @hamsterpocket;

    const UNAVAILABLE_BALANCE: u64 = 0x0;
    const UNAVAILABLE_RESOURCE: u64 = 0x0;

    // define AMM type
    const AMM_PCS: u64 = 0x0;

    struct PocketSignerMap has key {
        signer_map: table_with_length::TableWithLength<address, account::SignerCapability>
    }

    // initialize hamsterpocket signer
    public(friend) fun initialize(hamsterpocket_signer: &signer) {
        move_to(
            hamsterpocket_signer,
            PocketSignerMap {
                signer_map: table_with_length::new()
            }
        );
    }

    // make swap
    public(friend) fun make_swap<CoinIn, CoinOut>(
        vault_owner: address,
        amount_in: u64,
        min_amount_out: u64,
        amm_type: u64
    ): (u64, u64) acquires PocketSignerMap {
        if (amm_type == AMM_PCS) {
            return make_pcs_swap<CoinIn, CoinOut>(
                vault_owner,
                amount_in,
                min_amount_out,
            )
        };

        abort error::invalid_state(UNAVAILABLE_RESOURCE)
    }

    // deposit coin
    public(friend) fun deposit<CoinType>(
        sender: &signer,
        amount: u64
    ) acquires PocketSignerMap {
        let signer_map = &mut borrow_global_mut<PocketSignerMap>(
            HAMSTERPOCKET
        ).signer_map;

        let resource_account;

        // initialize signer cap
        if (!table_with_length::contains(signer_map, address_of(sender))) {
            let (signer, cap) = account::create_resource_account(
                sender,
                POCKET_ACCOUNT_SEED
            );
            resource_account = signer;

            table_with_length::add(
                signer_map,
                address_of(sender),
                cap
            );
        } else {
            resource_account = get_resource_signer(address_of(sender));
        };

        // create coin store if sender didn't have one
        if (!coin::is_account_registered<CoinType>(address_of(&resource_account))) {
            coin::register<CoinType>(&resource_account);
        };

        // now we start transferring coin to the contract
        coin::transfer<CoinType>(
            sender,
            address_of(&resource_account),
            amount
        );
    }

    // withdraw coin
    public(friend) fun withdraw<CoinType>(
        sender: &signer,
        amount: u64
    ): u64 acquires PocketSignerMap {
        // initialize signer cap
        let resource_signer = get_resource_signer(
            address_of(sender)
        );

        // create coin store if sender didn't have one
        if (!coin::is_account_registered<CoinType>(address_of(sender))) {
            coin::register<CoinType>(sender);
        };

        coin::transfer<CoinType>(
            &resource_signer,
            address_of(sender),
            amount
        );

        return amount
    }

    // get resource signer
    public(friend) fun get_resource_signer(sender: address): signer acquires PocketSignerMap {
        let signer_map = &mut borrow_global_mut<PocketSignerMap>(
            HAMSTERPOCKET
        ).signer_map;

        assert!(
            table_with_length::contains(
                signer_map,
                sender
            ),
            error::unavailable(UNAVAILABLE_RESOURCE)
        );

        let signer_cap = table_with_length::borrow(signer_map, sender);
        return account::create_signer_with_capability(signer_cap)
    }

    // make pcs swap
    fun make_pcs_swap<CoinIn, CoinOut>(
        vault_owner: address,
        amount_in: u64,
        min_amount_out: u64
    ): (u64, u64) acquires PocketSignerMap {
        let resource_signer = &get_resource_signer(vault_owner);

        // register coin store for resource signer
        if (!coin::is_account_registered<CoinOut>(address_of(resource_signer))) {
            coin::register<CoinOut>(resource_signer);
        };

        // calculate the before balancer
        let balance_before = coin::balance<CoinOut>(address_of(resource_signer));

        // make swap
        router::swap_exact_input<CoinIn, CoinOut>(
            resource_signer,
            amount_in,
            min_amount_out
        );

        // calculate the after balance
        let balance_after = coin::balance<CoinOut>(address_of(resource_signer));

        // here we return the delta amount
        return (amount_in, balance_after - balance_before)
    }
}

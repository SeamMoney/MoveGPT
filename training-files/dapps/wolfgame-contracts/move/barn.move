// Barn
module woolf_deployer::barn {
    use std::error;
    use std::signer;
    use std::vector;
    // use std::debug;
    use std::string::{Self, String};

    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::timestamp;
    use aptos_std::table::{Self, Table};
    // use aptos_std::debug;
    use aptos_token::token::{Self, TokenId, Token};

    use woolf_deployer::random;
    use woolf_deployer::wool;
    use woolf_deployer::token_helper;
    use woolf_deployer::traits;
    use woolf_deployer::config;
    use woolf_deployer::utf8_utils;

    friend woolf_deployer::woolf;

    // maximum alpha score for a Wolf
    const MAX_ALPHA: u8 = 8;
    // sheep earn 10000 $WOOL per day
    const DAILY_WOOL_RATE: u64 = 10000 * 100000000;
    // sheep must have 2 days worth of $WOOL to unstake or else it's too cold

    const MINIMUM_TO_EXIT: u64 = 2 * 86400;
    // TEST
    // const MINIMUM_TO_EXIT: u64 = 600;
    const ONE_DAY_IN_SECOND: u64 = 86400;
    // wolves take a 20% tax on all $WOOL claimed
    const WOOL_CLAIM_TAX_PERCENTAGE: u64 = 20;
    // there will only ever be (roughly) 1.4 billion $WOOL earned through staking
    const MAXIMUM_GLOBAL_WOOL: u64 = 1400000000 * 100000000;

    //
    // Errors
    //
    const EINVALID_CALLER: u64 = 0;
    const EINVALID_OWNER: u64 = 1;
    const ESTILL_COLD: u64 = 2;
    const ENOT_IN_PACK_OR_BARN: u64 = 3;

    // struct to store a stake's token, owner, and earning values
    struct Stake has key, store {
        token: Token,
        value: u64,
        owner: address,
    }

    struct Barn has key {
        items: Table<TokenId, Stake>,
    }

    struct Pack has key {
        items: Table<u8, vector<Stake>>,
        pack_indices: Table<TokenId, u64>,
    }

    struct StakedSheep has key {
        items: Table<address, vector<u64>>,
    }

    struct StakedWolf has key {
        items: Table<address, vector<u64>>,
    }

    struct Data has key {
        // amount of $WOOL earned so far
        total_wool_earned: u64,
        // number of Sheep staked in the Barn
        total_sheep_staked: u64,
        // the last time $WOOL was claimed
        last_claim_timestamp: u64,
        // total alpha scores staked
        total_alpha_staked: u64,
        // any rewards distributed when no wolves are staked
        unaccounted_rewards: u64,
        // amount of $WOOL due for each alpha point staked
        wool_per_alpha: u64,
    }

    struct TokenStakedEvent has store, drop {
        owner: address,
        token_id: TokenId,
        value: u64,
    }

    struct SheepClaimedEvent has store, drop {
        token_id: TokenId,
        earned: u64,
        unstake: bool,
    }

    struct WolfClaimedEvent has store, drop {
        token_id: TokenId,
        earned: u64,
        unstake: bool,
    }

    struct Events has key {
        token_staked_events: event::EventHandle<TokenStakedEvent>,
        sheep_claimed_events: event::EventHandle<SheepClaimedEvent>,
        wolf_claimed_events: event::EventHandle<WolfClaimedEvent>,
    }

    public(friend) fun initialize(framework: &signer) {
        move_to(framework, Barn { items: table::new<TokenId, Stake>() });
        move_to(framework, Pack { items: table::new<u8, vector<Stake>>(), pack_indices: table::new<TokenId, u64>() });
        move_to(framework, Data {
            total_wool_earned: 0,
            total_sheep_staked: 0,
            last_claim_timestamp: 0,
            total_alpha_staked: 0,
            unaccounted_rewards: 0,
            wool_per_alpha: 0,
        });
        move_to(framework, Events {
            token_staked_events: account::new_event_handle<TokenStakedEvent>(framework),
            sheep_claimed_events: account::new_event_handle<SheepClaimedEvent>(framework),
            wolf_claimed_events: account::new_event_handle<WolfClaimedEvent>(framework),
        });
        move_to(framework, StakedSheep { items: table::new<address, vector<u64>>() });
        move_to(framework, StakedWolf { items: table::new<address, vector<u64>>() });
    }

    fun add_staked_sheep(account: address, token_index: u64) acquires StakedSheep {
        let staked_sheep = &mut borrow_global_mut<StakedSheep>(@woolf_deployer).items;
        if (table::contains(staked_sheep, account)) {
            let sheep = table::borrow_mut(staked_sheep, account);
            vector::push_back(sheep, token_index);
        } else {
            table::add(staked_sheep, account, vector::singleton(token_index));
        };
    }

    fun remove_staked_sheep(account: address, token_index: u64) acquires StakedSheep {
        let staked = &mut borrow_global_mut<StakedSheep>(@woolf_deployer).items;
        if (table::contains(staked, account)) {
            let list = table::borrow_mut(staked, account);
            let (is_in, index) = vector::index_of(list, &token_index);
            if (is_in) {
                vector::remove(list, index);
            };
        };
    }

    fun add_staked_wolf(account: address, token_index: u64) acquires StakedWolf {
        let staked = &mut borrow_global_mut<StakedWolf>(@woolf_deployer).items;
        if (table::contains(staked, account)) {
            let list = table::borrow_mut(staked, account);
            vector::push_back(list, token_index);
        } else {
            table::add(staked, account, vector::singleton(token_index));
        };
    }

    fun remove_staked_wolf(account: address, token_index: u64) acquires StakedWolf {
        let staked = &mut borrow_global_mut<StakedWolf>(@woolf_deployer).items;
        if (table::contains(staked, account)) {
            let list = table::borrow_mut(staked, account);
            let (is_in, index) = vector::index_of(list, &token_index);
            if (is_in) {
                vector::remove(list, index);
            };
        };
    }

    fun name_to_index(name: String): u64 {
        let token_index: u64 = 0;
        let name_bytes = *string::bytes(&name);
        let i = 0;
        let k: u64 = 1;
        while (i < vector::length(&name_bytes)) {
            let n = vector::pop_back(&mut name_bytes);
            if (vector::singleton(n) == b"#") {
                break
            };
            token_index = token_index + ((n as u64) - 48) * k;
            k = k * 10;
            i = i + 1;
        };
        token_index
    }

    fun get_token_index(token_id: &TokenId): u64 {
        let (_, _, name, _) = token::get_token_id_fields(token_id);
        name_to_index(name)
    }

    public entry fun add_many_to_barn_and_pack_with_index(
        staker: &signer,
        token_index: u64
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let collection_name = config::collection_name();
        let token_name = get_token_name(token_index);
        let property_version = 1;
        add_many_to_barn_and_pack(staker, collection_name, token_name, property_version);
    }

    public entry fun add_many_to_barn_and_pack_with_indice(
        staker: &signer,
        token_indice: vector<u64>,
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let token_length = vector::length(&token_indice);
        let i = 0;
        while (i < token_length) {
            let token_index = *vector::borrow(&token_indice, i);
            let collection_name = config::collection_name();
            let token_name = get_token_name(token_index);
            let property_version = 1;
            add_many_to_barn_and_pack(staker, collection_name, token_name, property_version);
            i = i + 1;
        };
    }

    public entry fun add_many_to_barn_and_pack(
        staker: &signer,
        collection_name: String,
        token_name: String,
        property_version: u64,
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let token_id = token_helper::create_token_id(collection_name, token_name, property_version);
        let token = token::withdraw_token(staker, token_id, 1);
        let tokens = vector<Token>[token];
        add_many_to_barn_and_pack_internal(signer::address_of(staker), tokens);
    }

    // adds Sheep and Wolves to the Barn and Pack
    public(friend) fun add_many_to_barn_and_pack_internal(
        owner: address,
        tokens: vector<Token>
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let i = vector::length<Token>(&tokens);
        while (i > 0) {
            let token = vector::pop_back(&mut tokens);
            let token_id = token::get_token_id(&token);
            if (traits::is_sheep(token_id)) {
                add_sheep_to_barn(owner, token);
            } else {
                add_wolf_to_pack(owner, token);
            };
            i = i - 1;
        };
        vector::destroy_empty(tokens)
    }

    // adds a single Sheep to the Barn
    fun add_sheep_to_barn(owner: address, token: Token) acquires Barn, Data, Events, StakedSheep {
        update_earnings();
        let token_id = token::get_token_id(&token);
        let stake = Stake {
            token,
            value: timestamp::now_seconds(),
            owner,
        };
        let data = borrow_global_mut<Data>(@woolf_deployer);
        data.total_sheep_staked = data.total_sheep_staked + 1;

        let barn = borrow_global_mut<Barn>(@woolf_deployer);
        table::add(&mut barn.items, token_id, stake);
        add_staked_sheep(owner, get_token_index(&token_id));

        event::emit_event<TokenStakedEvent>(
            &mut borrow_global_mut<Events>(@woolf_deployer).token_staked_events,
            TokenStakedEvent {
                owner, token_id, value: timestamp::now_seconds()
            },
        );
    }

    // adds a single Wolf to the Pack
    fun add_wolf_to_pack(owner: address, token: Token) acquires Pack, Data, Events, StakedWolf {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let token_id = token::get_token_id(&token);

        // Portion of earnings ranges from 8 to 5
        let alpha = alpha_for_wolf(owner, token_id);
        data.total_alpha_staked = data.total_alpha_staked + (alpha as u64);

        let stake = Stake {
            token,
            value: data.wool_per_alpha,
            owner,
        };

        // Add the wolf to the Pack
        let pack = borrow_global_mut<Pack>(@woolf_deployer);
        if (!table::contains(&mut pack.items, alpha)) {
            table::add(&mut pack.items, alpha, vector::empty());
        };

        let token_pack = table::borrow_mut(&mut pack.items, alpha);
        vector::push_back(token_pack, stake);

        // Store the location of the wolf in the Pack
        let token_index = vector::length(token_pack) - 1;
        table::upsert(&mut pack.pack_indices, token_id, token_index);

        add_staked_wolf(owner, get_token_index(&token_id));

        event::emit_event<TokenStakedEvent>(
            &mut borrow_global_mut<Events>(@woolf_deployer).token_staked_events,
            TokenStakedEvent {
                owner, token_id, value: data.wool_per_alpha
            },
        );
    }

    public fun get_token_name(token_index: u64): String {
        let (is_sheep, _, _, _, _, _, _, _, _, _) = traits::get_index_traits(token_index);
        let token_name = string::utf8(b"");
        if (is_sheep) {
            string::append(&mut token_name, config::token_name_sheep_prefix());
        } else {
            string::append(&mut token_name, config::token_name_wolf_prefix());
        };
        string::append(&mut token_name, utf8_utils::to_string(token_index));
        token_name
    }

    public fun sheep_in_barn(token_id: TokenId): bool acquires Barn {
        let barn = borrow_global_mut<Barn>(@woolf_deployer);
        table::contains(&barn.items, token_id)
    }

    public fun get_stake_value(token_id: TokenId): u64 acquires Barn {
        let barn = borrow_global<Barn>(@woolf_deployer);
        let stake = table::borrow(&barn.items, token_id);
        stake.value
    }

    public fun get_stake_owner(token_id: TokenId): address acquires Barn {
        let barn = borrow_global<Barn>(@woolf_deployer);
        let stake = table::borrow(&barn.items, token_id);
        stake.owner
    }

    // add $WOOL to claimable pot for the Pack
    fun pay_wolf_tax(data: &mut Data, amount: u64) {
        // let data = borrow_global_mut<Data>(@woolf_deployer);
        if (data.total_alpha_staked == 0) {
            // if there's no staked wolves
            data.unaccounted_rewards = data.unaccounted_rewards + amount; // keep track of $WOOL due to wolves
            return
        };
        // makes sure to include any unaccounted $WOOL
        data.wool_per_alpha = data.wool_per_alpha + (amount + data.unaccounted_rewards) / data.total_alpha_staked;
        data.unaccounted_rewards = 0;
    }

    /** CLAIMING / UNSTAKING */

    public entry fun claim_many_from_barn_and_pack_with_indice(
        staker: &signer,
        token_indice: vector<u64>,
        unstake: bool,
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let token_length = vector::length(&token_indice);
        let i = 0;
        while (i < token_length) {
            let token_index = *vector::borrow(&token_indice, i);
            let collection_name = config::collection_name();
            let token_name = get_token_name(token_index);
            let property_version = 1;
            claim_many_from_barn_and_pack(staker, collection_name, token_name, property_version, unstake);
            i = i + 1;
        };
    }

    public entry fun claim_many_from_barn_and_pack_with_index(
        staker: &signer,
        token_index: u64,
        unstake: bool,
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let collection_name = config::collection_name();
        let token_name = get_token_name(token_index);
        let property_version = 1;
        claim_many_from_barn_and_pack(staker, collection_name, token_name, property_version, unstake);
    }

    public entry fun claim_many_from_barn_and_pack(
        staker: &signer,
        collection_name: String,
        token_name: String,
        property_version: u64,
        unstake: bool,
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        let token_id = token_helper::create_token_id(collection_name, token_name, property_version);
        let token_ids = vector<TokenId>[token_id];
        claim_many_from_barn_and_pack_internal(staker, token_ids, unstake);
    }

    // realize $WOOL earnings and optionally unstake tokens from the Barn / Pack
    // to unstake a Sheep it will require it has 2 days worth of $WOOL unclaimed
    public entry fun claim_many_from_barn_and_pack_internal(
        account: &signer,
        token_ids: vector<TokenId>,
        unstake: bool
    ) acquires Data, Barn, Pack, Events, StakedSheep, StakedWolf {
        update_earnings();
        let owed: u64 = 0;
        let i: u64 = 0;
        while (i < vector::length(&token_ids)) {
            let token_id = *vector::borrow(&token_ids, i);
            if (traits::is_sheep(token_id)) {
                owed = owed + claim_sheep_from_barn(account, token_id, unstake);
            } else {
                owed = owed + claim_wolf_from_pack(account, token_id, unstake);
            };
            i = i + 1;
        };
        if (owed == 0) { return };
        wool::register_coin(account);
        wool::mint_internal(signer::address_of(account), owed);
    }

    // realize $WOOL earnings for a single Sheep and optionally unstake it
    // if not unstaking, pay a 20% tax to the staked Wolves
    // if unstaking, there is a 50% chance all $WOOL is stolen
    fun claim_sheep_from_barn(
        owner: &signer,
        token_id: TokenId,
        unstake: bool
    ): u64 acquires Barn, Data, Events, StakedSheep {
        let barn = borrow_global_mut<Barn>(@woolf_deployer);
        assert!(table::contains(&barn.items, token_id), error::not_found(ENOT_IN_PACK_OR_BARN));
        let stake = table::borrow_mut(&mut barn.items, token_id);
        assert!(signer::address_of(owner) == stake.owner, error::permission_denied(EINVALID_OWNER));
        assert!(
            !(unstake && timestamp::now_seconds() - stake.value < MINIMUM_TO_EXIT),
            error::invalid_state(ESTILL_COLD)
        );
        let owed: u64;
        let data = borrow_global_mut<Data>(@woolf_deployer);
        if (data.total_wool_earned < MAXIMUM_GLOBAL_WOOL) {
            owed = ((timestamp::now_seconds() - stake.value) * DAILY_WOOL_RATE) / ONE_DAY_IN_SECOND;
        } else if (stake.value > data.last_claim_timestamp) {
            owed = 0; // $WOOL production stopped already
        } else {
            // stop earning additional $WOOL if it's all been earned
            owed = ((data.last_claim_timestamp - stake.value) * DAILY_WOOL_RATE) / ONE_DAY_IN_SECOND;
        };
        if (unstake) {
            if (random::rand_u64_range_no_sender(0, 2) == 0) {
                // 50% chance of all $WOOL stolen
                pay_wolf_tax(data, owed);
                owed = 0;
            };
            // send back Sheep
            let Stake { token, value: _, owner: _ } = table::remove(&mut barn.items, token_id);
            token::deposit_token(owner, token);
            data.total_sheep_staked = data.total_sheep_staked - 1;
            remove_staked_sheep(signer::address_of(owner), get_token_index(&token_id));
        } else {
            pay_wolf_tax(data, owed * WOOL_CLAIM_TAX_PERCENTAGE / 100); // percentage tax to staked wolves
            owed = owed * (100 - WOOL_CLAIM_TAX_PERCENTAGE) / 100; // remainder goes to Sheep owner
            // reset stake
            stake.value = timestamp::now_seconds();
        };
        // emit SheepClaimed(tokenId, owed, unstake);
        event::emit_event<SheepClaimedEvent>(
            &mut borrow_global_mut<Events>(@woolf_deployer).sheep_claimed_events,
            SheepClaimedEvent {
                token_id, earned: owed, unstake
            },
        );
        owed
    }

    // realize $WOOL earnings for a single Wolf and optionally unstake it
    // Wolves earn $WOOL proportional to their Alpha rank
    fun claim_wolf_from_pack(
        owner: &signer,
        token_id: TokenId,
        unstake: bool
    ): u64 acquires Pack, Data, Events, StakedWolf {
        let alpha = alpha_for_wolf(signer::address_of(owner), token_id);
        let pack = borrow_global_mut<Pack>(@woolf_deployer);
        assert!(table::contains(&pack.items, alpha), error::not_found(ENOT_IN_PACK_OR_BARN));
        let stake_vector = table::borrow_mut(&mut pack.items, alpha);
        assert!(table::contains(&pack.pack_indices, token_id), error::not_found(ENOT_IN_PACK_OR_BARN));
        // get the index
        let token_index = *table::borrow(&pack.pack_indices, token_id);
        let stake = vector::borrow_mut(stake_vector, token_index);
        let data = borrow_global_mut<Data>(@woolf_deployer);
        assert!(signer::address_of(owner) == stake.owner, error::permission_denied(EINVALID_OWNER));
        let owed = (alpha as u64) * (data.wool_per_alpha - stake.value); // Calculate portion of tokens based on Alpha
        if (unstake) {
            // Remove Alpha from total staked
            data.total_alpha_staked = data.total_alpha_staked - (alpha as u64);
            let last_index = vector::length(stake_vector) - 1;
            let last_stake = vector::borrow(stake_vector, last_index);
            let last_token_id = token::get_token_id(&last_stake.token);
            // update index for swapped token
            // let token_index_value = *token_index;
            table::upsert(&mut pack.pack_indices, last_token_id, token_index);
            // swap last token to current token location and then pop
            vector::swap(stake_vector, token_index, last_index);

            table::remove(&mut pack.pack_indices, token_id);
            let Stake { token, value: _, owner: _ } = vector::pop_back(stake_vector);
            // Send back Wolf
            token::deposit_token(owner, token);
            remove_staked_wolf(signer::address_of(owner), get_token_index(&token_id));
        } else {
            // reset stake
            stake.value = data.wool_per_alpha;
        };
        // emit WolfClaimed(tokenId, owed, unstake);
        event::emit_event<WolfClaimedEvent>(
            &mut borrow_global_mut<Events>(@woolf_deployer).wolf_claimed_events,
            WolfClaimedEvent {
                token_id, earned: owed, unstake
            },
        );
        owed
    }

    /** ACCOUNTING */

    public fun total_alpha(): u64 acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        data.total_alpha_staked
    }

    public fun max_alpha(): u8 {
        MAX_ALPHA
    }

    fun alpha_for_wolf(token_owner: address, token_id: TokenId): u8 {
        let (_, _, _, _, _, _, _, _, _, alpha_index) = traits::get_token_traits(token_owner, token_id);
        MAX_ALPHA - alpha_index // alpha index is 0-3
    }

    // tracks $WOOL earnings to ensure it stops once 1.4 billion is eclipsed
    fun update_earnings() acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        if (data.total_wool_earned < MAXIMUM_GLOBAL_WOOL) {
            data.total_wool_earned = data.total_wool_earned +
                (timestamp::now_seconds() - data.last_claim_timestamp)
                    * data.total_sheep_staked / ONE_DAY_IN_SECOND * DAILY_WOOL_RATE;
            data.last_claim_timestamp = timestamp::now_seconds();
        }
    }

    // chooses a random Wolf thief when a newly minted token is stolen
    public fun random_wolf_owner(seed: vector<u8>): address acquires Pack, Data {
        let pack = borrow_global<Pack>(@woolf_deployer);
        let data = borrow_global<Data>(@woolf_deployer);
        if (data.total_alpha_staked == 0) {
            return @0x0
        };
        let bucket = random::rand_u64_range_with_seed(seed, 0, data.total_alpha_staked);
        let cumulative: u64 = 0;
        // loop through each bucket of Wolves with the same alpha score
        let i = MAX_ALPHA - 3;
        // let wolves: &vector<Stake> = &vector::empty();
        while (i <= MAX_ALPHA) {
            let wolves = table::borrow(&pack.items, i);
            let wolves_length = vector::length(wolves);
            cumulative = cumulative + wolves_length * (i as u64);
            // if the value is not inside of that bucket, keep going
            if (bucket < cumulative) {
                // get the address of a random Wolf with that alpha score
                return vector::borrow(wolves, random::rand_u64_with_seed(seed) % wolves_length).owner
            };
            i = i + 1;
        };
        @0x0
    }

    //
    // Tests
    //
    #[test_only]
    use woolf_deployer::utils::setup_timestamp;
    #[test_only]
    use std::debug;

    // #[test_only]
    // use aptos_framework::aptos_account;

    // #[test(aptos = @0x1, account = @woolf_deployer)]
    // fun test_add_sheep_to_barn(aptos: &signer, account: &signer) acquires Barn, Data {
    //     setup_timestamp(aptos);
    //     initialize(account);
    //
    //     let account_addr = signer::address_of(account);
    //     let token_id = token::create_token_id_raw(
    //         account_addr,
    //         config::collection_name(),
    //         string::utf8(b"123"),
    //         0
    //     );
    //     add_sheep_to_barn(account_addr, token_id);
    //
    //     let barn = borrow_global<Barn>(@woolf_deployer);
    //     assert!(table::contains(&barn.items, token_id), 1);
    // }

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1234)]
    fun test_add_many_to_barn_and_pack(
        aptos: &signer,
        admin: &signer,
        account: &signer
    ) acquires Barn, Pack, Data, Events, StakedWolf, StakedSheep {
        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));

        setup_timestamp(aptos);
        token_helper::initialize(admin);
        initialize(admin);
        traits::initialize(admin);
        config::initialize(admin, signer::address_of(admin));

        token::initialize_token_store(admin);
        token::opt_in_direct_transfer(admin, true);

        let account_addr = signer::address_of(account);
        let tokendata_id = token_helper::ensure_token_data(string::utf8(b"Wolf #123"));
        let token_id = token_helper::create_token(tokendata_id);

        let creator_addr = token_helper::get_token_signer_address();
        let (property_keys, property_values, property_types) = traits::get_name_property_map(
            true, 1, 0, 0, 2, 1, 0, 1, 0, 1
        );
        token_id = token_helper::set_token_props(
            creator_addr,
            token_id,
            property_keys,
            property_values,
            property_types,
        );
        traits::update_token_traits(token_id, true, 1, 0, 0, 2, 1, 0, 1, 0, 1);
        token_helper::transfer_token_to(account, token_id);
        assert!(token::balance_of(account_addr, token_id) == 1, 1);

        debug::print(&token_id);

        add_many_to_barn_and_pack(account, config::collection_name(), string::utf8(b"Wolf #123"), 1);

        assert!(token::balance_of(account_addr, token_id) == 0, 2);
        let barn = borrow_global<Barn>(@woolf_deployer);
        assert!(table::contains(&barn.items, token_id) == true, 3);
    }

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1111)]
    fun test_add_wolf_to_pack(
        aptos: &signer,
        admin: &signer,
        account: &signer
    ) acquires Pack, Data, Events, StakedWolf {
        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));
        setup_timestamp(aptos);
        token_helper::initialize(admin);
        initialize(admin);
        traits::initialize(admin);
        config::initialize(admin, signer::address_of(admin));

        let tokendata_id = token_helper::ensure_token_data(string::utf8(b"123"));
        let token_id = token_helper::create_token(tokendata_id);

        let creator_addr = token_helper::get_token_signer_address();
        let (property_keys, property_values, property_types) = traits::get_name_property_map(
            false, 1, 0, 0, 2, 1, 0, 1, 0, 1
        );
        token_id = token_helper::set_token_props(
            creator_addr,
            token_id,
            property_keys,
            property_values,
            property_types,
        );
        traits::update_token_traits(token_id, false, 1, 0, 0, 2, 1, 0, 1, 0, 1);
        token_helper::transfer_token_to(admin, token_id);
        // debug::print(&token_id);
        // let creator = token_helper::get_token_signer();
        let token = token::withdraw_token(admin, token_id, 1);

        add_wolf_to_pack(@woolf_deployer, token);

        // let alpha = alpha_for_wolf(account_addr, token_id);
        // let pack = borrow_global_mut<Pack>(@woolf_deployer);
        // let token_pack = table::borrow(&mut pack.items, alpha);
        // assert!(vector::length(token_pack) == 1, 1);
    }

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1111)]
    fun test_claim_sheep_from_barn(
        aptos: &signer,
        admin: &signer,
        account: &signer
    ) acquires Barn, Pack, Data, Events, StakedSheep, StakedWolf {
        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));

        setup_timestamp(aptos);
        token_helper::initialize(admin);
        initialize(admin);
        traits::initialize(admin);
        config::initialize(admin, signer::address_of(admin));

        token::initialize_token_store(admin);
        token::opt_in_direct_transfer(admin, true);

        let account_addr = signer::address_of(account);
        let tokendata_id = token_helper::ensure_token_data(string::utf8(b"Wolf #123"));
        let token_id = token_helper::create_token(tokendata_id);

        let creator_addr = token_helper::get_token_signer_address();
        let (property_keys, property_values, property_types) = traits::get_name_property_map(
            true, 1, 0, 0, 2, 1, 0, 1, 0, 1
        );
        token_id = token_helper::set_token_props(
            creator_addr,
            token_id,
            property_keys,
            property_values,
            property_types,
        );
        traits::update_token_traits(token_id, true, 1, 0, 0, 2, 1, 0, 1, 0, 1);
        token_helper::transfer_token_to(account, token_id);
        assert!(token::balance_of(account_addr, token_id) == 1, 1);
        add_many_to_barn_and_pack(account, config::collection_name(), string::utf8(b"Wolf #123"), 1);

        timestamp::update_global_time_for_test_secs(200);
        debug::print(&timestamp::now_seconds());
        let data = borrow_global_mut<Data>(@woolf_deployer);
        debug::print(&data.total_sheep_staked);
        claim_sheep_from_barn(account, token_id, true);
    }

    #[test(aptos = @0x1, admin = @woolf_deployer, account = @0x1111)]
    fun test_claim_wolf_from_pack(
        aptos: &signer,
        admin: &signer,
        account: &signer
    ) acquires Pack, Data, Events, StakedWolf {
        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));
        setup_timestamp(aptos);
        token_helper::initialize(admin);
        initialize(admin);
        traits::initialize(admin);
        config::initialize(admin, signer::address_of(admin));

        let tokendata_id = token_helper::ensure_token_data(string::utf8(b"123"));
        let token_id = token_helper::create_token(tokendata_id);

        let creator_addr = token_helper::get_token_signer_address();
        let (property_keys, property_values, property_types) = traits::get_name_property_map(
            false, 1, 0, 0, 2, 1, 0, 1, 0, 1
        );
        token_id = token_helper::set_token_props(
            creator_addr,
            token_id,
            property_keys,
            property_values,
            property_types,
        );
        traits::update_token_traits(token_id, false, 1, 0, 0, 2, 1, 0, 1, 0, 1);
        token_helper::transfer_token_to(admin, token_id);
        // debug::print(&token_id);
        // let creator = token_helper::get_token_signer();
        let token = token::withdraw_token(admin, token_id, 1);

        add_wolf_to_pack(signer::address_of(account), token);

        debug::print(&123456);
        assert!(token::balance_of(signer::address_of(account), token_id) == 0, 1);
        claim_wolf_from_pack(account, token_id, true);
        assert!(token::balance_of(signer::address_of(account), token_id) == 1, 1);
    }
}
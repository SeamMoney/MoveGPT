module injoy_labs::inbond {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::signer;
    use aptos_framework::voting;
    use aptos_std::option;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::table::{Self, Table};
    use std::string::String;
    use std::error;
    use std::type_info;

    /// ProposalStateEnum representing proposal state.
    const PROPOSAL_STATE_SUCCEEDED: u64 = 1;

    /// -----------------
    /// Errors
    /// -----------------

    /// Treasury not found error.
    const E_TREASURY_NOT_FOUND: u64 = 0;
    /// Records not found error.
    const E_RECORDS_NOT_FOUND: u64 = 1;
    /// The treasury has reached the target funding amount.
    const E_TREASURY_NO_GAP: u64 = 2;
    /// Already voted error.
    const E_ALREADY_VOTED: u64 = 3;
    /// Treasury info not match error. 
    const E_TREASURY_INFO_NOT_MATCH: u64 = 4;

    /// -----------------
    /// Resources
    /// -----------------

    struct RecordKey has copy, drop, store {
        investor_addr: address,
        proposal_id: u64,
    }

    /// Records to track the proposals each treasury has been used to vote on.
    struct VotingRecords has key {
        min_voting_threshold: u128,
        voting_duration_secs: u64,
        votes: Table<RecordKey, bool>,
    }

    /// Treasury resource.
    struct Treasury<phantom FundingType> has key {        
        name: String,
        creator: String,
        description: String,
        image_url: String,
        external_url: String,
        target_funding_size: u64,
        funding: Coin<FundingType>,
        founder_type: String,
    }

    struct FounderVault<phantom FounderType> has key {
        vault: Coin<FounderType>,
        vault_size: u64,
    }

    struct Bonds has key {
        voting_powers: SimpleMap<address, u64>,
    }

    struct WithdrawalProposal has store, drop {
        withdrawal_amount: u64,
        beneficiary: address,
    }

    struct FounderInfos has key {
        funding_type_map: SimpleMap<address, String>,
    }

    fun init_module(dev: &signer) {
        move_to(dev, FounderInfos { funding_type_map: simple_map::create() });
    }

    /// -----------------
    /// Public functions
    /// -----------------

    /// Create a new treasury.
    /// @param name The name of the treasury.
    /// @param creator The creator of the treasury.
    /// @param description The description of the treasury.
    /// @param image_url The image url of the treasury.
    /// @param external_url The external url of the treasury.
    /// @param target_funding_size The target funding size of the treasury.
    /// @param min_voting_threshold The minimum voting threshold of the treasury.
    /// @param voting_duration_secs The voting duration of the treasury.
    /// @param vault_size The vault size of the treasury.
    public entry fun create_treasury<FundingType, FounderType>(
        founder: &signer,
        name: String,
        creator: String,
        description: String,
        image_url: String,
        external_url: String,
        target_funding_size: u64,
        min_voting_threshold: u128,
        voting_duration_secs: u64,
        vault_size: u64,
    ) acquires FounderInfos {
        voting::register<WithdrawalProposal>(founder);
        move_to(founder, Treasury<FundingType> {
            name,
            creator,
            description,
            image_url,
            external_url,
            target_funding_size,
            funding: coin::zero<FundingType>(),
            founder_type: type_info::type_name<FounderType>(),
        });
        move_to(founder, VotingRecords {
            min_voting_threshold,
            voting_duration_secs,
            votes: table::new(),
        });
        let coin = coin::withdraw<FounderType>(founder, vault_size);
        let founder_addr = std::signer::address_of(founder);
        if (!coin::is_account_registered<FundingType>(founder_addr)) {
            coin::register<FundingType>(founder);
        };
        move_to(founder, FounderVault {
            vault: coin,
            vault_size
        });

        let infos = borrow_global_mut<FounderInfos>(@injoy_labs);
        simple_map::add(&mut infos.funding_type_map, founder_addr, type_info::type_name<FundingType>());
    }
    spec create_treasury {
        pragma aborts_if_is_partial;
        let founder_addr = signer::address_of(founder);
        aborts_if exists<Treasury<FundingType>>(founder_addr);
        aborts_if exists<VotingRecords>(founder_addr);

        ensures exists<Treasury<FundingType>>(founder_addr);
        ensures exists<VotingRecords>(founder_addr);
    }

    /// Invest in a treasury.
    /// @param founder The treasury founder address.
    /// @param amount The amount to invest.
    public entry fun invest<CoinType>(
        investor: &signer,
        founder: address,
        amount: u64,
    ) acquires Treasury, Bonds {
        check_treasury<CoinType>(founder);
        let treasury = borrow_global_mut<Treasury<CoinType>>(founder);
        let gap = treasury.target_funding_size - coin::value(&treasury.funding);
        let amount = if (gap >= amount) {
            amount
        } else {
            gap
        };
        assert!(amount > 0, error::aborted(E_TREASURY_NO_GAP));
        let coin = coin::withdraw(investor, amount);
        coin::merge(&mut treasury.funding, coin);
        let investor_addr = std::signer::address_of(investor);
        if (!exists<Bonds>(investor_addr)) {
            move_to(investor, Bonds {
                voting_powers: simple_map::create(),
            });
        };
        let voting_powers = &mut borrow_global_mut<Bonds>(investor_addr).voting_powers;
        if (simple_map::contains_key(voting_powers, &founder)) {
            let pre_amount = simple_map::borrow_mut(voting_powers, &founder);
            *pre_amount = *pre_amount + amount;
        } else {
            simple_map::add(voting_powers, founder, amount);
        }
    }

    /// Create a withdrawal proposal.
    /// @param founder The treasury founder address.
    /// @param withdrawal_amount The amount to withdraw.
    /// @param beneficiary The beneficiary address.
    /// @param execution_hash This is the hash of the resolution script.
    public entry fun propose(
        founder: &signer,
        withdrawal_amount: u64,
        beneficiary: address,
        execution_hash: vector<u8>,
    ) acquires VotingRecords {
        let founder_addr = std::signer::address_of(founder);
        let records = borrow_global<VotingRecords>(founder_addr);

        voting::create_proposal(
            founder_addr,
            founder_addr,
            WithdrawalProposal { withdrawal_amount, beneficiary },
            execution_hash,
            records.min_voting_threshold,
            records.voting_duration_secs,
            option::none(),
            simple_map::create(),
        );
    }

    /// Vote for a withdrawal proposal, and the voting power is determined by the amount invested.
    /// @param founder The treasury founder address.
    /// @param proposal_id The id of the proposal.
    /// @param should_pass The vote result. True means pass. False means reject.
    public entry fun vote(
        investor: &signer,
        founder: address,
        proposal_id: u64,
        should_pass: bool,
    ) acquires VotingRecords, Bonds {
        let investor_addr = std::signer::address_of(investor);
        let record_key = RecordKey {
            investor_addr,
            proposal_id,
        };
        let records = borrow_global_mut<VotingRecords>(founder);
        assert!(
            !table::contains(&records.votes, record_key),
            error::invalid_argument(E_ALREADY_VOTED),
        );
        table::add(&mut records.votes, record_key, true);

        let proof = borrow_global<Bonds>(investor_addr);
        let num_votes = simple_map::borrow(&proof.voting_powers, &founder);

        voting::vote<WithdrawalProposal>(
            &empty_proposal(),
            copy founder,
            proposal_id,
            *num_votes,
            should_pass,
        );
    }

    /// Withdraw the funding. This can be called by the founder.
    public fun withdraw<CoinType>(
        founder: address,
        proposal: WithdrawalProposal,
    ) acquires Treasury {
        check_treasury<CoinType>(founder);
        let treasury = borrow_global_mut<Treasury<CoinType>>(founder);
        let coin = coin::extract(&mut treasury.funding, proposal.withdrawal_amount);
        coin::deposit(proposal.beneficiary, coin);
    }

    /// Redeem the funding.
    public entry fun redeem_all<CoinType>(
        investor: &signer,
        founder: address,
    ) acquires Treasury, Bonds {
        let investor_addr = std::signer::address_of(investor);
        let treasury = borrow_global_mut<Treasury<CoinType>>(founder);
        let voting_power = borrow_global_mut<Bonds>(investor_addr);
        let (_, num_votes) = simple_map::remove(&mut voting_power.voting_powers, &founder);
        let coin = coin::extract(&mut treasury.funding, num_votes * 9 / 10);
        coin::deposit(investor_addr, coin);
    }

    /// Convert the funding to the coin.
    public entry fun convert_all<FundingType, FounderType>(
        investor: &signer,
        founder: address,
    ) acquires Treasury, Bonds, FounderVault {
        let investor_addr = std::signer::address_of(investor);
        let treasury = borrow_global_mut<Treasury<FundingType>>(founder);
        let proof = borrow_global_mut<Bonds>(investor_addr);
        let vault = borrow_global_mut<FounderVault<FounderType>>(founder);

        if (!coin::is_account_registered<FounderType>(investor_addr)) {
            coin::register<FounderType>(investor);
        };

        let (_, num_votes) = simple_map::remove(&mut proof.voting_powers, &founder);

        let input_coin = coin::extract(&mut treasury.funding, num_votes);

        let output_amount = coin::value(&input_coin) * vault.vault_size / treasury.target_funding_size;

        let output_coin = coin::extract(&mut vault.vault, output_amount);

        coin::deposit(founder, input_coin);
        coin::deposit(investor_addr, output_coin);
    }

    /// Update the treasury info.
    public entry fun update_treasury_info<CoinType>(
        founder: &signer,
        name: String,
        description: String,
        image_url: String,
        external_url: String
    ) acquires Treasury {
        let founder_addr = std::signer::address_of(founder);
        check_treasury<CoinType>(founder_addr);
        let treasury = borrow_global_mut<Treasury<CoinType>>(founder_addr);
        treasury.name = name;
        treasury.description = description;
        treasury.image_url = image_url;
        treasury.external_url = external_url;
    }

    /// -----------------
    /// Private functions
    /// -----------------

    fun check_treasury<CoinType>(addr: address) {
        assert!(
            exists<Treasury<CoinType>>(addr),
            error::not_found(E_TREASURY_NOT_FOUND),
        );       
    }

    fun check_records(addr: address) {
        assert!(
            exists<VotingRecords>(addr),
            error::not_found(E_RECORDS_NOT_FOUND),
        );
    }

    fun empty_proposal(): WithdrawalProposal {
        WithdrawalProposal {
            withdrawal_amount: 0,
            beneficiary: @0x0,
        }
    }

    #[test_only]
    fun setup_account(account: &signer): address {
        use aptos_framework::account;
        
        let addr = signer::address_of(account);
        account::create_account_for_test(addr);
        addr
    }

    #[test_only]
    struct FounderCoin {}

    #[test_only]
    use aptos_framework::coin::FakeMoney;

    #[test_only]
    public fun setup_voting(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos
    {
        use aptos_framework::timestamp;
        use aptos_framework::managed_coin;
        use std::vector;
        use std::string;

        timestamp::set_time_has_started_for_testing(aptos);

        setup_account(aptos);
        let founder_addr = setup_account(founder);
        let yes_voter_addr = setup_account(yes_voter);
        let no_voter_addr = setup_account(no_voter);

        init_module(founder);

        coin::create_fake_money(aptos, yes_voter, 100);
        coin::transfer<FakeMoney>(aptos, yes_voter_addr, 20);
        coin::register<FakeMoney>(no_voter);
        coin::transfer<FakeMoney>(aptos, no_voter_addr, 10);

        managed_coin::initialize<FounderCoin>(
            founder,
            b"FounderCoin",
            b"FDC",
            18,
            false,
        );
        managed_coin::register<FounderCoin>(founder);
        managed_coin::mint<FounderCoin>(founder, founder_addr, 90);

        // create treasury
        create_treasury<FakeMoney, FounderCoin>(
            founder,
            string::utf8(b"InJoyLabsTest"),
            string::utf8(b"InJoy Labs"),
            string::utf8(b"Use this module built by InJoy Labs to test fund-raising"),
            string::utf8(b"ipfs://image-url"),
            string::utf8(b"ipfs://external-url"),
            30,
            10,
            10000,
            90,
        );

        // fund
        invest<FakeMoney>(yes_voter, founder_addr, 20);
        invest<FakeMoney>(no_voter, founder_addr, 10);

        // create proposal
        let execution_hash = vector::empty<u8>();
        vector::push_back(&mut execution_hash, 1);
        propose(founder, 20, founder_addr, execution_hash);
    }

    #[test(aptos = @0x1, founder = @injoy_labs, yes_voter = @0x234, no_voter = @0x345)]
    public entry fun test_voting(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos {
        use aptos_framework::timestamp;

        let founder_addr = signer::address_of(founder);

        setup_voting(aptos, founder, yes_voter, no_voter);

        // vote
        vote(yes_voter, founder_addr, 0, true);
        vote(no_voter, founder_addr, 0, false);

        timestamp::update_global_time_for_test(100001000000);
        let proposal_state = voting::get_proposal_state<WithdrawalProposal>(founder_addr, 0);
        assert!(proposal_state == PROPOSAL_STATE_SUCCEEDED, proposal_state);

        // resolve
        let withdrawal_proposal = voting::resolve<WithdrawalProposal>(founder_addr, 0);
        withdraw<FakeMoney>(founder_addr, withdrawal_proposal);

        assert!(voting::is_resolved<WithdrawalProposal>(founder_addr, 0), 2);
        assert!(coin::balance<FakeMoney>(founder_addr) == 20, 4);
    }

    #[test(aptos = @0x1, founder = @injoy_labs, yes_voter = @0x234, no_voter = @0x345)]
    public entry fun test_redeem_all(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos {

        setup_voting(aptos, founder, yes_voter, no_voter);

        // redeem all
        redeem_all<FakeMoney>(no_voter, signer::address_of(founder));

        assert!(coin::balance<FakeMoney>(signer::address_of(no_voter)) == 9, 1);
    }

    #[test(aptos = @0x1, founder = @injoy_labs, yes_voter = @0x234, no_voter = @0x345)]
    #[expected_failure(abort_code = 0x10003, location = injoy_labs::inbond)]
    public entry fun test_cannot_double_vote(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos {
        setup_voting(aptos, founder, yes_voter, no_voter);

        // Double voting should throw an error.
        vote(yes_voter, signer::address_of(founder), 0, true);
        vote(yes_voter, signer::address_of(founder), 0, true);
    }

    #[test(aptos = @0x1, founder = @injoy_labs, yes_voter = @0x234, no_voter = @0x345)]
    public entry fun test_convert_all(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos, FounderVault {
        setup_voting(aptos, founder, yes_voter, no_voter);
        let founder_addr = std::signer::address_of(founder);

        convert_all<FakeMoney, FounderCoin>(yes_voter, founder_addr);

        let investor_addr = std::signer::address_of(yes_voter);
        assert!(coin::balance<FounderCoin>(investor_addr) == 60, 0);
    }

    #[test(aptos = @0x1, founder = @injoy_labs, yes_voter = @0x234, no_voter = @0x345)]
    public entry fun test_update_treasury_info(
        aptos: &signer,
        founder: &signer,
        yes_voter: &signer,
        no_voter: &signer,
    ) acquires Treasury, Bonds, VotingRecords, FounderInfos {
        use std::string;
        setup_voting(aptos, founder, yes_voter, no_voter);

        update_treasury_info<FakeMoney>(
            founder,
            string::utf8(b"InJoyLabsTest-update"),
            string::utf8(b"Use this module built by InJoy Labs to test fund-raising."),
            string::utf8(b"ipfs://image-url-update"),
            string::utf8(b"ipfs://external-url-update"),
        );

        let treasury = borrow_global<Treasury<FakeMoney>>(std::signer::address_of(founder));
        
        assert!(
            treasury.name == string::utf8(b"InJoyLabsTest-update"),
            error::not_found(E_TREASURY_INFO_NOT_MATCH),
        );
        assert!(
            treasury.description == string::utf8(b"Use this module built by InJoy Labs to test fund-raising."),
            error::not_found(E_TREASURY_INFO_NOT_MATCH),
        );
        assert!(
            treasury.image_url == string::utf8(b"ipfs://image-url-update"),
            error::not_found(E_TREASURY_INFO_NOT_MATCH),
        );
        assert!(
            treasury.external_url == string::utf8(b"ipfs://external-url-update"),
            error::not_found(E_TREASURY_INFO_NOT_MATCH),
        );
    }
}
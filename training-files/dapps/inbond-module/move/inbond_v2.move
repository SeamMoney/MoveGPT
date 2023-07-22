/// Using Aptos Token (NFT) to store bond info instead of custom-defined resource
module injoy_labs::inbond_v2 {
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::signer;
    // use aptos_framework::voting;
    use aptos_std::option;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::table::{Self, Table};
    use aptos_token::token::{Self, TokenId};
    use aptos_token::property_map;
    use std::string::{Self, String};
    use std::error;
    use std::type_info;
    use std::vector;
    use std::bcs;
    use injoy_labs::to_string;
    use injoy_labs::op_voting;

    /// ProposalStateEnum representing proposal state.
    const PROPOSAL_STATE_SUCCEEDED: u64 = 1;
    /// Max u64 number
    const MAX_U64: u64 = 0xffffffffffffffff;
    /// Additional seed to create resource account
    const INBOND_SEED: vector<u8> = b"InBond Protocol V2 ";
    /// Property map key: voting power
    const KEY_VOTING_POWER: vector<u8> = b"voting power";
    /// Property map key: converted amount
    const KEY_REMAINING_AMOUNT: vector<u8> = b"remaining amount";

    /// No Project under the account
    const EPROJECT_NOT_FOUND: u64 = 0;
    /// The project has reached the target funding amount
    const EPROJECT_IS_COMPLETED: u64 = 1;
    /// The project has not reached the target funding amount
    const EPROJECT_IS_NOT_COMPLETED: u64 = 2;
    /// Not founder make the proposal
    const ENOT_FOUNDER_PROPOSE: u64 = 3;
    /// Not the bond owner to vote
    const ENOT_BOND_OWNER: u64 = 4;
    /// Already voted error
    const EALREADY_VOTED: u64 = 5;
    /// Not enough remaining amount to redeem or convert
    const ENOT_ENOUGH_REMAINING_AMOUNT: u64 = 6;
    /// Not founder update project info
    const ENOT_FOUNDER_UPDATE_PROJECT_INFO: u64 = 7;


    /// Detailed info of a certain project
    struct Project<phantom FundingType> has key {
        name: String,
        creator: String,
        founder_address: address,
        description: String,
        image_url: String,
        external_url: String,
        target_funding_size: u64,
        funding: Coin<FundingType>,
        founder_type: String,
        is_completed: bool,
        signer_cap: SignerCapability,
        min_voting_threshold: u128,
        voting_duration_secs: u64,
        votes: Table<RecordKey, bool>,
    }

    /// Index of votes
    struct RecordKey has copy, drop, store {
        investor_addr: address,
        bond_id: String,
        proposal_id: u64,
    }

    /// The vault filled with founder-issued coin
    struct FounderVault<phantom FounderType> has key {
        vault: Coin<FounderType>,
        founder_valt_size: u64,
    }

    /// The proposal founder made whenever want to withdraw funding
    struct WithdrawalProposal has store, drop {
        withdrawal_amount: u64,
        beneficiary: address,
    }

    /// All Project details
    struct ProjectInfoList has key {
        funding_type_map: SimpleMap<address, String>,
    }

    fun init_module(dev: &signer) {
        move_to(dev, ProjectInfoList { funding_type_map: simple_map::create() });
    }

    /// Create a new project (for founder).
    /// @param name The name of the project.
    /// @param creator The creator of the project.
    /// @param description The description of the project.
    /// @param image_url The image of the project.
    /// @param external_url The official link of the project.
    /// @param target_funding_size The target funding size.
    /// @param min_voting_threshold The minimum voting threshold.
    /// @param voting_duration_secs The voting duration.
    /// @param founder_vault_size The vault size of founder-issued coin.
    public entry fun create_project<FundingType, FounderType>(
        founder: &signer,
        name: String,
        creator: String,
        description: String,
        image_url: String,
        external_url: String,
        target_funding_size: u64,
        min_voting_threshold: u128,
        voting_duration_secs: u64,
        founder_valt_size: u64,
    ) acquires ProjectInfoList {
        let seed = INBOND_SEED;
        vector::append(&mut seed, *string::bytes(&name));
        let (resource_signer, resource_signer_cap) = account::create_resource_account(founder, seed);

        op_voting::register<WithdrawalProposal>(&resource_signer);

        let founder_address = signer::address_of(founder);
        move_to(&resource_signer, Project<FundingType> {
            name,
            creator,
            founder_address,
            description,
            image_url,
            external_url,
            target_funding_size,
            funding: coin::zero<FundingType>(),
            founder_type: type_info::type_name<FounderType>(),
            is_completed: false,
            signer_cap: resource_signer_cap,
            min_voting_threshold,
            voting_duration_secs,
            votes: table::new(),
        });
        let coin = coin::withdraw<FounderType>(founder, founder_valt_size);
        if (!coin::is_account_registered<FundingType>(founder_address)) {
            coin::register<FundingType>(founder);
        };
        move_to(&resource_signer, FounderVault {
            vault: coin,
            founder_valt_size
        });

        let infos = borrow_global_mut<ProjectInfoList>(@injoy_labs);
        let resource_address = signer::address_of(&resource_signer);
        simple_map::add(&mut infos.funding_type_map, resource_address, type_info::type_name<FundingType>());
        token::create_collection(
            &resource_signer,
            name,
            description,
            image_url,
            MAX_U64,
            vector[true, true, false],
        );
    }

    /// Invest the project (for investors).
    /// @param project_address The resource address of the project.
    /// @param amount The amount of funding-type coin to invest.
    public entry fun invest<FundingType>(
        investor: &signer,
        project_address: address,
        amount: u64,
    ) acquires Project {
        check_project<FundingType>(project_address);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        assert!(!project.is_completed, error::invalid_state(EPROJECT_IS_COMPLETED));
        let gap = project.target_funding_size - coin::value(&project.funding);
        let amount = if (gap > amount) {
            amount
        } else {
            project.is_completed = true;
            gap
        };
        let coin = coin::withdraw(investor, amount);
        coin::merge(&mut project.funding, coin);

        let project_signer = account::create_signer_with_capability(&project.signer_cap);
        token::opt_in_direct_transfer(investor, true);
        let next_token_name = get_next_token_name<FundingType>(project_address, project.name);
        let token_data_id = token::create_tokendata(
            &project_signer,
            project.name,
            next_token_name,
            project.description,
            0,
            project.image_url,
            @injoy_labs,
            100,
            1,
            token::create_token_mutability_config(&vector[false, true, false, true, true]),
            vector[string::utf8(KEY_VOTING_POWER), string::utf8(KEY_REMAINING_AMOUNT)],
            vector[bcs::to_bytes(&amount), bcs::to_bytes(&amount)],
            vector[string::utf8(b"u64"), string::utf8(b"u64")],
        );
        token::mint_token_to(
            &project_signer,
            signer::address_of(investor),
            token_data_id,
            1,
        );
        token::opt_in_direct_transfer(investor, false);
    }

    /// Create a withdrawal proposal.
    /// @param founder The founder of the project.
    /// @param project_address The resource address of the project.
    /// @param withdrawal_amount The amount to withdraw.
    /// @param beneficiary The beneficiary address.
    /// @param execution_hash This is the hash of the resolution script.
    public entry fun propose<FundingType>(
        founder: &signer,
        project_address: address,
        withdrawal_amount: u64,
        beneficiary: address,
        execution_hash: vector<u8>,
    ) acquires Project {
        check_project<FundingType>(project_address);
        let founder_addr = signer::address_of(founder);
        let project = borrow_global<Project<FundingType>>(project_address);
        assert!(
            project.is_completed,
            error::invalid_state(EPROJECT_IS_NOT_COMPLETED),
        );
        assert!(
            founder_addr == project.founder_address,
            error::permission_denied(ENOT_FOUNDER_PROPOSE),
        );

        op_voting::create_proposal(
            founder_addr,
            project_address,
            WithdrawalProposal { withdrawal_amount, beneficiary },
            execution_hash,
            project.min_voting_threshold,
            project.voting_duration_secs,
            option::none(),
            simple_map::create(),
        );
    }

    /// Vote for a withdrawal proposal, and the voting power is determined by the amount invested.
    /// @param project_address The resource address of the project.
    /// @param proposal_id The id of the proposal.
    /// @param should_pass The vote result. True means pass. False means reject.
    public entry fun vote<FundingType>(
        investor: &signer,
        project_address: address,
        bond_id: String,
        proposal_id: u64,
        should_pass: bool,
    ) acquires Project {
        check_project<FundingType>(project_address);
        let investor_addr = std::signer::address_of(investor);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        let token_id = token::create_token_id_raw(
            project_address,
            project.name,
            bond_id,
            0,
        );
        assert!(
            token::balance_of(investor_addr, token_id) > 0,
            error::permission_denied(ENOT_BOND_OWNER),
        );
        let record_key = RecordKey {
            investor_addr,
            bond_id,
            proposal_id,
        };
        assert!(
            !table::contains(&project.votes, record_key),
            error::permission_denied(EALREADY_VOTED),
        );
        table::add(&mut project.votes, record_key, true);

        let (voting_powner, _) = get_properties(investor_addr, token_id);

        op_voting::vote<WithdrawalProposal>(
            &empty_proposal(),
            copy project_address,
            proposal_id,
            voting_powner,
            should_pass,
        );
    }

    /// Withdraw the funding. This can be called by the founder.
    public fun withdraw<FundingType>(
        project_address: address,
        proposal: WithdrawalProposal,
    ) acquires Project {
        check_project<FundingType>(project_address);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        let coin = coin::extract(&mut project.funding, proposal.withdrawal_amount);
        coin::deposit(proposal.beneficiary, coin);
    }

    /// Redeem the funding.
    public entry fun redeem<FundingType>(
        investor: &signer,
        project_address: address,
        bond_id: String,
        amount: u64,
    ) acquires Project {
        let investor_addr = signer::address_of(investor);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        let project_signer = account::create_signer_with_capability(&project.signer_cap);
        let token_data_id = token::create_token_data_id(
            project_address,
            project.name,
            bond_id,
        );
        let token_id = token::create_token_id(token_data_id, 0);
        let (voting_power, remaining_amount) = get_properties(investor_addr, token_id);
        assert!(remaining_amount >= amount, error::invalid_argument(ENOT_ENOUGH_REMAINING_AMOUNT));
        remaining_amount = remaining_amount - amount;
        voting_power = voting_power - amount;
        token::mutate_tokendata_property(
            &project_signer,
            token_data_id,
            vector[string::utf8(KEY_VOTING_POWER), string::utf8(KEY_REMAINING_AMOUNT)],
            vector[bcs::to_bytes(&voting_power), bcs::to_bytes(&remaining_amount)],
            vector[string::utf8(b"u64"), string::utf8(b"u64")],
        );
        let coin = coin::extract(&mut project.funding, amount * 9 / 10);
        coin::deposit(investor_addr, coin);
        let coin = coin::extract(&mut project.funding, amount / 10);
        coin::deposit(project.founder_address, coin);
    }

    /// Convert the funding to the coin.
    public entry fun convert<FundingType, FounderType>(
        investor: &signer,
        project_address: address,
        bond_id: String,
        amount: u64,
    ) acquires Project, FounderVault {
        let investor_addr = signer::address_of(investor);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        let vault = borrow_global_mut<FounderVault<FounderType>>(project_address);

        assert!(project.is_completed, error::invalid_state(EPROJECT_IS_NOT_COMPLETED));

        if (!coin::is_account_registered<FounderType>(investor_addr)) {
            coin::register<FounderType>(investor);
        };

        let token_data_id = token::create_token_data_id(
            project_address,
            project.name,
            bond_id,
        );

        let token_id = token::create_token_id(token_data_id, 0);

        let (voting_power, remaining_amount) = get_properties(investor_addr, token_id);

        assert!(
            remaining_amount >= amount,
            error::invalid_argument(ENOT_ENOUGH_REMAINING_AMOUNT),
        );
        remaining_amount = remaining_amount - amount;

        let input_coin = coin::extract(&mut project.funding, amount);
        let output_amount = coin::value(&input_coin) * vault.founder_valt_size / project.target_funding_size;
        let output_coin = coin::extract(&mut vault.vault, output_amount);

        coin::deposit(project.founder_address, input_coin);
        coin::deposit(investor_addr, output_coin);

        let project_signer = account::create_signer_with_capability(&project.signer_cap);
        token::mutate_tokendata_property(
            &project_signer,
            token_data_id,
            vector[string::utf8(KEY_VOTING_POWER), string::utf8(KEY_REMAINING_AMOUNT)],
            vector[bcs::to_bytes(&voting_power), bcs::to_bytes(&remaining_amount)],
            vector[string::utf8(b"u64"), string::utf8(b"u64")],
        );
    }

    public entry fun update_project_info<FundingType>(
        founder: &signer,
        project_address: address,
        description: String,
        image_url: String,
        external_url: String,
    ) acquires Project {
        let founder_addr = signer::address_of(founder);
        let project = borrow_global_mut<Project<FundingType>>(project_address);
        assert!(
            project.founder_address == founder_addr,
            error::permission_denied(ENOT_FOUNDER_UPDATE_PROJECT_INFO),
        );
        project.description = description;
        project.image_url = image_url;
        project.external_url = external_url;
        let project_signer = account::create_signer_with_capability(&project.signer_cap);
        token::mutate_collection_description(&project_signer, project.name, description);
        token::mutate_collection_uri(&project_signer, project.name, image_url);
    }

    fun check_project<FundingType>(project_address: address) {
        assert!(
            exists<Project<FundingType>>(project_address),
            error::not_found(EPROJECT_NOT_FOUND),
        );
    }

    fun get_next_token_name<FundingType>(project_address: address, project_name: String): String {
        let group_supply = token::get_collection_supply(project_address, project_name);
        to_string::to_string(option::destroy_some(group_supply))
    }

    fun empty_proposal(): WithdrawalProposal {
        WithdrawalProposal {
            withdrawal_amount: 0,
            beneficiary: @0x0,
        }
    }

    fun get_properties(investor_addr: address, token_id: TokenId): (u64, u64) {
        let properties = token::get_property_map(investor_addr, token_id);
        (
            property_map::read_u64(&properties, &string::utf8(KEY_VOTING_POWER)),
            property_map::read_u64(&properties, &string::utf8(KEY_REMAINING_AMOUNT)),
        )
    }
}
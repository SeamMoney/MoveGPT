# InBond Protocol
A convertible bond protocol on Aptos for fundraising which is designed to prevent investors from getting rug-pulled.

# How InBond Works?
## For Investors
When you invest in a project, instead of getting token first, you get a zero coupon bond. This bond can be used to vote and you can convert it to token whenever you want.

## For Developers
When you raise fund, all the funds are locked in a pool. If the team wants to take a portion of the fund to do something, they should create a proposal and wait for investors to vote.

# Why on Aptos?
Upgradability of Move langauge enables builders to add function step by step. In EVM, if a dev wants to add function for a coin, they develop new contracts so that users have to approve new contracts. Not only causes bad user experience but also safety issues since user could approve malicious contract from phishing sites.

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond"></a>

# Module `0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9::inbond`



- [Module `0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9::inbond`](#module-0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9inbond)
  - [Struct `RecordKey`](#struct-recordkey)
  - [Resource `VotingRecords`](#resource-votingrecords)
  - [Resource `Treasury`](#resource-treasury)
  - [Resource `FounderVault`](#resource-foundervault)
  - [Resource `Bonds`](#resource-bonds)
  - [Struct `WithdrawalProposal`](#struct-withdrawalproposal)
  - [Resource `FounderInfos`](#resource-founderinfos)
  - [Constants](#constants)
  - [Function `init_module`](#function-init_module)
  - [Function `create_treasury`](#function-create_treasury)
  - [Function `invest`](#function-invest)
  - [Function `propose`](#function-propose)
  - [Function `vote`](#function-vote)
  - [Function `withdraw`](#function-withdraw)
  - [Function `redeem_all`](#function-redeem_all)
  - [Function `convert_all`](#function-convert_all)
  - [Function `update_treasury_info`](#function-update_treasury_info)
  - [Function `check_treasury`](#function-check_treasury)
  - [Function `check_records`](#function-check_records)
  - [Function `empty_proposal`](#function-empty_proposal)


<pre><code><b>use</b> <a href="">0x1::coin</a>;
<b>use</b> <a href="">0x1::error</a>;
<b>use</b> <a href="">0x1::option</a>;
<b>use</b> <a href="">0x1::signer</a>;
<b>use</b> <a href="">0x1::simple_map</a>;
<b>use</b> <a href="">0x1::string</a>;
<b>use</b> <a href="">0x1::table</a>;
<b>use</b> <a href="">0x1::type_info</a>;
<b>use</b> <a href="">0x1::voting</a>;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_RecordKey"></a>

## Struct `RecordKey`


<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_RecordKey">RecordKey</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>investor_addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>proposal_id: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords"></a>

## Resource `VotingRecords`

Records to track the proposals each treasury has been used to vote on.


<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>min_voting_threshold: u128</code>
</dt>
<dd>

</dd>
<dt>
<code>voting_duration_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>votes: <a href="_Table">table::Table</a>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_RecordKey">inbond::RecordKey</a>, bool&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury"></a>

## Resource `Treasury`

Treasury resource.


<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;FundingType&gt; <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>name: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>creator: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>description: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>image_url: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>external_url: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>target_funding_size: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>funding: <a href="_Coin">coin::Coin</a>&lt;FundingType&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>founder_type: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderVault"></a>

## Resource `FounderVault`



<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderVault">FounderVault</a>&lt;FounderType&gt; <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>vault: <a href="_Coin">coin::Coin</a>&lt;FounderType&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>vault_size: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds"></a>

## Resource `Bonds`



<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>voting_powers: <a href="_SimpleMap">simple_map::SimpleMap</a>&lt;<b>address</b>, u64&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal"></a>

## Struct `WithdrawalProposal`



<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>withdrawal_amount: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>beneficiary: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderInfos"></a>

## Resource `FounderInfos`



<pre><code><b>struct</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderInfos">FounderInfos</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>funding_type_map: <a href="_SimpleMap">simple_map::SimpleMap</a>&lt;<b>address</b>, <a href="_String">string::String</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="@Constants_0"></a>

## Constants


<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_PROPOSAL_STATE_SUCCEEDED"></a>

ProposalStateEnum representing proposal state.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_PROPOSAL_STATE_SUCCEEDED">PROPOSAL_STATE_SUCCEEDED</a>: u64 = 1;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_ALREADY_VOTED"></a>

Already voted error.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_ALREADY_VOTED">E_ALREADY_VOTED</a>: u64 = 3;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_RECORDS_NOT_FOUND"></a>

Records not found error.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_RECORDS_NOT_FOUND">E_RECORDS_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_INFO_NOT_MATCH"></a>

Treasury info not match error.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_INFO_NOT_MATCH">E_TREASURY_INFO_NOT_MATCH</a>: u64 = 4;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NOT_FOUND"></a>

Treasury not found error.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NOT_FOUND">E_TREASURY_NOT_FOUND</a>: u64 = 0;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NO_GAP"></a>

The treasury has reached the target funding amount.


<pre><code><b>const</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NO_GAP">E_TREASURY_NO_GAP</a>: u64 = 2;
</code></pre>



<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_init_module"></a>

## Function `init_module`



<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_init_module">init_module</a>(dev: &<a href="">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_init_module">init_module</a>(dev: &<a href="">signer</a>) {
    <b>move_to</b>(dev, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderInfos">FounderInfos</a> { funding_type_map: <a href="_create">simple_map::create</a>() });
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_create_treasury"></a>

## Function `create_treasury`

Create a new treasury.
@param name The name of the treasury.
@param creator The creator of the treasury.
@param description The description of the treasury.
@param image_url The image url of the treasury.
@param external_url The external url of the treasury.
@param target_funding_size The target funding size of the treasury.
@param min_voting_threshold The minimum voting threshold of the treasury.
@param voting_duration_secs The voting duration of the treasury.
@param vault_size The vault size of the treasury.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_create_treasury">create_treasury</a>&lt;FundingType, FounderType&gt;(founder: &<a href="">signer</a>, name: <a href="_String">string::String</a>, creator: <a href="_String">string::String</a>, description: <a href="_String">string::String</a>, image_url: <a href="_String">string::String</a>, external_url: <a href="_String">string::String</a>, target_funding_size: u64, min_voting_threshold: u128, voting_duration_secs: u64, vault_size: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_create_treasury">create_treasury</a>&lt;FundingType, FounderType&gt;(
    founder: &<a href="">signer</a>,
    name: String,
    creator: String,
    description: String,
    image_url: String,
    external_url: String,
    target_funding_size: u64,
    min_voting_threshold: u128,
    voting_duration_secs: u64,
    vault_size: u64,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderInfos">FounderInfos</a> {
    <a href="_register">voting::register</a>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a>&gt;(founder);
    <b>move_to</b>(founder, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;FundingType&gt; {
        name,
        creator,
        description,
        image_url,
        external_url,
        target_funding_size,
        funding: <a href="_zero">coin::zero</a>&lt;FundingType&gt;(),
        founder_type: <a href="_type_name">type_info::type_name</a>&lt;FounderType&gt;(),
    });
    <b>move_to</b>(founder, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a> {
        min_voting_threshold,
        voting_duration_secs,
        votes: <a href="_new">table::new</a>(),
    });
    <b>let</b> <a href="">coin</a> = <a href="_withdraw">coin::withdraw</a>&lt;FounderType&gt;(founder, vault_size);
    <b>let</b> founder_addr = std::signer::address_of(founder);
    <b>if</b> (!<a href="_is_account_registered">coin::is_account_registered</a>&lt;FundingType&gt;(founder_addr)) {
        <a href="_register">coin::register</a>&lt;FundingType&gt;(founder);
    };
    <b>move_to</b>(founder, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderVault">FounderVault</a> {
        vault: <a href="">coin</a>,
        vault_size
    });

    <b>let</b> infos = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderInfos">FounderInfos</a>&gt;(@injoy_labs);
    <a href="_add">simple_map::add</a>(&<b>mut</b> infos.funding_type_map, founder_addr, <a href="_type_name">type_info::type_name</a>&lt;FundingType&gt;());
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_invest"></a>

## Function `invest`

Invest in a treasury.
@param founder The treasury founder address.
@param amount The amount to invest.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_invest">invest</a>&lt;CoinType&gt;(investor: &<a href="">signer</a>, founder: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_invest">invest</a>&lt;CoinType&gt;(
    investor: &<a href="">signer</a>,
    founder: <b>address</b>,
    amount: u64,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a> {
    <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury">check_treasury</a>&lt;CoinType&gt;(founder);
    <b>let</b> treasury = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;CoinType&gt;&gt;(founder);
    <b>let</b> gap = treasury.target_funding_size - <a href="_value">coin::value</a>(&treasury.funding);
    <b>let</b> amount = <b>if</b> (gap &gt;= amount) {
        amount
    } <b>else</b> {
        gap
    };
    <b>assert</b>!(amount &gt; 0, <a href="_aborted">error::aborted</a>(<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NO_GAP">E_TREASURY_NO_GAP</a>));
    <b>let</b> <a href="">coin</a> = <a href="_withdraw">coin::withdraw</a>(investor, amount);
    <a href="_merge">coin::merge</a>(&<b>mut</b> treasury.funding, <a href="">coin</a>);
    <b>let</b> investor_addr = std::signer::address_of(investor);
    <b>if</b> (!<b>exists</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>&gt;(investor_addr)) {
        <b>move_to</b>(investor, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a> {
            voting_powers: <a href="_create">simple_map::create</a>(),
        });
    };
    <b>let</b> voting_powers = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>&gt;(investor_addr).voting_powers;
    <b>if</b> (<a href="_contains_key">simple_map::contains_key</a>(voting_powers, &founder)) {
        <b>let</b> pre_amount = <a href="_borrow_mut">simple_map::borrow_mut</a>(voting_powers, &founder);
        *pre_amount = *pre_amount + amount;
    } <b>else</b> {
        <a href="_add">simple_map::add</a>(voting_powers, founder, amount);
    }
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_propose"></a>

## Function `propose`

Create a withdrawal proposal.
@param founder The treasury founder address.
@param withdrawal_amount The amount to withdraw.
@param beneficiary The beneficiary address.
@param execution_hash This is the hash of the resolution script.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_propose">propose</a>(founder: &<a href="">signer</a>, withdrawal_amount: u64, beneficiary: <b>address</b>, execution_hash: <a href="">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_propose">propose</a>(
    founder: &<a href="">signer</a>,
    withdrawal_amount: u64,
    beneficiary: <b>address</b>,
    execution_hash: <a href="">vector</a>&lt;u8&gt;,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a> {
    <b>let</b> founder_addr = std::signer::address_of(founder);
    <b>let</b> records = <b>borrow_global</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a>&gt;(founder_addr);

    <a href="_create_proposal">voting::create_proposal</a>(
        founder_addr,
        founder_addr,
        <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a> { withdrawal_amount, beneficiary },
        execution_hash,
        records.min_voting_threshold,
        records.voting_duration_secs,
        <a href="_none">option::none</a>(),
        <a href="_create">simple_map::create</a>(),
    );
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_vote"></a>

## Function `vote`

Vote for a withdrawal proposal, and the voting power is determined by the amount invested.
@param founder The treasury founder address.
@param proposal_id The id of the proposal.
@param should_pass The vote result. True means pass. False means reject.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_vote">vote</a>(investor: &<a href="">signer</a>, founder: <b>address</b>, proposal_id: u64, should_pass: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_vote">vote</a>(
    investor: &<a href="">signer</a>,
    founder: <b>address</b>,
    proposal_id: u64,
    should_pass: bool,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a>, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a> {
    <b>let</b> investor_addr = std::signer::address_of(investor);
    <b>let</b> record_key = <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_RecordKey">RecordKey</a> {
        investor_addr,
        proposal_id,
    };
    <b>let</b> records = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a>&gt;(founder);
    <b>assert</b>!(
        !<a href="_contains">table::contains</a>(&records.votes, record_key),
        <a href="_invalid_argument">error::invalid_argument</a>(<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_ALREADY_VOTED">E_ALREADY_VOTED</a>),
    );
    <a href="_add">table::add</a>(&<b>mut</b> records.votes, record_key, <b>true</b>);

    <b>let</b> proof = <b>borrow_global</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>&gt;(investor_addr);
    <b>let</b> num_votes = <a href="_borrow">simple_map::borrow</a>(&proof.voting_powers, &founder);

    <a href="_vote">voting::vote</a>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a>&gt;(
        &<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_empty_proposal">empty_proposal</a>(),
        <b>copy</b> founder,
        proposal_id,
        *num_votes,
        should_pass,
    );
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_withdraw"></a>

## Function `withdraw`

Withdraw the funding. This can be called by the founder.


<pre><code><b>public</b> <b>fun</b> <a href="withdraw.md#0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw">withdraw</a>&lt;CoinType&gt;(founder: <b>address</b>, proposal: <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">inbond::WithdrawalProposal</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="withdraw.md#0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw">withdraw</a>&lt;CoinType&gt;(
    founder: <b>address</b>,
    proposal: <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a>,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a> {
    <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury">check_treasury</a>&lt;CoinType&gt;(founder);
    <b>let</b> treasury = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;CoinType&gt;&gt;(founder);
    <b>let</b> <a href="">coin</a> = <a href="_extract">coin::extract</a>(&<b>mut</b> treasury.funding, proposal.withdrawal_amount);
    <a href="_deposit">coin::deposit</a>(proposal.beneficiary, <a href="">coin</a>);
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_redeem_all"></a>

## Function `redeem_all`

Redeem the funding.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_redeem_all">redeem_all</a>&lt;CoinType&gt;(investor: &<a href="">signer</a>, founder: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_redeem_all">redeem_all</a>&lt;CoinType&gt;(
    investor: &<a href="">signer</a>,
    founder: <b>address</b>,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a> {
    <b>let</b> investor_addr = std::signer::address_of(investor);
    <b>let</b> treasury = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;CoinType&gt;&gt;(founder);
    <b>let</b> voting_power = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>&gt;(investor_addr);
    <b>let</b> (_, num_votes) = <a href="_remove">simple_map::remove</a>(&<b>mut</b> voting_power.voting_powers, &founder);
    <b>let</b> <a href="">coin</a> = <a href="_extract">coin::extract</a>(&<b>mut</b> treasury.funding, num_votes * 9 / 10);
    <a href="_deposit">coin::deposit</a>(investor_addr, <a href="">coin</a>);
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_convert_all"></a>

## Function `convert_all`

Convert the funding to the coin.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_convert_all">convert_all</a>&lt;FundingType, FounderType&gt;(investor: &<a href="">signer</a>, founder: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_convert_all">convert_all</a>&lt;FundingType, FounderType&gt;(
    investor: &<a href="">signer</a>,
    founder: <b>address</b>,
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>, <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderVault">FounderVault</a> {
    <b>let</b> investor_addr = std::signer::address_of(investor);
    <b>let</b> treasury = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;FundingType&gt;&gt;(founder);
    <b>let</b> proof = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Bonds">Bonds</a>&gt;(investor_addr);
    <b>let</b> vault = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_FounderVault">FounderVault</a>&lt;FounderType&gt;&gt;(founder);

    <b>if</b> (!<a href="_is_account_registered">coin::is_account_registered</a>&lt;FounderType&gt;(investor_addr)) {
        <a href="_register">coin::register</a>&lt;FounderType&gt;(investor);
    };

    <b>let</b> (_, num_votes) = <a href="_remove">simple_map::remove</a>(&<b>mut</b> proof.voting_powers, &founder);

    <b>let</b> input_coin = <a href="_extract">coin::extract</a>(&<b>mut</b> treasury.funding, num_votes);

    <b>let</b> output_amount = <a href="_value">coin::value</a>(&input_coin) * vault.vault_size / treasury.target_funding_size;

    <b>let</b> output_coin = <a href="_extract">coin::extract</a>(&<b>mut</b> vault.vault, output_amount);

    <a href="_deposit">coin::deposit</a>(founder, input_coin);
    <a href="_deposit">coin::deposit</a>(investor_addr, output_coin);
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_update_treasury_info"></a>

## Function `update_treasury_info`

Update the treasury info.


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_update_treasury_info">update_treasury_info</a>&lt;CoinType&gt;(founder: &<a href="">signer</a>, name: <a href="_String">string::String</a>, description: <a href="_String">string::String</a>, image_url: <a href="_String">string::String</a>, external_url: <a href="_String">string::String</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_update_treasury_info">update_treasury_info</a>&lt;CoinType&gt;(
    founder: &<a href="">signer</a>,
    name: String,
    description: String,
    image_url: String,
    external_url: String
) <b>acquires</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a> {
    <b>let</b> founder_addr = std::signer::address_of(founder);
    <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury">check_treasury</a>&lt;CoinType&gt;(founder_addr);
    <b>let</b> treasury = <b>borrow_global_mut</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;CoinType&gt;&gt;(founder_addr);
    treasury.name = name;
    treasury.description = description;
    treasury.image_url = image_url;
    treasury.external_url = external_url;
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury"></a>

## Function `check_treasury`



<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury">check_treasury</a>&lt;CoinType&gt;(addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_treasury">check_treasury</a>&lt;CoinType&gt;(addr: <b>address</b>) {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_Treasury">Treasury</a>&lt;CoinType&gt;&gt;(addr),
        <a href="_not_found">error::not_found</a>(<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_TREASURY_NOT_FOUND">E_TREASURY_NOT_FOUND</a>),
    );
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_records"></a>

## Function `check_records`



<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_records">check_records</a>(addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_check_records">check_records</a>(addr: <b>address</b>) {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_VotingRecords">VotingRecords</a>&gt;(addr),
        <a href="_not_found">error::not_found</a>(<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_E_RECORDS_NOT_FOUND">E_RECORDS_NOT_FOUND</a>),
    );
}
</code></pre>



</details>

<a name="0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_empty_proposal"></a>

## Function `empty_proposal`



<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_empty_proposal">empty_proposal</a>(): <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">inbond::WithdrawalProposal</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_empty_proposal">empty_proposal</a>(): <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a> {
    <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">WithdrawalProposal</a> {
        withdrawal_amount: 0,
        beneficiary: @0x0,
    }
}
</code></pre>



</details>

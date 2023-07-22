
<a name="0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw"></a>

# Module `0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff::withdraw`



-  [Function `withdraw`](#0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw_withdraw)


<pre><code><b>use</b> <a href="">0x1::voting</a>;
<b>use</b> <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond">0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9::inbond</a>;
</code></pre>



<a name="0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw_withdraw"></a>

## Function `withdraw`



<pre><code><b>public</b> entry <b>fun</b> <a href="withdraw.md#0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw">withdraw</a>&lt;CoinType&gt;(founder: <b>address</b>, proposal_id: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="withdraw.md#0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff_withdraw">withdraw</a>&lt;CoinType&gt;(founder: <b>address</b>, proposal_id: u64) {
    <b>let</b> withdrawal_proposal = <a href="_resolve">voting::resolve</a>&lt;<a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_WithdrawalProposal">inbond::WithdrawalProposal</a>&gt;(founder, proposal_id);
    <a href="inbond.md#0x6064192b201dc3a7cff0513654610b141e754c9eb1ff22d40622f858c9d912e9_inbond_withdraw">inbond::withdraw</a>&lt;CoinType&gt;(founder, withdrawal_proposal);
}
</code></pre>



</details>


<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter"></a>

# Module `0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3::MyCounter`



-  [Resource `Counter`](#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter)
-  [Function `init`](#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init)
-  [Function `incr`](#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr)
-  [Function `init_counter`](#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init_counter)
-  [Function `incr_counter`](#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr_counter)


<pre><code><b>use</b> <a href="">0x1::signer</a>;
</code></pre>



<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter"></a>

## Resource `Counter`



<pre><code><b>struct</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter">Counter</a> <b>has</b> store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>value: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init"></a>

## Function `init`



<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init">init</a>(account: &<a href="">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init">init</a>(account: &<a href="">signer</a>){
    <b>move_to</b>(account, <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter">Counter</a>{value:0});
}
</code></pre>



</details>

<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr"></a>

## Function `incr`



<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr">incr</a>(account: &<a href="">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr">incr</a>(account: &<a href="">signer</a>) <b>acquires</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter">Counter</a> {
    <b>let</b> counter = <b>borrow_global_mut</b>&lt;<a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter">Counter</a>&gt;(<a href="_address_of">signer::address_of</a>(account));
    counter.value = counter.value + 1;
}
</code></pre>



</details>

<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init_counter"></a>

## Function `init_counter`



<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init_counter">init_counter</a>(account: <a href="">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init_counter">init_counter</a>(account: <a href="">signer</a>){
    <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_init">Self::init</a>(&account)
}
</code></pre>



</details>

<a name="0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr_counter"></a>

## Function `incr_counter`



<pre><code><b>public</b> <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr_counter">incr_counter</a>(account: <a href="">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr_counter">incr_counter</a>(account: <a href="">signer</a>)  <b>acquires</b> <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_Counter">Counter</a> {
    <a href="MyCounter.md#0x6ed9ceadd7f04e9e30f39a70b2b8f090cefe6b886f8766d3e1ed1fb70655e9c3_MyCounter_incr">Self::incr</a>(&account)
}
</code></pre>



</details>

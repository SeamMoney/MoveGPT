
<a name="0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo"></a>

# Module `0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136::UserInfo`



-  [Resource `UserProfile`](#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile)
-  [Function `get_username`](#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_get_username)
-  [Function `set_username`](#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_set_username)


<pre><code><b>use</b> <a href="">0x1::signer</a>;
<b>use</b> <a href="">0x1::string</a>;
</code></pre>



<a name="0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile"></a>

## Resource `UserProfile`



<pre><code><b>struct</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>username: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_get_username"></a>

## Function `get_username`



<pre><code><b>public</b> <b>fun</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_get_username">get_username</a>(user_addr: <b>address</b>): <a href="_String">string::String</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_get_username">get_username</a>(user_addr: <b>address</b>): String
<b>acquires</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a> {
    <b>borrow_global</b>&lt;<a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a>&gt;(user_addr).username
}
</code></pre>



</details>

<a name="0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_set_username"></a>

## Function `set_username`



<pre><code><b>public</b> <b>fun</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_set_username">set_username</a>(user_account: &<a href="">signer</a>, username_raw: <a href="">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_set_username">set_username</a>(user_account: &<a href="">signer</a>, username_raw: <a href="">vector</a>&lt;u8&gt;)
<b>acquires</b> <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a> {
    <b>let</b> username = utf8(username_raw);
    <b>let</b> user_addr = <a href="_address_of">signer::address_of</a>(user_account);
    <b>if</b> (!<b>exists</b>&lt;<a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a>&gt;(user_addr)) {
        <b>let</b> info_store = <a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a> {
            username
        };
        <b>move_to</b>(user_account, info_store);
    } <b>else</b> {
        <b>let</b> existing_info_store = <b>borrow_global_mut</b>&lt;<a href="UserInfo.md#0x7cb7997f4efeb24360446117369e3b55220f8a1f8a907dcb33c81e2a63e7e136_UserInfo_UserProfile">UserProfile</a>&gt;(user_addr);
        existing_info_store.username = username
    }
}
</code></pre>



</details>

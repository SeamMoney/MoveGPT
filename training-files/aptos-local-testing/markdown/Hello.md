
<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message"></a>

# Module `0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60::message`



-  [Resource `MessageHolder`](#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder)
-  [Struct `MessageChangeEvent`](#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent)
-  [Constants](#@Constants_0)
-  [Function `get_message`](#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_get_message)
-  [Function `set_message`](#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_set_message)


<pre><code><b>use</b> <a href="">0x1::error</a>;
<b>use</b> <a href="">0x1::event</a>;
<b>use</b> <a href="">0x1::signer</a>;
<b>use</b> <a href="">0x1::string</a>;
</code></pre>



<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder"></a>

## Resource `MessageHolder`



<pre><code><b>struct</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>message_change_events: <a href="_EventHandle">event::EventHandle</a>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent">message::MessageChangeEvent</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent"></a>

## Struct `MessageChangeEvent`



<pre><code><b>struct</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent">MessageChangeEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>from_message: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>to_message: <a href="_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a name="@Constants_0"></a>

## Constants


<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_ENO_MESSAGE"></a>

There is no message present


<pre><code><b>const</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_ENO_MESSAGE">ENO_MESSAGE</a>: u64 = 0;
</code></pre>



<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_get_message"></a>

## Function `get_message`



<pre><code><b>public</b> <b>fun</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_get_message">get_message</a>(addr: <b>address</b>): <a href="_String">string::String</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_get_message">get_message</a>(addr: <b>address</b>): <a href="_String">string::String</a> <b>acquires</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a>&gt;(addr), <a href="_not_found">error::not_found</a>(<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_ENO_MESSAGE">ENO_MESSAGE</a>));
    *&<b>borrow_global</b>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a>&gt;(addr).<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>
}
</code></pre>



</details>

<a name="0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_set_message"></a>

## Function `set_message`



<pre><code><b>public</b> <b>fun</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_set_message">set_message</a>(account: <a href="">signer</a>, message_bytes: <a href="">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_set_message">set_message</a>(account: <a href="">signer</a>, message_bytes: <a href="">vector</a>&lt;u8&gt;)
<b>acquires</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a> {
    <b>let</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a> = <a href="_utf8">string::utf8</a>(message_bytes);
    <b>let</b> account_addr = <a href="_address_of">signer::address_of</a>(&account);
    <b>if</b> (!<b>exists</b>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a>&gt;(account_addr)) {
        <b>move_to</b>(&account, <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a> {
            <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>,
            message_change_events: <a href="_new_event_handle">event::new_event_handle</a>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent">MessageChangeEvent</a>&gt;(&account),
        })
    } <b>else</b> {
        <b>let</b> old_message_holder = <b>borrow_global_mut</b>&lt;<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageHolder">MessageHolder</a>&gt;(account_addr);
        <b>let</b> from_message = *&old_message_holder.<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>;
        <a href="_emit_event">event::emit_event</a>(&<b>mut</b> old_message_holder.message_change_events, <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message_MessageChangeEvent">MessageChangeEvent</a> {
            from_message,
            to_message: <b>copy</b> <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>,
        });
        old_message_holder.<a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a> = <a href="Hello.md#0x6de8a991b1a881c2c1637b810aae0ea40ab52cbca67bfd93be78e06faa43f60_message">message</a>;
    }
}
</code></pre>



</details>

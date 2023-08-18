
<a name="0x1_system_addresses"></a>

# Module `0x1::system_addresses`



-  [Constants](#@Constants_0)
-  [Function `assert_core_resource`](#0x1_system_addresses_assert_core_resource)
-  [Function `assert_core_resource_address`](#0x1_system_addresses_assert_core_resource_address)
-  [Function `is_core_resource_address`](#0x1_system_addresses_is_core_resource_address)
-  [Function `assert_aptos_framework`](#0x1_system_addresses_assert_aptos_framework)
-  [Function `assert_framework_reserved_address`](#0x1_system_addresses_assert_framework_reserved_address)
-  [Function `assert_framework_reserved`](#0x1_system_addresses_assert_framework_reserved)
-  [Function `is_framework_reserved_address`](#0x1_system_addresses_is_framework_reserved_address)
-  [Function `is_aptos_framework_address`](#0x1_system_addresses_is_aptos_framework_address)
-  [Function `assert_vm`](#0x1_system_addresses_assert_vm)
-  [Function `is_vm`](#0x1_system_addresses_is_vm)
-  [Function `is_vm_address`](#0x1_system_addresses_is_vm_address)
-  [Function `is_reserved_address`](#0x1_system_addresses_is_reserved_address)
-  [Specification](#@Specification_1)
    -  [Function `assert_core_resource`](#@Specification_1_assert_core_resource)
    -  [Function `assert_core_resource_address`](#@Specification_1_assert_core_resource_address)
    -  [Function `is_core_resource_address`](#@Specification_1_is_core_resource_address)
    -  [Function `assert_aptos_framework`](#@Specification_1_assert_aptos_framework)
    -  [Function `assert_framework_reserved_address`](#@Specification_1_assert_framework_reserved_address)
    -  [Function `assert_framework_reserved`](#@Specification_1_assert_framework_reserved)
    -  [Function `assert_vm`](#@Specification_1_assert_vm)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
</code></pre>



<a name="@Constants_0"></a>

## Constants


<a name="0x1_system_addresses_ENOT_APTOS_FRAMEWORK_ADDRESS"></a>

The address/account did not correspond to the core framework address


<pre><code><b>const</b> <a href="system_addresses.md#0x1_system_addresses_ENOT_APTOS_FRAMEWORK_ADDRESS">ENOT_APTOS_FRAMEWORK_ADDRESS</a>: u64 = 3;
</code></pre>



<a name="0x1_system_addresses_ENOT_CORE_RESOURCE_ADDRESS"></a>

The address/account did not correspond to the core resource address


<pre><code><b>const</b> <a href="system_addresses.md#0x1_system_addresses_ENOT_CORE_RESOURCE_ADDRESS">ENOT_CORE_RESOURCE_ADDRESS</a>: u64 = 1;
</code></pre>



<a name="0x1_system_addresses_ENOT_FRAMEWORK_RESERVED_ADDRESS"></a>

The address is not framework reserved address


<pre><code><b>const</b> <a href="system_addresses.md#0x1_system_addresses_ENOT_FRAMEWORK_RESERVED_ADDRESS">ENOT_FRAMEWORK_RESERVED_ADDRESS</a>: u64 = 4;
</code></pre>



<a name="0x1_system_addresses_EVM"></a>

The operation can only be performed by the VM


<pre><code><b>const</b> <a href="system_addresses.md#0x1_system_addresses_EVM">EVM</a>: u64 = 2;
</code></pre>



<a name="0x1_system_addresses_assert_core_resource"></a>

## Function `assert_core_resource`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource">assert_core_resource</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource">assert_core_resource</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_core_resource_address">assert_core_resource_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>))
}
</code></pre>



</details>

<a name="0x1_system_addresses_assert_core_resource_address"></a>

## Function `assert_core_resource_address`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource_address">assert_core_resource_address</a>(addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource_address">assert_core_resource_address</a>(addr: <b>address</b>) {
    <b>assert</b>!(<a href="system_addresses.md#0x1_system_addresses_is_core_resource_address">is_core_resource_address</a>(addr), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="system_addresses.md#0x1_system_addresses_ENOT_CORE_RESOURCE_ADDRESS">ENOT_CORE_RESOURCE_ADDRESS</a>))
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_core_resource_address"></a>

## Function `is_core_resource_address`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_core_resource_address">is_core_resource_address</a>(addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_core_resource_address">is_core_resource_address</a>(addr: <b>address</b>): bool {
    addr == @core_resources
}
</code></pre>



</details>

<a name="0x1_system_addresses_assert_aptos_framework"></a>

## Function `assert_aptos_framework`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">assert_aptos_framework</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">assert_aptos_framework</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>assert</b>!(
        <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">is_aptos_framework_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="system_addresses.md#0x1_system_addresses_ENOT_APTOS_FRAMEWORK_ADDRESS">ENOT_APTOS_FRAMEWORK_ADDRESS</a>),
    )
}
</code></pre>



</details>

<a name="0x1_system_addresses_assert_framework_reserved_address"></a>

## Function `assert_framework_reserved_address`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved_address">assert_framework_reserved_address</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved_address">assert_framework_reserved_address</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved">assert_framework_reserved</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>));
}
</code></pre>



</details>

<a name="0x1_system_addresses_assert_framework_reserved"></a>

## Function `assert_framework_reserved`



<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved">assert_framework_reserved</a>(addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved">assert_framework_reserved</a>(addr: <b>address</b>) {
    <b>assert</b>!(
        <a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">is_framework_reserved_address</a>(addr),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="system_addresses.md#0x1_system_addresses_ENOT_FRAMEWORK_RESERVED_ADDRESS">ENOT_FRAMEWORK_RESERVED_ADDRESS</a>),
    )
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_framework_reserved_address"></a>

## Function `is_framework_reserved_address`

Return true if <code>addr</code> is 0x0 or under the on chain governance's control.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">is_framework_reserved_address</a>(addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">is_framework_reserved_address</a>(addr: <b>address</b>): bool {
    <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">is_aptos_framework_address</a>(addr) ||
        addr == @0x2 ||
        addr == @0x3 ||
        addr == @0x4 ||
        addr == @0x5 ||
        addr == @0x6 ||
        addr == @0x7 ||
        addr == @0x8 ||
        addr == @0x9 ||
        addr == @0xa
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_aptos_framework_address"></a>

## Function `is_aptos_framework_address`

Return true if <code>addr</code> is 0x1.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">is_aptos_framework_address</a>(addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">is_aptos_framework_address</a>(addr: <b>address</b>): bool {
    addr == @aptos_framework
}
</code></pre>



</details>

<a name="0x1_system_addresses_assert_vm"></a>

## Function `assert_vm`

Assert that the signer has the VM reserved address.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_vm">assert_vm</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_vm">assert_vm</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>assert</b>!(<a href="system_addresses.md#0x1_system_addresses_is_vm">is_vm</a>(<a href="account.md#0x1_account">account</a>), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="system_addresses.md#0x1_system_addresses_EVM">EVM</a>))
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_vm"></a>

## Function `is_vm`

Return true if <code>addr</code> is a reserved address for the VM to call system modules.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_vm">is_vm</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_vm">is_vm</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): bool {
    <a href="system_addresses.md#0x1_system_addresses_is_vm_address">is_vm_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>))
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_vm_address"></a>

## Function `is_vm_address`

Return true if <code>addr</code> is a reserved address for the VM to call system modules.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_vm_address">is_vm_address</a>(addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_vm_address">is_vm_address</a>(addr: <b>address</b>): bool {
    addr == @vm_reserved
}
</code></pre>



</details>

<a name="0x1_system_addresses_is_reserved_address"></a>

## Function `is_reserved_address`

Return true if <code>addr</code> is either the VM address or an Aptos Framework address.


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_reserved_address">is_reserved_address</a>(addr: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_reserved_address">is_reserved_address</a>(addr: <b>address</b>): bool {
    <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">is_aptos_framework_address</a>(addr) || <a href="system_addresses.md#0x1_system_addresses_is_vm_address">is_vm_address</a>(addr)
}
</code></pre>



</details>

<a name="@Specification_1"></a>

## Specification



<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict;
</code></pre>



<a name="@Specification_1_assert_core_resource"></a>

### Function `assert_core_resource`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource">assert_core_resource</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>pragma</b> opaque;
<b>include</b> <a href="system_addresses.md#0x1_system_addresses_AbortsIfNotCoreResource">AbortsIfNotCoreResource</a> { addr: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>) };
</code></pre>



<a name="@Specification_1_assert_core_resource_address"></a>

### Function `assert_core_resource_address`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_core_resource_address">assert_core_resource_address</a>(addr: <b>address</b>)
</code></pre>




<pre><code><b>pragma</b> opaque;
<b>include</b> <a href="system_addresses.md#0x1_system_addresses_AbortsIfNotCoreResource">AbortsIfNotCoreResource</a>;
</code></pre>



<a name="@Specification_1_is_core_resource_address"></a>

### Function `is_core_resource_address`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_is_core_resource_address">is_core_resource_address</a>(addr: <b>address</b>): bool
</code></pre>




<pre><code><b>pragma</b> opaque;
<b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == (addr == @core_resources);
</code></pre>



<a name="@Specification_1_assert_aptos_framework"></a>

### Function `assert_aptos_framework`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">assert_aptos_framework</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>pragma</b> opaque;
<b>include</b> <a href="system_addresses.md#0x1_system_addresses_AbortsIfNotAptosFramework">AbortsIfNotAptosFramework</a>;
</code></pre>



<a name="@Specification_1_assert_framework_reserved_address"></a>

### Function `assert_framework_reserved_address`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved_address">assert_framework_reserved_address</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>aborts_if</b> !<a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">is_framework_reserved_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(<a href="account.md#0x1_account">account</a>));
</code></pre>



<a name="@Specification_1_assert_framework_reserved"></a>

### Function `assert_framework_reserved`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_framework_reserved">assert_framework_reserved</a>(addr: <b>address</b>)
</code></pre>




<pre><code><b>aborts_if</b> !<a href="system_addresses.md#0x1_system_addresses_is_framework_reserved_address">is_framework_reserved_address</a>(addr);
</code></pre>



<a name="@Specification_1_assert_vm"></a>

### Function `assert_vm`


<pre><code><b>public</b> <b>fun</b> <a href="system_addresses.md#0x1_system_addresses_assert_vm">assert_vm</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>pragma</b> opaque;
<b>include</b> <a href="system_addresses.md#0x1_system_addresses_AbortsIfNotVM">AbortsIfNotVM</a>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
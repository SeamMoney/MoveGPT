# CheckDot Aptos Coin Contract

#### Install

UTIL: https://imcoding.online/tutorials/how-to-issue-your-coins-on-aptos

https://aptos.dev/tools/install-cli/

`aptos init`

#### Compile

`aptos move compile`

#### Deploy

```shell
aptos move publish
aptos move run --function-id b366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::CdtCoin::init
```

#### Burn

Example of burn of 1 CDT:

```
aptos move run --function-id b366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::CdtCoin::burn_amount --args u64:100000000
```

#### Unused Test Addresses (On Mainnet)

0x5fdb279c9078dea0d6aff86c64664a6929e61b304e9bc398c21f66ecb6750483::cdt::CDT
0x35d0bf2dc52774f8f154b649b91d49c6e71df6ed6ab9df5103c07e0f8405bb70::cdt::CDT

#### Final Address (On Mainnet Final used Address)

0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::CdtCoin::CDT
TraceMove Link: https://tracemove.io/coin/0xb366c7c4521277846a7fee4f3bcc92c435089537d30390d8854ca31addfbae4f::CdtCoin::CDT/CheckDot%20Coin/CDT
# mint_nft_aptos

1. Run `aptos init` to create account
2. Create Resource account `aptos account create-resource-account --seed 15`
3. Deploying contract with `aptos move create-resource-account-and-publish-package --address-name "f632ba942630010a4655cae333e361230f5f24af3f3e9f90ff5620162356d463" --seed 20 --named-addresses mint_nft=f632ba942630010a4655cae333e361230f5f24af3f3e9f90ff5620162356d463`
4. I have tried with different seed while publishing like 10/15/20 and trying to change -address-name with new created address, but getting below error

```log
{
  "Error": "Simulation failed with status: Transaction Executed and Committed with Error MODULE_ADDRESS_DOES_NOT_MATCH_SENDER"
}
```

```log
{
  "Error": "Simulation failed with status: Move abort in 0x1::account: ERESOURCE_ACCCOUNT_EXISTS(0x8000f): An attempt to create a resource account on a claimed account"
}
```
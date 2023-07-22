# Just NFTs Smart Contract 🧠

This repository houses the smart contract for Just NFTs written in Move.

## Table of Contents 📚
- [Overview](#overview-)
- [Files](#files-)
- [Getting Started](#getting-started-)
- [Usage](#usage-)
  - [Mint](#mint-)
  - [Transfer](#transfer-)
  - [Burn](#burn-)
  - [Opt Into Transfer](#opt-into-transfer-)
  - [Register Token Store](#register-token-store-)
- [Building](#building-)
- [Testing](#testing-)
- [Deploying](#deploying-)

## Overview 👀
This contract lets users **mint NFTs**, **tranfer NFTs**, and **burn NFTs**. It also has several utility functions that allow users to **register a Token Store** and **opt-in to transfers**.

## Files 📁
- `just_nfts.move` - The main contract file
- `utils.move` - Utility functions
- `mint.move` - Minting Scipt to mint NFTs

## Getting Started 🚀
Before calling any function make sure you call `opt_into_transfer(account: &signer)` and `register_token_store(account: &signer)`. This will make sure that you are able to mint and receive the NFTs. It will also make sure that you are able to receive transfers.

## Usage ⚙️

### Mint 🎨
The `mint(caller: &signer)` function can be called to mint and NFT to the caller's account.

It takes a `reference to signer` as an argument.

This function will fail if the caller has **not opted into the transfer** and **token store**.

```move
public entry fun mint(
    caller: &signer
) acquires CollectionData
```

### Transfer 📤
The `transfer(owner: &signer, recipient: address, token_id: u128)` function can be called to transfer an NFT to the recipient.

It takes a `reference to signer`, `address`, and `u128` as arguments.

This function will fail if the receiver has **not opted into the transfer** and **token store** or if the **caller is not the owner** of the set token. The function would also fail if the **token does not exist** or the **token id is out of range**.

```move
public entry fun transfer(
    owner: &signer,
    recipient: address,
    token_id: u128
) acquires CollectionData
```

### Burn 🔥
The `burn(caller: &signer, token_id: u128)` function can be called to burn an NFT.

It takes a `reference to signer` and `u128` as arguments.

This function will fail if the **caller is not the owner** of the set token. The function would also fail if the **token does not exist** or the **token id is out of range**.

```move
public entry fun burn(
    owner: &signer,
    token_id: u128
) acquires CollectionData
```

### Opt Into Transfer 📥
The `opt_into_transfer(account: &signer)` function can be called to opt into transfers. This allows the account to receive NFTs.

It takes a `reference to signer` as an argument.

```move
public entry fun opt_into_transfer(
    account: &signer
)
```

### Register Token Store 📦
The `register_token_store(account: &signer)` function can be called to register a token store. This allows the account to store NFTs.

It takes a `reference to signer` as an argument.

```move
public entry fun register_token_store(
    account: &signer
)
```

## Building 🏗️
> ⚠️ You need the [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/) to build the project.

To build the project run the following command:

```bash
aptos move compile --named-addresses nft_api=default --included-artifacts all
```
We include all aritifacts so that we get access to the ABI after compiling the contract.

## Testing 🧪
> ⚠️ You need the [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/) to test the project.

To test the project run the following command:

```bash
aptos move test --named-addresses nft_api=default
```

## Deploying 🚀
> ⚠️ You need the [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/) to deploy the project.

To deploy the project run the following command:

```bash
aptos move publish --named-addresses nft_api=default
```

The contract would be published to the `nft_api` address.
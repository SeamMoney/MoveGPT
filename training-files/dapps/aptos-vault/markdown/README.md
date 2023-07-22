# Ducky Vault 🦆

[![Twitter](https://custom-icon-badges.demolab.com/badge/-Follow-blue?style=for-the-badge&logoColor=white&logo=twitter)](https://twitter.com/AadeeWasTaken)
[![GitHub](https://custom-icon-badges.demolab.com/badge/-Follow-orange?style=for-the-badge&logoColor=white&logo=github)](https://github.com/AadeeWasTaken)

This repository contains the module for a Vault on the [Aptos Network](https://aptoslabs.com/).

## Overview 👀

The module lets users deposit their coins safely into a Vault and then withdraw them at a later point when needed. The module creates a new Vault for each user for each type of coin. Users can only deposit and withdraw from their own Vaults. Deposits and Withdrawals from the Vaults can be paused by the Admin.

> ⚠️ Publisher of the module is the Admin and must be the same as DuckyVault

## Usage ⚙️

### Deposit 🏦

The `deposit<CoinType>(account: &signer, amount: u64)` function can be called to deposit coins into the vault.

It takes the `reference to signer` of the account that want's to deposit and `amount` they want to deposit as it's parameters.

The function will `abort` if the user doesn't have enough Coins in their account.

```move
public entry fun deposit<CoinType>(
    account: &signer,
    amount: u64
) acquires VaultsInfo, VaultsHolder
```

### Withdraw 💸

The `withdraw<CoinType>(account: &signer, amount: u64)` function can be called to withdraw coins from the vault.

It takes the `reference to signer` of the account that want's to withdraw and `amount` they want to withdraw as it's parameters.

The function will `abort` if the Vault doesn't exist or if user doesn't have enough Coins in their vault.

```move
public entry fun withdraw<CoinType>(
    account: &signer,
    amount: u64
) acquires VaultsInfo, VaultsHolder
```

### Pause ⏸️

The `pause(account: &signer)` function can be called by the owner of the module to pause deposits and withdrawals for all Vaults.

It takes the `reference to signer` as it's parameters. The signer must be the Admin.

The function will `abort` if signer is not the Admin or if already paused.

```move
public entry fun pause(account: &signer) acquires VaultsInfo
```

### Unpause ▶️

The `unpause(account: &signer)` function can be called by the owner of the module to unpause deposits and withdrawals for all Vaults.

It takes the `reference to signer` as it's parameters. The signer must be the Admin.

The function will `abort` if signer is not the Admin or if if already unpaused.

```move
public entry fun unpause(account: &signer) acquires VaultsInfo
```

## Test 🧪

The `Vault.move` file also has tests for all the functions of the module.
The tests can be run by running the following command

> ⚠️ You need the [Aptos CLI](https://aptos.dev/cli-tools/aptos-cli-tool/aptos-cli-index/) to run the tests

```bash
aptos move test
```

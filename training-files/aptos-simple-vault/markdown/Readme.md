# Simple Aptos Vault smart contract

## Spec
1) There should be a ‘deposit’, and ‘withdraw’ function that any user can use to deposit and withdraw their own Coins, but no other user's coins

2) There should also be two additional functions that only admins can call. ‘Pause’ and ‘Unpause’ that prevent/enable new deposits or withdrawals from occurring.

3) The module should contain testing for functions as well. 

4) The module can accept any ‘Coin’ of any type from any number of users

## Setup environment

### Install Aptos CLI
Install the Aptos CLI following the [Installing Aptos CLI] guide.

### Create an account and fund it
Create an account and fund it following the [Aptos Developer Tutorials] guide.

[installing aptos cli]: <https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli/>
[aptos developer tutorials]: <https://aptos.dev/tutorials/first-move-module#step-2-create-an-account-and-fund-it>

## How to run

### Compile

Compile the contract

```sh
aptos move compile --named-addresses simple_vault=default
```

### Run tests

Run unit tests

```sh
aptos move test --named-addresses simple_vault=default
```
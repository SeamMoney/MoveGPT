### Learn Aptos by example

#### Build a coin (token)

-   With Move/Aptos, we will have source of module code and scripts. We will deploy our module `TestCoin.move`.

The `TESTCOIN` using `aptos_framework::coin` to initialize the coin with burn capability.

**Install aptos cli and init your profile (account)**

-   You can folllow the aptos tutorial to install aptos cli then using `aptos init --profile <profile_name>` to init account.

**Compile source code**

Run `aptos move compile`

```sh
saphamdang@Sas-MacBook-Pro sa-coin % aptos move compile
Compiling, may take a little while to download git dependencies...
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING ex-testcoin
{
  "Result": [
    "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205::testcoin"
  ]
}
```

**Publish module**

```sh
saphamdang@Sas-MacBook-Pro sa-coin % aptos move publish
Compiling, may take a little while to download git dependencies...
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING ex-testcoin
package size 1912 bytes
Do you want to submit a transaction for a range of [699700 - 1049500] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0xaf30ddf2faced568028727d682bad02abbe00b16643b91954ba24f079dcbf5b6",
    "gas_used": 6997,
    "gas_unit_price": 100,
    "sender": "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205",
    "sequence_number": 4,
    "success": true,
    "timestamp_us": 1667551595139876,
    "version": 860615,
    "vm_status": "Executed successfully"
  }
}
```

**Register Coin for account**

To mint or receive coin in aptos, we should register coin for Coinstore.

To register TESTCOIN, we will use script `register.move` in scripts folder.

Using aptos CLI and compiled script

```
aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/register.mv
```

Output

```sh
saphamdang@Sas-MacBook-Pro sa-coin % aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/register.mv
Do you want to submit a transaction for a range of [96500 - 144700] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0xd3c15d1ba41547cfa92e35f845325e17c52132d41d9df02d3a9c45cd61350736",
    "gas_used": 999,
    "gas_unit_price": 100,
    "sender": "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205",
    "sequence_number": 5,
    "success": true,
    "timestamp_us": 1667552886017986,
    "version": 885171,
    "vm_status": "Executed successfully"
  }
}
```

**Mint Coin**

We will init the coin with mint action for the deployer account by using `mint.move` script in scripts folder

```
aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/mint_testcoin.mv
```

Output

```sh
saphamdang@Sas-MacBook-Pro sa-coin % aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/mint_testcoin.mv
Do you want to submit a transaction for a range of [160900 - 241300] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0x4d9ab69fe50485bbadd5c3a28a6b3d42ca186b0ecd740be30f286f43450b067e",
    "gas_used": 1609,
    "gas_unit_price": 100,
    "sender": "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205",
    "sequence_number": 6,
    "success": true,
    "timestamp_us": 1667553230320345,
    "version": 891769,
    "vm_status": "Executed successfully"
  }
}
```

**Transfer Coin to other account**

To transfer to another account, that account need to register this COIN as well. If the account is not register yet, the TX will be failed.

We can use the same register script in the above step with `--profile` argument in aptos CLI to execute by other account.

To transfer coin, we will use `transfer.move` script with account address argument, change to your account address

```sh
saphamdang@Sas-MacBook-Pro sa-coin % aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/transfer.mv  --args address:0xaa811b65aa485ab3f6d432829068c5e8d1a4ae622bb9c77e96f54416a1322b13
Do you want to submit a transaction for a range of [54600 - 81900] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0xc6b169a81085935f8f48686a550021b3088f57200255b9c9639d1e12093edf1f",
    "gas_used": 546,
    "gas_unit_price": 100,
    "sender": "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205",
    "sequence_number": 7,
    "success": true,
    "timestamp_us": 1667553372495794,
    "version": 894910,
    "vm_status": "Executed successfully"
  }
}
```

**Burn TESTCOIN**

Use `burn.move` script

```sh
saphamdang@Sas-MacBook-Pro testcoin % aptos move run-script --compiled-script-path build/ex-testcoin/bytecode_scripts/burn.mv --args u64:100
Do you want to submit a transaction for a range of [53300 - 79900] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0x3e69d78ecda854f39d063f7af1aae47a89f0e9812b895ea9db167c54a09dbc0d",
    "gas_used": 533,
    "gas_unit_price": 100,
    "sender": "ce83e85e96fae68815abbf35be18d6d4dda6884f65fb08e99de0d35a0df1a205",
    "sequence_number": 9,
    "success": true,
    "timestamp_us": 1667572744086531,
    "version": 1261824,
    "vm_status": "Executed successfully"
  }
}
```

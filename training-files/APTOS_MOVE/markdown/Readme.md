# APTOS-MOVE

Aptos & Move integration:

- Setup
  - Init
  - Config
  - Compile
  - Test
- Deployment
  - Init
  - Funding the Wallet
  - Compile & test
  - Publishing
- Interaction

## MODULES

- Aptos Basics (Global Counter)
- Aptos Coin

---

## SETUP

### Initialize

```sh
aptos move init
```

### Config file

```toml
[package]
name = 'counter_mod'
version = '1.0.0'
[dependencies.AptosFramework]
git = 'https://github.com/aptos-labs/aptos-core.git'
rev = 'main'
subdir = 'aptos-move/framework/aptos-framework'
[addresses]
publisher= "0x42"
```

### Compiling

```sh
aptos move compile --bytecode-version 6
# bytecode version : 6
# If not gives rust compilation error
```

### Testing

```sh
aptos move test --bytecode-version 6
```

## Deployment

### Initialization

To initialize an account on the aptos blockchain dev net. This will generate a `config.yaml` in `.aptos` folder and the config will look something like this.

```yaml
---
profiles:
  default:
    private_key: "<PRIVATE_KEY>"
    public_key: "<PUBLIC_KEY>"
    account: 015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a
    rest_url: "https://fullnode.devnet.aptoslabs.com"
    faucet_url: "https://faucet.devnet.aptoslabs.com"

```

```sh
aptos init

---

Aptos CLI is now set up for account 015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a as profile default!  Run `aptos --help` for more information about commands
{
  "Result": "Success"
}
```

### Funding the Wallet

```sh
aptos account fund-with-faucet --account default
```

### Compiling & Testing

```sh
aptos move compile --bytecode-version 6 --named-addresses publisher=default

# OUTPUT

Compiling, may take a little while to download git dependencies...
UPDATING GIT DEPENDENCY https://github.com/aptos-labs/aptos-core.git
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING counter_mod
{
  "Result": [
    "015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a::counter"
  ]
}

---

aptos move test --bytecode-version 6 --named-addresses publisher=default

# OUTPUT

INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING counter_mod
Running Move unit tests
[ PASS    ] 0x15f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a::counter_test::test_if_it_init
[ PASS    ] 0x15f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a::counter_test::test_increase_count_1
Test result: OK. Total tests: 2; passed: 2; failed: 0
{
  "Result": "Success"
}

```

### Publishing the Module

```sh
aptos move publish --bytecode-version 6 --named-addresses publisher=default

# OUTPUT

Compiling, may take a little while to download git dependencies...
UPDATING GIT DEPENDENCY https://github.com/aptos-labs/aptos-core.git
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING counter_mod
package size 1357 bytes
Do you want to submit a transaction for a range of [126400 - 189600] Octas at a gas unit price of 100 Octas? [yes/no] >
y
{
  "Result": {
    "transaction_hash": "0x95f8244b7e0da3dca296d7b3b8d8303643f8985bb5612dbc7f3d2011b772eae6",
    "gas_used": 1264,
    "gas_unit_price": 100,
    "sender": "015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1678230421614233,
    "version": 3218334,
    "vm_status": "Executed successfully"
  }
}

```

## Interaction

To interact with the aptos modules

```sh
aptos move run \
∙ --function-id 'default::counter::bump'

# OUTPUT

{
  "Result": {
    "transaction_hash": "0x819a2ea021a206cd57ccafec356db8257f5343388a8ebc5670cbd92aa9a235a4",
    "gas_used": 503,
    "gas_unit_price": 100,
    "sender": "015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a",
    "sequence_number": 1,
    "success": true,
    "timestamp_us": 1678231552403299,
    "version": 3226174,
    "vm_status": "Executed successfully"
  }
}

---

# to read the struct at particular account
# curl https://fullnode.devnet.aptoslabs.com/v1/accounts/<Account>/resource/0x<Account>::<Module_name>::<Function_name>

curl https://fullnode.devnet.aptoslabs.com/v1/accounts/015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a/resource/0x015f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a::counter::CountHolder

# OUTPUT

{
    "type":"0x15f8870f86159f196f178981c7e8a66a5171108586b73fdce98fece81505f4a::counter::CountHolder",
    "data":{
        "count":"0"
    }
}

# to get change in events :
# curl https://fullnode.devnet.aptoslabs.com/v1/accounts/<Account>/resource/0x<Account>::<Module_name>::<Function_name>/message_change_events

```

## Structs

- `copy`: Allows values of types with this ability to be copied.
- `drop`: Allows values of types with this ability to be popped/dropped.
- `store`: Allows values of types with this ability to exist inside a struct in global storage.
- `key`: Allows the type to serve as a key for global storage operations.

## Specs

The prover basically tells us that we need to explicitly specify the condition under which the function `balance_of` will abort, which is caused by calling the function `borrow_global` when `owner` does not own the resource `Balance<CoinType>`.

```move
spec balance_of {
    pragma aborts_if_is_strict;
    aborts_if !exists<Balance<CoinType>>(owner);
}
```

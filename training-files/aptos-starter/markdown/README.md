# Aptos Hello World

We are going to build a basic module to learn how to build on Aptos. Modules in Aptos are like contracts in EVM chains.

0. Getting started: Clone https://github.com/aeither/aptos-starter/

only the `.move` files and `Move.toml` are required to follow this guide.
- Move.toml
- sources/

### 1. Setup Wallet

Install [Martian Wallet](https://chrome.google.com/webstore/detail/martian-aptos-wallet/efbglgofoippbgcjepnhiblaibcnclgk) extension. It's the most Popular wallet with more than 600K downloads

### 2. Install Aptos CLI

I followed these steps to install on my macOS Ventura:

- [Download zip](https://github.com/aptos-labs/aptos-core/releases?q=cli&expanded=true) It has this pattern: `aptos-cli-<version>-<platform>` ex. `aptos-cli-1.0.0-MacOSX-x86_64.zip`
- Unzip the downloaded file. Move the extracted `aptos` binary file to `usr/local/bin/`
- Open terminal and type `aptos help` to verify it is installed correctly.

If it does not work for you or you are not a Mac user, here is the official guide to [install the CLI](https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli)

### 3. Setup IDE
Download visual studio code and install move-analyzer extension. 

(Optional) The extension for Move (`.move`) enables syntax highlighting, commenting/uncommenting, simple context-unaware completion suggestions while typing, and other basic language features in Move files.
https://marketplace.visualstudio.com/items?itemName=move.move-analyzer

### 4. Initiate the project
Move to the project folder `aptos-starter`. Remove `.aptos`. Open the terminal and run:

```bash
aptos init
```

It will generate `.aptos/config.yaml` config file containing a funded address on devnet with default settings.

If more funds are needed:

```bash
aptos account fund-with-faucet --account default
```

### 5. Compile

```bash
aptos move compile --named-addresses hello_blockchain=default
```

Terminal response:

```bash
Compiling, may take a little while to download git dependencies...
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING Examples
{
  "Result": [
    "21db140d69608013d6791d9d8157102251798317c565350f519e361dd507e963::message"
  ]
}
```

The `--named-addresses` is a list of address mappings that must be translated in order for the package to be compiled to be stored in the default account. `--save-metadata` is required to publish the package.

### 6. Test

```bash
aptos move test --named-addresses hello_blockchain=default
```

Output:
```bash
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING Examples
Running Move unit tests
[ PASS    ] 0x21db140d69608013d6791d9d8157102251798317c565350f519e361dd507e963::message_tests::sender_can_set_message
[ PASS    ] 0x21db140d69608013d6791d9d8157102251798317c565350f519e361dd507e963::message::sender_can_set_message
Test result: OK. Total tests: 2; passed: 2; failed: 0
{
  "Result": "Success"
}
```

### Publish
```bash
aptos move publish --named-addresses hello_blockchain=default
```

Terminal response:

```
Compiling, may take a little while to download git dependencies...
INCLUDING DEPENDENCY AptosFramework
INCLUDING DEPENDENCY AptosStdlib
INCLUDING DEPENDENCY MoveStdlib
BUILDING Examples
package size 1813 bytes
Do you want to submit a transaction for a range of [702600 - 1053900] Octas at a gas unit price of 100 Octas? [yes/no] >
yes
{
  "Result": {
    "transaction_hash": "0x1bfe2ac5c916c7f3deffc8c7a37754641b0ffed430ca4323d10d286036445a91",
    "gas_used": 7026,
    "gas_unit_price": 100,
    "sender": "1e5fcba9d2a7b14194b331d04adbe354139e17dd520ac53d9d05ba7bca420e5d",
    "sequence_number": 0,
    "success": true,
    "timestamp_us": 1667203290078387,
    "version": 18058074,
    "vm_status": "Executed successfully"
  }
}
```

If we go to [Aptos Explorer](https://explorer.aptoslabs.com/) , switch to Devnet and open Modules under our account. We can find the bytecode with the ABI of the contract we just deployed.

![PUBLISHED_MODULE](https://user-images.githubusercontent.com/36173828/198960261-4b7cb52d-6248-4946-90ea-827883b087a1.png)


### Interact with the module

Calling contract function with:

```bash
aptos move run --assume-yes \
  --function-id 'default::message::set_message' \
  --args 'string:hello, blockchain'
```

It will print out the following on success:

```bash
{
  "Result": {
    "transaction_hash": "0x8185fe45c002d41c491005b489a2faeea75b0bf9c4a0be4218e47a3da6a6eaf0",
    "gas_used": 782,
    "gas_unit_price": 100,
    "sender": "1e5fcba9d2a7b14194b331d04adbe354139e17dd520ac53d9d05ba7bca420e5d",
    "sequence_number": 1,
    "success": true,
    "timestamp_us": 1667203753729894,
    "version": 18087040,
    "vm_status": "Executed successfully"
  }
}
```

We passed `--function-id` with a value of this `<ADDRESS>::<MODULE_ID>::<FUNCTION_NAME>` structure.

Head to the explorer and open the resources tab.

![SET_HELLO_WORLD](https://user-images.githubusercontent.com/36173828/198961988-aae1c7ac-e85c-4863-a76a-01a90aaea0e3.png)

By opening `message::MessageHolder` you can see the new message.

### Conclusion

You can find the original [here](https://aptos.dev/tutorials/first-move-module) by Aptos Foundation. 
This is a modified version where I have added, removed, and modified pieces of content to better fit my journey.

PD: You should NOT expose to the public the `.aptos` folder as it contain the privateKey.

Learn more: https://github.com/aeither/aptos-starter/blob/main/AWESOME_STARTER_LIST.md

In the past few days, I have been exploring resources to get started with Aptos. The transaction speed is almost instant and very cheap. One of the blockchains born from Facebook's defunct Diem Blockchain. Here is a list of the best resources to start your journey to building on top of Aptos.

### Wallets

Martian Wallet - Most Popular wallet with more than 600K downloads
https://chrome.google.com/webstore/detail/martian-aptos-wallet/efbglgofoippbgcjepnhiblaibcnclgk

![WALLETS](https://user-images.githubusercontent.com/36173828/198897078-460278b0-716f-4e96-b383-a5477252e910.png)

Petra Wallet - From Aptos core Team
Blocto, Pontem...

### Setup 

#### Aptos CLI
Installing
https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli

I followed these instruction on macOS Ventura:

Download zip `aptos-cli-<version>-<platform>` ex. `aptos-cli-1.0.0-MacOSX-x86_64.zip`
https://github.com/aptos-labs/aptos-core/releases?q=cli&expanded=true

Unzip the downloaded file. Move the extracted `aptos` binary file to `usr/local/bin/`

Open the terminal and type aptos help to verify it is installed correctly.

#### Move CLI (Optional)
Move CLI is a tool that provides an easy way to interact with Move, to experiment with writing and running Move code, and to experiment with developing new tools useful for Move development.
it is grouped in 3 subcommands
**package commands**: are commands to create, compile, and test Move packages
**sandbox commands**: are commands that allow you to write Move modules and scripts, write and run scripts and tests, and view the resulting state of execution.
and **experimental commands**.
https://aptos.dev/cli-tools/install-move-prover

#### Move prover
It verifies and provides a user experience similar to a type checker or linter.   
Its purpose is to make contracts more trustworthy.
https://github.com/move-language/move/tree/main/language/move-prover

### IDE

Online editor Like Remix for Move
https://playground.pontem.network/

If you are using Visual Studio Code,. This extension for Move (`.move`) enables syntax highlighting, commenting/uncommenting, simple context-unaware completion suggestions while typing, and other basic language features in Move files.
https://marketplace.visualstudio.com/items?itemName=move.move-analyzer

### First Steps

Learn how to how to 
- generate and submit transactions, 
- create and transfer NFTs, 
- compile, test, publish and interact with Move modules
- how to build a dapp
- compile, deploy, and mint your own coin
https://aptos.dev/tutorials/aptos-quickstarts

### REST API

The Aptos Node API is a RESTful API that lets client apps talk to the Aptos blockchain.
https://fullnode.devnet.aptoslabs.com/v1/spec#/

### SDKs

#### Typescript

The Aptos SDK lets you make keys, sign and send transactions, check their status, use the BCS library, get information, use a faucet, and make tokens.

1. Install 

Install using the NPM instructions.
https://www.npmjs.com/package/aptos

or via Github
https://github.com/aptos-labs/aptos-core/tree/main/ecosystem/typescript/sdk

2. Examples
Learn how to send a transaction, create a NFT or transfer coins by example.
https://github.com/aptos-labs/aptos-core/tree/main/ecosystem/typescript/sdk/examples

#### Rust

Installing
https://aptos.dev/sdks/rust-sdk/

Code examples
https://github.com/aptos-labs/aptos-core/tree/main/sdk

#### Python

Installing 
https://aptos.dev/sdks/python-sdk

Code examples 
https://github.com/aptos-labs/aptos-core/tree/main/ecosystem/python/sdk

### Move Language 

Move Tutorial 
https://github.com/move-language/move/tree/main/language/documentation/tutorial

Move examples
https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples

Learn Move by example from a single source of moving language knowledge.
https://move-book.com/index.html

### Aptos Framework
The Aptos Framework defines the standard actions that can be performed.

Aptos Move examples
https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples

auto-generated reference documentation

Aptos framework
https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-framework/doc/overview.md

Aptos Token
https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-token/doc/overview.md

Aptos standard library
https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/aptos-stdlib/doc/overview.md

Move standard library
https://github.com/aptos-labs/aptos-core/blob/main/aptos-move/framework/move-stdlib/doc/overview.md


### Ecosystem Apps

The first apps that we can find on Aptos mainnet. 

- https://ariesmarkets.xyz - lending, swap aggregator
- argo.fi - collateral stable
- app.animeswap.org - Swap
- explorer.aptoslabs.com - Explorer
- martian - Wallet
- bluemove.net, topaz - NFT marketplaces

### Others

escrow
https://github.com/dhruvja/aptos-escrow

tokenized yield-bearing vaults
https://github.com/cryptomonk12/erc4626-move

staking
https://github.com/dhruvja/aptos-staking

lending
https://github.com/DreamXzxy/AptinLend

awesome list of Move examples
https://github.com/MystenLabs/awesome-move

### Conclusion

This post will be updated as I discover more useful resources to help learn and onboard developers to Aptos.

# Coin Objects 
create coin module based on 0x1::aptos_framework::object module
https://github.com/aptos-labs/aptos-core/tree/main/aptos-move/move-examples/token_objects

## Run your local-testnet
`cargo run -p aptos -- node run-local-testnet --with-faucet --faucet-port 8081 --force-restart --assume-yes`

## Create two aptos accounts
Ex.
`aptos init --profile default`
`aptos init --profile seller`

## Check the address of seller profile
set `SELLER` variable to `@{seller_address}`

## Compile and Publish the coin module 
`aptos move compile --named-addresses coin_objects=default --bytecode-version 6`
`aptos move publish --named-addresses coin_objects=default --bytecode-version 6`

## Run Transfer Method
`aptos move run --function-id 'default::coin::test_transfer'`

- Before Transfer
  - buyer's coin balance : 400
  - seller's coin balance : 0
- After Transfer
  - buyer's coin balance: 300
  - seller's coin balance : 100
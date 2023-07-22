# A Simple Counter Dapp (written in move for aptos)

This is a sample dapp where each user has a unique counter. each time the user bump the contract, the counter associated with the user's address increases by 1.

# Command lines
```shell
# initialize aptos profile
aptos init --profile default

# compile contract
aptos move compile --named-addresses publisher=default

# request aptos token from faucet
aptos account fund-with-faucet --account default

# pubish contract to the blockchain
aptos move publish --named-addresses publisher=default

# run bump function in contract
aptos move run --function-id "default::counter::bump"
```
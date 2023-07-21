# How to deploy an AMM

deploy init module

```
aptos move publish --package-dir init
```

precompute resource account address, then use the address as `lp` in lp/Move.toml

```
aptos move test --package-dir init
```

create the resource account and it will hold lp_coin resource

```
aptos move compile --package-dir lp --save-metadata
hexdump -ve '1/1 "%02x"' lp/build/lp/package-metadata.bcs # 1st arg
hexdump -ve '1/1 "%02x"' lp/build/lp/bytecode_modules/lp_coin.mv # 2nd arg

aptos move run --function-id <init address>::lp_account::initialize_lp_account --args hex:<1st arg> hex:<2nd arg>
```

deploy swap module

```
aptos move publish --package-dir swap
```

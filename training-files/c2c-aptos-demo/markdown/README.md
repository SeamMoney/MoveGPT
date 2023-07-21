# C2C Aptos Demo

## Install Aptos CLI

```bash
RUSTFLAGS="--cfg tokio_unstable" cargo install --git https://github.com/aptos-labs/aptos-core.git --branch devnet aptos
cargo install --git https://github.com/move-language/move move-analyzer —features “address32”
```

## Publish packages

```bash
cd callee
aptos init
aptos move publish
```

```
cd caller
aptos init
aptos move publish --named-addresses caller=default
```

## Call function

```bash
cd caller
aptos move run --function-id 'default::message_board::set_message' --args 'string:hello, blockchain'
```
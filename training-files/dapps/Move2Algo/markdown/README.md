# aptos-test
Testing Move language on Aptos Blockchain

## Example CLI commands 
Make sure you have correctly **configured** aptos CLI to work in Devnet.

### Compile
In order to compile you need either a local .aptos folder in the repository root OR a .aptos folder in your home directory.
```
aptos move compile --named-addresses deploy_address=default
```

### Publish
```
aptos move publish  --assume-yes --named-addresses deploy_address=default
```

### Run move_fib entry function
This command runs the ```move_fib``` function inside ```fibonacci``` module.
```
aptos move run --function-id 0xf77304f0b8426e09de5799104bfbc0a0efbbdaef95b5c172fb93522a19d5ee9e::fibonacci::move_fib --args u64:6 --assume-yes
```

### Run set_val entry function
This command runs the ```set_val``` function inside ```test``` module.
```
aptos move run --function-id 0x221e04878647f87928e83d1a0f0ec826a40364527027dca5a940d6ae95e8fdf1::set_val::set_val --args u64:6 --assume-yes
```
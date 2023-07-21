## 1. Create aptos keypair
```
aptos init
```
## 2. Copy account address from .aptos/config.yaml to address in Move.toml
```
profiles:
  default:
    private_key: "0xfd666917effab8640f13be3a2549ee0e7064004c904f133819180d9096efa6c0"
    public_key: "0x250cfa1714a8bdde74890c4e57a2de68ed436385a141e30a000443fe304f2299"
    account: cbbda9b62c585b850de1e283f5ef8541f119a1ad50fa469c6b7b63363afb2129
    rest_url: "https://fullnode.devnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.devnet.aptoslabs.com/"
```
> copy `cbbda9b62c585b850de1e283f5ef8541f119a1ad50fa469c6b7b63363afb2129` to `MultiSender` part in `Move.toml`
```
[addresses]
AptosFramework = "0x1"
MultiSender = "cbbda9b62c585b850de1e283f5ef8541f119a1ad50fa469c6b7b63363afb2129"
```

## 3. On devnet and testnet, we use faucet
> copy address from .aptos/config.yaml to package.json -> scripts/
faucet address and Move.toml
```
yarn faucet
```

## 4. yarn compile to build Move file, yarn pubmod to publish(deploy) the move module
```
yarn compile
yarn pubmod
```

## 5. You can change the network by modifying rest_url and faucet_url in config.yaml
    rest_url: "https://fullnode.testnet.aptoslabs.com/v1"
    faucet_url: "https://faucet.testnet.aptoslabs.com/"

## 6. To create a coin, you can follow this example
https://aptos.dev/tutorials/your-first-coin
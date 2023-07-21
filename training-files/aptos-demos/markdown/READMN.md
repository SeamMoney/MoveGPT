1. 编译
   aptos-bulletproof move compile --named-addresses veiled_coin=local --save-metadata

2. test
   aptos-bulletproof move test --named-addresses veiled_coin=local

3. 发布
   aptos-bulletproof move publish --profile local --named-addresses veiled_coin=local

4. mint

reister

```bash
# 要使用硬币，实体必须 CoinStore 在其帐户上为其注册：
aptos-bulletproof move run \
  --function-id '0x1::managed_coin::register' \
  --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
  --profile local --sender-account local

# 给 local mint 100 个 MoonCoin
aptos move run \
 --function-id '0x1::managed_coin::mint' \
 --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
 --args 'address:0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8' 'u64:100' \
 --profile local --sender-account local
```

```bash
# register
aptos-bulletproof move run \
  --function-id 'local::veiled_coin::register' \
  --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
  --profile local --sender-account local

aptos-bulletproof move run \
  --function-id 'local::veiled_coin::mint' \
  --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
  --profile local --sender-account local --args 'u64:100'
```

```bash
# bob register
aptos-bulletproof move run \
  --function-id 'local::veiled_coin::register' \
  --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
  --profile bob --sender-account bob

# local 将钱转 50 给bob
aptos-bulletproof move run \
  --function-id 'local::veiled_coin::mint_to' \
  --type-args '0x5297b2ac7168b32f5080b7c2e0bb8556a58668bfa2c0cc0c50e6bdb3654fb3a8::moon_coin::MoonCoin' \
  --profile local --sender-account local --args 'address:0x15aca3407c6885d1367c212a8e1fe9c05ad4dced3a3e410897911464b03388ef' 'u64:50'
```

5. mint

```bash
aptos move run \
  --function-id '0x1::managed_coin::mint' \
  --type-args '0x780c1311fdce701e32c71eba887c9c74585c4e62637d6fbe3bba89df8365014c::moon_coin::MoonCoin' \
  --sender-account default --args 'address:0x3747967d9963f0b72bb5b4af39c6e196d4f4566c5d08107b78f7ea78f3b471ab' 'u64:50'
```

6. burn
   只有 default 才可以 burn

```bash
aptos move run \
  --function-id '0x1::managed_coin::burn' \
  --type-args '0x780c1311fdce701e32c71eba887c9c74585c4e62637d6fbe3bba89df8365014c::moon_coin::MoonCoin' \
  --sender-account default --args 'u64:50'
```

7. 查看 moon_coin 余额
   https://fullnode.devnet.aptoslabs.com/v1/accounts/${account}/resource/0x1::coin::CoinStore<${account}::moon_coin::MoonCoin>

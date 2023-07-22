# aptos-move
1. 安装aptos CLI
```
brew install aptos
```

2. 创建项目
```
aptos move init --name aptos-move

创建完后会account写入到move.toml文件
```

3. 初始化项目,关联account
```
cd aptos-move
aptos init

生成.aptos/config.yaml文件，包含account公私钥等信息
```

4. 编译合约
```
aptos move compile
```

5. 测试合约
```
aptos move test
```

6. 获取测试币
```
aptos account fund-with-faucet  --account 地址(不包含0x)

aptos account fund-with-faucet  --account a39ed74050b15875a66750fb20a8279ccc721b1f5a2829bf9ed840f960757d05
```                  

7. 发布合约
```
aptos move publish

发布完合约以后，合约地址就是部署合约的account地址
```

8. 执行合约交易
```
aptos move run \
    --function-id default::message::set_message \
    --args string:'Hello, Aptos-Move'
```

# 区块链浏览器(devnet)
1. https://explorer.aptoslabs.com/
2. 输入account地址，查看合约状态

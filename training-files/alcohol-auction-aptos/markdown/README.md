# Alcohol auction

## Prerequisites

[Prepare your Aptos Dev Environment](https://aptos.dev/guides/getting-started/)

## Running tests

```sh
aptos move test --named-addresses alcohol_auction=0xff,source_addr=0xab
```

You can use any addresses instead of 0xff and 0xab.

If you also want to see test coverage, use the following command:

```sh
aptos move test --named-addresses alcohol_auction=0xff,source_addr=0xab --coverage
```

## Deploying contracts

Before running the following command, you should run the `aptos init --profile default` command and follow the instructions.

```sh
aptos move create-resource-account-and-publish-package --seed 0 --address-name alcohol_auction --named-addresses source_addr=default
```

## License

[Apriorit](http://www.apriorit.com/) released [alcohol-auction-aptos](https://github.com/apriorit/alcohol-auction-aptos) under the OSI-approved 3-clause BSD license. You can freely use it in your commercial or opensource software.

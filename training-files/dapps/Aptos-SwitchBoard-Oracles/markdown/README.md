<div align="center">


  <h1>Switchboard Oracles in Move language</h1>
  <p>An example contract reading the price of aptos in USD using a Switchboard Aptos Test net Oracle </p>
</div>

## Usage

To create one account (default) by running following command and select "testnet".

```bash
aptos init
```


TO Compile Code

```bash
aptos move compile --named-addresses switchboard_feed_parser=default
```

To deploy contracts
```bash
aptos move publish --named-addresses switchboard_feed_parser=default
```

To run oracle function 
Note: to call the below 2 functions we need feed address.You can find feed addresses from below link (select aptos testnet for testnet oracles).
https://switchboard.xyz/explorer
```bash
aptos move run --function-id switchboard_feed_parser::switchboard_feed_parser::log_aggregator_info --args address:[FEED_ADDRESS]
```
To get latest value of oracle price feed
```bash
aptos move run --function-id [Wallet address]::switchboard_feed_parser::get_latest_price --args address:[FEED_ADDRESS]
```



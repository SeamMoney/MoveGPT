# use-oracle-v3

```bash
 yarn ts-node:testnet src/log_feeds_from_switchboard.ts
 ADDR=...
 yarn ts-node:testnet src/log_feeds.ts current ${ADDR} > testnet_${ADDR}_current_`date +%Y%m%d%H%M%S`.log
 yarn ts-node:testnet src/generate_feed.ts
 ```
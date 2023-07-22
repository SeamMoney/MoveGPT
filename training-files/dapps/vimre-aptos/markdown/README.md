# Run script

```
aptos move compile
aptos move run-script --private-key $PK \
    --compiled-script-path $(pwd)/build/CreateToken/bytecode_scripts/create_tokens.mv \
    --assume-yes
```

# List

```
MODULE=$ADDR::marketplace
MARKET=$ADDR
CREATOR=$ADDR
COLLECTION_NAME="Vietnamese Metaverse Real Estate"
TOKEN_NAME="ViMRE #3"
PROPERTY=0
AMOUNT=1
PRICE=12000000
COIN="0x1::aptos_coin::AptosCoin"

aptos move run \
    --function-id $MODULE::list_token \
    --args address:$MARKET address:$CREATOR string:"$COLLECTION_NAME" string:"$TOKEN_NAME" u64:$PROPERTY u64:$AMOUNT u64:$PRICE \
    --type-args $COIN \
    --private-key $PK \
    --assume-yes
```
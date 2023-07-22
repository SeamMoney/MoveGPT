# Aptos Breeding Contract

This repository contains the customizable NFT breeding contract.
The `breeding` module lets users breed NFTs from any desired collection.
Parent NFTs should belong to the same collection.
Any number of parent NFTs can be used to breed one NFT.
It assumes that the metadata of children's NFTs (the ones that are bred from the parents) are generated based on parents' metadata. We leave the possibility to customize this feature by leaving empty arrays.
Each NFT has a breed locking period, meaning it cannot breed repeatedly but the user has to wait a set amount of time before using again the same NFTs to breed. 

### Future improvement ideas
1. Metadata generation logic:
  Currently, it assumes that metadata will be based on parents'.
  - If the parent's metadata is not important, it's possible to generate children's pre-mint and then select a random one among them.
  - Another way is to generate based on the parent's metadata and add some probability.
  - Or it's possible to make children NFTS as intermediaries like eggs or somewhat unrevealed ones, then prepare metadata on the admin side, then update metadata or let users mint a new collection based on it.
2. Add more test cases:
  There are some cases to cover in the unit test, but irrelevant before finalizing the desired logic.

## How to test
```shell
aptos move test
```
## How to interact with module
There are three kinds of address: `admin`, `creator`, `user`.
`admin` is the admin of the module.
`creator` is the creator of nft.
`user` is someone who wants breed new nfts from there own ones.
- Deploy
  ```shell
  aptos move publish \
    --named-addresses aptos_breeding_contract=$admin \
    --profile admin 
  ```
- Set
  ```shell
  aptos move run \    
    --function-id $admin::breeding::set_collection_config_and_create_collection \
    --args \
    address:$creator \
    string:$parent_collection_name \
    string:$collection_name \                    
    string:$collection_uri \
    u64:$collection_maximum \            
    string:$collection_description \
    string:$token_base_name \
    'vector<bool>:false,false,false' \
    address:$admin \
    string:$token_description \
    u64:$token_maximum \
    'vector<bool>:false,false,false,false,false' \
    u64:$royalty_points_den \
    u64:$royalty_points_num \
    u64:$breed_lock_period \
    --profile admin
  ```
- Breed
  ```shell
  aptos move run \                          
    --function-id $admin::breeding::breed \                                      
    --args \          
    address:$creator \
    string:$parent_collection_name \
    'vector<string>:$token_names_separated_by_commas' \
    'vector<string>:$property_keys_separated_by_commas' \           
    'vector<string>:$property_types_separated_by_commas' \
    'vector<u64>:$property_versions_separated_by_commas' \        
    --profile user     
  ```
  
## Auxiliary 
This repo provides simple scripts for minting NFTs.
```shell
yarn simple_nft
```
It will create one collection and two tokens and transfer them to `user`.
It requires setting .env with private keys and addresses of `creator` and `user`

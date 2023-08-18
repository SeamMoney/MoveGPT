```rust
module realm::Treasury{

    use std::string::String;
    // use std::account::{create_resource_account,SignerCapability};
    friend realm::Realm;

    struct Treasury<CoinType> has store{
        realm:address,
        fundraise_count:u64,
        name:String,
        coin:CoinType,
        has_active_fundraise:bool,
        // signer_cap:SignerCapability
    }

    // fun create_treasury<CoinType>(realm_authority:signer,realm_address:address,treasury_signer:&signer){
    //     let (treasury_resource,treasury_signer_cap)=create_resource_account(treasury_signer,b"treasury");
      
    // }

}
```
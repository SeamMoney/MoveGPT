```rust


// Mint a dynamic NFT.
module rangers::mint_dynamic_nft {
    use aptos_token::token;
    use aptos_framework::account::{Self, SignerCapability};
    use std::string::{Self, String};
    use std::signer;
    use std::vector;
    use rangers::base64;

    struct ResourceSigner has key {
        cap: SignerCapability
    }

    struct MintingInfo has key {
        index: u64,
        base_name: String,
        collection_name: String,
    }

    fun init_module(account: &signer) {
        assert_admin(account);
        let (_, cap) = account::create_resource_account(account, b"SEED_DYNAMIC");
        move_to(account, ResourceSigner { cap: cap });
    }

    fun resource_account(): (signer, address) acquires ResourceSigner {
        let resource = borrow_global<ResourceSigner>(@rangers);
        (account::create_signer_with_capability(&resource.cap), account::get_signer_capability_address(&resource.cap))
    }

    fun assert_admin(a: &signer) {
        assert!(signer::address_of(a) == @rangers, 0);
    }

    public fun to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    public fun generate_base64_image(i: u64): String {
        let image = string::utf8(b"<svg height=\"600\" width=\"400\" fill=\"black\" viewBox=\"0 0 400 600\" xmlns=\"http://www.w3.org/2000/svg\"><style>svg {background: black;} .small {fill: white;}</style><text x=\"10\" y=\"40\" class=\"small\">Dynaimic NFT #");
        string::append(&mut image, to_string(i));
        string::append(&mut image, string::utf8(b"</text></svg>"));
        
        let encoded = string::utf8(b"data:image/svg+xml;base64,");
        string::append(&mut encoded, base64::encode_string(image));
        encoded
    }

    public fun generate_base64_metadata(img: String, i: u64): String {
        let metadata = string::utf8(b"{\"name\": \"Test Dynamic NFT #");
        string::append(&mut metadata, to_string(i));
        string::append(&mut metadata, string::utf8(b"\", \"description\": \"Testing dynamic NFTs.\", \"image\": \""));
        string::append(&mut metadata, img);
        string::append(&mut metadata, string::utf8(b"\"}"));
        
        let encoded = string::utf8(b"data:application/json;base64,");
        string::append(&mut encoded, base64::encode_string(metadata));
        encoded
    }

    public entry fun create_collection(account: &signer) acquires ResourceSigner {
        assert_admin(account);
        let (resource, _) = resource_account();
        token::create_collection(
            &resource,
            string::utf8(b"Test Dynamic NFT"),
            string::utf8(b"Testing dynamic NFTs."),
            string::utf8(b"https://vivek.ink"),
            1000,
            vector<bool>[false, false, false]
        );
        
        move_to(account, MintingInfo {
            index: 1,
            base_name: string::utf8(b"Test NFT #"),
            collection_name: string::utf8(b"Test Dynamic NFT"),
        });
    }

    public entry fun mint_nft(_account: &signer) acquires ResourceSigner, MintingInfo {
        let (_resource, _resource_addr) = resource_account();
        let minting_info = borrow_global_mut<MintingInfo>(@rangers);

        let name = string::utf8(b"");
        string::append(&mut name, minting_info.base_name);
        string::append(&mut name, to_string(minting_info.index));
        let img = generate_base64_image(minting_info.index);
        let uri = generate_base64_metadata(img, minting_info.index);
        std::debug::print(&uri);

        minting_info.index = minting_info.index + 1;

        // let token_mut_config = token::create_token_mutability_config(&vector<bool>[false, false, false, false, false]);
        // let tokendata_id = token::create_tokendata(
        //     &resource,
        //     minting_info.collection_name,
        //     name,
        //     string::utf8(b"This is some bullshit description."),
        //     1,
        //     uri,
        // );

        // token::mint_script(&resource, resource_addr, minting_info.collection_name, name, 1);
    }

    #[test]
    public fun test() {
        let img = generate_base64_image(1);
        let uri = generate_base64_metadata(img, 1);
        std::debug::print(&uri);
    }




}
```
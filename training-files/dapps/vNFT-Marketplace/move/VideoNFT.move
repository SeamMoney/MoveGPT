// module NamedAddr:: NFT6 {

//     // use std::error;
//     use std::signer;
//     use std::vector;
//     use std::string;
//     // use aptos_framework::account;
//     // use aptos_framework::event;

//     const EALREADY_Registered: u64 = 0;
    
//     struct VideoNft has store{
//         id : string::String,
//         name: string::String,
//         creater : address
//     }

//     struct ChingariGallery has key {
//         videoNFT : vector<VideoNft>
//     }

//     public fun init_gallery(account: &signer) {
//         assert!(!exists<ChingariGallery>(signer::address_of(account)), EALREADY_Registered);
//         let nft = vector::empty<VideoNft>();
//         move_to<ChingariGallery>(account, ChingariGallery { videoNFT: nft })
//     }

//     public entry fun create_nft(account: signer, id: string::String, name: string::String) acquires ChingariGallery {
//         let minter = signer::address_of(&account);
//         let nft = VideoNft{ id: id, name: name, creater: minter};
//         let gallery = borrow_global_mut<ChingariGallery>(minter);
//         vector::push_back(&mut gallery.videoNFT, nft);
//     }
// }
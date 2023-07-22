module coin_objects::mirny_token {
        use std::string;
        use std::option;
        use std::signer;
        use coin_objects::token;
        use aptos_framework::object::{Self, CreatorRef, ObjectId};
    

        public fun mint_to(account: &signer, to: address) {
            let collection = string::utf8(b"Mirny NFT Collection");
            let description = string::utf8(b"Mirny NFT Collection for Aptos Seoul Hackathon");
            let mutability_config = token::create_mutability_config(true, true, true);
            let name = string::utf8(b"Mirny NFT #1");
            let uri = string::utf8(b"https://aptosfoundation.org/assets/logomark/PNG/Aptos_mark_BLK-909b80e008685d22df54870ca38313008c2c15f0.png");

            let token_object_creator_ref = token::create_token(
                account,
                collection,
                description,
                mutability_config,
                name,
                option::none(),
                uri,
            );
            let token_object_signer = object::generate_signer(&token_object_creator_ref);
            let token_object_id = object::address_to_object_id(signer::address_of(&token_object_signer));

            object::transfer(
                account,
                token_object_id,
                to
            );
        }
}
script {
    use std::signer;
    use aptos_token::token;
    use std::string::{Self, String};
    use std::bcs;

    const COLLECTION_NAME : vector<u8> = b"Vietnamese Metaverse Real Estate";
    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";
    const TOKEN_METADATA: vector<u8> = b"TOKEN_METADATA";

    fun create_tokens(
        creator: &signer
    ) {
        let mutate_setting = vector<bool>[true, true, true, true, true];
        let token_mut_config = token::create_token_mutability_config(&mutate_setting);
        let creator_addr = signer::address_of(creator);
        let metadata = string::utf8(b"https://vimre.s3.ap-southeast-1.amazonaws.com/metadata/vimre_token_3.json");

        let tokendata_id = token::create_tokendata(
            creator,
            string::utf8(COLLECTION_NAME),
            string::utf8(b"ViMRE #3"),
            string::utf8(b"Token: ViMRE #3"),
            0,
            string::utf8(b"https://vimre.s3.ap-southeast-1.amazonaws.com/images/vimre_token_3.gif"),
            creator_addr,
            100,
            2,
            token_mut_config,
            vector<String>[string::utf8(BURNABLE_BY_CREATOR), string::utf8(TOKEN_METADATA)], // keys
            vector<vector<u8>>[bcs::to_bytes<bool>(&true), bcs::to_bytes<String>(&metadata)], // values
            vector<String>[string::utf8(b"bool"), string::utf8(b"0x1::string::String")] // types
        );

        token::mint_token(
            creator,
            tokendata_id,
            1,
        );
    }
}

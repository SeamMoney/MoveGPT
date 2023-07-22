
script {
    use aptos_token::token;
    use std::string;

    const COLLECTION_NAME : vector<u8> = b"Vietnamese Metaverse Real Estate";
    const COLLECTION_DESC : vector<u8> = b"Collection: ViMRE";
    const COLLECTION_URL : vector<u8> = b"https://vimre.s3.ap-southeast-1.amazonaws.com/images/vimre_collection.gif";

    fun create_collection(
        creator: &signer
    ) {
        token::create_collection(
            creator, 
            string::utf8(COLLECTION_NAME), 
            string::utf8(COLLECTION_DESC), 
            string::utf8(COLLECTION_URL), 
            0, 
            vector<bool>[true, true, true]
        );
    }
}

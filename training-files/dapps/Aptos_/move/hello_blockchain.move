// A simple smart contract to store and retrieve metadata URIs

// Define a struct to represent a metadata URI
struct MetadataURI {
    address: address,
    uri: vector<u8>,
}

// Define the storage for our contract
// This will store a mapping of address to MetadataURI
// where address is the address of the sender and MetadataURI is the metadata URI they want to store
// We use vector<u8> to store the URI
// This can be replaced with other types such as string if desired
resource struct MetadataStorage {
    metadata: vector<MetadataURI>,
}

// Define a function to allow users to store their metadata URI
// This function takes a vector<u8> as input representing the URI
// The function stores the metadata URI in the contract's storage
public fun store_metadata_uri(metadata_uri: vector<u8>): void {
    // Get the address of the sender
    let sender: address = get_txn_sender();
    // Get a reference to the contract's storage
    let metadata_storage_ref: &mut MetadataStorage;
    metadata_storage_ref = move_from(metadata_storage_resource_path<Mint>());
    // Create a MetadataURI struct representing the sender's address and their metadata URI
    let metadata_uri_struct = MetadataURI {
        address: sender,
        uri: metadata_uri,
    };
    // Append the MetadataURI struct to the metadata vector in the contract's storage
    metadata_storage_ref.metadata.push(metadata_uri_struct);
}

// Define a function to allow users to retrieve their stored metadata URI
// This function takes no input
// The function returns the metadata URI stored by the sender
public fun get_metadata_uri(): vector<u8> {
    // Get the address of the sender
    let sender: address = get_txn_sender();
    // Get a reference to the contract's storage
    let metadata_storage_ref: &MetadataStorage;
    metadata_storage_ref = borrow_global_mut(metadata_storage_resource_path<Mint>()) as &mut MetadataStorage;
    // Loop through the metadata vector in the contract's storage
    // Find the MetadataURI struct with the sender's address and return its URI
    for metadata_uri in metadata_storage_ref.metadata {
        if metadata_uri.address == sender {
            return metadata_uri.uri;
        }
    }
    // If the sender's metadata URI is not found, return an empty vector
    return vector<u8>(0);
}

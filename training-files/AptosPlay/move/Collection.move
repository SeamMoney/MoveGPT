module Viper::Collection {
    use 0x1::Vector;
    use 0x1::Signer;

    struct Item has store, drop { }

    // define resources
    struct Collection has key, store {
        items: vector<Item>,
    }

    // create move
    public fun make_collection(account: &signer) {
       // set collection to account
        move_to<Collection>(account, Collection{
            items: Vector::empty<Item>()
        })
    }

    // check exist
    public fun exists_at(addr: address): bool {
        exists<Collection>(addr)
    }

    // update resource
    // need "acquires resources_name" if u use borrow_global_mut function 
    public fun add_item(account: &signer) acquires Collection {
        let addr = Signer::address_of(account);
        let collection = borrow_global_mut<Collection>(addr);
        // add new item to collection items
        Vector::push_back(&mut collection.items, Item{});

    }

    public fun size(account: &signer): u64 acquires Collection {
        let addr = Signer::address_of(account);
        let collection = borrow_global<Collection>(addr);
        // Note : implicit return can not has ";"
        Vector::length(&collection.items)
    }

    // xiaohu
    public fun destroy(account: &signer) acquires Collection {
        let addr = Signer::address_of(account);
        let collection = move_from<Collection>(addr);
        let Collection{ items: _ } = collection;
    }

}
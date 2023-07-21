script {
    use 0x1::Debug;
    use Viper::Collection;
    use 0x1::Signer;

    fun test_resourses(account: signer) {
        let addr = Signer::address_of(&account);
        // let addr = @0x41; 
        let exist = Collection::exists_at(addr);
        Debug::print(&exist);
        if (exist) {
            Collection::destroy(&account);
        };
        Collection::make_collection(&account);
        exist = Collection::exists_at(addr);
        Debug::print(&exist);

        Collection::add_item(&account);
        let lsize = Collection::size(&account);
        Debug::print(&lsize);



    }

}
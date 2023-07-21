module counter::count{


    use std::signer;

    struct Counter has key{
        counter:u8
    }

   entry fun init_module(account:&signer) acquires Counter{
        let counter:u8= 0;
        let account_addr= signer::address_of(account);
        if(!exists<Counter>(account_addr)){
            move_to(account,Counter{
                counter,
            })

        }else{
            let old_counter= borrow_global_mut<Counter>(account_addr);
            old_counter.counter=0;
        }
    }

    public fun get_counter(account:&signer):u8 acquires Counter{
        let account_addr= signer::address_of(account);
        let counter= borrow_global_mut<Counter>(account_addr);
        counter.counter
    }

    public entry fun plus_counter(account:&signer) acquires Counter{
        let account_addr= signer::address_of(account);
        let counter= borrow_global_mut<Counter>(account_addr);
        counter.counter= counter.counter+1
    }

}
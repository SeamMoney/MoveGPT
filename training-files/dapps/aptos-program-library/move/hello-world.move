module hello_world::message {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::account;

    //:!:>resource
    struct MessageHolder has key {
        message: string::String,
    }

    /// There is no message present
    const ENO_MESSAGE: u64 = 0;


    public fun get_message(addr: address): string::String acquires MessageHolder {
        assert!(exists<MessageHolder>(addr), error::not_found(ENO_MESSAGE));
        *&borrow_global<MessageHolder>(addr).message
    }

    public entry fun set_message(account: signer, message: string::String) acquires MessageHolder {
        let account_addr = signer::address_of(&account);
        if (!exists<MessageHolder>(account_addr)) {
            move_to(&account, MessageHolder { message })
        } else {
            let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);

            old_message_holder.message = message;
        }
    }

}
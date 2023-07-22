module caller::message_board {
    use std::string::String;
    use callee::message;

    public entry fun set_message(account: signer, message: String) {
        message::set_message(account, message);
    }
}
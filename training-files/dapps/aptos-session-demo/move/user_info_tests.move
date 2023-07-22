#[test_only]
module sender::user_info_tests {
    use std::string::utf8;
    use std::signer;

    use sender::user_info;

    // this named parameter to the test attribute allows to provide a signer to the test function,
    // it should be named the same way as parameter of the function
    #[test(user_account = @0x42)]
    public entry fun test_getter_setter(user_account: signer) {
        let username = b"MyUser";
        user_info::set_username(&user_account, username);

        let user_addr = signer::address_of(&user_account);
        // assert! macro for asserts, needs an expression and a failure error code
        assert!(user_info::get_username(user_addr) == utf8(username), 1);
    }
}

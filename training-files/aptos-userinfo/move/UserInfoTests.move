#[test_only]
module Sender::UserInfoTests {

    use std::string::utf8;
    use std::signer;

    use Sender::UserInfo;

    #[test(user_account = @0x42)]
    public entry fun test_getter_setter(user_account: signer) {
        let username = b"MyUser";
        UserInfo::set_username(&user_account, username);

        let user_addr = signer::address_of(&user_account);
        assert!(UserInfo::get_username(user_addr) == utf8(username), 1);
    }
}
#[test_only]
module satay::setup_tests {

    use aptos_framework::stake;

    use satay::satay_account;
    use satay::satay;
    use aptos_framework::aptos_coin;
    use aptos_framework::account;
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    public fun setup_aptos(
        aptos_framework: &signer
    ) {
        stake::initialize_for_test(aptos_framework);
    }

    public fun setup_satay(satay: &signer) {
        let satay_coins_metadata_serialized = x"0a5361746179436f696e73020000000000000000403241383933453237324133313136324437393735414641464239344439333132453041413143323532424139353946393543323536453939343342373946434196021f8b08000000000002ff2d50bd6e833010defd14114ba6800163a052a7ce9d32465174679f132b80916d68f3f6b5db6ef7dd7d7fbacb0aea0977bab205663abc1f8e6788f0fa70760947b6930fd62d795d97bce447b6ad770f9a6eab9bac7aa54361e7798b8013158c5d406b4f2150b8b2907d6e2a1b651affeeb88151486839081c00476ca5a4bad502a996ad018d8d31bcefc4d0b4d874c2d4ed28fb5e0d409cab2efb6bda4f9a565a342dca52283fdd4ee7a8278b5776b731273d625cc35b5525f8d8b0546eae608d2e9c26c0f03f2ae7a94c848279dab348773d8e3da624940265dd0f7234a94e23a9172375bc1dc4300859b0b0a1b63e6bfeace6d4a0323e7defcbf96795e129fc362a7e00444fcab75d010000020d73747261746567795f636f696ec4011f8b08000000000002ff4d8f410ac3201045f79e620e50c85e4a17ed115aba0d539d26a14946742c48c8ddab62a0e2c6f1fff7ff745d0723cf36808c04417c3402319085377bb88b47a121dd785a21dfaa41c1040ecd0707525df65b7233a76c79a5aaf014387a4380c6705c058ca78cb18550dd5a7f31ced29b8ced9b482d6ce3dcf0f527681d5a7e7dc3a6209f9258529e05518b0db4929f4c6b5f456d91fffe6737e22abcc0150395c1098ec9217b24471aac6777816d57bbfa012fb975701e01000000000a7661756c745f636f696eaf011f8b08000000000002ff4d8f310ec2300c45f79cc237c88e1003307002d6cab8a6ad48e32a7190aaaa77278922c0f2643fffff6dad859bb83e828e0c5143228514b987a704b863727a91c943ee0aa0e20a0bd20b0736361f5f7971b266feb156227094148801892479050a8c9af759a15e1f0eefa2da5196ed1a6466e9936bf27513ff31d80ce42a76c5e2976a60cf61a296bb42ed852f735c46f42a339c3172199c60dbcd6e3e1cb58cd7f900000000000000";
        let satay_coins_code = vector[
            x"a11ceb0b0500000005010002020208070a270831200a5105000000010002000102010d73747261746567795f636f696e0c5374726174656779436f696e0b64756d6d795f6669656c6450fa946a30a4b8ab9b366e13d4be163fadb2ff0754823b254f139677c8ae00c5000201020100",
            x"a11ceb0b05000000050100020202060708210829200a490500000001000100010a7661756c745f636f696e095661756c74436f696e0b64756d6d795f6669656c6450fa946a30a4b8ab9b366e13d4be163fadb2ff0754823b254f139677c8ae00c5000201020100"
        ];

        satay_account::initialize_satay_account(
            satay,
            satay_coins_metadata_serialized,
            satay_coins_code,
        );
        satay::initialize(satay);
    }

    public fun setup_tests(aptos_framework: &signer, satay: &signer) {
        setup_aptos(aptos_framework);
        setup_satay(satay);
    }

    public fun setup_user(aptos_framework: &signer, user: &signer, mint_amount: u64) {
        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        coin::register<AptosCoin>(user);
        aptos_coin::mint(aptos_framework, user_addr, mint_amount)
    }

    public fun setup_tests_with_user(aptos_framework: &signer, satay: &signer, user: &signer, mint_amount: u64) {
        setup_tests(aptos_framework, satay);
        setup_user(aptos_framework, user, mint_amount);
    }
}

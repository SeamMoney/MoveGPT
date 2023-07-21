#[test_only]
module starcoin_utils::starcoin_verifier_tests {
    use starcoin_utils::starcoin_address;
    use starcoin_utils::starcoin_event;
    use starcoin_utils::starcoin_verifier;
    use std::vector;

    #[test]
    fun test_create_literal_hash() {
        let word = b"SPARSE_MERKLE_PLACEHOLDER_HASH";
        let r = starcoin_verifier::create_literal_hash(&word);
        assert!(r == x"5350415253455f4d45524b4c455f504c414345484f4c4445525f484153480000", 111);
    }


    #[test]
    fun test_verify_resource_state_proof() {
        let state_root = x"99163c0fc319b62c3897ada8f97881e396e33b30383f47e23d93aaed07d6806d";
        let account_address = x"8c109349c6bd91411d6bc962e080c4a3";//@0x8c109349c6bd91411d6bc962e080c4a3;
        let state = x"";
        let resource_struct_tag = x"8c109349c6bd91411d6bc962e080c4a312546f6b656e537761704661726d426f6f73740855736572496e666f020700000000000000000000000000000001035354430353544300078c109349c6bd91411d6bc962e080c4a30453544152045354415200";

        let account_proof_side_nodes = vector::empty<vector<u8>>();
        vector::push_back(&mut account_proof_side_nodes, x"08525e1e7220b4a64f3fd89fc931b0beff7490607b0716faddf3bc942747386e");
        vector::push_back(&mut account_proof_side_nodes, x"5cc7a4f20b31bddd3294b1e314fbf6bb791953ac6444d8a0ac4e5e7c6480812e");
        vector::push_back(&mut account_proof_side_nodes, x"280cbb1fd1f796242ebea71068c798ef4a7a5b1da07f9422e288b746f67c1e06");
        vector::push_back(&mut account_proof_side_nodes, x"159bdffefc930493129b8897e202bfcf17d7d3c74aa47d1d5b6c2f896b0d98f4");
        vector::push_back(&mut account_proof_side_nodes, x"de769cbc998a1b2c4367adb540c4a75db394e20c0eb9bb4d5c0087624102ee0d");
        vector::push_back(&mut account_proof_side_nodes, x"785f187c658ac42cb872ea7e18b88062b4870715414b6e3e872bf84d14d28d09");
        vector::push_back(&mut account_proof_side_nodes, x"ccb4c4d91cfccf082b1e66a469d8d9e8ee2b433b24f7afda0a955e40d32a6ca4");
        vector::push_back(&mut account_proof_side_nodes, x"b43df3454127a4a04542d6ba268e3a55bda95c4fb658627a2962744c05bc1349");
        vector::push_back(&mut account_proof_side_nodes, x"4a0f4d65ebfc745229afba2edb4c68e5073e6b87db310e955c60adbc9e00d65d");
        vector::push_back(&mut account_proof_side_nodes, x"7d91edf874ac7c8f7b65e95229e011e844c068cc1a0c81ea8b18cf1245793c21");
        vector::push_back(&mut account_proof_side_nodes, x"0e381be317564409496aa53d9d7a734884116d0073495a00378ebb201ed50fd1");
        vector::push_back(&mut account_proof_side_nodes, x"f6e248a05d4a69a606bfc8b7cd207948c9c3f574b46c01838cff1ffef9a05df3");
        vector::push_back(&mut account_proof_side_nodes, x"c45577b225f3a1eb7c04fbe64c9a07a330a32a6eca8754e8f4a95ec869610dc6");
        vector::push_back(&mut account_proof_side_nodes, x"f3e6cf306092cdbd478d2ff7153fbf688d5c3d1e3d62d2eab94eb1083c074306");

        let state_proof_side_nodes = vector::empty<vector<u8>>();
        vector::push_back(&mut state_proof_side_nodes, x"66d13f603dda1966f5da6cb1593f7beece2bed60447cfa3af6c8e554379af086");
        vector::push_back(&mut state_proof_side_nodes, x"5350415253455f4d45524b4c455f504c414345484f4c4445525f484153480000");
        vector::push_back(&mut state_proof_side_nodes, x"51294505d6efd9fbf1ab69acbab1f96affbb5a8d21ec0cb677749335ca0ca69b");
        vector::push_back(&mut state_proof_side_nodes, x"8624870eed10be3da5bd4c844d2e353b1fa669fac2def2dc50ef41f83f0b88a0");
        vector::push_back(&mut state_proof_side_nodes, x"ca94481b3ed045922fad7d8bf592af16c2c5c9253c79136ca3bed73ea3c23699");
        vector::push_back(&mut state_proof_side_nodes, x"6ac0af801ccb0a6ceb5c6ac82c7c20e29b9e2c69ee12bb4a3c5395e4400f4bfb");
        vector::push_back(&mut state_proof_side_nodes, x"4c2daa765e34f38cde5dcc20ea4b10264c10427ba1a02388077f33befb422677");
        vector::push_back(&mut state_proof_side_nodes, x"8d7893145f15bb8aeccf0424f267b6aeb807b20889f8498f5f15f4defe0f806f");

        let proof = starcoin_verifier::new_state_proof(
            starcoin_verifier::new_sparse_merkle_proof(
                account_proof_side_nodes,
                starcoin_verifier::new_smt_node(
                    x"5852858a6bd0e1607d7b0664fc35762466bbed4edfd80041b4318357f99abb73",
                    x"bbc50d7538140e5d721dffad1b799effe4393b552581400f07ec9e8aac2e506f",
                ),
            ),
            x"020120e3b097bd2d35e749599f5ab323dd8a1f9ad876a38a006b9f07068c3d662cc3d301206ceb24e0929653e882cb7dd3f4a4914a1e427f502c4f90c52ec6e591e1a2a94c",
            starcoin_verifier::new_sparse_merkle_proof(
                state_proof_side_nodes,
                starcoin_verifier::new_smt_node(
                    x"3173da2c06e9caf448ab60e9a475d0278c842810d611a25063b85f9cfd7605f8",
                    x"c6a66554c88f2e25c251a49f068574930681944e906f1c66fab1b7cfc42d9eb0",
                ),
            ),
        );
        //        _ = proof;
        //        _ = state_root;
        //        _ = account_address;
        //        _ = resource_struct_tag;
        //        _ = state;
        let b = starcoin_verifier::verify_resource_state_proof(
            &proof,
            &state_root,
            &starcoin_address::new_address(account_address),
            &resource_struct_tag,
            &state,
        );
        //debug::print(&b);
        assert!(b, 111);
    }

    #[test]
    fun test_verify_sm_proof_by_key_value() {
        let side_nodes = vector::empty<vector<u8>>();
        vector::push_back(&mut side_nodes, x"24521d9cbd1bb73959b54a3993159b125f1500221e1455490189466858725948");
        vector::push_back(&mut side_nodes, x"a5f028948c522a35e6a75775de25c097ffefee7d63c4949482e38df0428b3b6d");
        vector::push_back(&mut side_nodes, x"33c4f5958cb1a1875eb1be51d2601e13f5e5a4f5518d578d4c6368ac0af6d648");
        vector::push_back(&mut side_nodes, x"d9ff5eeb7dde4db48f44b79d54f7bb162b5a4ce32d583ee91431dea52d6fced1");
        vector::push_back(&mut side_nodes, x"a2dbe6355af9d9f00d84d2e944b97841de2221451887e0fadbc957dbe39d1a3e");
        vector::push_back(&mut side_nodes, x"3cc075bcc91302e92fb6a23880669085a0436a12e6e407aea6e7192344f41667");
        vector::push_back(&mut side_nodes, x"fc8d88d2484e154836aca3afd927fec8a8168667d24ceaf5e4d3c22722020609");

        let leaf_node = starcoin_verifier::new_smt_node(
            x"313fcf74be39e19d75b6d028d28cf3e43efd92e95abd580971b6552667e69ee0",
            x"e5c11e706a534b191358b9954c2f03c371162d950ff81a7cd3d20701bbaec525",
        );
        let expected_root = x"0f30a41872208c6324fa842889315b14f9be6f3dd0d5050686317adfdd0cda60";
        let key = x"8c109349c6bd91411d6bc962e080c4a312546f6b656e537761704661726d426f6f73740855736572496e666f020700000000000000000000000000000001035354430353544300078c109349c6bd91411d6bc962e080c4a30453544152045354415200";
        //
        // Above key is this StructTag BCS serialized bytes:
        //
        //    private StructTag getTestStructTag() {
        //        List<TypeTag> typeParams = new ArrayList<>();
        //        StructTag innerStructTag1 = new StructTag(AccountAddress.valueOf(HexUtils.hexToByteArray("0x00000000000000000000000000000001")),
        //                new Identifier("STC"), new Identifier("STC"), Collections.emptyList());
        //        StructTag innerStructTag2 = new StructTag(AccountAddress.valueOf(HexUtils.hexToByteArray("0x8c109349c6bd91411d6bc962e080c4a3")),
        //                new Identifier("STAR"), new Identifier("STAR"), Collections.emptyList());
        //        typeParams.add(new TypeTag.Struct(innerStructTag1));
        //        typeParams.add(new TypeTag.Struct(innerStructTag2));
        //        StructTag structTag = new StructTag(AccountAddress.valueOf(HexUtils.hexToByteArray("0x8c109349c6bd91411d6bc962e080c4a3")),
        //                new Identifier("TokenSwapFarmBoost"), new Identifier("UserInfo"), typeParams);
        //        return structTag;
        //    }
        let value = x"fa000000000000007b161ceeef010000000000000000000000000000000000000000000000000000";

        let b = starcoin_verifier::verify_sm_proof_by_key_value(&side_nodes, &leaf_node, &expected_root, &key, &value);
        //debug::print<bool>(&b);
        assert!(b, 111)
    }


    #[test]
    fun test_verify_sm_proof_by_key_value_2() {
        let side_nodes: vector<vector<u8>> = vector::empty();
        let leaf_data: starcoin_verifier::SMTNode = starcoin_verifier::empty_smt_node();
        let expected_root: vector<u8> = starcoin_verifier::placeholder();
        let key: vector<u8> = b"random key";
        let value: vector<u8> = vector::empty(); //x""
        let b = starcoin_verifier::verify_sm_proof_by_key_value(&side_nodes, &leaf_data, &expected_root, &key, &value);
        //Debug::print(&b);
        assert!(b, 111);

        value = b"random value";
        b = starcoin_verifier::verify_sm_proof_by_key_value(&side_nodes, &leaf_data, &expected_root, &key, &value);
        assert!(!b, 111);
    }


    #[test]
    fun test_bcs_deserialize_transaction_info() {
        let txn_data = x"20a3cac3fc94d4e68de66812b3bb638e82211c26ed0e879eb368196bd849eea86a206f9ff224f38492ac5b1d9369d17c93d2540d569b7b98b386e2d9e165f441628520229243707efa8c9c303e9325f758148dbc8b1e7ea3e96846cb2711dd1bf3a2626b6c0f000000000000";
        let txn_info = starcoin_verifier::bcs_deserialize_executed_transaction_info(&txn_data);
        //debug::print(&starcoin_verifier::get_transaction_info_event_root_hash(txn_info));
        let expected_hash = x"229243707efa8c9c303e9325f758148dbc8b1e7ea3e96846cb2711dd1bf3a262";
        //debug::print(&expected_hash);
        assert!(expected_hash == starcoin_verifier::get_transaction_info_event_root_hash(txn_info), 101);
        //debug::print(&starcoin_verifier::hash_transaction_info_bcs_bytes(txn_data));
        //let expected_txn_info_hash = x"aeb3fb4cd22b635a6a2947e027af41ef881d874fb7ddf289b1865d25c77ec13b";
        //assert!(expected_txn_info_hash == starcoin_verifier::hash_transaction_info_bcs_bytes(txn_data), 101)
    }


    #[test]
    fun test_verify_accumulator() {
        let siblings = vector::empty<vector<u8>>();
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"6eee994de6e916476aa77459d1fcd0719d9a6f36b3b8ae74e9cbad6d07065400");
        vector::push_back(&mut siblings, x"eab43f07f813200e3f810aea74a6af91532c17ed4ce4756a20adf33dbe183c2e");
        vector::push_back(&mut siblings, x"7f94b361c5027c06fafb03b57b1a1b8879c77e3eaf9bba0d896a33b4aeffa1a1");
        vector::push_back(&mut siblings, x"59ec68da7c6f9d7097d280ac1fab2ee18d91e0cfa5d64a4fbdb6c712e82c7bf2");
        vector::push_back(&mut siblings, x"1b47606d7b71ee665bd169855e0115296ccf9fdb2463f4fb2f9994e30b0476aa");
        vector::push_back(&mut siblings, x"ce1c3f9ea3a484f175254b7ae3009781e87218d46f24381dcd230ddcdff117e3");
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"86667ea18999fbcad72c7eda474c2212fa0effdaaa964205f803ad250e03abfe");
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"50d7486d96eb7a6f76a399a41fad052d2a64e1d0b6de37f34dec53bab06b9924");
        vector::push_back(&mut siblings, x"48583f70ae30de2bc4617a5eb95e17bb7436987e2fb04c8c6e3dedf185c87b7c");
        vector::push_back(&mut siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut siblings, x"0c2f667f50ca04d5d3547b81ae0a61fb7718f074db01bd6fe75559f4860f929a");
        vector::push_back(&mut siblings, x"479474a6b9f65dd8ebddeba92fef7e0e4f83639993adf88f9041cf188d6e4da3");
        vector::push_back(&mut siblings, x"f01372f8a7e518557ca8b3bc471397a3a0c33216e92934cf3653cb8b11c69c0a");
        vector::push_back(&mut siblings, x"095ce71d1dcd45d3381927d6d24d15b72ccf17a27342cc510fa54ade551ca27e");
        vector::push_back(&mut siblings, x"4871d81d292baa485e6aed64e1e04454f2103f153b26aa6839492765ddef060f");
        vector::push_back(&mut siblings, x"0bf9a0eaacd7db0d51ac57142a5a703f5b3f88c57725e0fc28196000b686310b");
        vector::push_back(&mut siblings, x"8079193f2a30402bd81970a0f79fbe752587ed215ec8ab1ba056d309a5015eca");
        vector::push_back(&mut siblings, x"b201b5e82b25765089b529c99c23c8851b5c2b43aa7ee803551a5231bc6594f8");
        let proof = starcoin_verifier::new_accumulator_proof(siblings);

        let expected_root = x"9e9dc633087fcdeec84f6306900c76298e6667b53a743e953dbb333c74994243";
        let hash = x"aeb3fb4cd22b635a6a2947e027af41ef881d874fb7ddf289b1865d25c77ec13b";
        let index = 8369404;

        let b = starcoin_verifier::verify_accumulator(&proof, &expected_root, &hash, index);
        assert!(b, 101)
    }

    fun test_verify_accumulator_2() {
        let siblings = vector::empty<vector<u8>>();
        vector::push_back(&mut siblings, x"e6f83b89b939d718d3d1ecbabcdb8cebf54d030015c252c8deda7f1a1ab9c43e");
        vector::push_back(&mut siblings, x"d97c6dfc606206f7a5f4b27ddf56f252a368cf81ab91bd51f7565f839b7bcefd");
        vector::push_back(&mut siblings, x"da7936f4309b7c79991d9bb7143bd2129735dd9343aafef06c0796740861eb49");
        let proof = starcoin_verifier::new_accumulator_proof(siblings);

        let expected_root = x"229243707efa8c9c303e9325f758148dbc8b1e7ea3e96846cb2711dd1bf3a262";
        let hash = x"a9548c5b167eb39a8acc1c5aa90b7aaa8e8ce0d0bf281cc6b89d45fb6684af61";
        let index = 1;

        let b = starcoin_verifier::verify_accumulator(&proof, &expected_root, &hash, index);
        assert!(b, 101)
    }


    #[test]
    fun test_verify_event_proof() {
        let txn_proof_siblings = vector::empty<vector<u8>>();
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"6eee994de6e916476aa77459d1fcd0719d9a6f36b3b8ae74e9cbad6d07065400");
        vector::push_back(&mut txn_proof_siblings, x"eab43f07f813200e3f810aea74a6af91532c17ed4ce4756a20adf33dbe183c2e");
        vector::push_back(&mut txn_proof_siblings, x"7f94b361c5027c06fafb03b57b1a1b8879c77e3eaf9bba0d896a33b4aeffa1a1");
        vector::push_back(&mut txn_proof_siblings, x"59ec68da7c6f9d7097d280ac1fab2ee18d91e0cfa5d64a4fbdb6c712e82c7bf2");
        vector::push_back(&mut txn_proof_siblings, x"1b47606d7b71ee665bd169855e0115296ccf9fdb2463f4fb2f9994e30b0476aa");
        vector::push_back(&mut txn_proof_siblings, x"ce1c3f9ea3a484f175254b7ae3009781e87218d46f24381dcd230ddcdff117e3");
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"86667ea18999fbcad72c7eda474c2212fa0effdaaa964205f803ad250e03abfe");
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"50d7486d96eb7a6f76a399a41fad052d2a64e1d0b6de37f34dec53bab06b9924");
        vector::push_back(&mut txn_proof_siblings, x"48583f70ae30de2bc4617a5eb95e17bb7436987e2fb04c8c6e3dedf185c87b7c");
        vector::push_back(&mut txn_proof_siblings, x"414343554d554c41544f525f504c414345484f4c4445525f4841534800000000");
        vector::push_back(&mut txn_proof_siblings, x"0c2f667f50ca04d5d3547b81ae0a61fb7718f074db01bd6fe75559f4860f929a");
        vector::push_back(&mut txn_proof_siblings, x"479474a6b9f65dd8ebddeba92fef7e0e4f83639993adf88f9041cf188d6e4da3");
        vector::push_back(&mut txn_proof_siblings, x"f01372f8a7e518557ca8b3bc471397a3a0c33216e92934cf3653cb8b11c69c0a");
        vector::push_back(&mut txn_proof_siblings, x"095ce71d1dcd45d3381927d6d24d15b72ccf17a27342cc510fa54ade551ca27e");
        vector::push_back(&mut txn_proof_siblings, x"4871d81d292baa485e6aed64e1e04454f2103f153b26aa6839492765ddef060f");
        vector::push_back(&mut txn_proof_siblings, x"0bf9a0eaacd7db0d51ac57142a5a703f5b3f88c57725e0fc28196000b686310b");
        vector::push_back(&mut txn_proof_siblings, x"8079193f2a30402bd81970a0f79fbe752587ed215ec8ab1ba056d309a5015eca");
        vector::push_back(&mut txn_proof_siblings, x"b201b5e82b25765089b529c99c23c8851b5c2b43aa7ee803551a5231bc6594f8");

        let txn_accumulator_root = x"9e9dc633087fcdeec84f6306900c76298e6667b53a743e953dbb333c74994243";
        let txn_proof = starcoin_verifier::new_accumulator_proof(txn_proof_siblings);
        let txn_info_bcs_byets = x"20a3cac3fc94d4e68de66812b3bb638e82211c26ed0e879eb368196bd849eea86a206f9ff224f38492ac5b1d9369d17c93d2540d569b7b98b386e2d9e165f441628520229243707efa8c9c303e9325f758148dbc8b1e7ea3e96846cb2711dd1bf3a2626b6c0f000000000000";
        let txn_global_index: u64 = 8369404;

        let event_proof_siblings = vector::empty<vector<u8>>();
        vector::push_back(&mut event_proof_siblings, x"e6f83b89b939d718d3d1ecbabcdb8cebf54d030015c252c8deda7f1a1ab9c43e");
        vector::push_back(&mut event_proof_siblings, x"d97c6dfc606206f7a5f4b27ddf56f252a368cf81ab91bd51f7565f839b7bcefd");
        vector::push_back(&mut event_proof_siblings, x"da7936f4309b7c79991d9bb7143bd2129735dd9343aafef06c0796740861eb49");

        let event_proof = starcoin_verifier::new_accumulator_proof(event_proof_siblings);
        let contract_event_bcs_bytes = x"0018000000000000000076a45fbf9631f68eb09812a21452e38ee5350000000000000700000000000000000000000000000001074163636f756e740d57697468647261774576656e74002b4120db000100000000000000000000008c109349c6bd91411d6bc962e080c4a30453544152045354415200";
        let event_index: u64 = 1;

        let b = starcoin_verifier::verify_event_proof(
            &txn_accumulator_root,
            &txn_proof,
            &txn_info_bcs_byets,
            txn_global_index,
            &event_proof,
            &contract_event_bcs_bytes,
            event_index,
        );
        assert!(b, 101)
    }

    #[test]
    fun test_bcs_deserialize_contract_event() {
        let contract_event_bcs_bytes = x"0018000000000000000076a45fbf9631f68eb09812a21452e38ee5350000000000000700000000000000000000000000000001074163636f756e740d57697468647261774576656e74002b4120db000100000000000000000000008c109349c6bd91411d6bc962e080c4a30453544152045354415200";
        let contract_event = starcoin_event::bcs_deserialize_contract_event(&contract_event_bcs_bytes);
        //0x00000000000000000000000000000001::Account::WithdrawEvent
        let expected_event_type_tag_data = x"0700000000000000000000000000000001074163636f756e740d57697468647261774576656e7400";
        assert!(expected_event_type_tag_data == starcoin_event::get_contract_event_type_tag_data(contract_event), 101);
        let expected_event_data = x"4120db000100000000000000000000008c109349c6bd91411d6bc962e080c4a30453544152045354415200";
        assert!(expected_event_data == starcoin_event::get_contract_event_event_data(contract_event), 101);
        let expected_event_key = x"000000000000000076a45fbf9631f68eb09812a21452e38e";
        assert!(expected_event_key == starcoin_event::get_contract_event_key(contract_event), 101);
        let expected_sequence_number = 13797;
        assert!(expected_sequence_number == starcoin_event::get_contract_event_sequence_number(contract_event), 101);
    }
}
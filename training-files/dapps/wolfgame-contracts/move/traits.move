module woolf_deployer::traits {
    use std::error;
    use std::string::{Self, String};
    use std::vector;
    use std::bcs;
    use std::hash;
    // use std::debug;
    use aptos_std::table::Table;
    use aptos_std::table;
    use aptos_token::token::{Self, TokenId};
    use aptos_token::property_map;

    use woolf_deployer::random;

    friend woolf_deployer::woolf;
    friend woolf_deployer::barn;

    const EMISMATCHED_INPUT: u64 = 1;
    const ETOKEN_NOT_FOUND: u64 = 2;

    // struct to store each trait's data for metadata and rendering
    struct Trait has store, drop, copy {
        name: String,
        png: String,
    }

    struct TraitData {
        items: Table<u8, Trait>
    }

    struct Data has key {
        trait_types: vector<String>,
        trait_data: Table<u8, Table<u8, Trait>>,
        // {trait_type => {id => trait}}
        alphas: vector<vector<u8>>,
        token_traits: Table<TokenId, SheepWolf>,
        index_traits: Table<u64, SheepWolf>,
        rarities: vector<vector<u8>>,
        aliases: vector<vector<u8>>,
        existing_combinations: Table<vector<u8>, bool>,
    }

    struct SheepWolf has drop, store, copy, key {
        is_sheep: bool,
        fur: u8,
        head: u8,
        ears: u8,
        eyes: u8,
        nose: u8,
        mouth: u8,
        neck: u8,
        feet: u8,
        alpha_index: u8,
    }

    public(friend) fun initialize(account: &signer) {
        let trait_types: vector<String> = vector[
            string::utf8(b"Fur"),
            string::utf8(b"Head"),
            string::utf8(b"Ears"),
            string::utf8(b"Eyes"),
            string::utf8(b"Nose"),
            string::utf8(b"Mouth"),
            string::utf8(b"Neck"),
            string::utf8(b"Feet"),
            string::utf8(b"Alpha"),
            string::utf8(b"IsSheep"),
        ];
        let trait_data: Table<u8, Table<u8, Trait>> = table::new();
        let alphas = vector[b"8", b"7", b"6", b"5"];

        let rarities: vector<vector<u8>> = vector::empty();
        let aliases: vector<vector<u8>> = vector::empty();
        // I know this looks weird but it saves users gas by making lookup O(1)
        // A.J. Walker's Alias Algorithm
        // sheep
        // fur
        vector::push_back(&mut rarities, vector[15, 50, 200, 250, 255]);
        vector::push_back(&mut aliases, vector[4, 4, 4, 4, 4]);
        // head
        vector::push_back(
            &mut rarities,
            vector[190, 215, 240, 100, 110, 135, 160, 185, 80, 210, 235, 240, 80, 80, 100, 100, 100, 245, 250, 255]
        );
        vector::push_back(&mut aliases, vector[1, 2, 4, 0, 5, 6, 7, 9, 0, 10, 11, 17, 0, 0, 0, 0, 4, 18, 19, 19]);
        // ears
        vector::push_back(&mut rarities, vector[255, 30, 60, 60, 150, 156]);
        vector::push_back(&mut aliases, vector[0, 0, 0, 0, 0, 0]);
        // eyes
        vector::push_back(
            &mut rarities,
            vector[221, 100, 181, 140, 224, 147, 84, 228, 140, 224, 250, 160, 241, 207, 173, 84, 254, 220, 196, 140, 168, 252, 140, 183, 236, 252, 224, 255]
        );
        vector::push_back(
            &mut aliases,
            vector[1, 2, 5, 0, 1, 7, 1, 10, 5, 10, 11, 12, 13, 14, 16, 11, 17, 23, 13, 14, 17, 23, 23, 24, 27, 27, 27, 27]
        );
        // nose
        vector::push_back(&mut rarities, vector[175, 100, 40, 250, 115, 100, 185, 175, 180, 255]);
        vector::push_back(&mut aliases, vector[3, 0, 4, 6, 6, 7, 8, 8, 9, 9]);
        // mouth
        vector::push_back(
            &mut rarities,
            vector[80, 225, 227, 228, 112, 240, 64, 160, 167, 217, 171, 64, 240, 126, 80, 255]
        );
        vector::push_back(&mut aliases, vector[1, 2, 3, 8, 2, 8, 8, 9, 9, 10, 13, 10, 13, 15, 13, 15]);
        // neck
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);
        // feet
        vector::push_back(
            &mut rarities,
            vector[243, 189, 133, 133, 57, 95, 152, 135, 133, 57, 222, 168, 57, 57, 38, 114, 114, 114, 255]
        );
        vector::push_back(&mut aliases, vector[1, 7, 0, 0, 0, 0, 0, 10, 0, 0, 11, 18, 0, 0, 0, 1, 7, 11, 18]);
        // alphaIndex
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);

        // wolves
        // fur
        vector::push_back(&mut rarities, vector[210, 90, 9, 9, 9, 150, 9, 255, 9]);
        vector::push_back(&mut aliases, vector[5, 0, 0, 5, 5, 7, 5, 7, 5]);
        // head
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);
        // ears
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);
        // eyes
        vector::push_back(
            &mut rarities,
            vector[135, 177, 219, 141, 183, 225, 147, 189, 231, 135, 135, 135, 135, 246, 150, 150, 156, 165, 171, 180, 186, 195, 201, 210, 243, 252, 255]
        );
        vector::push_back(
            &mut aliases,
            vector[1, 2, 3, 4, 5, 6, 7, 8, 13, 3, 6, 14, 15, 16, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 26, 26]
        );
        // nose
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);
        // mouth
        vector::push_back(&mut rarities, vector[239, 244, 249, 234, 234, 234, 234, 234, 234, 234, 130, 255, 247]);
        vector::push_back(&mut aliases, vector[1, 2, 11, 0, 11, 11, 11, 11, 11, 11, 11, 11, 11]);
        // neck
        vector::push_back(&mut rarities, vector[75, 180, 165, 120, 60, 150, 105, 195, 45, 225, 75, 45, 195, 120, 255]);
        vector::push_back(&mut aliases, vector[1, 9, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 14, 12, 14]);
        // feet
        vector::push_back(&mut rarities, vector[255]);
        vector::push_back(&mut aliases, vector[0]);
        // alphaIndex
        vector::push_back(&mut rarities, vector[8, 160, 73, 255]);
        vector::push_back(&mut aliases, vector[2, 3, 3, 3]);

        move_to(
            account,
            Data {
                trait_types, trait_data, alphas, token_traits: table::new(), index_traits: table::new(),
                rarities,
                aliases,
                existing_combinations: table::new()
            }
        );
    }

    public(friend) fun update_token_traits(
        token_id: TokenId,
        is_sheep: bool,
        fur: u8,
        head: u8,
        ears: u8,
        eyes: u8,
        nose: u8,
        mouth: u8,
        neck: u8,
        feet: u8,
        alpha_index: u8
    ) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        table::upsert(&mut data.token_traits, token_id, SheepWolf {
            is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index,
        });
        let (_, _, name, _) = token::get_token_id_fields(&token_id);
        let token_index: u64 = 0;
        let name_bytes = *string::bytes(&name);
        let i = 0;
        let k: u64 = 1;
        while (i < vector::length(&name_bytes)) {
            let n = vector::pop_back(&mut name_bytes);
            if (vector::singleton(n) == b"#") {
                break
            };
            token_index = token_index + ((n as u64) - 48) * k;
            k = k * 10;
            i = i + 1;
        };
        table::upsert(&mut data.index_traits, token_index, SheepWolf {
            is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index,
        });
    }

    public fun get_index_traits(
        // _token_owner: address,
        token_index: u64
    ): (bool, u8, u8, u8, u8, u8, u8, u8, u8, u8) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        assert!(table::contains(&data.index_traits, token_index), error::not_found(ETOKEN_NOT_FOUND));
        let traits = table::borrow(&data.index_traits, token_index);

        let SheepWolf { is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index } = *traits;

        (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
    }

    public fun get_token_traits(
        _token_owner: address,
        token_id: TokenId
    ): (bool, u8, u8, u8, u8, u8, u8, u8, u8, u8) acquires Data {
        let data = borrow_global_mut<Data>(@woolf_deployer);
        let traits = table::borrow(&data.token_traits, token_id);

        let SheepWolf { is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index } = *traits;

        (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
    }

    public fun is_sheep(token_id: TokenId): bool acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(table::contains(&data.token_traits, token_id), error::not_found(ETOKEN_NOT_FOUND));
        let sw = table::borrow(&data.token_traits, token_id);
        return sw.is_sheep
    }

    public fun get_name_property_map(
        is_sheep: bool, fur: u8, head: u8, ears: u8, eyes: u8, nose: u8, mouth: u8, neck: u8, feet: u8, alpha_index: u8
    ): (vector<String>, vector<vector<u8>>, vector<String>) acquires Data {
        let is_sheep_value = property_map::create_property_value(&is_sheep);
        let fur_value = property_map::create_property_value(&fur);
        let head_value = property_map::create_property_value(&head);
        let ears_value = property_map::create_property_value(&ears);
        let eyes_value = property_map::create_property_value(&eyes);
        let nose_value = property_map::create_property_value(&nose);
        let mouth_value = property_map::create_property_value(&mouth);
        let neck_value = property_map::create_property_value(&neck);
        let feet_value = property_map::create_property_value(&feet);
        let alpha_value = property_map::create_property_value(&alpha_index);

        let data = borrow_global<Data>(@woolf_deployer);
        let property_keys = data.trait_types;
        let property_values: vector<vector<u8>> = vector[
            property_map::borrow_value(&fur_value),
            property_map::borrow_value(&head_value),
            property_map::borrow_value(&ears_value),
            property_map::borrow_value(&eyes_value),
            property_map::borrow_value(&nose_value),
            property_map::borrow_value(&mouth_value),
            property_map::borrow_value(&neck_value),
            property_map::borrow_value(&feet_value),
            property_map::borrow_value(&alpha_value),
            property_map::borrow_value(&is_sheep_value),
        ];
        let property_types: vector<String> = vector[
            property_map::borrow_type(&fur_value),
            property_map::borrow_type(&head_value),
            property_map::borrow_type(&ears_value),
            property_map::borrow_type(&eyes_value),
            property_map::borrow_type(&nose_value),
            property_map::borrow_type(&mouth_value),
            property_map::borrow_type(&neck_value),
            property_map::borrow_type(&feet_value),
            property_map::borrow_type(&alpha_value),
            property_map::borrow_type(&is_sheep_value),
        ];
        (property_keys, property_values, property_types)
    }

    public fun select_traits(_seed: vector<u8>): SheepWolf acquires Data {
        select_traits_internal()
    }

    fun select_traits_internal(): SheepWolf acquires Data {
        let data = borrow_global<Data>(@woolf_deployer);
        let is_sheep = random::rand_u64_range_no_sender(0, 100) >= 10;
        let shift = if (is_sheep) 0 else 9;
        SheepWolf {
            is_sheep,
            fur: select_trait(data, random::rand_u64_range_no_sender(0, 255), 0 + shift),
            head: select_trait(data, random::rand_u64_range_no_sender(0, 255), 1 + shift),
            ears: select_trait(data, random::rand_u64_range_no_sender(0, 255), 2 + shift),
            eyes: select_trait(data, random::rand_u64_range_no_sender(0, 255), 3 + shift),
            nose: select_trait(data, random::rand_u64_range_no_sender(0, 255), 4 + shift),
            mouth: select_trait(data, random::rand_u64_range_no_sender(0, 255), 5 + shift),
            neck: select_trait(data, random::rand_u64_range_no_sender(0, 255), 6 + shift),
            feet: select_trait(data, random::rand_u64_range_no_sender(0, 255), 7 + shift),
            alpha_index: select_trait(data, random::rand_u64_range_no_sender(0, 255), 8 + shift),
        }
    }

    fun select_trait(data: &Data, seed: u64, trait_type: u64): u8 {
        let trait = seed % vector::length(vector::borrow(&data.rarities, trait_type));
        if (seed < (*vector::borrow(vector::borrow(&data.rarities, trait_type), trait) as u64)) {
            return (trait as u8)
        };
        *vector::borrow(vector::borrow(&data.aliases, trait_type), trait)
    }

    // generates traits for a specific token, checking to make sure it's unique
    public(friend) fun generate_traits(
        seed: vector<u8>
    ): (bool, u8, u8, u8, u8, u8, u8, u8, u8, u8) acquires Data {
        let t = select_traits(seed);
        let trait_hash = struct_to_hash(&t);
        let dashboard = borrow_global_mut<Data>(@woolf_deployer);
        if (!table::contains(&dashboard.existing_combinations, trait_hash)) {
            table::add(&mut dashboard.existing_combinations, trait_hash, true);
            let SheepWolf {
                is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index
            } = t;
            return (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
        };
        generate_traits(random::seed_no_sender())
    }

    fun struct_to_hash(s: &SheepWolf): vector<u8> {
        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, bcs::to_bytes(&s.is_sheep));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.fur));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.head));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.eyes));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.mouth));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.neck));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.ears));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.feet));
        vector::append<u8>(&mut info, bcs::to_bytes(&s.alpha_index));
        let hash: vector<u8> = hash::sha3_256(info);
        hash
    }

    #[test_only]
    use woolf_deployer::config;
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use woolf_deployer::utils::setup_timestamp;

    #[test(admin = @woolf_deployer, account = @0x1111)]
    fun test_update_token_traits(admin: &signer, account: &signer) acquires Data {
        account::create_account_for_test(signer::address_of(account));
        account::create_account_for_test(signer::address_of(admin));
        token::initialize_token_store(admin);
        token::opt_in_direct_transfer(admin, true);

        initialize(admin);
        let token_id = token::create_token_id_raw(
            signer::address_of(admin),
            config::collection_name(),
            string::utf8(b"Sheep #123"),
            0
        );
        // let data = borrow_global<Data>(@woolf_deployer);
        // assert!(!table::contains(&data.token_traits, token_id), 1);
        // assert!(!table::contains(&data.index_traits, 1), 2);

        update_token_traits(token_id, true, 1, 1, 1, 1, 1, 1, 1, 1, 1);
        let data = borrow_global<Data>(@woolf_deployer);
        assert!(table::contains(&data.token_traits, token_id), 1);
        assert!(table::contains(&data.index_traits, 123), 2);
    }

    #[test(aptos = @0x1, admin = @woolf_deployer)]
    fun test_select_traits(aptos: &signer, admin: &signer) acquires Data {
        setup_timestamp(aptos);
        // block::initialize_modules(aptos, 1);
        initialize(admin);
        select_traits(random::seed_no_sender());
    }

    #[test]
    fun test_struct_to_hash() {
        let sw = SheepWolf {
            is_sheep: false,
            fur: 1,
            head: 1,
            ears: 1,
            eyes: 1,
            nose: 1,
            mouth: 1,
            neck: 1,
            feet: 1,
            alpha_index: 1,
        };
        let hash = struct_to_hash(&sw);
        // debug::print(&hash);
        assert!(
            hash == vector[221, 61, 243, 38, 36, 70, 50, 235, 234, 246, 152,
                66, 26, 160, 62, 165, 60, 27, 51, 24, 219, 125, 95, 216, 122,
                202, 224, 140, 185, 217, 181, 187],
            1
        );
    }
}

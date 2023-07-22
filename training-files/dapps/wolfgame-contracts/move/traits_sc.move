// module woolf_deployer::traits {
//     use std::error;
//     use std::string::{Self, String};
//     use std::vector;
//     // use std::debug;
//     use std::option::{Self, Option};
//     use aptos_std::table::Table;
//     use aptos_std::table;
//     use aptos_token::token::{Self, TokenId};
//     use aptos_token::property_map;
//
//     use woolf_deployer::base64;
//
//     friend woolf_deployer::woolf;
//     friend woolf_deployer::barn;
//
//     const EMISMATCHED_INPUT: u64 = 1;
//     const ETOKEN_NOT_FOUND: u64 = 2;
//
//     // struct to store each trait's data for metadata and rendering
//     struct Trait has store, drop, copy {
//         name: String,
//         png: String,
//     }
//
//     struct TraitData {
//         items: Table<u8, Trait>
//     }
//
//     struct Data has key {
//         trait_types: vector<String>,
//         trait_data: Table<u8, Table<u8, Trait>>,
//         // {trait_type => {id => trait}}
//         alphas: vector<vector<u8>>,
//         token_traits: Table<TokenId, SheepWolf>,
//         index_traits: Table<u64, SheepWolf>
//     }
//
//     struct SheepWolf has drop, store, copy, key {
//         is_sheep: bool,
//         fur: u8,
//         head: u8,
//         ears: u8,
//         eyes: u8,
//         nose: u8,
//         mouth: u8,
//         neck: u8,
//         feet: u8,
//         alpha_index: u8,
//     }
//
//     public(friend) fun initialize(account: &signer) acquires Data {
//         let trait_types: vector<String> = vector[
//             string::utf8(b"Fur"),
//             string::utf8(b"Head"),
//             string::utf8(b"Ears"),
//             string::utf8(b"Eyes"),
//             string::utf8(b"Nose"),
//             string::utf8(b"Mouth"),
//             string::utf8(b"Neck"),
//             string::utf8(b"Feet"),
//             string::utf8(b"Alpha"),
//             string::utf8(b"IsSheep"),
//         ];
//         let trait_data: Table<u8, Table<u8, Trait>> = table::new();
//         let alphas = vector[b"8", b"7", b"6", b"5"];
//
//         move_to(
//             account,
//             Data { trait_types, trait_data, alphas, token_traits: table::new(), index_traits: table::new() }
//         );
//
//         upload_traits(0, vector<u8>[0,1,2,3,4], vector[
//             Trait { name: string::utf8(b"Gray"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Brown"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"White"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Black"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Survivor"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(1, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19], vector[
//             Trait { name: string::utf8(b"Curved Brown Horns"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Silky"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Sun Hat"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Cowboy Hat"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Mailman"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Beanie"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"None"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pointy Brown Horns"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pointy Golden Horns"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Blue Horns"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Blue Hat"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Rainbow Fro"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Capone"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Visor"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Fedora"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Red Cap"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Santa"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Curved Golden Horns"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"White Cap"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Bucket Hat"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(2, vector<u8>[0,1,2,3,4,5], vector[
//             Trait { name: string::utf8(b"Diamond Stud"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gold Bling"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gold Hoop"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Two Gold Piercings"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"None"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Diamond Bling"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(3, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27], vector[
//             Trait { name: string::utf8(b"Cyclops"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Staring Contest"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Fearless"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Fearful"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Squint Right"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Dork"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"OMG"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Angry"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Rolling"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Red Glasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Basic Sun Protection"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Big Blue"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Night Vision Visor"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Sleepy"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Black Glasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Rainbow Sunnies"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Bloodshot"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Small Blue"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"X Ray"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Livid"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Squint Left"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Confused"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Face Painted"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Leafy Green"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Fake Glasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Happy"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Cross Eyed"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Spacey"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(4, vector<u8>[0,1,2,3,4,5,6,7,8,9], vector[
//             Trait { name: string::utf8(b"Dots"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Wide"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"X"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Punched"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gold"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Normal"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Dot"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Red"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Triangle"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"U"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(5, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15], vector[
//             Trait { name: string::utf8(b"Beard"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Teasing"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Wide Open Mouth"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Big Smile"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pouting"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Grillz"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Missing Tooth"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Smirk"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Mustache"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Neutral"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Cigarette"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Cheese"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pipe"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Narrow Open Mouth"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Chill Smile"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Chinstrap"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(6, vector<u8>[0], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(7, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18], vector[
//             Trait { name: string::utf8(b"Blue Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Slippers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Roller Blades"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"None"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Striped Socks"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Green Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gray Shoes"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Yellow Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Snowboard"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Ice Skates"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"White Boots"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Frozen"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Elf"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"White and Gray Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"High"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Dress Shoes"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Red Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Purple Sneakers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Clogs"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(8, vector<u8>[0], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(9, vector<u8>[0,1,2,3,4,5,6,7,8], vector[
//             Trait { name: string::utf8(b"Brown"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Black"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Skeleton"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"White"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Zombie"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Golden"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gray"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Cyborg"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Demon"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(10, vector<u8>[0], vector[
//             Trait { name: string::utf8(b"Alpha"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(11, vector<u8>[0], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(12, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26], vector[
//             Trait { name: string::utf8(b"Rightward Gaze"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Calm"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Non"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pouncing"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"3D Glasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Sus"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Downward Gaze"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Full Moon"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Wide Dots"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Hipster Glasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Deep Blue"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Mascara"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Curious"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Flashy Sunnies"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"The Intellectual"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Unibrow"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Expressionless"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Crossed"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Leftward Gaze"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Triangle"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Simple"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Lovable"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Closed"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Challenged"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Narrow Dots"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Standard Sunnies"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Restless"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(13, vector<u8>[0], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(14, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12], vector[
//             Trait { name: string::utf8(b"Mischievous"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Wide Smile"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Neutral"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Flared Nostrils"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Brown Nose Smirk"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gray Nose Smirk"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Frown"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Relaxed"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Tongue Out"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Narrow Smile"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Howling"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Smoking"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Red Nose Smirk"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(15, vector<u8>[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14], vector[
//             Trait { name: string::utf8(b"Clock"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Silver"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Sunglasses"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Bowtie"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Dress Tie"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Teeth"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Pearls"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Mask"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Diamond"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Gold"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Flowers"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Secret Society"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Bandana"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"None"), png: string::utf8(b"")},
//             Trait { name: string::utf8(b"Sheep Heart"), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(16, vector<u8>[0], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//
//         upload_traits(17, vector<u8>[0,1,2,3], vector[
//             Trait { name: string::utf8(b""), png: string::utf8(b"")},
//             Trait { name: string::utf8(b""), png: string::utf8(b"")},
//             Trait { name: string::utf8(b""), png: string::utf8(b"")},
//             Trait { name: string::utf8(b""), png: string::utf8(b"")}
//         ]);
//     }
//
//     public(friend) fun update_token_traits(
//         token_id: TokenId,
//         is_sheep: bool,
//         fur: u8,
//         head: u8,
//         ears: u8,
//         eyes: u8,
//         nose: u8,
//         mouth: u8,
//         neck: u8,
//         feet: u8,
//         alpha_index: u8
//     ) acquires Data {
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//         table::upsert(&mut data.token_traits, token_id, SheepWolf {
//             is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index,
//         });
//         let (_,_,name,_) = token::get_token_id_fields(&token_id);
//         let token_index: u64 = 0;
//         let name_bytes = *string::bytes(&name);
//         let i = 0;
//         let k: u64 = 1;
//         while ( i < vector::length(&name_bytes) ) {
//             let n = vector::pop_back(&mut name_bytes);
//             if (vector::singleton(n) == b"#") {
//                 break
//             };
//             token_index = token_index + ((n as u64) - 48) * k;
//             k = k * 10;
//             i = i + 1;
//         };
//         table::upsert(&mut data.index_traits, token_index, SheepWolf {
//             is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index,
//         });
//     }
//
//     public entry fun upload_traits(
//         trait_type: u8,
//         trait_ids: vector<u8>,
//         traits: vector<Trait>
//     ) acquires Data {
//         assert!(vector::length(&trait_ids) == vector::length(&traits), error::invalid_argument(EMISMATCHED_INPUT));
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//         let i = 0;
//         while (i < vector::length(&traits)) {
//             if (!table::contains(&data.trait_data, trait_type)) {
//                 table::add(&mut data.trait_data, trait_type, table::new());
//             };
//             let trait_data_table = table::borrow_mut(&mut data.trait_data, trait_type);
//             // let trait = Trait {
//             //     name: vector::borrow(&traits, i).name,
//             //     png: vector::borrow(&traits, i).png,
//             // };
//             let trait = *vector::borrow(&traits, i);
//             table::upsert(trait_data_table, *vector::borrow(&trait_ids, i), trait);
//
//             i = i + 1;
//         }
//     }
//
//     public fun get_index_traits(
//         // _token_owner: address,
//         token_index: u64
//     ): (bool, u8, u8, u8, u8, u8, u8, u8, u8, u8) acquires Data {
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//         let traits = table::borrow(&data.index_traits, token_index);
//
//         let SheepWolf { is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index } = *traits;
//
//         (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//     }
//
//     public fun get_token_traits(
//         _token_owner: address,
//         token_id: TokenId
//     ): (bool, u8, u8, u8, u8, u8, u8, u8, u8, u8) acquires Data {
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//         let traits = table::borrow(&data.token_traits, token_id);
//
//         let SheepWolf { is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index } = *traits;
//
//         (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//
//         // // FIXME
//         // debug::print(&5);
//         // debug::print(&token_owner);
//         // debug::print(&token_id);
//         // let properties = token::get_property_map(token_owner, token_id);
//         // debug::print(&properties);
//         // debug::print(&6);
//         // let data = borrow_global_mut<Data>(@woolf_deployer);
//         // debug::print(&1001);
//         // debug::print(vector::borrow(&data.trait_types, 0));
//         // let fur = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 0));
//         // debug::print(&1002);
//         // let head = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 1));
//         // debug::print(&1003);
//         // let ears = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 2));
//         // debug::print(&1004);
//         // let eyes = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 3));
//         // debug::print(&1005);
//         // let nose = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 4));
//         // debug::print(&1006);
//         // let mouth = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 5));
//         // debug::print(&1007);
//         // let neck = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 6));
//         // debug::print(&1008);
//         // let feet = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 7));
//         // debug::print(&1009);
//         // let alpha_index = property_map::read_u8(&properties, vector::borrow(&data.trait_types, 8));
//         // debug::print(&1010);
//         // let is_sheep = property_map::read_bool(&properties, vector::borrow(&data.trait_types, 9));
//         // debug::print(&1011);
//         // // debug::print(&SheepWolf { is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index });
//         // (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//     }
//
//     public fun is_sheep(token_id: TokenId): bool acquires Data {
//         let data = borrow_global<Data>(@woolf_deployer);
//         assert!(table::contains(&data.token_traits, token_id), error::not_found(ETOKEN_NOT_FOUND));
//         let sw = table::borrow(&data.token_traits, token_id);
//         return sw.is_sheep
//     }
//
//     public fun get_name_property_map(
//         is_sheep: bool, fur: u8, head: u8, ears: u8, eyes: u8, nose: u8, mouth: u8, neck: u8, feet: u8, alpha_index: u8
//     ): (vector<String>, vector<vector<u8>>, vector<String>) acquires Data {
//         let is_sheep_value = property_map::create_property_value(&is_sheep);
//         let fur_value = property_map::create_property_value(&fur);
//         let head_value = property_map::create_property_value(&head);
//         let ears_value = property_map::create_property_value(&ears);
//         let eyes_value = property_map::create_property_value(&eyes);
//         let nose_value = property_map::create_property_value(&nose);
//         let mouth_value = property_map::create_property_value(&mouth);
//         let neck_value = property_map::create_property_value(&neck);
//         let feet_value = property_map::create_property_value(&feet);
//         let alpha_value = property_map::create_property_value(&alpha_index);
//
//         let data = borrow_global<Data>(@woolf_deployer);
//         let property_keys = data.trait_types;
//         let property_values: vector<vector<u8>> = vector[
//             property_map::borrow_value(&fur_value),
//             property_map::borrow_value(&head_value),
//             property_map::borrow_value(&ears_value),
//             property_map::borrow_value(&eyes_value),
//             property_map::borrow_value(&nose_value),
//             property_map::borrow_value(&mouth_value),
//             property_map::borrow_value(&neck_value),
//             property_map::borrow_value(&feet_value),
//             property_map::borrow_value(&alpha_value),
//             property_map::borrow_value(&is_sheep_value),
//         ];
//         let property_types: vector<String> = vector[
//             property_map::borrow_type(&fur_value),
//             property_map::borrow_type(&head_value),
//             property_map::borrow_type(&ears_value),
//             property_map::borrow_type(&eyes_value),
//             property_map::borrow_type(&nose_value),
//             property_map::borrow_type(&mouth_value),
//             property_map::borrow_type(&neck_value),
//             property_map::borrow_type(&feet_value),
//             property_map::borrow_type(&alpha_value),
//             property_map::borrow_type(&is_sheep_value),
//         ];
//         (property_keys, property_values, property_types)
//     }
//
//     fun draw_trait(trait: Trait): String {
//         let s: String = string::utf8(b"");
//         string::append_utf8(&mut s, b"<image x=\"4\" y=\"4\" width=\"32\" height=\"32\" image-rendering=\"pixelated\" preserveAspectRatio=\"xMidYMid\" xlink:href=\"data:image/png;base64,");
//         string::append(&mut s, trait.png);
//         string::append_utf8(&mut s, b"\"/>");
//         s
//     }
//
//     fun draw_trait_or_none(trait: Option<Trait>): String {
//         if (option::is_some(&trait)) {
//             draw_trait(option::extract(&mut trait))
//         } else {
//             string::utf8(b"")
//         }
//     }
//
//     public fun draw_svg(token_owner: address, token_id: TokenId): String acquires Data {
//         let (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index) = get_token_traits(
//             token_owner, token_id
//         );
//         draw_svg_internal(is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//     }
//
//     fun draw_svg_internal(is_sheep: bool, fur: u8, head: u8, ears: u8, eyes: u8, nose: u8, mouth: u8, neck: u8, feet: u8, alpha_index: u8): String acquires Data {
//
//         let shift: u8 = if (is_sheep) 0 else 9;
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//
//         let s0 = option::some(*table::borrow(table::borrow(&data.trait_data, 0 + shift), fur));
//         let s1 = if (is_sheep) {
//             option::some(*table::borrow(table::borrow(&data.trait_data, 1 + shift), head))
//         } else {
//             option::some(*table::borrow(table::borrow(&data.trait_data, 1 + shift), alpha_index))
//         };
//         let s2 = if (is_sheep) option::some(
//             *table::borrow(table::borrow(&data.trait_data, 2 + shift), ears)
//         ) else option::none<Trait>();
//         let s3 = option::some(*table::borrow(table::borrow(&data.trait_data, 3 + shift), eyes));
//         let s4 = if (is_sheep) option::some(
//             *table::borrow(table::borrow(&data.trait_data, 4 + shift), nose)
//         ) else option::none<Trait>();
//         let s5 = option::some(*table::borrow(table::borrow(&data.trait_data, 5 + shift), mouth));
//         let s6 = if (is_sheep) option::none<Trait>() else option::some(
//             *table::borrow(table::borrow(&data.trait_data, 6 + shift), neck)
//         );
//         let s7 = if (is_sheep) option::some(
//             *table::borrow(table::borrow(&data.trait_data, 7 + shift), feet)
//         ) else option::none<Trait>();
//
//         let svg_string: String = string::utf8(b"");
//         string::append_utf8(&mut svg_string, b"<svg id=\"woolf\" width=\"100%\" height=\"100%\" version=\"1.1\" viewBox=\"0 0 40 40\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">");
//         string::append(&mut svg_string, draw_trait_or_none(s0));
//         string::append(&mut svg_string, draw_trait_or_none(s1));
//         string::append(&mut svg_string, draw_trait_or_none(s2));
//         string::append(&mut svg_string, draw_trait_or_none(s3));
//         string::append(&mut svg_string, draw_trait_or_none(s4));
//         string::append(&mut svg_string, draw_trait_or_none(s5));
//         string::append(&mut svg_string, draw_trait_or_none(s6));
//         string::append(&mut svg_string, draw_trait_or_none(s7));
//         string::append_utf8(&mut svg_string, b"</svg>");
//         svg_string
//     }
//
//     fun attribute_for_type_and_value(trait_type: String, value: String): String {
//         let s = string::utf8(b"");
//         string::append_utf8(&mut s, b"{\"trait_type\":\"");
//         string::append(&mut s, trait_type);
//         string::append_utf8(&mut s, b"\",\"value\":\"");
//         string::append(&mut s, value);
//         string::append_utf8(&mut s, b"\"}");
//         s
//     }
//
//     fun compile_attributes(token_owner: address, token_id: TokenId): String acquires Data {
//         let (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index) = get_token_traits(
//             token_owner, token_id
//         );
//         compile_attributes_internal(is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//     }
//
//     fun compile_attributes_internal(is_sheep: bool, fur: u8, head: u8, ears: u8, eyes: u8, nose: u8, mouth: u8, neck: u8, feet: u8, alpha_index: u8): String acquires Data {
//
//         let s = vector[fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index];
//         let traits: String = string::utf8(b"");
//         let data = borrow_global_mut<Data>(@woolf_deployer);
//         if (is_sheep) {
//             let types = vector[0, 1, 2, 3, 4, 5, 7];
//             let i = 0;
//             while (i < vector::length(&types)) {
//                 let index = *vector::borrow(&types, i);
//                 string::append(&mut traits, attribute_for_type_and_value(
//                     *vector::borrow(&data.trait_types, index),
//                     table::borrow(
//                         table::borrow(&data.trait_data, (index as u8)),
//                         *vector::borrow(&s, index)
//                     ).name
//                 ));
//                 string::append_utf8(&mut traits, b",");
//                 i = i + 1;
//             };
//         } else {
//             let types = vector[0, 1, 3, 5, 6];
//             let sindice = vector[0, 8, 3, 5, 6];
//             let i = 0;
//             while (i < vector::length(&types)) {
//                 let index = *vector::borrow(&types, i);
//                 string::append(&mut traits, attribute_for_type_and_value(
//                     *vector::borrow(&data.trait_types, index),
//                     table::borrow(
//                         table::borrow(&data.trait_data, (index as u8) + 9),
//                         *vector::borrow(&s, *vector::borrow(&sindice, i))
//                     ).name
//                 ));
//                 string::append_utf8(&mut traits, b",");
//                 i = i + 1;
//             };
//             string::append(&mut traits, attribute_for_type_and_value(
//                 string::utf8(b"Alpha"),
//                 string::utf8(*vector::borrow(&data.alphas, (*vector::borrow(&s, 8) as u64))) // alpha_index
//             ));
//             string::append_utf8(&mut traits, b",");
//         };
//         let attributes: String = string::utf8(b"");
//         string::append_utf8(&mut attributes, b"[");
//         string::append(&mut attributes, traits);
//         string::append_utf8(&mut attributes, b"{\"trait_type\":\"Generation\",\"value\":");
//         string::append_utf8(&mut attributes, if (is_sheep) b"\"Gen 0\"" else b"\"Gen 1\"");
//         string::append_utf8(&mut attributes, b"},{\"trait_type\":\"Type\",\"value\":");
//         string::append_utf8(&mut attributes, if (is_sheep) b"\"Sheep\"" else b"\"Wolf\"");
//         string::append_utf8(&mut attributes, b"}]");
//
//         attributes
//     }
//
//     public(friend) fun token_uri(token_owner: address, token_id: TokenId): String acquires Data {
//         let (is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index) = get_token_traits(
//             token_owner, token_id
//         );
//         token_uri_internal(is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index)
//     }
//
//     public(friend) fun token_uri_internal(
//         is_sheep: bool, fur: u8, head: u8, ears: u8, eyes: u8, nose: u8, mouth: u8, neck: u8, feet: u8, alpha_index: u8
//     ): String acquires Data {
//         let metadata = string::utf8(b"");
//         string::append_utf8(&mut metadata, b"{\"name\": \"");
//         string::append_utf8(&mut metadata, if (is_sheep) b"Sheep #" else b"Wolf #");
//         string::append_utf8(&mut metadata, b"tokenId"); // FIXME: token id
//         string::append_utf8(&mut metadata, b"\", \"description\": \"Thousands of Sheep and Wolves compete on a farm in the metaverse. A tempting prize of $WOOL awaits, with deadly high stakes. All the metadata and images are generated and stored 100% on-chain. No IPFS. NO API. Just the Ethereum blockchain.\", \"image\": \"data:image/svg+xml;base64,");
//         string::append_utf8(&mut metadata, base64::encode(string::bytes(&draw_svg_internal(is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index))));
//         string::append_utf8(&mut metadata, b"\", \"attributes\":");
//         string::append(&mut metadata, compile_attributes_internal(is_sheep, fur, head, ears, eyes, nose, mouth, neck, feet, alpha_index));
//         string::append_utf8(&mut metadata, b"}");
//         let uri = string::utf8(b"data:application/json;base64,");
//         string::append_utf8(&mut uri, base64::encode(string::bytes(&metadata)));
//         uri
//     }
//
//     #[test_only]
//     use std::signer;
//
//     #[test(admin = @woolf_deployer)]
//     fun test_upload_traits(admin: &signer) acquires Data {
//         initialize(admin);
//         let trait_type: u8 = 8;
//         let trait_ids: vector<u8> = vector[1, 2];
//         let traits: vector<Trait> = vector[
//             Trait { name: string::utf8(b"1"), png: string::utf8(b"1") },
//             Trait { name: string::utf8(b"2"), png: string::utf8(b"2") }
//         ];
//         upload_traits(trait_type, trait_ids, traits);
//
//         let data = borrow_global<Data>(signer::address_of(admin));
//         assert!(table::borrow(table::borrow(&data.trait_data, trait_type), 1).png == string::utf8(b"1"), 0);
//     }
//     #[test]
//     fun test_draw_trait() {
//         draw_trait(Trait { name: string::utf8(b"1"), png: string::utf8(b"1") });
//     }
//
//     #[test(admin = @woolf_deployer)]
//     fun test_compile_attributes_internal(admin: &signer) acquires Data {
//         initialize(admin);
//         let _s = compile_attributes_internal(true, 0,0,0,0,0,0,0,0,0);
//         // debug::print(&s);
//         let _w = compile_attributes_internal(false, 0,0,0,0,0,0,0,0,0);
//         // debug::print(&w);
//     }
//
//     #[test(admin = @woolf_deployer)]
//     fun test_draw_svg_internal(admin: &signer) acquires Data {
//         initialize(admin);
//         let _s = draw_svg_internal(true, 1,0,0,1,0,0,0,0,0);
//         // debug::print(&_s);
//     }
//
//     #[test(admin = @woolf_deployer)]
//     fun test_token_uri_internal(admin: &signer) acquires Data {
//         initialize(admin);
//         let _s = token_uri_internal(true, 1,0,0,1,0,0,0,0,0);
//         // debug::print(&_s);
//     }
// }

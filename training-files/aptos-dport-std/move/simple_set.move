/// This module provides a solution for small unsorted sets, that is it has the properties that:
/// 1) Each item must be unique
/// 2) The items in set are unsorted
/// 3) Insertions and removals take O(n) time
module dport_std::simple_set {
    use std::error;
    use std::option;
    use std::vector;

    /// Map key is not found
    const EKEY_NOT_FOUND: u64 = 1;

    /// A simple implementation of set backed by an underlying vector, suitable for small sets.
    struct SimpleSet<Element> has copy, drop, store {
        data: vector<Element>,
    }

    /// Return the number of keys in the set.
    public fun length<Element>(set: &SimpleSet<Element>): u64 {
        vector::length(&set.data)
    }

    /// Create an empty set.
    public fun create<Element: store + copy + drop>(): SimpleSet<Element> {
        SimpleSet {
            data: vector::empty<Element>(),
        }
    }

    public fun borrow<Element>(
        map: &SimpleSet<Element>,
        key: &Element,
    ): &Element {
        let maybe_idx = find(map, key);
        assert!(option::is_some(&maybe_idx), error::invalid_argument(EKEY_NOT_FOUND));
        let idx = option::extract(&mut maybe_idx);
        vector::borrow(&map.data, idx)
    }

    public fun borrow_mut<Element>(
        map: &mut SimpleSet<Element>,
        key: &Element,
    ): &Element {
        let maybe_idx = find(map, key);
        assert!(option::is_some(&maybe_idx), error::invalid_argument(EKEY_NOT_FOUND));
        let idx = option::extract(&mut maybe_idx);
        vector::borrow_mut(&mut map.data, idx)
    }

    /// Return true if the set contains `key`, or false vice versa.
    public fun contains<Element>(
        set: &SimpleSet<Element>,
        key: &Element,
    ): bool {
        let maybe_idx = find(set, key);
        option::is_some(&maybe_idx)
    }

    /// Destroy the set. Aborts if set is not empty.
    public inline fun destroy_empty<Element>(set: SimpleSet<Element>) {
        let SimpleSet { data } = set;
        vector::destroy_empty(data);
    }

    /// Insert `key` into the set.
    /// Return `true` if `key` did not already exist in the set and `false` vice versa.
    public fun insert<Element: drop>(
        set: &mut SimpleSet<Element>,
        key: Element,
    ): bool {
        let maybe_idx = find(set, &key);
        if (option::is_some(&maybe_idx)) {
            false
        } else {
            vector::push_back(&mut set.data, key);
            true
        }
    }

    /// Remove `key` into the set.
    /// Return `true` if `key` already existed in the set and `false` vice versa.
    public fun remove<Element: drop>(
        set: &mut SimpleSet<Element>,
        key: &Element,
    ): bool {
        let maybe_idx = find(set, key);
        if (option::is_some(&maybe_idx)) {
            vector::swap_remove(&mut set.data, *option::borrow(&maybe_idx));
            true
        } else {
            false
        }
    }

    /// Find the potential index of `key` in the underlying data vector.
    fun find<Element>(
        set: &SimpleSet<Element>,
        key: &Element,
    ): option::Option<u64>{
        let leng = vector::length(&set.data);
        let i = 0;
        while (i < leng) {
            let cur = vector::borrow(&set.data, i);
            if (cur == key){
                return option::some(i)
            };
            i = i + 1;
        };
        option::none<u64>()
    }

    public fun key_at_idx<Element>(
        set: &SimpleSet<Element>,
        idx: u64
    ): &Element {
        vector::borrow(&set.data, idx)
    }

    #[test]
    public fun insert_remove_many() {
        let set = create<u64>();

        assert!(length(&set) == 0, 0);
        assert!(!contains(&set, &3), 0);
        insert(&mut set, 3);
        assert!(length(&set) == 1, 0);
        assert!(contains(&set, &3), 0);
        assert!(!contains(&set, &2), 0);
        insert(&mut set, 2);
        assert!(length(&set) == 2, 0);
        assert!(contains(&set, &2), 0);
        remove(&mut set, &2);
        assert!(length(&set) == 1, 0);
        assert!(!contains(&set, &2), 0);
        remove(&mut set, &3);
        assert!(length(&set) == 0, 0);
        assert!(!contains(&set, &3), 0);

        destroy_empty(set);
    }

    #[test]
    public fun insert_twice() {
        let set = create<u64>();
        assert!(insert(&mut set, 3) == true, 0);
        assert!(insert(&mut set, 3) == false, 0);

        remove(&mut set, &3);
        destroy_empty(set);
    }

    #[test]
    public fun remove_twice() {
        let set = create<u64>();
        insert(&mut set, 3);
        assert!(remove(&mut set, &3) == true, 0);
        assert!(remove(&mut set, &3) == false, 0);

        destroy_empty(set);
    }
}

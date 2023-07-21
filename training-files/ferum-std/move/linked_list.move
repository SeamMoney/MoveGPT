/// ---
/// description: ferum_std::linked_list
/// ---
///
/// Ferum's implementation of a doubly linked list. Values stored in the list should be cheap to copy. Duplicate values
/// are supported.
///
/// This list should be used for values that are cheap to copy. For a list that stores by moving values, see
/// (ref_linked_list)[/]
///
/// | Operation                            | Worst Case Time Complexity |
/// |--------------------------------------|----------------------------|
/// | Insertion of value to tail           | O(D)                       |
/// | Deletion of value                    | O(1)                       |
/// | Deletion of value at head            | O(D)                       |
/// | Deletion of value at tail            | O(D)                       |
/// | Contains value                       | O(1)                       |
///
/// Where D is the number of duplicates of that particular value.
///
/// Each value is stored internally in a table with a unique key pointing to that value. The key is generated
/// sequentially using a u128 counter. So the maximum number of values that can be added to the list is MAX_U128
/// (340282366920938463463374607431768211455).
///
/// # Quick Example
///
/// ```
/// use ferum_std::linked_list::{Self, List};
///
/// // Create a list with u128 values.
/// let list = linked_list::new<u128>();
///
/// // Add values
/// linked_list::add(&mut list, 100);
/// linked_list::add(&mut list, 50);
/// linked_list::add(&mut list, 20);
/// linked_list::add(&mut list, 200);
/// linked_list::add(&mut list, 100); // Duplicate
///
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100
///
/// // Iterate through the list, left to right.
/// let iterator = iterator(&list);
/// while (linked_list::has_next(&iterator)) {
///  let value = linked_list::get_next(&list, &mut iterator);
/// };
///
/// // Get length of list.
/// linked_list::length(&list) // == 4
///
/// // Check if list contains value.
/// linked_list::contains(&list, 100) // true
/// linked_list::contains(&list, 300) // false
///
/// // Remove last
/// linked_list::remove_last(&list);
/// print_list(&list) // 100 <-> 50 <-> 20 <-> 200
///
/// // Remove first
/// linked_list::remove_first(&list);
/// print_list(&list) // 50 <-> 20 <-> 200
/// ```
module ferum_std::linked_list {
    use aptos_std::table_with_length as table;
    use std::vector;
    #[test_only]
    use std::string;
    #[test_only]
    use ferum_std::test_utils::to_string_u128;
    #[test_only]
    use std::string::String;

    /// Thrown when the key for a given node is not found.
    const KEY_NOT_FOUND: u64 = 1;
    /// Thrown when a duplicate key is added to the list.
    const DUPLICATE_KEY: u64 = 2;
    /// Thrown when a trying to perform an operation that requires a list to have elements but it doesn't.
    const EMPTY_LIST: u64 = 3;
    /// Thrown when a value being searched for is not found.
    const VALUE_NOT_FOUND: u64 = 4;
    /// Thrown when attempting to iterate beyond the limit of the linked list.
    const MUST_HAVE_NEXT_VALUE: u64 = 5;

    struct Node<V: store + copy + drop> has store, drop {
        key: u128,
        value: V,
        nextKey: u128,
        nextKeyIsSet: bool,
        prevKey: u128,
        prevKeyIsSet: bool,
    }

    /// Struct representing the linked list.
    struct LinkedList<V: store + copy + drop> has key, store {
        nodes: table::TableWithLength<u128, Node<V>>,
        nodeKeys: table::TableWithLength<V, vector<u128>>,
        keyCounter: u128,
        length: u128,
        head: u128,
        tail: u128,
    }

    /// Used to represent a position within a doubly linked list during iteration.
    struct ListPosition<phantom V: store + copy + drop> has store, copy, drop {
        currentKey: u128,
        hasNextKey: bool,
        // The first time next(..) is called, the first value is returned; in other words, position is a leading pointer.
        // Without having completed flag, it would be hard to handle the last element. For example, in a list with a
        // single element, hasNextKey would be set to false, so it would be impossible to know if iteration has come to
        // a stop.
        completed: bool,
    }

    /// Initialize a new list.
    public fun new<V: store + copy + drop>(): LinkedList<V> {
        return LinkedList<V>{
            nodes: table::new<u128, Node<V>>(),
            nodeKeys: table::new<V, vector<u128>>(),
            keyCounter: 0,
            length: 0,
            head: 0,
            tail: 0,
        }
    }

    /// Creates a linked list with a single element.
    public fun singleton<V: store + copy + drop>(val: V): LinkedList<V> {
        let list = new();
        add(&mut list, val);
        list
    }

    /// Add a value to the list.
    public fun add<V: store + copy + drop>(list: &mut LinkedList<V>, value: V) {
        let end = list.length;
        insert_at(list, value, end);
    }

    /// Inserts a value to the given index.
    public fun insert_at<V: store + copy + drop>(list: &mut LinkedList<V>, value: V, idx: u128) {
        let key = list.keyCounter;
        list.keyCounter = list.keyCounter + 1;

        let nodeKeys = table::borrow_mut_with_default(&mut list.nodeKeys, value, vector::empty());
        vector::push_back(nodeKeys, key);

        let node = Node{
            key,
            value,
            nextKey: 0,
            nextKeyIsSet: false,
            prevKey: 0,
            prevKeyIsSet: false,
        };

        if (list.length == 0) {
            list.head = key;
            list.tail = key;

            table::add(&mut list.nodes, key, node);
            list.length = list.length + 1;
            return
        };

        if (idx == list.length) {
            // We're inserting at the end of a non empty list.
            node.prevKeyIsSet = true;
            node.prevKey = list.tail;
            let tail = table::borrow_mut(&mut list.nodes, list.tail);
            list.tail = key;
            tail.nextKey = key;
            tail.nextKeyIsSet = true;

            table::add(&mut list.nodes, key, node);
            list.length = list.length + 1;
            return
        };

        let i = 0;
        let it = iterator(list);
        while (i <= list.length) {
            if (i == idx) {
                if (i < list.length) {
                    // Inserting at the beginning or middle of list.
                    let targetKey = peek_next_node(list, &it).key;
                    let targetNode = table::borrow_mut(&mut list.nodes, targetKey);
                    let targetNodePrevKey = targetNode.prevKey;
                    let targetNodePrevKeyIsSet = targetNode.prevKeyIsSet;
                    node.nextKey = targetKey;
                    node.nextKeyIsSet = true;
                    targetNode.prevKey = key;
                    targetNode.prevKeyIsSet = true;
                    if (targetNodePrevKeyIsSet) {
                        let targetNodePrev = table::borrow_mut(&mut list.nodes, targetNodePrevKey);
                        targetNodePrev.nextKeyIsSet = true;
                        targetNodePrev.nextKey = key;
                        node.prevKey = targetNodePrevKey;
                        node.prevKeyIsSet = true;
                    };
                    if (i == 0) {
                        list.head = key;
                    }
                };
                break
            };
            get_next(list, &mut it);
            i = i + 1;
        };

        table::add(&mut list.nodes, key, node);
        list.length = list.length + 1;
    }

    /// Removes a value from the list. If there are duplicates, a random occurence is removed.
    public fun remove<V: store + copy + drop>(list: &mut LinkedList<V>, value: V) {
        assert!(list.length > 0, EMPTY_LIST);
        assert!(table::contains(&list.nodeKeys, value), VALUE_NOT_FOUND);

        let idxVector = table::borrow(&mut list.nodeKeys, value);
        remove_key(list, *vector::borrow(idxVector, 0));
    }

    /// Remove the first element of the list. If the list is empty, will throw an error.
    public fun remove_first<V: store + copy + drop>(list: &mut LinkedList<V>) {
        assert!(list.length > 0, EMPTY_LIST);
        let headKey = list.head;
        remove_key(list, headKey);
    }

    /// Remove the last element of the list. If the list is empty, will throw an error.
    public fun remove_last<V: store + copy + drop>(list: &mut LinkedList<V>) {
        assert!(!is_empty(list), EMPTY_LIST);
        let tailKey = list.tail;
        remove_key(list, tailKey);
    }

    /// Get a reference to the first element of the list.
    public fun borrow_first<V: store + copy + drop>(list: &LinkedList<V>): &V {
        assert!(!is_empty(list), EMPTY_LIST);
        let node = table::borrow(&list.nodes, list.head);
        &node.value
    }

    /// Get a reference to the last element of the list.
    public fun borrow_last<V: store + copy + drop>(list: &LinkedList<V>): &V {
        assert!(!is_empty(list), EMPTY_LIST);
        let node = table::borrow(&list.nodes, list.tail);
        &node.value
    }

    /// Returns true is the element is in the list.
    public fun contains<V: store + copy + drop>(list: &LinkedList<V>, value: V): bool {
        table::contains(&list.nodeKeys, value)
    }

    /// Returns the length of the list.
    public fun length<V: store + copy + drop>(list: &LinkedList<V>): u128 {
        list.length
    }

    /// Returns true if empty.
    public fun is_empty<V: store + copy + drop>(list: &LinkedList<V>): bool {
        return list.length == 0
    }

    /// Returns the list as a vector.
    public fun as_vector<V: store + copy + drop>(list: &LinkedList<V>): vector<V> {
        let out = vector::empty();
        let it = iterator(list);
        while (has_next(&it)) {
            vector::push_back(&mut out, get_next(list, &mut it));
        };
        out
    }

    /// Returns a left to right iterator. First time you call next(...) will return the first value.
    /// Updating the list while iterating will abort.
    public fun iterator<V: store + copy + drop>(list: &LinkedList<V>): ListPosition<V> {
        if (is_empty(list)) {
            return ListPosition<V> {
                currentKey: 0,
                hasNextKey: false,
                completed: true,
            }
        };
        ListPosition<V> {
            currentKey: list.head,
            hasNextKey: list.head != list.tail,
            completed: false,
        }
    }

    /// Returns true if there is another element left in the iterator.
    public fun has_next<V: store + copy + drop>(position: &ListPosition<V>): bool {
        !position.completed
    }

    /// Returns the next value, and updates the current position.
    public fun get_next<V: store + copy + drop>(list: &LinkedList<V>, position: &mut ListPosition<V>): V {
        assert!(has_next(position), MUST_HAVE_NEXT_VALUE);
        let node = get_node(list, position.currentKey);
        position.currentKey = node.nextKey;
        position.completed = !position.hasNextKey;
        position.hasNextKey = if (position.hasNextKey) get_node(list, node.nextKey).nextKeyIsSet else false;
        node.value
    }

    /// Returns a reference to the next value in the iterator. The iterator position is not updated.
    public fun peek_next<V: store + copy + drop>(list: &LinkedList<V>, position: &ListPosition<V>): &V {
        &peek_next_node(list, position).value
    }

    /// Empties out the list and drops all values.
    public fun drop<V: store + copy + drop>(list: LinkedList<V>) {
        empty_list(&mut list);
        let LinkedList<V>{
            nodes,
            nodeKeys,
            keyCounter: _,
            length: _,
            head: _,
            tail: _
        } = list;
        table::destroy_empty(nodes);
        table::destroy_empty(nodeKeys);
    }

    //
    // Private Helpers
    //

    fun peek_next_node<V: store + copy + drop>(list: &LinkedList<V>, position: &ListPosition<V>): &Node<V> {
        assert!(has_next(position), MUST_HAVE_NEXT_VALUE);
        get_node(list, position.currentKey)
    }

    fun empty_list<V: store + copy + drop>(list: &mut LinkedList<V>) {
        while (length(list) > 0) {
            remove_first(list);
        }
    }

    fun get_node<V: store + copy + drop>(list: &LinkedList<V>, key: u128): &Node<V> {
        table::borrow(&list.nodes, key)
    }

    fun remove_key<V: store + copy + drop>(list: &mut LinkedList<V>, key: u128) {
        assert!(table::contains(&list.nodes, key), KEY_NOT_FOUND);

        let node = table::remove(&mut list.nodes, key);
        list.length = list.length - 1;

        let idxVector = table::borrow_mut(&mut list.nodeKeys, node.value);
        let (_, idx) = vector::index_of(idxVector, &key);
        vector::swap_remove(idxVector, idx);
        if (vector::length(idxVector) == 0) {
            table::remove(&mut list.nodeKeys, node.value);
        };

        // Update prev node.
        if (node.prevKeyIsSet) {
            let prev = table::borrow_mut(&mut list.nodes, node.prevKey);
            prev.nextKeyIsSet = node.nextKeyIsSet;
            prev.nextKey = node.nextKey;
        };

        // Update next node.
        if (node.nextKeyIsSet) {
            let next = table::borrow_mut(&mut list.nodes, node.nextKey);
            next.prevKeyIsSet = node.prevKeyIsSet;
            next.prevKey = node.prevKey;
        };

        // Update the list.
        if (list.head == key) {
            list.head = node.nextKey;
        };
        if (list.tail == key) {
            list.tail = node.prevKey;
        };
    }

    #[test]
    fun test_list_iteration_with_empty_list() {
        let list = new<u128>();
        let it = iterator(&list);
        assert!(!has_next(&it), 0);
        drop(list);
    }

    #[test]
    fun test_list_iteration_with_one_value() {
        let list = new<u128>();
        add(&mut list, 1);

        // First value.
        let iterator = iterator(&list);
        assert!(has_next(&iterator), 0);
        let value = get_next(&list, &mut iterator);
        assert!(value == 1, 0);
        assert!(!has_next(&iterator), 0);

        drop(list);
    }

    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_list_iteration_invalid_call_to_next() {
        let list = new<u128>();
        add(&mut list, 1);
        let iterator = iterator(&list);
        get_next(&list, &mut iterator);
        get_next(&list, &mut iterator);
        drop(list);
    }

    #[test]
    fun test_as_vector() {
        let list = new<u128>();
        add(&mut list, 1);
        add(&mut list, 2);
        add(&mut list, 2);
        add(&mut list, 1);

        assert!(as_vector(&list) == vector<u128>[1, 2, 2, 1], 0);

        drop(list);
    }

    #[test]
    fun test_list_iteration_with_two_values() {
        let list = new<u128>();
        add(&mut list, 1);
        add(&mut list, 2);

        // First value.
        let iterator = iterator(&list);
        assert!(has_next(&iterator), 0);
        let value = get_next(&list, &mut iterator);
        assert!(value == 1, 0);
        assert!(has_next(&iterator), 0);

        // Second value.
        let value = get_next(&list, &mut iterator);
        assert!(value == 2, 0);
        assert!(!has_next(&iterator), 0);

        drop(list);
    }

    #[test]
    fun test_list_iteration_with_many_values() {
        let list = new<u128>();
        add(&mut list, 1);
        add(&mut list, 2);
        add(&mut list, 2);
        add(&mut list, 1);

        let  iterator = iterator(&list);
        
        // First value.
        assert!(has_next(&iterator), 0);
        let value = get_next(&list, &mut iterator);
        assert!(value == 1, 0);
        assert!(has_next(&iterator), 0);

        // Second value.
        let value = get_next(&list, &mut iterator);
        assert!(value == 2, 0);
        assert!(has_next(&iterator), 0);

        // Third value.
        let value = get_next(&list, &mut iterator);
        assert!(value == 2, 0);
        assert!(has_next(&iterator), 0);

        // Fourth value.
        let value = get_next(&list, &mut iterator);
        assert!(value == 1, 0);


        // Should not have any more values!
        assert!(!has_next(&iterator), 0);

        drop(list);
    }

    #[test]
    fun test_linked_list_duplicate_values() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 5);
        add(&mut list, 4);
        add(&mut list, 1);
        add(&mut list, 5);
        assert_list(&list, b"5 <-> 1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 5 <-> 4 <-> 1 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 4");

        drop(list);
    }

    #[test]
    fun test_linked_list_all_duplicate_values() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        add(&mut list, 5);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5 <-> 5");
        remove_first(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 5");
        remove_last(&mut list);
        assert_list(&list, b"5");
        remove_last(&mut list);
        assert_list(&list, b"");

        drop(list);
    }

    #[test]
    fun test_linked_list_add_remove_first() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"1 <-> 4");
        remove_first(&mut list);
        assert_list(&list, b"4");
        remove_first(&mut list);
        assert_list(&list, b"");

        drop(list);
    }

    #[test]
    fun test_linked_list_insert_at() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        assert_list(&list, b"5 <-> 1 <-> 4");
        insert_at(&mut list, 7, 1);
        assert_list(&list, b"5 <-> 7 <-> 1 <-> 4");
        insert_at(&mut list, 8, 0);
        assert_list(&list, b"8 <-> 5 <-> 7 <-> 1 <-> 4");
        insert_at(&mut list, 10, 5);
        assert_list(&list, b"8 <-> 5 <-> 7 <-> 1 <-> 4 <-> 10");

        drop(list);
    }

    #[test]
    fun test_linked_list_insert_at_middle() {
        let list = new<u128>();
        insert_at(&mut list, 1, 0);
        insert_at(&mut list, 1000, 1);
        insert_at(&mut list, 100, 1);
        insert_at(&mut list, 10, 1);
        assert_list(&list, b"1 <-> 10 <-> 100 <-> 1000");

        drop(list);
    }

    #[test]
    fun test_linked_list_add_remove_last() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        assert_list(&list, b"5 <-> 1 <-> 4");
        remove_last(&mut list);
        assert_list(&list, b"5 <-> 1");
        remove_last(&mut list);
        assert_list(&list, b"5");
        remove_last(&mut list);
        assert_list(&list, b"");

        drop(list);
    }

    #[test]
    fun test_linked_list_add_remove_value() {
        let list = new<u128>();
        add(&mut list, 5);
        add(&mut list, 1);
        add(&mut list, 4);
        add(&mut list, 1);
        remove(&mut list, 1);
        let listStr = *string::bytes(&list_as_string(&list));
        assert!(listStr == b"5 <-> 1 <-> 4" || listStr == b"5 <-> 4 <-> 1", 0);

        drop(list);
    }

    #[test]
    #[expected_failure]
    fun test_linked_list_remove_last_on_empty() {
        let list = new<u128>();
        remove_last(&mut list);

        drop(list);
    }

    #[test]
    #[expected_failure]
    fun test_linked_list_remove_first_on_empty() {
        let list = new<u128>();
        remove_first(&mut list);

        drop(list);
    }

    //
    // Test helpers.
    //

    #[test_only]
    public fun assert_list(list: &LinkedList<u128>, expected: vector<u8>) {
        assert!(list_as_string(list) == string::utf8(expected), 0);
    }

    #[test_only]
    public fun print_list(list: &LinkedList<u128>) {
        std::debug::print(&list_as_string(list));
    }

    #[test_only]
    public fun list_as_string(list: &LinkedList<u128>): String {
        let output = string::utf8(b"");

        if (length(list) == 0) {
            return output
        };

        let curr = get_node(list, list.head);
        string::append(&mut output, to_string_u128(curr.value));
        while (curr.nextKeyIsSet) {
            string::append_utf8(&mut output, b" <->");
            curr = get_node(list, curr.nextKey);
            string::append_utf8(&mut output, b" ");
            string::append(&mut output, to_string_u128(curr.value));
        };
        output
    }
}
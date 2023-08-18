```rust
/// # Module-level documentation sections
///
/// * [Background](#Background)
/// * [Implementation](#Implementation)
/// * [Basic public functions](#Basic-public-functions)
/// * [Traversal](#Traversal)
///
/// # Background
///
/// A rbtree (red black tree) is a kind of self-balancing binary search tree.
/// Each node stores an extra bit representing "color" ("red" or "black"), used
/// to ensure that the tree remains balanced during insertions and deletions.
/// When the tree is modified, the new tree is rearranged and "repainted" to 
/// restore the coloring properties that constrain how unbalanced the tree can 
/// become in the worst case. The properties are designed such that this rearranging 
/// and recoloring can be performed efficiently.
/// The re-balancing is not perfect, but guarantees searching in O(logn) time, 
/// where n is the number of entries. The insert and delete operations, along 
/// with the tree rearrangement and recoloring, are also performed in O(logn) time.
///
/// code:
/// https://github.com/torvalds/linux/blob/master/include/linux/rbtree.h
/// https://github.com/torvalds/linux/blob/master/include/linux/rbtree_types.h
/// https://github.com/tickbh/rbtree-rs
/// 
module sealib::rbtree {
    use std::vector;
    // use std::debug;

    // Structs ====================================================
    
    /// A rbtree node
    struct RBNode<V> has store, drop {
        // color is the first 1 bit
        // pos is the follow 31 bits
        // parent is the last 32 bits
        color_parent: u64,
        // left is the first 32 bits
        // right is the last 32 bits
        left_right: u64,
        // this is the key of the node, just use u128 for simplity and storage efficient
        key: u128,
        value: V
    }

    /// A rbtree for key-value pairs with value type `V`
    /// all vector index + 1
    /// nodes should less than 0x7fffffff
    struct RBTree<V> has store {
        /// the less is on left side
        left_is_less: bool,
        /// Root node index
        root: u64,
        /// the left most node index
        leftmost: u64,
        nodes: vector<RBNode<V>>
    }

    // Constants ====================================================
    const U64_MASK: u64 = 0xffffffffffffffff;
    const COLOR_MASK: u64 = 0x8000000000000000;
    const POS_MASK: u64 = 0x7fffffff00000000;
    const PARENT_MASK: u64 = 0x00000000ffffffff;
    const PARENT_CLEAR_MASK: u64 = 0xffffffff00000000;
    const POSITION_CLEAR_MASK: u64 = 0x80000000ffffffff;
    const LEFT_MASK: u64  = 0xffffffff00000000;
    const RIGHT_MASK: u64 = 0x00000000ffffffff;
    const RED: u64 = 0x8000000000000000;
    const BLACK: u64 = 0;
    const BLACK_MASK: u64 = 0x7fffffffffffffff;
    const RED_NULL_PARENT: u64 = 0x8000000000000000;
    const BLACK_NULL_PARENT: u64 = 0x0;
    const NULL_LEFT_RIGHT: u64 = 0x0;
    const MAX_NODES_LEN: u64 = 0x7fffffff;

    // Errors ====================================================
    const E_INSERT_FULL: u64       = 1;
    const E_DUP_KEY: u64           = 2;
    const E_NOT_FOUND_KEY: u64     = 3;
    const E_INVALID_CHILD_POS: u64 = 4;
    const E_NOT_EXIST: u64         = 5;
    const E_REMOVE_EMPTY_TREE: u64 = 6;

    // Public functions ====================================================

    /// Return an empty tree
    public fun empty<V>(left_is_less: bool): RBTree<V> {
        RBTree{
            left_is_less,
            root: 0,
            leftmost: 0,
            nodes: vector::empty<RBNode<V>>()
        }
    }

    /// Return a tree with one node having `key` and `value`
    public fun singleton<V>(
        left_is_less: bool,
        key: u128,
        value: V
    ): RBTree<V> {
        RBTree{
            left_is_less: left_is_less,
            root: 1,
            leftmost: 1,
             // the root node is BLACK node
            nodes: vector::singleton<RBNode<V>>(create_rb_node(false, 1, key, value))
        }
    }

    /// Return `true` if `tree` has no outer nodes
    public fun is_empty<V>(tree: &RBTree<V>): bool {
        vector::is_empty<RBNode<V>>(&tree.nodes)
    }

    /// Return length of tree
    public fun length<V>(tree: &RBTree<V>): u64 {
        vector::length<RBNode<V>>(&tree.nodes)
    }

    public fun get_leftmost_key<V>(
        tree: &RBTree<V>
    ): u128 {
        let pos = tree.leftmost;
        let node = vector::borrow<RBNode<V>>(&tree.nodes, pos-1);
        node.key
    }

    public fun get_leftmost_pos_key<V>(
        tree: &RBTree<V>
    ): (u64, u128) {
        let pos = tree.leftmost;
        let node = vector::borrow<RBNode<V>>(&tree.nodes, pos-1);
        (get_position(node.color_parent), node.key)
    }

    public fun get_leftmost_pos_key_val<V>(
        tree: &RBTree<V>
    ): (u64, u128, &V) {
        let pos = tree.leftmost;
        let node = vector::borrow<RBNode<V>>(&tree.nodes, pos-1);
        (get_position(node.color_parent), node.key, &node.value)
    }

    // return (pos, key)
    // if pos is 0, it has not next
    public fun get_next_pos_key<V>(
        tree: &RBTree<V>,
        pos: u64): (u64, u128) {
        let next = next_pos(tree, pos);
        if (next == 0) {
            return (0, 0)
        };
        let node = get_node<V>(&tree.nodes, next);
        (next, node.key)
    }

    /// Return immutable reference to value corresponding to position `pos` in
    /// `tree`, abort if the tree is empty
    public fun borrow_by_pos<V>(
        tree: &RBTree<V>,
        pos: u64): &V {
        // let next = next_pos(tree, pos);
        // assert!(next > 0, E_NOT_EXIST);
        let node = get_node<V>(&tree.nodes, pos);
        &node.value
    }

    public fun borrow_leftmost_mut<V>(tree: &mut RBTree<V>): &mut RBNode<V> {
        let pos = tree.leftmost;
        vector::borrow_mut<RBNode<V>>(&mut tree.nodes, pos-1)
    }

    public fun borrow_leftmost_keyval_mut<V>(tree: &mut RBTree<V>): (u64, u128, &mut V) {
        let pos = tree.leftmost;
        let node = vector::borrow_mut<RBNode<V>>(&mut tree.nodes, pos-1);
        (get_position(node.color_parent), node.key, &mut node.value)
    }

    public fun pop_leftmost<V>(tree: &mut RBTree<V>): (u128, V) {
        let pos = tree.leftmost;
        rb_remove_by_pos(tree, pos)
    }

    /// insert a new node with key & value
    public fun rb_insert<V>(
        tree: &mut RBTree<V>,
        key: u128,
        value: V) {
        assert!(length<V>(tree) < MAX_NODES_LEN, E_INSERT_FULL);

        let node: RBNode<V>;
        if (is_empty(tree)) {
            // the root node is BLACK
            node = create_rb_node(false, 1, key, value);
            tree.leftmost = 1;
            tree.root = 1;
            // push value, rbnode to vector
            vector::push_back(&mut tree.nodes, node);
        } else {
            let pos = length(tree)+1;
            node = create_rb_node(true, pos, key, value);
            // push value, rbnode to vector
            vector::push_back(&mut tree.nodes, node);
            rb_insert_node(tree, pos, key);
        };
    }

    /// find node position
    public fun rb_find<V>(
        tree: &RBTree<V>,
        key: u128): u64 {
        if (is_empty(tree)) {
            return 0
        };
        let idx = tree.root;
        loop {
            let node = get_node(&tree.nodes, idx);
            if (key == node.key) {
                return idx
            };
            if (tree.left_is_less) {
                if (key < node.key) {
                    idx = get_left_index(node.left_right);
                } else {
                    idx = get_right_index(node.left_right);
                };
            } else {
                if (key > node.key) {
                    idx = get_left_index(node.left_right);
                } else {
                    idx = get_right_index(node.left_right);
                };
            };
            if (idx == 0) {
                return 0
            }
        }
    }

    public fun rb_remove_by_key<V>(
        tree: &mut RBTree<V>,
        key: u128): RBNode<V> {
        let pos = rb_find(tree, key);
        // if (pos == 0) {
        //     return
        // };
        assert!(pos > 0, E_NOT_EXIST);

        rb_remove_node(tree, pos)
    }

    public fun rb_remove_by_pos<V>(
        tree: &mut RBTree<V>,
        pos: u64): (u128, V) {
        // if (is_empty(tree)) {
        //     return
        // };
        assert!(!is_empty(tree), E_REMOVE_EMPTY_TREE);
        let RBNode<V> {
            color_parent: _,
            left_right: _,
            key: key,
            value: v } = rb_remove_node(tree, pos);
        (key, v)
    }

    // Private functions ====================================================

    fun is_red(color: u64): bool {
        color & COLOR_MASK == RED
    }

    fun is_black(color: u64): bool {
        color & COLOR_MASK == BLACK
    }

    fun get_left_index(index: u64): u64 {
        (index & LEFT_MASK) >> 32
    }

    fun get_right_index(index: u64): u64 {
        index & RIGHT_MASK
    }

    fun get_left_right_index(index: u64): (u64, u64) {
        ((index & LEFT_MASK) >> 32, index & RIGHT_MASK)
    }

    fun get_parent_index(index: u64): u64 {
        index & PARENT_MASK
    }

    fun get_position(index: u64): u64 {
        (index & POS_MASK) >> 32
    }

    /// create a RBNode, without parent, left, right links
    fun create_rb_node<V>(
        is_red: bool,
        pos: u64,
        key: u128,
        val: V): RBNode<V> {
        let color_parent: u64;
        if (is_red) {
            color_parent = RED_NULL_PARENT | (pos << 32);
        } else {
            color_parent = (pos << 32);
        };
        RBNode{
            color_parent: color_parent,
            left_right: NULL_LEFT_RIGHT,
            key: key,
            value: val
        }
    }

    // get node info
    fun get_node_info<V>(node: &RBNode<V>): (
        bool,
        u64,
        u64,
        u64,
        u64
    ) {
        (
            is_red(node.color_parent),
            get_position(node.color_parent),
            get_parent_index(node.color_parent),
            get_left_index(node.left_right),
            get_right_index(node.left_right)
        )
    }

    fun get_node_info_by_pos<V>(
        nodes: &vector<RBNode<V>>,
        node_pos: u64): (
        bool,
        u64,
        u64,
        u64
    ) {
        let node = get_node(nodes, node_pos);
        (
            is_red(node.color_parent),
            get_parent_index(node.color_parent),
            get_left_index(node.left_right),
            get_right_index(node.left_right)
        )
    }

    // tree is NOT empty
    fun rb_remove_node<V>(
        tree: &mut RBTree<V>,
        pos: u64): RBNode<V> {
        let node_pos = pos;
        let (
            node_is_red,
            node_parent_pos,
            node_left_pos,
            node_right_pos) = get_node_info_by_pos(&tree.nodes, pos);
        let nodes = &mut tree.nodes;
        let child_pos: u64;
        let parent_pos: u64;

        if (pos == tree.leftmost) {
            // if it has right pos, set to right pos
            if (node_right_pos > 0) {
                    let leftest = get_node_least_node(nodes, node_right_pos);
                    tree.leftmost = get_position(leftest.color_parent);
            } else if (node_parent_pos > 0) {
                tree.leftmost = node_parent_pos;
            } else {
                // here, the tree is empty
                tree.leftmost = 0;
            }
        };

        // both left child and right child is NOT null
        if (node_left_pos != 0 && node_right_pos != 0) {
            let (
                replace_is_red,
                replace_pos,
                replace_parent_pos,
                _,
                right_child_pos) = get_node_info(get_node_least_node(nodes, node_right_pos));
            // let replace_pos = get_position(replace.color_parent);
            if (is_root(tree.root, node_pos)) {
                tree.root = replace_pos;
            } else {
                let node_parent = get_node_mut(nodes, node_parent_pos);
                if (is_left_child(node_parent.left_right, node_pos)) {
                    set_node_left(node_parent, replace_pos);
                } else {
                    set_node_right(node_parent, replace_pos);
                }
            };

            if (node_pos == replace_parent_pos) {
                parent_pos = replace_pos;
            } else {
                if (right_child_pos != 0) {
                    // set child parent
                    let child = get_node_mut(nodes, right_child_pos);
                    set_node_parent(child, replace_parent_pos);
                };
                parent_pos = replace_parent_pos;
                // set replace parent's left child
                let parent = get_node_mut(nodes, replace_parent_pos);
                set_node_left(parent, right_child_pos);
                // set replace node right child
                // set node right child parent to replace
                set_parent_child_rel(nodes, replace_pos, node_right_pos, false);
            };

            // set replace parent, color, left node
            let replace_node = get_node_mut(nodes, replace_pos);
            set_node_parent(replace_node, node_parent_pos);
            set_node_color(replace_node, node_is_red);
            set_node_left(replace_node, node_left_pos);
            let node_left_child = get_node_mut(nodes, node_left_pos);
            set_node_parent<V>(node_left_child, replace_pos);

            // 12-17 right_child_pos may be 0
            if ((!replace_is_red) && (right_child_pos > 0)) {
            // if ((!replace_is_red) ) {
                rb_delete_rebalance(tree, right_child_pos, parent_pos);
            };
            // last vector swap
            return remove_node_from_vector(tree, pos)
        };

        if (node_left_pos != 0) {
            child_pos = node_left_pos; //get_left_index(node.left_right);
        } else {
            child_pos = node_right_pos; // get_right_index(node.left_right);
        };
        parent_pos = node_parent_pos; // get_parent_index(node.color_parent);
        if (child_pos != 0) {
            let child = get_node_mut(nodes, child_pos);
            set_node_parent(child, parent_pos);
        };
        if (is_root(tree.root, node_pos)) {
            tree.root = child_pos;
        } else {
            let parent = get_node_mut(nodes, parent_pos);
            if (is_left_child(parent.left_right, node_pos)) {
                set_node_left(parent, child_pos);
            } else {
                set_node_right(parent, child_pos);
            }
        };
        if (child_pos != 0 && (!node_is_red)) {
            rb_delete_rebalance(tree, child_pos, parent_pos);
        };
        remove_node_from_vector(tree, pos)
    }

    fun remove_node_from_vector<V>(
        tree: &mut RBTree<V>,
        pos: u64): RBNode<V> {
        let nodes = &mut tree.nodes;
        if (pos == vector::length(nodes)) {
            let nodes = &mut tree.nodes;
            // the node is last vector item, just pop it
            let node = vector::pop_back(nodes);
            return node
        };

        let nodes = &mut tree.nodes;
        let v_len = vector::length(nodes);
        let (
            _,
            last_node_parent_pos,
            last_node_left_pos,
            last_node_right_pos) = get_node_info_by_pos(nodes, v_len);

        if (last_node_parent_pos > 0) {
            let parent = get_node_mut(nodes, last_node_parent_pos);
            let (parent_left_child_pos, parent_right_child_pos) = get_left_right_index(parent.left_right);
            if (parent_left_child_pos == v_len) {
                set_node_left(parent, pos);
            } else {
                assert!(parent_right_child_pos == v_len, E_INVALID_CHILD_POS);
                set_node_right(parent, pos);
            }
        };
        if (last_node_left_pos > 0) {
            set_node_parent_by_pos(nodes, last_node_left_pos, pos);
        };
        if (last_node_right_pos > 0) {
            set_node_parent_by_pos(nodes, last_node_right_pos, pos)
        };
        // update node position to new postion
        let last_node = get_node_mut(nodes, v_len);
        set_node_position(last_node, pos);

        let removed = vector::swap_remove(nodes, pos-1);
        if (tree.root == v_len) {
            tree.root = pos;
        };
        if (tree.leftmost == v_len) {
            tree.leftmost = pos;
        };
        removed
    }

    fun is_black_node<V>(
        nodes: &vector<RBNode<V>>,
        pos: u64): bool {
        if (pos == 0) {
            return true
        };
        let node   = get_node(nodes, pos);
        is_black(node.color_parent)
    }

    fun get_child_color_is_black<V>(
        nodes: &vector<RBNode<V>>,
        left_pos: u64,
        right_pos: u64): (bool, bool) {
        let left_is_black = true;
        let right_is_black = true;
        if (left_pos != 0) {
            let node   = get_node(nodes, left_pos);
            left_is_black = is_black(node.color_parent);
        };
        if (right_pos != 0) {
            let node = get_node(nodes, right_pos);
            right_is_black = is_black(node.color_parent);
        };
        (left_is_black, right_is_black)
    }

    fun rb_delete_rebalance<V>(
        tree: &mut RBTree<V>,
        node_pos: u64,
        parent_pos: u64) {
        let (node_is_red,
            _,
            _,
            _) = get_node_info_by_pos(&tree.nodes, node_pos);

        while ((!is_root(tree.root, node_pos)) && (!node_is_red)) {
            let (
                parent_is_red,
                parent_parent_pos,
                parent_left_pos,
                parent_right_pos) = get_node_info_by_pos(&tree.nodes, parent_pos);
            
            if (parent_left_pos == node_pos) {
                let other_pos = parent_right_pos;
                let (
                    other_is_red,
                    other_parent_pos,
                    other_left_pos,
                    other_right_pos
                ) = get_node_info_by_pos(&tree.nodes, parent_right_pos);
                // other = get_node_mut(&mut tree.nodes, parent_right_pos); // get_right_index(parent.left_right));
                if (other_is_red) {
                    set_black_color(get_node_mut(&mut tree.nodes, other_pos));
                    // let parent = get_node_mut(&mut tree.nodes, parent_pos);
                    set_red_color(get_node_mut(&mut tree.nodes, parent_pos));
                    left_rotate(tree, parent_pos, parent_parent_pos, parent_right_pos); // get_node_mut(&mut tree.nodes, parent_pos));
                    // let other = get_node_mut(&mut tree.nodes, parent_right_pos); // get_right_index(parent.left_right));
                    other_pos = parent_right_pos;
                    (
                        _,
                        other_parent_pos,
                        other_left_pos,
                        other_right_pos
                    ) = get_node_info_by_pos(&tree.nodes, other_pos);
                };

                // both left and right child is black 
                let (left_is_black, right_is_black) = get_child_color_is_black(&tree.nodes, other_left_pos, other_right_pos);
                if (left_is_black && right_is_black) {
                    set_red_color(get_node_mut(&mut tree.nodes, other_pos));
                    // node  = parent;
                    node_pos = parent_pos; // get_position(parent.color_parent);
                    node_is_red = is_red(get_node(&tree.nodes, node_pos).color_parent);
                    parent_pos = parent_parent_pos;
                } else {
                    // x brother w is black, and w left child is red, right child is black
                    if (right_is_black) {
                        set_node_color_by_pos(&mut tree.nodes, other_left_pos, false);
                        set_red_color(get_node_mut(&mut tree.nodes, other_pos));
                        right_rotate(tree, other_pos, other_parent_pos, other_left_pos);
                        other_pos = parent_right_pos; // get_right_index(parent.left_right);
                        // other = get_node_mut(nodes, get_right_index(parent.left_right)); 
                    };
                    if (other_pos != 0) {
                        set_node_color_by_pos(&mut tree.nodes, other_pos, parent_is_red); // is_red(parent.color_parent));
                        let other = get_node_mut(&mut tree.nodes, other_pos);
                        set_node_color_by_pos(&mut tree.nodes, get_right_index(other.left_right), false);
                    };
                    let parent = get_node_mut(&mut tree.nodes, parent_pos);
                    set_black_color(parent);
                    left_rotate(tree,
                        get_position(parent.color_parent),
                        get_parent_index(parent.color_parent),
                        get_right_index(parent.left_right));
                    // node = get_node_mut(nodes_mut, tree.root);
                    node_pos = tree.root;
                    break
                }
            } else {
                let other_pos = parent_left_pos;
                let (
                    other_is_red,
                    other_parent_pos,
                    other_left_pos,
                    other_right_pos
                ) = get_node_info_by_pos(&tree.nodes, parent_left_pos);
                // other = get_node_mut(&mut tree.nodes, parent_left_pos); // get_left_index(parent.left_right));
                if (other_is_red) {
                    set_black_color(get_node_mut(&mut tree.nodes, other_pos));
                    let parent = get_node_mut(&mut tree.nodes, parent_pos);
                    set_red_color(parent);
                    right_rotate(tree, parent_pos, parent_parent_pos, parent_left_pos);
                    other_pos = parent_left_pos;
                    (
                        _,
                        other_parent_pos,
                        other_left_pos,
                        other_right_pos
                    ) = get_node_info_by_pos(&tree.nodes, parent_left_pos);
                };

                let (left_is_black, right_is_black) = get_child_color_is_black(&tree.nodes, other_left_pos, other_right_pos);
                if (left_is_black && right_is_black) {
                    set_red_color(get_node_mut(&mut tree.nodes, other_pos));
                    node_pos = parent_pos; // get_position(node.color_parent);
                    node_is_red = is_red(get_node(&tree.nodes, node_pos).color_parent);
                    parent_pos = parent_parent_pos;
                } else {
                    if (left_is_black) {
                        set_node_color_by_pos(&mut tree.nodes, other_right_pos, false);
                        set_red_color(get_node_mut(&mut tree.nodes, other_pos));
                        left_rotate(tree, other_pos, other_parent_pos, other_right_pos);
                        other_pos = parent_left_pos;
                    };
                    if (other_pos != 0) {
                        set_node_color_by_pos(&mut tree.nodes, other_pos, parent_is_red);
                        let other = get_node_mut(&mut tree.nodes, other_pos);
                        set_node_color_by_pos(&mut tree.nodes, get_left_index(other.left_right), false);
                    };
                    let parent = get_node_mut(&mut tree.nodes, parent_pos);
                    set_black_color(parent);
                    right_rotate(tree, parent_pos, parent_parent_pos, parent_left_pos);
                    // node = get_node_mut(nodes_mut, tree.root);
                    node_pos = tree.root;
                    break
                }
            }
        };
        
        set_black_color(get_node_mut(&mut tree.nodes, node_pos));
    }

    fun set_node_color<V>(
        node: &mut RBNode<V>,
        is_red: bool) {
        if (is_red) {
            set_red_color(node);
        } else {
            set_black_color(node);
        }
    }

    fun set_node_color_by_pos<V>(
        nodes: &mut vector<RBNode<V>>,
        pos: u64,
        is_red: bool) {
        if (pos == 0) {
            return
        };
        let node = get_node_mut(nodes, pos);
        if (is_red) {
            set_red_color(node);
        } else {
            set_black_color(node);
        }
    }

    // left child is black or nil
    fun is_left_child_black<V>(
        nodes: &vector<RBNode<V>>,
        node: &RBNode<V>): bool {
        let left = get_left_index(node.left_right);
        if (left == 0) {
            return true
        };
        let left_node = get_node(nodes, left);
        return is_black(left_node.color_parent)
    }

    fun is_right_child_black<V>(
        nodes: &vector<RBNode<V>>,
        node: &RBNode<V>): bool {
        let right = get_right_index(node.left_right);
        if (right == 0) {
            return true
        };
        let right_node = get_node(nodes, right);
        return is_black(right_node.color_parent)
    }

    fun get_node_least_node<V>(
        nodes: &vector<RBNode<V>>,
        pos: u64): &RBNode<V> {
        // let tmp: &RBNode<V> = node;
        loop {
            let left_right = get_node(nodes, pos).left_right;
            let left = get_left_index(left_right);
            if (left == 0) {
                return get_node(nodes, pos)
            };
            pos = left;
        }
    }

    fun get_node_least_pos<V>(
        nodes: &vector<RBNode<V>>,
        pos: u64): u64 {
        // let tmp: &RBNode<V> = node;
        loop {
            let left_right = get_node(nodes, pos).left_right;
            let left = get_left_index(left_right);
            // debug::print(&left);
            if (left == 0) {
                return pos
            };
            pos = left;
        }
    }

    // color: is_black
    fun get_node_key_children_color<V>(
        nodes: &vector<RBNode<V>>,
        pos: u64): (u128, u64, bool) {
        let node = get_node(nodes, pos);
        (node.key, node.left_right, is_black(node.color_parent))
    }

    /// insert/link node into the rbtree
    fun rb_insert_node<V>(
        tree: &mut RBTree<V>,
        node_pos: u64,
        key: u128) {
        // here, the tree should NOT be empty
        let parent_pos = tree.root;
        // let parent: &mut RBNode<V>;
        let is_least = true;
        let parent_key: u128;
        let left_right: u64;
        let is_black: bool;

        // find the parent
        loop {
            (parent_key, left_right, is_black) = get_node_key_children_color(&tree.nodes, parent_pos);
            assert!(key != parent_key, E_DUP_KEY);
            // debug::print(&parent_key);
            // debug::print(&parent_pos);
            // debug::print(&left_right);
            if ( (tree.left_is_less && key < parent_key) ||
                (tree.left_is_less == false && key > parent_key)) {
                // left
                let left = get_left_index(left_right);
                if (left == 0) {
                    set_parent_child_rel(&mut tree.nodes, parent_pos, node_pos, true);
                    break
                };
                parent_pos = left;
            } else {
                is_least = false;
                // right
                let right = get_right_index(left_right);
                if (right == 0) {
                    set_parent_child_rel(&mut tree.nodes, parent_pos, node_pos, false);
                    break
                };
                parent_pos = right;
            }
        };
        if (is_least) {
            // set_leftmost_index(tree, node_pos);
            tree.leftmost = node_pos;
        };
        if (is_black) {
            // the parent is BLACK node, done
            return
        };

        // rebalance the rbtree
        rb_insert_rebalance<V>(tree, parent_pos, node_pos);
    }

    fun is_left_child(left_right: u64, child_pos: u64): bool {
        get_left_index(left_right) == child_pos
    }

    fun is_right_child(left_right: u64, child_pos: u64): bool {
        get_right_index(left_right) == child_pos
    }

    /// set grandad color to red, set parent and uncle color to black
    fun flip_color<V>(
        nodes: &mut vector<RBNode<V>>,
        grandad_pos: u64,
        parent_pos: u64,
        uncle_pos: u64) {
        set_red_color(get_node_mut(nodes, grandad_pos));
        set_black_color(get_node_mut(nodes, uncle_pos));
        set_black_color(get_node_mut(nodes, parent_pos));
    }

    fun rb_insert_rebalance<V>(
        tree: &mut RBTree<V>,
        parent_pos: u64,
        node_pos: u64) {
        let (
            parent_is_red,
            grandad_pos,
            parent_left_pos,
            parent_right_pos
        ) = get_node_info_by_pos(&tree.nodes, parent_pos);

        while(parent_is_red) {
            let (
                _,
                grandad_parent_pos,
                grandad_left_pos,
                grandad_right_pos
            ) = get_node_info_by_pos(&tree.nodes, grandad_pos);

            // parent is the left child of grandad
            if (grandad_left_pos == parent_pos) {
                let uncle_pos = grandad_right_pos;
                // Case 1: uncle is not null and uncle is red node
                if (uncle_pos != 0) {
                    let uncle = get_node_mut(&mut tree.nodes, uncle_pos);
                    // Case 1: uncle is red node
                    if (is_red(uncle.color_parent)) {
                        flip_color(&mut tree.nodes, grandad_pos, parent_pos, uncle_pos);
                        node_pos = grandad_pos;
                        if (grandad_parent_pos == 0) {
                            break
                        };
                        parent_pos = grandad_parent_pos;
                        (
                            parent_is_red,
                            grandad_pos,
                            parent_left_pos,
                            parent_right_pos
                        ) = get_node_info_by_pos(&tree.nodes, parent_pos);
                        continue
                    }
                };
                // Case 2: uncle is black, and node is right node
                // if (is_right_child(parent.left_right, node_pos)) {
                if (parent_right_pos == node_pos) {
                    left_rotate(tree, parent_pos, grandad_pos, parent_right_pos);
                    let temp_pos = parent_pos;
                    parent_pos = node_pos;
                    node_pos = temp_pos;
                };
                // Case 3: uncle is black, and node is left node
                // set_black_color(parent);
                set_node_color_by_pos(&mut tree.nodes, parent_pos, false);
                let grandad = get_node_mut(&mut tree.nodes, grandad_pos);
                set_red_color(grandad);
                grandad_left_pos = get_left_index(grandad.left_right);
                right_rotate(tree, grandad_pos, grandad_parent_pos, grandad_left_pos);
            } else {
                // Case 1: uncle is red
                let uncle_pos = grandad_left_pos;
                if (uncle_pos != 0) {
                    let uncle = get_node_mut(&mut tree.nodes, uncle_pos);
                    // Case 1: uncle is null or uncle is red node
                    if (is_red(uncle.color_parent)) {
                        flip_color(&mut tree.nodes, grandad_pos, parent_pos, uncle_pos);
                        node_pos = grandad_pos;
                        if (grandad_parent_pos == 0) {
                            break
                        };
                        parent_pos = grandad_parent_pos; // get_node_mut(&mut tree.nodes, get_parent_index(node.color_parent));
                        (
                            parent_is_red,
                            grandad_pos,
                            parent_left_pos,
                            parent_right_pos
                        ) = get_node_info_by_pos(&tree.nodes, parent_pos);
                        continue
                    };
                };
                // Case 2: uncle is black, and node is right child
                if (parent_left_pos == node_pos) {
                    right_rotate(tree, parent_pos, grandad_pos, parent_left_pos);
                    let temp_pos = parent_pos;
                    parent_pos = node_pos;
                    node_pos = temp_pos;
                };
                // Case 3: uncle is black andd nodee is left child
                set_node_color_by_pos(&mut tree.nodes, parent_pos, false);
                let grandad = get_node_mut(&mut tree.nodes, grandad_pos);
                set_red_color(grandad);
                let grand_right_pos = get_right_index(grandad.left_right);
                left_rotate(tree, grandad_pos, grandad_parent_pos, grand_right_pos);
            };

            (
                parent_is_red,
                grandad_pos,
                parent_left_pos,
                parent_right_pos
            ) = get_node_info_by_pos(&tree.nodes, parent_pos);
        };
        set_black_color(get_node_mut(&mut tree.nodes, tree.root));
    }

    /*
     *
     *      px                              px
     *     /                               /
     *    x                               y
     *   /  \            -->             / \                #
     *  lx   y                          x  ry
     *     /   \                       /  \
     *    ly   ry                     lx  ly
     *
     *  x_pos: node x pos -> x
     *  px_pos: node x parent node pos
     *  y_pos: node x right child pos -> y
     */
    fun left_rotate<V>(
        tree: &mut RBTree<V>,
        x_pos: u64,
        px_pos: u64,
        y_pos: u64) {
        let nodes = &mut tree.nodes;
        let y_left_pos = get_left_index(get_node_mut(nodes, y_pos).left_right);

        // debug::print(&px_pos);
        if (y_left_pos != 0) {
            let ly: &mut RBNode<V> = get_node_mut(nodes, y_left_pos);
            set_node_parent<V>(ly, x_pos);
        };
        // set_node_parent_by_pos(nodes, y_pos, px_pos);
        if (is_root(tree.root, x_pos)) {
            tree.root = y_pos;
        } else {
            let grandad = get_node_mut(nodes, px_pos);
            if (is_left_child(grandad.left_right, x_pos)) {
                set_node_left(grandad, y_pos);
            } else {
                set_node_right(grandad, y_pos);
            }
        };
        let y = get_node_mut(nodes, y_pos);
        set_node_left(y, x_pos);
        set_node_parent(y, px_pos);

        // set node parent, node right child
        let node = get_node_mut(nodes, x_pos);
        set_node_right(node, y_left_pos);
        set_node_parent(node, y_pos);
    }

    fun is_root(root: u64,
        node_pos: u64): bool {
        root == node_pos
    }

    /*
     *
     *            py                               py
     *           /                                /
     *          y                                x
     *         /  \           ---->             /  \                     #
     *        x   ry                           lx   y
     *       / \                                   / \                   #
     *      lx  rx                                rx  ry
     *
     *  y_pos: the node pos to rotate -> y
     *  py_pos: y parent pos -> py
     *  x_pos: y left child pos -> x
     */
    fun right_rotate<V>(
        tree: &mut RBTree<V>,
        y_pos: u64,
        py_pos: u64,
        x_pos: u64) {
        let nodes = &mut tree.nodes;
        let (_, _, _, x_right_pos) = get_node_info_by_pos(nodes, x_pos);

        if (x_right_pos > 0) {
            let rx = get_node_mut(nodes, x_right_pos);
            set_node_parent(rx, y_pos);
        };

        if (is_root(tree.root, y_pos)) {
            tree.root = x_pos; // get_position(x.color_parent);
        } else {
            let grandad = get_node_mut(nodes, py_pos);
            if (is_right_child(grandad.left_right, y_pos)) {
                set_node_right(grandad, x_pos);
            } else {
                set_node_left(grandad, x_pos);
            }
        };
        let x = get_node_mut(nodes, x_pos);
        set_node_right(x, y_pos);
        set_node_parent(x, py_pos);

        let y = get_node_mut(nodes, y_pos);
        set_node_left(y, x_right_pos);
        set_node_parent(y, x_pos);
        // debug::print(&y_pos);
        // debug::print(&x_right_pos);
    }

    fun set_red_color<V>(node: &mut RBNode<V>) {
        node.color_parent = node.color_parent | RED;
    }
    
    fun set_black_color<V>(node: &mut RBNode<V>) {
        node.color_parent = node.color_parent & BLACK_MASK;
    }

    fun set_node_position<V>(node: &mut RBNode<V>, pos: u64) {
        node.color_parent = (node.color_parent & POSITION_CLEAR_MASK) | (pos << 32);
    }

    fun set_node_parent<V>(node: &mut RBNode<V>, parent_pos: u64) {
        // node.color_parent = node.color_parent & PARENT_CLEAR_MASK;
        node.color_parent = (node.color_parent & PARENT_CLEAR_MASK) | parent_pos;
    }

    fun set_node_parent_by_pos<V>(
        nodes: &mut vector<RBNode<V>>,
        node_pos: u64,
        parent_pos: u64) {
        let node = get_node_mut(nodes, node_pos);
        // node.color_parent = node.color_parent & PARENT_CLEAR_MASK;
        node.color_parent = (node.color_parent & PARENT_CLEAR_MASK) | parent_pos;
    }

    fun set_node_left<V>(node: &mut RBNode<V>, left_pos: u64) {
        node.left_right = (node.left_right & (0x00000000ffffffff)) | (left_pos << 32);
    }

    fun set_node_right<V>(node: &mut RBNode<V>, right_pos: u64) {
        node.left_right =  (node.left_right & (0xffffffff00000000)) | right_pos;
    }
    
    /// set parent left child or right child
    fun set_parent_child_rel<V>(
        nodes: &mut vector<RBNode<V>>,
        parent_pos: u64,
        child_pos: u64,
        is_left: bool) {
        let child = get_node_mut(nodes, child_pos);
        set_node_parent<V>(child, parent_pos);

        let parent = get_node_mut(nodes, parent_pos);
        if (is_left) {
            // left child
            set_node_left(parent, child_pos);
        } else {
            // right child
            set_node_right(parent, child_pos);
        };
    }

    fun get_node<V>(
        nodes: &vector<RBNode<V>>,
        pos: u64): &RBNode<V> {
        if (pos == 0 || pos > vector::length(nodes))  {
            // debug::print_stack_trace();
            assert!(false, pos);
        };

        vector::borrow<RBNode<V>>(nodes, pos-1)
    }

    fun get_node_mut<V>(
        nodes: &mut vector<RBNode<V>>,
        pos: u64): &mut RBNode<V> {
        assert!(pos > 0, 2);
        vector::borrow_mut<RBNode<V>>(nodes, pos-1)
    }

    fun get_node_left_index<V>(
        tree: &mut RBTree<V>,
        pos: u64): u64 {
        get_left_index(vector::borrow<RBNode<V>>(&tree.nodes, pos).left_right)
    }

    fun get_node_left_child<V>(
        nodes: &mut vector<RBNode<V>>,
        node: &RBNode<V>): &mut RBNode<V> {
        vector::borrow_mut<RBNode<V>>(nodes, get_left_index(node.left_right))
    }

    fun get_node_right_index<V>(
        tree: &mut RBTree<V>,
        pos: u64): u64 {
        get_right_index(vector::borrow<RBNode<V>>(&tree.nodes, pos).left_right)
    }

    fun get_node_right_child<V>(
        nodes: &mut vector<RBNode<V>>,
        node: &RBNode<V>): &mut RBNode<V> {
        vector::borrow_mut<RBNode<V>>(nodes, get_right_index(node.left_right))
    }

    fun get_node_left_right_index<V>(
        tree: &mut RBTree<V>,
        pos: u64): (u64, u64) {
        let left_right = vector::borrow<RBNode<V>>(&tree.nodes, pos).left_right;
        (get_left_index(left_right), get_right_index(left_right))
    }

    fun next_pos<V>(
        tree: &RBTree<V>,
        pos: u64): u64 {
        let node = get_node(&tree.nodes, pos);
        let right_pos = get_right_index(node.left_right);

        if (right_pos > 0) {
            return get_node_least_pos(&tree.nodes, right_pos)
        } else {
            let parent_pos = get_parent_index(node.color_parent);
            loop {
                // parent_pos = get_parent_index(node.color_parent);
                if (parent_pos == 0) {
                    return 0
                };
                let parent = get_node(&tree.nodes, parent_pos);

                if (is_right_child(parent.left_right, pos)) {
                    pos = parent_pos;
                    parent_pos = get_parent_index(parent.color_parent)
                } else {
                    break
                }
            };
            parent_pos
        }
    }

    // Test-only functions ====================================================
    #[test_only]
    struct ExtracRBNode has drop {
        color: u64,
        pos: u64,
        parent: u64,
        left: u64,
        right: u64,
        key: u128,
    }

    #[test_only]
    fun extract_rbnode<V>(node: &RBNode<V>): ExtracRBNode {
        let color = node.color_parent >> 63;
        let pos = get_position(node.color_parent);
        let parent = get_parent_index(node.color_parent);
        let left = get_left_index(node.left_right);
        let right = get_right_index(node.left_right);

        ExtracRBNode{
            color: color, pos: pos, parent: parent, left: left, right: right, key: node.key,
        }
    }

    #[test_only]
    fun validate_tree<V>(tree: &RBTree<V>, print: bool): u64 {
        if (tree.root == 0) {
            return 0
        };
        assert!(is_empty(tree) == false, 0);
        let pos = tree.leftmost;
        let nodes = 1;
    
        // debug::print(&pos);
        if (print) {
            // let s: address = @0x111111111;
            // debug::print(&s);
            // debug::print(&tree.root);
            // debug::print(&tree.leftmost);
            // debug::print(&length(tree));
        };
        loop {
        // debug::print(&pos);
            let node = get_node(&tree.nodes, pos);
            let (
                node_is_red,
                _,
                node_parent_pos,
                node_left_pos,
                node_right_pos
            ) = get_node_info(node);

            if (print) {
                // let enode = extract_rbnode(node);
                // debug::print(&enode);
            };

            if (node_parent_pos > 0) {
                let parent = get_node(&tree.nodes, node_parent_pos);
                let parent_pos = get_position(parent.color_parent);
                assert!(parent_pos == node_parent_pos, 1);
            };
            if (node_left_pos > 0) {
                let child = get_node(&tree.nodes, node_left_pos);
                let child_pos = get_position(child.color_parent);
                let child_is_red = is_red(child.color_parent);
                let child_parent_pos = get_parent_index(child.color_parent);
                assert!(child_pos == node_left_pos, 10);
                assert!(pos == child_parent_pos, 11);
                if (node_is_red) {
                    assert!(child_is_red == false, 12);
                };
                if (tree.left_is_less) {
                    assert!(child.key < node.key, 13);
                } else {
                    assert!(child.key > node.key, 14);
                }
            };
            if (node_right_pos > 0) {
                let child = get_node(&tree.nodes, node_right_pos);
                let child_pos = get_position(child.color_parent);
                let child_parent_pos = get_parent_index(child.color_parent);
                let child_is_red = is_red(child.color_parent);
                assert!(child_pos == node_right_pos, 20);
                if (pos != child_parent_pos) {
                    // debug::print(&pos);
                    // debug::print(&child_parent_pos);
                };
                assert!(pos == child_parent_pos, 21);
                if (node_is_red) {
                    assert!(child_is_red == false, 22);
                };
                if (tree.left_is_less) {
                    assert!(child.key > node.key, 23);
                } else {
                    assert!(child.key < node.key, 24);
                }
            };

            pos = next_pos(tree, pos);
            if (pos == 0) {
                break
            };
            // debug::print(&pos);
            nodes = nodes + 1;
        };
        if (print) {
            // let s: address = @0x1111111110000000000000000000000000000000000000000000000000000000;
            // debug::print(&s);
        };
        nodes
    }

    // Tests ==================================================================
    #[test]
    fun test_is_empty(): RBTree<u64> {
        let tree = empty<u64>(true);
        assert!(is_empty(&tree), 1);
        tree
    }

    #[test]
    fun test_insert_empty(): RBTree<u64> {
        let tree = empty<u64>(true);
        rb_insert<u64>(&mut tree, 1000, 1000);
        assert!(tree.root == 1, 1);
        assert!(tree.leftmost == 1, 1);

        let node = get_node(&tree.nodes, 1);
        assert!(node.color_parent == 1<<32, 1);
        assert!(node.key == 1000, 2);
        assert!(node.left_right == 0, 3);

        validate_tree(&tree, false);

        tree
    }

    #[test]
    fun test_insert(): RBTree<u64> {
        let tree = empty<u64>(true);
        rb_insert<u64>(&mut tree, 1000, 1000);
        assert!(tree.root == 1, 1);
        assert!(tree.leftmost == 1, 1);

        rb_insert<u64>(&mut tree, 500, 500);
        assert!(tree.root == 1, 1);
        assert!(tree.leftmost == 2, 2);

        rb_insert<u64>(&mut tree, 600, 600);
        assert!(tree.root == 3, 3);
        assert!(tree.leftmost == 2, 2);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 600);

        rb_insert<u64>(&mut tree, 1600, 1600);
        // assert!(tree.root == 1, 1);
        // assert!(tree.root == 3, 3);
        assert!(tree.leftmost == 2, 2);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 1600);

        rb_insert<u64>(&mut tree, 2000, 2000);
        assert!(tree.leftmost == 2, 2);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 2000);

        rb_insert<u64>(&mut tree, 200, 200);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 200);
        // debug::print(&tree.root);

        rb_insert<u64>(&mut tree, 300, 300);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 300);

        rb_insert<u64>(&mut tree, 320, 320);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 320);

        rb_insert<u64>(&mut tree, 720, 720);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 720);

        rb_insert<u64>(&mut tree, 800, 800);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 800);

        rb_insert<u64>(&mut tree, 1800, 1800);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 1800);

        rb_insert<u64>(&mut tree, 2500, 2500);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 2500);

        rb_insert<u64>(&mut tree, 3000, 3000);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 3000);

        rb_insert<u64>(&mut tree, 250, 250);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 250);

        rb_insert<u64>(&mut tree, 450, 450);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 450);

        rb_insert<u64>(&mut tree, 660, 660);
        assert!(tree.leftmost == 6, 6);
        let nodes = validate_tree(&tree, false);
        assert!(length(&tree) == nodes, 600);

        // let nodes = validate_tree(&tree);
        // assert!(length(&tree) == nodes, 0);
        tree
    }

    #[test]
    fun test_insert_asc(): RBTree<u128> {
        let tree = empty<u128>(true);

        let i: u128 = 0;
        while (i < 50) {
            rb_insert<u128>(&mut tree, i, i);
            i = i + 1;
            if (i % 100 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
        };
        
        // i = 0;
        // while(i < 5000) {
        //     rb_remove_by_key(&mut tree, i);
        //     i = i + 1;
        // };
        // assert!(tree.root == 0, 0);
        tree
    }

    #[test]
    fun test_insert_desc(): RBTree<u128> {
        let tree = empty<u128>(true);

        let i: u128 = 50;
        let j = 1;
        while (i > 0) {
            rb_insert<u128>(&mut tree, i, i);
            assert!(tree.leftmost == j, (i as u64));
            if (i % 100 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
            i = i - 1;
            j  = j + 1;
        };
        // i = 1;
        // while(i <= 5000) {
        //     rb_remove_by_key(&mut tree, i);
        //     if (i % 100 == 0) {
        //         validate_tree(&tree);
        //         // assert!(length(&tree) == nodes, (i as u64));
        //         debug::print(&i);
        //     };
        //     i = i + 1;
        // };
        // assert!(tree.root == 0, 0);
        tree
    }

    #[test]
    fun test_insert_reverse_asc(): RBTree<u128> {
        let tree = empty<u128>(false);
        let max: u128 = 150;
        let i: u128 = 0;
        // let j = 1;
        while (i < max) {
            rb_insert<u128>(&mut tree, i, i);
            assert!(tree.leftmost == ((i+1) as u64), (i as u64));
            if (i % 1 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
            i = i + 1;
            // j  = j + 1;
        };
        i = 0;
        while(i < max) {
            rb_remove_by_key(&mut tree, i);
            if (i % 1 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
            i = i + 1;
        };
        assert!(tree.root == 0, 0);
        tree
    }

    #[test]
    fun test_insert_reverse_desc(): RBTree<u128> {
        let tree = empty<u128>(false);
        let max: u128 = 150;
        let i: u128 = max;
        // let j = 1;
        while (i > 0) {
            rb_insert<u128>(&mut tree, i, i);
            assert!(tree.leftmost == 1, (i as u64));
            if (i % 1 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
            i = i - 1;
            // j  = j + 1;
        };
        i = max;
        while(i > 0) {
            rb_remove_by_key(&mut tree, i);
            if (i % 1 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
            i = i - 1;
        };
        assert!(tree.root == 0, 0);
        tree
    }

    #[test]
    fun test_remove(): RBTree<u128> {
        let tree = empty<u128>(true);
        let i: u128 = 0;
        while (i < 100) {
            rb_insert<u128>(&mut tree, i, i);
            i = i + 1;
            if (i % 100 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(length(&tree) == nodes, (i as u64));
                // debug::print(&i);
            };
        };
        validate_tree(&tree, false);
        // let hr = @0x22222222222;
        // debug::print(&hr);

        i = 0;
        while(i < 100) {
            rb_remove_by_key(&mut tree, i);
            if (i % 10 == 0) {
                let nodes = validate_tree(&tree, false);
                assert!(nodes == length(&tree), nodes);
                // if (length(&tree) != nodes) {
                //     debug::print(&length(&tree));
                //     debug::print(&nodes);
                //     // debug::print(&i);
                //     // assert!(false, (i as u64));
                // }
            };
            i = i + 1;
        };
        assert!(tree.root == 0, 0);
        assert!(length(&tree) == 0, 0);
        tree
    }

    #[test]
    fun test_remove_from_root(): RBTree<u128> {
        let tree = empty<u128>(true);
        let i: u128 = 0;
        while (i < 1000) {
            rb_insert<u128>(&mut tree, i, i);
            rb_insert<u128>(&mut tree, i+1000, i+1000);
            i = i + 1;
        };
        while (tree.root > 0) {
            let root = tree.root;
            rb_remove_by_pos(&mut tree, root);
        };

        tree
    }

    #[test]
    fun test_remove_from_left(): RBTree<u128> {
        let tree = empty<u128>(true);
        let i: u128 = 0;
        while (i < 1000) {
            rb_insert<u128>(&mut tree, i, i);
            rb_insert<u128>(&mut tree, i+1000, i+1000);
            i = i + 1;
        };
        while (tree.leftmost > 0) {
            let leftmost = tree.leftmost;
            rb_remove_by_pos(&mut tree, leftmost);
        };

        tree
    }

    #[test]
    fun test_remove_from_right(): RBTree<u128> {
        let tree = empty<u128>(true);
        let i: u128 = 0;
        while (i < 1000) {
            rb_insert<u128>(&mut tree, i, i);
            rb_insert<u128>(&mut tree, i+1000, i+1000);
            i = i + 1;
        };
        i = 1999;
        while (i > 0) {
            rb_remove_by_key(&mut tree, i);
            i = i - 1;
        };
        rb_remove_by_key(&mut tree, 0);

        tree
    }
    #[test]
    fun test_remove_root(): RBTree<u128> {
        let tree = empty<u128>(false);

        rb_insert<u128>(&mut tree, 27670116110564327425099511627788, 27670116110564327425099511627788);
        rb_insert<u128>(&mut tree, 27670116110564327425099511627789, 27670116110564327425099511627789);
        rb_insert<u128>(&mut tree, 29514790517935282586699511627790, 29514790517935282586699511627790);
        rb_insert<u128>(&mut tree, 30437127721620760167499511627791, 30437127721620760167499511627791);
        rb_insert<u128>(&mut tree, 30437127721620760167499511627792, 30437127721620760167499511627792);

        // debug::print(&tree);

        rb_remove_by_key(&mut tree, 30437127721620760167499511627792);
        rb_remove_by_key(&mut tree, 30437127721620760167499511627791);
        // debug::print(&tree);
        rb_remove_by_key(&mut tree, 27670116110564327425099511627789);
        rb_remove_by_key(&mut tree, 27670116110564327425099511627788);
        rb_remove_by_key(&mut tree, 29514790517935282586699511627790);

        // debug::print(&tree);
        tree
    }
}

```
// <autogenerated>
//   This file was generated by dddappp code generator.
//   Any changes made to this file manually will be lost next time the file is regenerated.
// </autogenerated>

module aptos_test_proj1::order {
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_std::table::{Self, Table};
    use aptos_std::table_with_length::{Self, TableWithLength};
    use aptos_test_proj1::day::Day;
    use aptos_test_proj1::genesis_account;
    use aptos_test_proj1::order_item::{Self, OrderItem};
    use aptos_test_proj1::order_ship_group::{Self, OrderShipGroup};
    use aptos_test_proj1::pass_object;
    use std::option::Option;
    use std::string::String;
    friend aptos_test_proj1::order_create_logic;
    friend aptos_test_proj1::order_remove_item_logic;
    friend aptos_test_proj1::order_update_item_quantity_logic;
    friend aptos_test_proj1::order_update_estimated_ship_date_logic;
    friend aptos_test_proj1::order_add_order_ship_group_logic;
    friend aptos_test_proj1::order_cancel_order_ship_group_quantity_logic;
    friend aptos_test_proj1::order_remove_order_ship_group_item_logic;
    friend aptos_test_proj1::order_remove_order_ship_group_logic;
    friend aptos_test_proj1::order_aggregate;

    const EID_ALREADY_EXISTS: u64 = 101;
    const EID_DATA_TOO_LONG: u64 = 102;
    const EINAPPROPRIATE_VERSION: u64 = 103;

    struct Events has key {
        order_created_handle: event::EventHandle<OrderCreated>,
        order_item_removed_handle: event::EventHandle<OrderItemRemoved>,
        order_item_quantity_updated_handle: event::EventHandle<OrderItemQuantityUpdated>,
        order_estimated_ship_date_updated_handle: event::EventHandle<OrderEstimatedShipDateUpdated>,
        order_ship_group_added_handle: event::EventHandle<OrderShipGroupAdded>,
        order_ship_group_quantity_canceled_handle: event::EventHandle<OrderShipGroupQuantityCanceled>,
        order_ship_group_item_removed_handle: event::EventHandle<OrderShipGroupItemRemoved>,
        order_ship_group_removed_handle: event::EventHandle<OrderShipGroupRemoved>,
    }

    struct Tables has key {
        order_table: Table<String, Order>,
    }

    public fun initialize(account: &signer) {
        genesis_account::assert_genesis_account(account);

        let res_account = genesis_account::resource_account_signer();
        move_to(&res_account, Events {
            order_created_handle: account::new_event_handle<OrderCreated>(&res_account),
            order_item_removed_handle: account::new_event_handle<OrderItemRemoved>(&res_account),
            order_item_quantity_updated_handle: account::new_event_handle<OrderItemQuantityUpdated>(&res_account),
            order_estimated_ship_date_updated_handle: account::new_event_handle<OrderEstimatedShipDateUpdated>(&res_account),
            order_ship_group_added_handle: account::new_event_handle<OrderShipGroupAdded>(&res_account),
            order_ship_group_quantity_canceled_handle: account::new_event_handle<OrderShipGroupQuantityCanceled>(&res_account),
            order_ship_group_item_removed_handle: account::new_event_handle<OrderShipGroupItemRemoved>(&res_account),
            order_ship_group_removed_handle: account::new_event_handle<OrderShipGroupRemoved>(&res_account),
        });

        move_to(
            &res_account,
            Tables {
                order_table: table::new(),
            },
        );

    }

    struct Order has store {
        order_id: String,
        version: u64,
        total_amount: u128,
        estimated_ship_date: Option<Day>,
        items: TableWithLength<String, OrderItem>,
        order_ship_groups: TableWithLength<u8, OrderShipGroup>,
    }

    public fun order_id(order: &Order): String {
        order.order_id
    }

    public fun version(order: &Order): u64 {
        order.version
    }

    public fun total_amount(order: &Order): u128 {
        order.total_amount
    }

    public(friend) fun set_total_amount(order: &mut Order, total_amount: u128) {
        order.total_amount = total_amount;
    }

    public fun estimated_ship_date(order: &Order): Option<Day> {
        order.estimated_ship_date
    }

    public(friend) fun set_estimated_ship_date(order: &mut Order, estimated_ship_date: Option<Day>) {
        order.estimated_ship_date = estimated_ship_date;
    }

    public(friend) fun add_item(order: &mut Order, item: OrderItem) {
        let key = order_item::product_id(&item);
        table_with_length::add(&mut order.items, key, item);
    }

    public(friend) fun remove_item(order: &mut Order, product_id: String) {
        let item = table_with_length::remove(&mut order.items, product_id);
        order_item::drop_order_item(item);
    }

    public(friend) fun borrow_mut_item(order: &mut Order, product_id: String): &mut OrderItem {
        table_with_length::borrow_mut(&mut order.items, product_id)
    }

    public fun borrow_item(order: &Order, product_id: String): &OrderItem {
        table_with_length::borrow(&order.items, product_id)
    }

    public fun items_contains(order: &Order, product_id: String): bool {
        table_with_length::contains(&order.items, product_id)
    }

    public fun items_length(order: &Order): u64 {
        table_with_length::length(&order.items)
    }

    public(friend) fun add_order_ship_group(order: &mut Order, order_ship_group: OrderShipGroup) {
        let key = order_ship_group::ship_group_seq_id(&order_ship_group);
        table_with_length::add(&mut order.order_ship_groups, key, order_ship_group);
    }

    /*
    public(friend) fun remove_order_ship_group(order: &mut Order, ship_group_seq_id: u8) {
        let order_ship_group = table_with_length::remove(&mut order.order_ship_groups, ship_group_seq_id);
        order_ship_group::drop_order_ship_group(order_ship_group);
    }
    */

    public(friend) fun borrow_mut_order_ship_group(order: &mut Order, ship_group_seq_id: u8): &mut OrderShipGroup {
        table_with_length::borrow_mut(&mut order.order_ship_groups, ship_group_seq_id)
    }

    public fun borrow_order_ship_group(order: &Order, ship_group_seq_id: u8): &OrderShipGroup {
        table_with_length::borrow(&order.order_ship_groups, ship_group_seq_id)
    }

    public fun order_ship_groups_contains(order: &Order, ship_group_seq_id: u8): bool {
        table_with_length::contains(&order.order_ship_groups, ship_group_seq_id)
    }

    public fun order_ship_groups_length(order: &Order): u64 {
        table_with_length::length(&order.order_ship_groups)
    }

    fun new_order(
        order_id: String,
        total_amount: u128,
        estimated_ship_date: Option<Day>,
    ): Order {
        assert!(std::string::length(&order_id) <= 50, EID_DATA_TOO_LONG);
        Order {
            order_id,
            version: 0,
            total_amount,
            estimated_ship_date,
            items: table_with_length::new<String, OrderItem>(),
            order_ship_groups: table_with_length::new<u8, OrderShipGroup>(),
        }
    }

    struct OrderCreated has store, drop {
        order_id: String,
        product_id: String,
        quantity: u64,
        unit_price: u128,
        total_amount: u128,
        owner: address,
    }

    public fun order_created_order_id(order_created: &OrderCreated): String {
        order_created.order_id
    }

    public fun order_created_product_id(order_created: &OrderCreated): String {
        order_created.product_id
    }

    public fun order_created_quantity(order_created: &OrderCreated): u64 {
        order_created.quantity
    }

    public fun order_created_unit_price(order_created: &OrderCreated): u128 {
        order_created.unit_price
    }

    public fun order_created_total_amount(order_created: &OrderCreated): u128 {
        order_created.total_amount
    }

    public fun order_created_owner(order_created: &OrderCreated): address {
        order_created.owner
    }

    public(friend) fun new_order_created(
        order_id: String,
        product_id: String,
        quantity: u64,
        unit_price: u128,
        total_amount: u128,
        owner: address,
    ): OrderCreated {
        OrderCreated {
            order_id,
            product_id,
            quantity,
            unit_price,
            total_amount,
            owner,
        }
    }

    struct OrderItemRemoved has store, drop {
        order_id: String,
        version: u64,
        product_id: String,
    }

    public fun order_item_removed_order_id(order_item_removed: &OrderItemRemoved): String {
        order_item_removed.order_id
    }

    public fun order_item_removed_product_id(order_item_removed: &OrderItemRemoved): String {
        order_item_removed.product_id
    }

    public(friend) fun new_order_item_removed(
        order: &Order,
        product_id: String,
    ): OrderItemRemoved {
        OrderItemRemoved {
            order_id: order_id(order),
            version: version(order),
            product_id,
        }
    }

    struct OrderItemQuantityUpdated has store, drop {
        order_id: String,
        version: u64,
        product_id: String,
        quantity: u64,
    }

    public fun order_item_quantity_updated_order_id(order_item_quantity_updated: &OrderItemQuantityUpdated): String {
        order_item_quantity_updated.order_id
    }

    public fun order_item_quantity_updated_product_id(order_item_quantity_updated: &OrderItemQuantityUpdated): String {
        order_item_quantity_updated.product_id
    }

    public fun order_item_quantity_updated_quantity(order_item_quantity_updated: &OrderItemQuantityUpdated): u64 {
        order_item_quantity_updated.quantity
    }

    public(friend) fun new_order_item_quantity_updated(
        order: &Order,
        product_id: String,
        quantity: u64,
    ): OrderItemQuantityUpdated {
        OrderItemQuantityUpdated {
            order_id: order_id(order),
            version: version(order),
            product_id,
            quantity,
        }
    }

    struct OrderEstimatedShipDateUpdated has store, drop {
        order_id: String,
        version: u64,
        estimated_ship_date: Day,
    }

    public fun order_estimated_ship_date_updated_order_id(order_estimated_ship_date_updated: &OrderEstimatedShipDateUpdated): String {
        order_estimated_ship_date_updated.order_id
    }

    public fun order_estimated_ship_date_updated_estimated_ship_date(order_estimated_ship_date_updated: &OrderEstimatedShipDateUpdated): Day {
        order_estimated_ship_date_updated.estimated_ship_date
    }

    public(friend) fun new_order_estimated_ship_date_updated(
        order: &Order,
        estimated_ship_date: Day,
    ): OrderEstimatedShipDateUpdated {
        OrderEstimatedShipDateUpdated {
            order_id: order_id(order),
            version: version(order),
            estimated_ship_date,
        }
    }

    struct OrderShipGroupAdded has store, drop {
        order_id: String,
        version: u64,
        ship_group_seq_id: u8,
        shipment_method: String,
        product_id: String,
        quantity: u64,
    }

    public fun order_ship_group_added_order_id(order_ship_group_added: &OrderShipGroupAdded): String {
        order_ship_group_added.order_id
    }

    public fun order_ship_group_added_ship_group_seq_id(order_ship_group_added: &OrderShipGroupAdded): u8 {
        order_ship_group_added.ship_group_seq_id
    }

    public fun order_ship_group_added_shipment_method(order_ship_group_added: &OrderShipGroupAdded): String {
        order_ship_group_added.shipment_method
    }

    public fun order_ship_group_added_product_id(order_ship_group_added: &OrderShipGroupAdded): String {
        order_ship_group_added.product_id
    }

    public fun order_ship_group_added_quantity(order_ship_group_added: &OrderShipGroupAdded): u64 {
        order_ship_group_added.quantity
    }

    public(friend) fun new_order_ship_group_added(
        order: &Order,
        ship_group_seq_id: u8,
        shipment_method: String,
        product_id: String,
        quantity: u64,
    ): OrderShipGroupAdded {
        OrderShipGroupAdded {
            order_id: order_id(order),
            version: version(order),
            ship_group_seq_id,
            shipment_method,
            product_id,
            quantity,
        }
    }

    struct OrderShipGroupQuantityCanceled has store, drop {
        order_id: String,
        version: u64,
        ship_group_seq_id: u8,
        product_id: String,
        cancel_quantity: u64,
    }

    public fun order_ship_group_quantity_canceled_order_id(order_ship_group_quantity_canceled: &OrderShipGroupQuantityCanceled): String {
        order_ship_group_quantity_canceled.order_id
    }

    public fun order_ship_group_quantity_canceled_ship_group_seq_id(order_ship_group_quantity_canceled: &OrderShipGroupQuantityCanceled): u8 {
        order_ship_group_quantity_canceled.ship_group_seq_id
    }

    public fun order_ship_group_quantity_canceled_product_id(order_ship_group_quantity_canceled: &OrderShipGroupQuantityCanceled): String {
        order_ship_group_quantity_canceled.product_id
    }

    public fun order_ship_group_quantity_canceled_cancel_quantity(order_ship_group_quantity_canceled: &OrderShipGroupQuantityCanceled): u64 {
        order_ship_group_quantity_canceled.cancel_quantity
    }

    public(friend) fun new_order_ship_group_quantity_canceled(
        order: &Order,
        ship_group_seq_id: u8,
        product_id: String,
        cancel_quantity: u64,
    ): OrderShipGroupQuantityCanceled {
        OrderShipGroupQuantityCanceled {
            order_id: order_id(order),
            version: version(order),
            ship_group_seq_id,
            product_id,
            cancel_quantity,
        }
    }

    struct OrderShipGroupItemRemoved has store, drop {
        order_id: String,
        version: u64,
        ship_group_seq_id: u8,
        product_id: String,
    }

    public fun order_ship_group_item_removed_order_id(order_ship_group_item_removed: &OrderShipGroupItemRemoved): String {
        order_ship_group_item_removed.order_id
    }

    public fun order_ship_group_item_removed_ship_group_seq_id(order_ship_group_item_removed: &OrderShipGroupItemRemoved): u8 {
        order_ship_group_item_removed.ship_group_seq_id
    }

    public fun order_ship_group_item_removed_product_id(order_ship_group_item_removed: &OrderShipGroupItemRemoved): String {
        order_ship_group_item_removed.product_id
    }

    public(friend) fun new_order_ship_group_item_removed(
        order: &Order,
        ship_group_seq_id: u8,
        product_id: String,
    ): OrderShipGroupItemRemoved {
        OrderShipGroupItemRemoved {
            order_id: order_id(order),
            version: version(order),
            ship_group_seq_id,
            product_id,
        }
    }

    struct OrderShipGroupRemoved has store, drop {
        order_id: String,
        version: u64,
        ship_group_seq_id: u8,
    }

    public fun order_ship_group_removed_order_id(order_ship_group_removed: &OrderShipGroupRemoved): String {
        order_ship_group_removed.order_id
    }

    public fun order_ship_group_removed_ship_group_seq_id(order_ship_group_removed: &OrderShipGroupRemoved): u8 {
        order_ship_group_removed.ship_group_seq_id
    }

    public(friend) fun new_order_ship_group_removed(
        order: &Order,
        ship_group_seq_id: u8,
    ): OrderShipGroupRemoved {
        OrderShipGroupRemoved {
            order_id: order_id(order),
            version: version(order),
            ship_group_seq_id,
        }
    }


    public(friend) fun create_order(
        order_id: String,
        total_amount: u128,
        estimated_ship_date: Option<Day>,
    ): Order acquires Tables {
        asset_order_not_exists(order_id);
        let order = new_order(
            order_id,
            total_amount,
            estimated_ship_date,
        );
        order
    }

    public(friend) fun asset_order_not_exists(
        order_id: String,
    ) acquires Tables {
        let tables = borrow_global_mut<Tables>(genesis_account::resouce_account_address());
        assert!(!table::contains(&tables.order_table, order_id), EID_ALREADY_EXISTS);
    }

    public(friend) fun update_version_and_add(order: Order) acquires Tables {
        assert!(order.version != 0, EINAPPROPRIATE_VERSION);
        order.version = order.version + 1;
        private_add_order(order);
    }

    public(friend) fun add_order(order: Order) acquires Tables {
        assert!(order.version == 0, EINAPPROPRIATE_VERSION);
        private_add_order(order);
    }

    public(friend) fun remove_order(order_id: String): Order acquires Tables {
        let tables = borrow_global_mut<Tables>(genesis_account::resouce_account_address());
        table::remove(&mut tables.order_table, order_id)
    }

    fun private_add_order(order: Order) acquires Tables {
        let tables = borrow_global_mut<Tables>(genesis_account::resouce_account_address());
        table::add(&mut tables.order_table, order_id(&order), order);
    }

    public fun get_order(order_id: String): pass_object::PassObject<Order> acquires Tables {
        let order = remove_order(order_id);
        pass_object::new(order)
    }

    public fun return_order(order_pass_obj: pass_object::PassObject<Order>) acquires Tables {
        let order = pass_object::extract(order_pass_obj);
        private_add_order(order);
    }

    public(friend) fun emit_order_created(order_created: OrderCreated) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_created_handle, order_created);
    }

    public(friend) fun emit_order_item_removed(order_item_removed: OrderItemRemoved) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_item_removed_handle, order_item_removed);
    }

    public(friend) fun emit_order_item_quantity_updated(order_item_quantity_updated: OrderItemQuantityUpdated) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_item_quantity_updated_handle, order_item_quantity_updated);
    }

    public(friend) fun emit_order_estimated_ship_date_updated(order_estimated_ship_date_updated: OrderEstimatedShipDateUpdated) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_estimated_ship_date_updated_handle, order_estimated_ship_date_updated);
    }

    public(friend) fun emit_order_ship_group_added(order_ship_group_added: OrderShipGroupAdded) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_ship_group_added_handle, order_ship_group_added);
    }

    public(friend) fun emit_order_ship_group_quantity_canceled(order_ship_group_quantity_canceled: OrderShipGroupQuantityCanceled) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_ship_group_quantity_canceled_handle, order_ship_group_quantity_canceled);
    }

    public(friend) fun emit_order_ship_group_item_removed(order_ship_group_item_removed: OrderShipGroupItemRemoved) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_ship_group_item_removed_handle, order_ship_group_item_removed);
    }

    public(friend) fun emit_order_ship_group_removed(order_ship_group_removed: OrderShipGroupRemoved) acquires Events {
        let events = borrow_global_mut<Events>(genesis_account::resouce_account_address());
        event::emit_event(&mut events.order_ship_group_removed_handle, order_ship_group_removed);
    }

}

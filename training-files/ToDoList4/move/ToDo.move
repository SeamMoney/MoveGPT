module journeyman::ToDo4 {
    use std::signer;
    use std::string::String;
    use std::vector;

    const ERROR_TODO_STORE_EXISTS: u64 = 1;

    struct TodoStore has key {
        todos: vector<String>
    }

    // chuacw's simple ToDo list ....

    public entry fun add_todos(account: &signer, todo: String) acquires TodoStore {
        let account_address = signer::address_of(account);

        if (exists<TodoStore>(account_address)) {
            let todo_store = borrow_global_mut<TodoStore>(account_address);
            vector::push_back(&mut todo_store.todos, todo);
        } else {
            let todos = vector::empty<String>();
            vector::push_back(&mut todos, todo);
            move_to(account, TodoStore { todos });
        }
    }

    #[view]
    public fun get_all_todos(todo_address: address): vector<String> acquires TodoStore {
        borrow_global<TodoStore>(todo_address).todos
    }

    #[view]
    public fun get_last_todo(todo_address: address): String acquires TodoStore {
        let todos = borrow_global<TodoStore>(todo_address).todos;
        let i = vector::length(&mut todos)-1;
        let last = vector::borrow(&mut todos, i);
        *last
    }

}
module todo::test{
    use std::signer;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    use aptos_framework::event;
    use aptos_framework::account;

    struct Task has store, drop, copy{
        task_id:u64,
        address: address,
        content: String,
        completed:bool
    }

    struct ToDoList has key{
        tasks: Table<u64, Task>,
        task_event: event::EventHandle<Task>,
        counter: u64
    }

    public fun create_list(account: &signer){
        let list_instance = ToDoList{
            tasks: table::new(),
            task_event: account::new_event_handle<Task>(account),
            counter: 0
        };
        move_to(account, list_instance);
    }

    public fun create_task(account:&signer, task:String) acquires ToDoList{
        let signer_address = signer::address_of(account);
        assert_resource_exist(signer_address);

        let todo_list = borrow_global_mut<ToDoList>(signer_address);
        let counter = todo_list.counter + 1;

        let new_task = Task{
            task_id : counter,
            address: signer_address,
            content: task,
            completed: false
        };

        table::upsert(&mut todo_list.tasks, counter, new_task);

        todo_list.counter = counter;
        event::emit_event<Task>(&mut borrow_global_mut<ToDoList>(signer_address).task_event, new_task);

    }

    public fun complete_task(account: &signer, task_id: u64) acquires ToDoList{
        let signer_address = signer::address_of(account);
        assert_resource_exist(signer_address);

        let task = borrow_global_mut<ToDoList>(signer_address);
        assert!(table::contains(&task.tasks, task_id), 0);

        let my_task = table::borrow_mut(&mut task.tasks, task_id);
        assert!(my_task.completed == false, 0);
        my_task.completed = true;

    }

    inline fun assert_resource_exist(signer_address: address){
        assert!(exists<ToDoList>(signer_address), 0);
    }

    //
    //-----------Tests---------------
    //

    #[test(tester = @61)]
    public fun test_create_task(tester: signer){
        account::create_account_for_test(signer::address_of(&tester));
        create_list(&tester);

        assert!(exists<ToDoList>(signer::address_of(&tester)),0);
    }
}
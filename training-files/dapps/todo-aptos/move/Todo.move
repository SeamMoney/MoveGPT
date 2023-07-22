module Todo::tasks {
    use std::account;
    use std::error;
    use std::signer;
    use std::string;
    use std::vector;
    use aptos_std::event;

    // :!:>errors
    const NO_TASK: u64 = 0;
    const ALREADY_COMPLETED: u64 = 1;
    // <:!:errors

    // :!:>structs
    struct Task has store {
        task: string::String,
        completed: bool,
    }
    // <:!:structs

    // :!:>resource
    struct TasksHolder has key {
        tasks: vector<Task>,
        add_task_events: event::EventHandle<AddTaskEvent>,
        complete_task_events: event::EventHandle<CompleteTaskEvent>,
        remove_task_events: event::EventHandle<RemoveTaskEvent>
    }
    // <:!:resource

    // :!:>events
    struct AddTaskEvent has drop, store {
        task: string::String,
    }

    struct CompleteTaskEvent has drop, store {
        task: string::String,
    }

    struct RemoveTaskEvent has drop, store {
        task: string::String,
    }
    // <:!:events

    public entry fun add_task(account: signer, task: string::String) acquires TasksHolder {
        let account_addr = signer::address_of(&account);

        if(!exists<TasksHolder>(account_addr)) {
            move_to(&account, TasksHolder {
                tasks: vector::singleton<Task>(Task {
                    task: task,
                    completed: false,
                }),
                add_task_events: account::new_event_handle<AddTaskEvent>(&account),
                complete_task_events: account::new_event_handle<CompleteTaskEvent>(&account),
                remove_task_events: account::new_event_handle<RemoveTaskEvent>(&account),
            });
        } else {
            let tasks_holder = borrow_global_mut<TasksHolder>(account_addr);

            vector::push_back<Task>(&mut tasks_holder.tasks, Task {
                task: task,
                completed: false,
            });

            event::emit_event(&mut tasks_holder.add_task_events, AddTaskEvent {
                task: task,
            });
        }
    }

    public entry fun complete_task(account: signer, index: u64): string::String acquires TasksHolder {
        let account_addr = signer::address_of(&account);
        assert!(exists<TasksHolder>(account_addr), error::not_found(NO_TASK));

        let tasks_holder = borrow_global_mut<TasksHolder>(account_addr);
        let tasks = &mut tasks_holder.tasks;
        assert!(index < vector::length<Task>(tasks), error::not_found(NO_TASK));

        let task = vector::borrow_mut<Task>(tasks, index);
        assert!(!task.completed, error::not_found(ALREADY_COMPLETED));
        *&mut task.completed = true;

        event::emit_event(&mut tasks_holder.complete_task_events, CompleteTaskEvent {
            task: *&task.task,
        });

        *&task.task
    }

    public entry fun remove_task(account: signer, index: u64): string::String acquires TasksHolder {
        let account_addr = signer::address_of(&account);
        assert!(exists<TasksHolder>(account_addr), error::not_found(NO_TASK));

        let tasks_holder = borrow_global_mut<TasksHolder>(account_addr);
        let tasks = &mut tasks_holder.tasks;
        assert!(index < vector::length<Task>(tasks), error::not_found(NO_TASK));

        let Task { task: task, completed: _completed } = vector::remove<Task>(tasks, index);

        event::emit_event(&mut tasks_holder.remove_task_events, RemoveTaskEvent {
            task: task,
        });

        task
    }

    public entry fun get_number_of_tasks(addr: address): u64 acquires TasksHolder {
        assert!(exists<TasksHolder>(addr), error::not_found(NO_TASK));
        vector::length<Task>(&borrow_global<TasksHolder>(addr).tasks)
    }

    public entry fun get_task(addr: address, index: u64): string::String acquires TasksHolder {
        assert!(exists<TasksHolder>(addr), error::not_found(NO_TASK));
        
        let tasks_holder = borrow_global<TasksHolder>(addr);
        let tasks = &tasks_holder.tasks;
        assert!(index < vector::length<Task>(tasks), error::not_found(NO_TASK));

        let task = vector::borrow<Task>(tasks, index);
        *&task.task
    }

    public entry fun is_completed(addr: address, index: u64): bool acquires TasksHolder {
        assert!(exists<TasksHolder>(addr), error::not_found(NO_TASK));

        let tasks_holder = borrow_global<TasksHolder>(addr);
        let tasks = &tasks_holder.tasks;
        assert!(index < vector::length<Task>(tasks), error::not_found(NO_TASK));

        let task = vector::borrow<Task>(tasks, index);
        *&task.completed
    }
}
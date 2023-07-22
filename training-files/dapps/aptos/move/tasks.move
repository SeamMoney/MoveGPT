address tasks{

    module moveToDo{
        
        use std::string;
        use std::vector;
        use std::signer;
        use aptos_framework::account::create_account_for_test;
        use std::debug;
        // use aptos_std::event;

        struct Task has store, drop, copy{
            task: string::String,
            signee: address,
            wager: u64,
            publish_time: u64,
        }

        struct UserTasks has key, copy{
            tasks: vector<Task>
        }

        struct ChangeTaskEvent has drop, store{
            task: string::String,
            publish_time: string::String
        }

        struct AddSigneeEvent has drop, store{

        }

        struct SigneeConfirmationEvent has drop, store{

        }

        const ECollectionExists: u64 = 1;
        const ECollectionDoesNotExists: u64 = 2;

        public fun addTaskCollection(account: &signer){
            assert!(!exists<UserTasks>(signer::address_of(account)), ECollectionExists);
            move_to<UserTasks>(account, UserTasks {
                tasks: vector::empty<Task>()
            })
        }


        public fun addTasks(taskItem: string::String, signee: address ,account: &signer, current_time: u64) acquires UserTasks{
            assert!(exists<UserTasks>(signer::address_of(account)), ECollectionDoesNotExists);
            let task = Task{
                task: taskItem,
                signee: signee,
                publish_time: current_time,
            };
            let userTasks = borrow_global_mut<UserTasks>(signer::address_of(account));
            vector::push_back(&mut userTasks.tasks, task);
        }

        public fun getUserTasks(account: address): string::String acquires UserTasks{
            assert!(exists<UserTasks>(account), ECollectionExists);
            let tasks = borrow_global_mut<UserTasks>(account);
            let firstTaskInfo = vector::borrow_mut<Task>(&mut tasks.tasks, 0);
            let task = *&mut firstTaskInfo.task;
            task
        }

        #[test(account = @0x1, taskSignee = @0x2)]
        public entry fun sender_add_task (account: &signer, taskSignee: address) acquires UserTasks {
            let addr = signer::address_of(account);
            create_account_for_test(addr);
            addTaskCollection(account);
            let task = string::utf8(b"Practise Move");
            addTasks(task, taskSignee, account, 1234);
            let firstTask = getUserTasks(addr);
            debug::print<string::String>(&firstTask);
            // let allTasks = getUserTasks(addr);
            // debug::print(&allTasks);
        }
        // #[test_only (taskItem = "Practise Move")]

    }
}
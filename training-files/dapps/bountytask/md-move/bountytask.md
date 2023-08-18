```rust
module tasklist_addr::bountytask {

  use aptos_framework::account;
  use aptos_framework::aptos_account;
  use std::signer;
  use aptos_framework::event;
  use std::string::{String, Self};
  use aptos_std::table::{Self, Table};
  // #[test_only]
  // use std::string;

  // Errors
  const E_NOT_INITIALIZED: u64 = 1;
  const ETASK_DOESNT_EXIST: u64 = 2;
  const ETASK_STATUS_INVALID: u64 = 3;
  const ETASK_STATUS_PERMISSION_DENIED: u64 = 4;

  // status-enum

  const TASK_INIT:u8 = 0;
  const TASK_TAKED:u8 = 1;
  const TASK_SUBMITED:u8 = 2;
  const TASK_COMPLETED:u8 = 3;
  const INIT_HUNTER:address = @0xcafe;

  struct TaskList has key {
    tasks: Table<u64, Task>,
    set_task_event: event::EventHandle<Task>,
    task_counter: u64
  }

  struct Task has store, drop, copy {
    task_id: u64,
    publisher:address,
    content: String,
    hunter:address, 
    status:u8,
    bounty:u64,
    comment:String,
  }

  fun create_list(account: &signer){
    let task_list = TaskList {
      tasks: table::new(),
      set_task_event: account::new_event_handle<Task>(account),
      task_counter: 0
    };
    // move the TaskList resource under the signer account
    move_to(account, task_list);
  }

  fun init_module(account: &signer) {
    create_list(account);
  }

  public entry fun create_task(account: &signer, content: String, bounty:u64) acquires TaskList {
    // gets the signer address
    let signer_address = signer::address_of(account);
    // assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    // increment task counter
    let counter = task_list.task_counter + 1;
    // creates a new Task
    let new_task = Task {
      task_id: counter,
      publisher: signer_address,
      content,
      bounty,
      hunter:INIT_HUNTER,
      status: TASK_INIT,
      comment: string::utf8(b"-"),
    };
    // adds the new task into the tasks table
    table::upsert(&mut task_list.tasks, counter, new_task);
    // sets the task counter to be the incremented counter
    task_list.task_counter = counter;
    // fires a new task created event
    event::emit_event<Task>(
      &mut borrow_global_mut<TaskList>(@tasklist_addr).set_task_event,
      new_task,
    );
  }

  public entry fun take_task(account: &signer, task_id: u64) acquires TaskList {
    // gets the signer address
    let signer_address = signer::address_of(account);
		// assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    // assert task exists
    assert!(table::contains(&task_list.tasks, task_id), ETASK_DOESNT_EXIST);
    // gets the task matched the task_id
    let task_record = table::borrow_mut(&mut task_list.tasks, task_id);
    // assert task is not completed
    assert!(task_record.status == TASK_INIT, ETASK_STATUS_INVALID);
    // update task as completed
    task_record.status = TASK_TAKED;
    task_record.hunter = signer_address;
  }

  public entry fun submit_task(account: &signer, task_id: u64) acquires TaskList {
    // gets the signer address
    let signer_address = signer::address_of(account);
		// assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    // assert task exists
    assert!(table::contains(&task_list.tasks, task_id), ETASK_DOESNT_EXIST);
    // gets the task matched the task_id
    let task_record = table::borrow_mut(&mut task_list.tasks, task_id);
    // assert task is not taked
    assert!(task_record.status == TASK_TAKED, ETASK_STATUS_INVALID);
    // assert task is not completed
    assert!(task_record.hunter == signer_address, ETASK_STATUS_PERMISSION_DENIED);
    // update task as completed
    task_record.status = TASK_SUBMITED;
  }

  public entry fun confirm_task(account: &signer, task_id: u64, is_pass:bool, comment:String) acquires TaskList {
    // gets the signer address
    let signer_address = signer::address_of(account);
		// assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    // assert task exists
    assert!(table::contains(&task_list.tasks, task_id), ETASK_DOESNT_EXIST);
    // gets the task matched the task_id
    let task_record = table::borrow_mut(&mut task_list.tasks, task_id);
    // assert task is not submited
    assert!(task_record.status == TASK_SUBMITED, ETASK_STATUS_INVALID);
    // assert task's publiser is signer_address
    assert!(task_record.publisher == signer_address, ETASK_STATUS_PERMISSION_DENIED);
    task_record.comment = comment;
    if(!is_pass) {
      task_record.status = TASK_TAKED;
    } else {
      task_record.status = TASK_COMPLETED;
      aptos_account::transfer(account, task_record.hunter, task_record.bounty);
    }
    
  }

  #[view]
  public fun get_counter() :u64 acquires TaskList {
    // assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    task_list.task_counter
  }

  #[view]
  public fun read_task(id: u64) :Task acquires TaskList {
    // assert signer has created a list
    assert!(exists<TaskList>(@tasklist_addr), E_NOT_INITIALIZED);
    // gets the TaskList resource
    let task_list = borrow_global_mut<TaskList>(@tasklist_addr);
    *table::borrow(& task_list.tasks, id)
  }

  #[test(admin = @tasklist_addr)]
  public entry fun test_flow(admin: signer) acquires TaskList  {
    // creates an admin @todolist_addr account for test
    account::create_account_for_test(signer::address_of(&admin));
    // initialize contract with admin account
    create_list(&admin);

    //creates a task by the admin account
    create_task(&admin, string::utf8(b"New Task"), 100);
    let task_count = event::counter(&borrow_global<TaskList>(signer::address_of(&admin)).set_task_event);
    assert!(task_count == 1, 4);
    // let task_list = borrow_global<TaskList>(signer::address_of(&admin));
    // assert!(task_list.task_counter == 1, 5);
    // let task_record = table::borrow(&task_list.tasks, task_list.task_counter);
    // assert!(task_record.task_id == 1, 6);
    // assert!(task_record.status == TASK_INIT, 7);
    // assert!(task_record.content == string::utf8(b"New Task"), 8);
    // assert!(task_record.hunter == signer::address_of(&admin), 9);

    // //updates task as completed
    // submit_task(&admin, 1);
    // let task_list = borrow_global<TaskList>(signer::address_of(&admin));
    // let task_record = table::borrow(&task_list.tasks, 1);
    // assert!(task_record.task_id == 1, 10);
    // assert!(task_record.status == TASK_SUBMITED, 11);
    // assert!(task_record.content == string::utf8(b"New Task"), 12);
    // assert!(task_record.hunter == signer::address_of(&admin), 13);
  }

  // #[test(admin = @0x123)]
  // #[expected_failure(abort_code = E_NOT_INITIALIZED)]
  // public entry fun account_can_not_update_task(admin: signer) acquires TaskList {
  //   // creates an admin @todolist_addr account for test
  //   account::create_account_for_test(signer::address_of(&admin));
  //   // account can not toggle task as no list was created
  //   complete_task(&admin, 2);
  // }

}

```
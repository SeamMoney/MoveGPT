module demo::item {
    use 0x1::vector;

    struct School has key {
        class: Class,
        name: vector<u8>,
    }

    struct Class has store {
        name: vector<u8>,
        grade: u8,
        students: vector<Student>
    }

    struct Student has store, copy, drop {
        name: vector<u8>,
        age: u8
    }

    public fun new_studnet(name: vector<u8>, age: u8): Student {
        Student {
            name,age
        }
    }

    public fun new_class(name: vector<u8>, grade: u8): Class {
        let stus = vector::empty<Student>();
        Class {
            name,
            grade,
            students: stus
        }
    }

    public fun add_student(class: &mut Class, stu: Student) {
        vector::push_back(&mut class.students, stu);
    }

    public fun new_school(name:vector<u8>, class: Class): School {
        School {
            name,
            class
        }
    }

    public fun delete(s: School) {
        let School {
            name: _, 
            class: Class {
                name: _,
                grade: _,
                students: _
            } 
        } = s;
    }

}

// aptos-bulletproof move run \
//   --function-id 'local::m::foo' \
//   --profile local --sender-account local

// aptos-bulletproof move run --function-id 'local::m::foo' --profile local 

// aptos-bulletproof move run --function-id '0x126c8f6a869615ec37160234a010b3dc89fd2113dce6073410cecb960efa2b1::item::test' --profile alice 
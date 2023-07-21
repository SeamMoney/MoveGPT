address Viper {
    module Student {
        struct Empty {}

        // define Student struct
        struct Student has drop {
            id: u64,
            age: u8,
            sex: bool,
        }

        // constructor gouzaohanshu
        public fun new_student(_id: u64, _age: u8, _sex: bool): Student {
            Student{
                id: _id,
                age: _age,
                sex: _sex,
            }
        }     
        
        public fun new_student2(id: u64, age: u8, sex: bool): Student {
            Student{
                id,
                age,
                sex,
            }
        }         

        public fun get_id(s: Student): u64 {
            // need ability of drop
            // define struct Student has drop
            s.id
        }

        // -----------
        struct User<T1, T2> has drop {
            id: T1,
            age: T2,
        }

        public fun new_user<T1, T2>(id: T1, age: T2): User<T1, T2> {
            User{ id, age,}
        }


    }


}
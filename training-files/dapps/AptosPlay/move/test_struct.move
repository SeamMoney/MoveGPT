script {
    use 0x1::Debug;
    use Viper::Student;

    use Viper::Math;

    fun test_struct() {
        let s = Student::new_student(1001, 20, true);
        let id = Student::get_id(s);
        Debug::print(&id);
            // -----------
            // can automatic infer
        let user = Student::new_user(1002, 30);

        let user1 = Student::new_user<u64, u8>(1003, 40);

        Debug::print(&user1);

        // -----------------
        let aa = 10;
        Math::show(copy aa);
        Math::show(move aa);
 
    }

}
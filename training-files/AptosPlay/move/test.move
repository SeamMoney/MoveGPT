script {

    use 0x1::Debug;
    use Viper::Math;
    use 0x1::Vector;

    fun test_test() {

        // a array of string's ASCII
        let str = b"hello";
        // [104, 101, 108, 108, 111]
        Debug::print(&str);

        let v2 = Vector::empty<u64>();

        // add 10 to v2 list
        Vector::push_back(&mut v2, 10);
        Vector::push_back(&mut v2, 20);
        // [10, 20]
        Debug::print(&v2);


        let v3 = Vector::empty<u64>();
        Vector::push_back(&mut v3, 30);
        Vector::push_back(&mut v3, 40);
        Vector::push_back(&mut v3, 50);

        Vector::append<u64>(&mut v2, v3);
        Debug::print(&v2);

        Vector::reverse<u64>(&mut v2);
        Debug::print(&v2);

        let x = 10;
        let (flag, index) = Vector::index_of<u64>(&v2, &x);
        Debug::print(&flag);
        Debug::print(&index);

        let (m, _) = (1, 2);
    }


}
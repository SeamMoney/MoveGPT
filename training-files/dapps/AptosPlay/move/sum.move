script {
    use 0x1::Debug;
    use Viper::Math as MM;


    /*
    fun test_sum(a: u64, b: u64) {

        let c = MM::sum(a, b);
        Debug::print(&c);


        let d:u8 = 10;

        let e = MM::sum_2(a, d);
        Debug::print(&e);

    }
    */

    /*
    fun test_max(a: u64, b: u64) {

        Debug::print(&MM::max(a, b));

    }
    */

    fun test_sum_100(a: u64) {
        Debug::print(&MM::sum_to_a(a));
        Debug::print(&MM::sum_99());

        let r:u64 = 8;
        let area = MM::get_area(r);
        Debug::print(&area);

//        if (r < 10) {
//          abort 12;
//        };

//       assert!(r >= 10, 10);
        let addr:address = @Viper;
        Debug::print(&addr);

        let (x, y) = (10, 19);
        let (x, y) = (20, 30);

        // reference 
        let m:&u64 = &x;
        Debug::print(m);

        let a:u64 = 10;
        let b:u64 = 20;

        MM::swap(&mut a, &mut b);
        Debug::print(&a);
        Debug::print(&b);


        let k = 9999;
        Debug::print(&k);

        MM::show(a);
        

    }   
}
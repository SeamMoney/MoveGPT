script {
    // import other module
    use 0x1::Debug; 

    // main func just a name
    fun main() {
        let num:u64 = 1024;
        Debug::print(&num);

        let b:u8 = 13;
        Debug::print(&b);

        let c = 1024u64;
        Debug::print(&c);

        let d = true;
        Debug::print(&d);

    }

}
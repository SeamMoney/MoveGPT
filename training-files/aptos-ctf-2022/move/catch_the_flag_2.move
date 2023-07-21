script {
    use ctfmovement::hello_move;

    fun catch_the_flag(dev: &signer) {
        hello_move::init_challenge(dev);
        hello_move::hash(dev, b"good");
        hello_move::discrete_log(dev, 3123592912467026955);
        hello_move::add(dev, 2, 0);
        hello_move::get_flag(dev);
    }
}
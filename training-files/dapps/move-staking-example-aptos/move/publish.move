script {
    use 0x1::StakingPool;
    fun main(owner: signer) {
        StakingPool::create_pool(&owner);
    }
}

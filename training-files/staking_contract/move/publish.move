script {
    use 0x1::StakingPool;
    fun main(owner: signer) {
        StakingPool::create_pool(&owner);
    }
}
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
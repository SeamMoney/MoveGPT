script {
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use std::signer;

    fun main(
        first: &signer,
        dst_first: address,
    ) {
        assert!( coin::balance<aptos_coin::AptosCoin>(signer::address_of(first)) == 0 , 1);
        let coin_first = coin::withdraw<aptos_coin::AptosCoin>(first, 1);
        coin::deposit(dst_first, coin_first);
    }
}

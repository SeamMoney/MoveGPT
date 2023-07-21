script {
    use std::signer;

    fun mint (account: &signer) 
    {
        let signer_addr = signer::address_of(account);
        aptos_framework::managed_coin::mint<MoonCoin::moon_coin::MoonCoin>(
            account, 
            signer_addr, 
            78000000
        )
    }
}
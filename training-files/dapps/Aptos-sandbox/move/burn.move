script 
{
    fun burn (account: &signer)
    {
        aptos_framework::managed_coin::burn<MoonCoin::moon_coin::MoonCoin>(
            account, 
            20500000
        )
    }
}
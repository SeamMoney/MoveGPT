module AptosShiba::aptos_shiba_coin {
    struct AptosShibaCoin {}
    use std::signer;
    fun init_module(deployerSigner: &signer) {
        aptos_framework::managed_coin::initialize<AptosShibaCoin>(
            deployerSigner,
            b"Aptos Shiba",
            b"APTSHIBA",
            6,
            false,
        );
        let deployerAddress = signer::address_of(deployerSigner);
        aptos_framework::coin::register<AptosShibaCoin>(deployerSigner);        
        aptos_framework::managed_coin::mint<AptosShibaCoin>(deployerSigner, deployerAddress, 1000000000000);        
    }
}
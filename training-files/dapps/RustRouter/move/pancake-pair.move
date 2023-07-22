module aptos_router::pancakepair {
    use aptos_framework::coin;

    use pancake::router;
    use pancake::swap_utils;
    use pancake::swap;   

    fun token_order_correct<X, Y>(): bool{
        swap_utils::sort_token_type<X, Y>()
    }


    //Swap expects the pair's resource account address to already have tokens on it.
    public fun swap_pancake_pair<I, O>(
        amount_in: u64,
        resource_signer: &signer,
        resource_account_addr: address
    ): u64 {
        
        if(!coin::is_account_registered<I>(resource_account_addr)){
            coin::register<I>(resource_signer);
        };

        let reserve_x: u64;
        let reserve_y: u64;
        let output_amount: u64;
        if(token_order_correct<I, O>()){
            (reserve_x, reserve_y, _) =  swap::token_reserves<I, O>();
            output_amount = swap_utils::get_amount_out(amount_in, reserve_x, reserve_y);
        }
        else {
            (reserve_x, reserve_y, _) =  swap::token_reserves<O, I>();
            output_amount = swap_utils::get_amount_out(amount_in, reserve_y, reserve_x);
        };

        router::swap_exact_input<I, O>(resource_signer, amount_in, 0);

        return output_amount
    }

}
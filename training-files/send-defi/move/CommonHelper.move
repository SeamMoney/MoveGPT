address admin {

module CommonHelper {
    use aptos_framework::coin;
    use aptos_framework::account;
    use aptos_framework::signer;

    use admin::CoinMock;


    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;

    public fun safe_accept_token<CoinType: store>(account: &signer) {
        if (!coin::is_account_registered<CoinType>(signer::address_of(account))) {
            coin::register<CoinType>(account);
        };
    }

    public fun safe_mint<CoinType: store>(account: &signer, token_amount: u64) {
        let is_accept_token = account::is_account_registered<CoinType>(Signer::address_of(account));
        if (!is_accept_token) {
            coin::register<CoinType>(account);
        };
        let token = CoinMock::mint_token<CoinType>(token_amount);
        coin::deposit<CoinType>(signer::address_of(account), token);
    }

    public fun transfer<CoinType: store>(account: &signer, token_address: address, token_amount: u64){
        let token = coin::withdraw<CoinType>(account, token_amount);
         coin::deposit(token_address, token);
    }

    public fun get_safe_balance<CoinType: store>(token_address: address): u64{
        let token_balance: u64 = 0;
        if (coin::is_account_registered<CoinType>(token_address)) {
            token_balance = coin::balance<CoinType>(token_address);
        };
        token_balance
    }

    public fun register_and_mint<CoinType: store>(account: &signer, token_amount: u64) {
        CoinMock::register_coin<CoinType>(account, );
        safe_mint<TokenType>(account, token_amount);
    }

    public fun pow_amount<Token: store>(amount: u128): u128 {
        amount * Token::scaling_factor<Token>()
    }

    public fun pow_10(exp: u8): u128 {
        pow(10, exp)
    }

    public fun pow(base: u64, exp: u8): u128 {
        let result_val = 1u128;
        let i = 0;
        while (i < exp) {
            result_val = result_val * (base as u128);
            i = i + 1;
        };
        result_val
    }

}
}
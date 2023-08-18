```rust
/// Coins used for devnet.

module faucet::dev_coin {
    use faucet::faucet;
    use mint_wrapper::mint_wrapper;

    /// Creates a coin.
    fun create_coin<CoinType>(
        name: vector<u8>,
        decimals: u64,
        hard_cap: u64
    ) {
        let source = faucet::get_signer();
        let minter = faucet::get_minter();
        mint_wrapper::create_with_coin<CoinType>(&source, name, decimals, hard_cap);
        mint_wrapper::offer_minter<CoinType>(&source, minter, hard_cap);
    }

    {% for coin in coins %}
    /// CoinType of {{ coin.name }}.
    struct {{ coin.symbol }} {}

    /// Initializes the {{ coin.symbol }} token.
    public entry fun init_{{ coin.symbol | lower }}() {
        create_coin<{{ coin.symbol }}>(b"{{ coin.name }}", {{ coin.decimals }}, {{ coin.hard_cap }});
    }
    {% endfor %}
}
```
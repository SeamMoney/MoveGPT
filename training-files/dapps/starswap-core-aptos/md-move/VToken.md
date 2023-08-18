```rust
module SwapAdmin::VToken {
    use aptos_framework::coin;
    use aptos_std::type_info;

    use std::string;
    use std::signer;

    use SwapAdmin::CommonHelper;

    struct VToken<phantom CoinT> has key, store {
        token: coin::Coin<CoinT>
    }

    struct OwnerCapability<phantom CoinT> has key, store {
        mint_cap: coin::MintCapability<CoinT>,
        burn_cap: coin::BurnCapability<CoinT>,
        freeze_cap: coin::FreezeCapability<CoinT>,
    }

    public fun register_token<CoinT>(account: &signer, precision: u8) {
        let coin_info = type_info::type_of<CoinT>();
        let coin_name = type_info::struct_name(&coin_info);
        let (
            burn_cap,
            freeze_cap,
            mint_cap
        ) = coin::initialize<CoinT>(
            account,
            string::utf8(coin_name),
            string::utf8(coin_name),
            precision,
            true,
        );
        CommonHelper::safe_accept_token<CoinT>(account);

        move_to(account, OwnerCapability<CoinT> {
            mint_cap,
            burn_cap,
            freeze_cap,
        });
    }

    public fun extract_cap<CoinT>(signer: &signer): OwnerCapability<CoinT> acquires OwnerCapability {
        move_from<OwnerCapability<CoinT>>(signer::address_of(signer))
    }

    /// Create a new VToken::VToken<CoinT> with a value of 0
    public fun zero<CoinT>(): VToken<CoinT> {
        VToken<CoinT> {
            token: coin::zero<CoinT>()
        }
    }

    public fun mint<CoinT>(signer: &signer, amount: u128): VToken<CoinT> acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<CoinT>>(signer::address_of(signer));
        VToken<CoinT> {
            token: coin::mint((amount as u64), &cap.mint_cap)
        }
    }

    public fun mint_with_cap<CoinT>(cap: &OwnerCapability<CoinT>, amount: u128): VToken<CoinT> {
        let bared_token = coin::mint((amount as u64), &cap.mint_cap);
        VToken<CoinT> {
            token: bared_token
        }
    }

    public fun burn<CoinT>(signer: &signer, vt: VToken<CoinT>) acquires OwnerCapability {
        let cap = borrow_global<OwnerCapability<CoinT>>(signer::address_of(signer));
        burn_with_cap(cap, vt)
    }

    public fun burn_with_cap<CoinT>(cap: &OwnerCapability<CoinT>, vt: VToken<CoinT>) {
        let VToken<CoinT> {
            token
        } = vt;
        coin::burn(token, &cap.burn_cap);
    }

    public fun value<CoinT>(vt: &VToken<CoinT>): u128 {
        (coin::value<CoinT>(&vt.token) as u128)
    }

    public fun deposit<CoinT>(lhs: &mut VToken<CoinT>, rhs: VToken<CoinT>) {
        let VToken<CoinT> {
            token
        } = rhs;
        coin::merge(&mut lhs.token, token);
    }

    /// Withdraw from a token
    public fun withdraw<CoinT>(src_token: &mut VToken<CoinT>, amount: u128): VToken<CoinT> {
        VToken<CoinT> {
            token: coin::extract(&mut src_token.token, (amount as u64))
        }
    }
}


```
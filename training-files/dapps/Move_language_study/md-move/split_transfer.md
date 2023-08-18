```rust
script {
    use aptos_framework::coin;
    // 명시적 타입인 phantom type CoinType을 사용한다
    fun main<CoinType>(sender: &signer, receiver_a: address, receiver_b: address, amount: u64) {
        // sender에서 amount만큼 코인을 뽑아서 객체를 얻고
        let coin = coin::withdraw<CoinType>(sender, amount);
        // 그 객체에서 절반을 뽑아서 객체를 만들어서
        let coins_a = coin::extract(&mut coins, amount / 2);
        // receiver a, b의 coin 객체에 각각 코인 추가
        coin::deposit(receiver_a, coins_a);
        coin::deposit(receiver_b, coins);
    }
}

// ========================================================================================

    // public fun withdraw<CoinType>(
    //         account: &signer,
    //         amount: u64,
    // ): Coin<CoinType> acquires CoinStore {
    //     // 주소값 변수에 저장 
    //     let account_addr = signer::address_of(account);
    //     // 주소값이 account로 등록되어있는지 체크
    //     // 등록 되어있지 않다면 에러코드와 함께 revert
    //     assert!(
    //         is_account_registered<CoinType>(account_addr),
    //         error::not_found(ECOIN_STORE_NOT_PUBLISHED),
    //     );
    //     // coin store에 대해 수정권한과 소유권을 얻어온다
    //     let coin_store = borrow_global_mut<CoinStore<CoinType>>(account_addr);
    //     // store가 frozen 상태라면 에러코드와 함께 revert
    //     // frozen 상태는 계정이 store에 코인을 저장할 수 없도록 지정하는 bool값
    //     assert!(
    //         !coin_store.frozen,
    //         error::permission_denied(EFROZEN),
    //     );
    //     // withdraw한만큼 이벤트 발생
    //     event::emit_event<WithdrawEvent>(
    //         &mut coin_store.withdraw_events,
    //         WithdrawEvent { amount },
    //     );
    //     // ERC20의 transfer와 같은 기능
    //     extract(&mut coin_store.coin, amount)
    // }

// ========================================================================================

    // public fun extract<CoinType>(coin: &mut Coin<CoinType>, amount: u64): Coin<CoinType> {
    //     // 충분한 coin안에 보낼 양보다 많은 코인이 있는지 확인
    //     assert!(coin.value >= amount, error::invalid_argument(EINSUFFICIENT_BALANCE));
    //     spec {
    //         update supply<CoinType> = supply<CoinType> - amount;
    //     };
    //     // 코인을 꺼내서
    //     coin.value = coin.value - amount;
    //     spec {
    //         update supply<CoinType> = supply<CoinType> + amount;
    //     };
    //     // 꺼낸 양만큼 들어있는 객체를 리턴
    //     Coin { value: amount }
    // }

// ========================================================================================

    // public fun deposit<CoinType>(account_addr: address, coin: Coin<CoinType>) acquires CoinStore {
    //     // 인수로 들어온 주소에 대한 코인 객체가 있는지 확인
    //     assert!(
    //         is_account_registered<CoinType>(account_addr),
    //         error::not_found(ECOIN_STORE_NOT_PUBLISHED),
    //     );
    //     // 인수로 들어온 주소에 대한 코인 객체의 소유권과 수정권한을 얻는다
    //     let coin_store = borrow_global_mut<CoinStore<CoinType>>(account_addr);
    //     // 코인 객체가 frozen 상태라면 revert
    //     assert!(
    //         !coin_store.frozen,
    //         error::permission_denied(EFROZEN),
    //     );
    //     // deposit 이벤트 발생
    //     event::emit_event<DepositEvent>(
    //         &mut coin_store.deposit_events,
    //         DepositEvent { amount: coin.value },
    //     );
    //     // 첫 번째 인수로 들어온 coin 객체에
    //     // 두 번째 인수로 들어온 coin 객체의 amount를 넣어 합친다
    //     merge(&mut coin_store.coin, coin);
    // }

// ========================================================================================

    // public fun merge<CoinType>(dst_coin: &mut Coin<CoinType>, source_coin: Coin<CoinType>) {
    //     // overflow 검사
    //     spec {
    //         assume dst_coin.value + source_coin.value <= MAX_U64;
    //     };
    //     // merge 전의 coin = total supply - merge할 양 (!재확인 필요)
    //     spec {
    //         // supply<CoinType>은 코인 생성자가 가지고 있는 total supply 정보
    //         update supply<CoinType> = supply<CoinType> - source_coin.value;
    //     };
    //     let Coin { value } = source_coin;
    //     // merge 후의 coin = merge 전의 coin + merge할 양 (!재확인 필요)
    //     spec {
    //         update supply<CoinType> = supply<CoinType> + value;
    //     };
    //     첫 번째 인수로 들어온 coin 객체에 두 번째 인수로 들어온 coin 객체의 amount를 넣어 합친다
    //     dst_coin.value = dst_coin.value + value;
    // }

// ========================================================================================
```
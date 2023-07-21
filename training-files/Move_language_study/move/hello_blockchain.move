// Move.toml의 addresses에는 작성하는 모듈의 주소를 지정할 수 있다 
// ::message는 message모듈을 선언하는 것
module hello_blockchain::message {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::event;

    struct MessageHolder has key {
        message: string::String,
        message_change_events: event::EventHandle<MessageChangeEvent>,
    }

    // key도 storage에 저장되는거 같은데, 아직 drop의 용도를 잘 모르겠음
    struct MessageChangeEvent has drop, store {
        from_message: string::String,
        to_messsage: string::String,
    }

    const ENO_MESSAGE: u64 = 0;

    #[view]
    public fun get_message(addr: address): string::String acquires MessageHolder {
        // 주소에게 MessageHolder가 없다면 에러처리
        assert!(exists<MessageHolder>(addr), error::not_found(ENO_MESSAGE));
        // mutable reference에서 값 가져오기
        borrow_global<MessageHolder>(addr).message
    }

    public entry fun set_message(account: signer, message: string::String) acquires MessageHolder {
        let account_addr = signer::address_of(&account);
        // 주소에게 MessageHolder가 없다면
        if (!exists<MessageHolder>(account_addr)) {
            // 
            move_to(&account, MessageHolder {
                message,
                // create_guid로 새로 생성한 message change event nonce값 부여
                message_change_events: account::new_event_handle<MessageChangeEvent>(&account),
                // public fun new_event_handle<T: drop + store>(account: &signer): EventHandle<T> acquires Account {
                // event::new_event_handle(create_guid(account))

                // public(friend) fun new_event_handle<T: drop + store>(guid: GUID): EventHandle<T> {
                //     EventHandle<T> {
                //         counter: 0,
                //         guid,
                //     }
            }
        } else {
            let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
            
            let from_message = old_message_holder.message;
            event::emit_event(&mut old_message_holder.message_change_events, MessageChangeEvent {
                // to message -> from message
                from_message,
                // 인수로 들어온 message로 업데이트
                to_messsage: copy message,
            });
            old_message_holder.messsage = message;
        }
    }

    // testing할 때 0x1 address를 account라는 변수에 바인딩
    #[test(account = @0x1)]
    public entry fun sender_can_set_message(account: signer) acquires MessageHolder {
        // addr에 0x1가져오기 
        let addr = signer::address_of(&account);
        // 0x1로 테스트용 계정 생성
        aptos_framework::account::create_account_for_test(addr);
        // MessageHolder의 message에 string 저장
        set_message(account, string::utf8(b"hello, Blockchain"));
        // 의도한대로 string이 저장되었는지 확인
        assert!(get_message(addr) == string::utf8(b"Hello, Blockchain")), ENO_MESSAGE);
    }
}
module openmove::timers {
    use aptos_framework::timestamp;

    struct Timestamp has drop, key {
        deadline: u64,
    }

    const DEADLINE_ERROR: u64 = 1;

    public entry fun init_module(sender: &signer) {
        move_to<Timestamp>(sender, Timestamp { deadline: 0});
    }

    public fun getDeadline(): u64 acquires Timestamp {
        let timer = borrow_global<Timestamp>(@openmove);
        timer.deadline
    }

    public fun setDeadline(timestamp: u64) acquires Timestamp {
        let timer = borrow_global_mut<Timestamp>(@openmove);
        timer.deadline = timestamp;
    }

    public fun reset() acquires Timestamp {
        let timer = borrow_global_mut<Timestamp>(@openmove);
        timer.deadline = 0;
    }

    public fun isUnset(): bool acquires Timestamp {
        let timer = borrow_global<Timestamp>(@openmove);
        if (timer.deadline == 0) {
            return true
        } else {
            return false
        }
    }

    public fun isStarted(): bool acquires Timestamp {
        let timer = borrow_global<Timestamp>(@openmove);
        if (timer.deadline > 0) {
            return true
        } else {
            return false
        }
    }

    public fun isPending(): bool acquires Timestamp {
        let timer = borrow_global<Timestamp>(@openmove);
        if (timer.deadline > timestamp::now_seconds()) {
            return true
        } else {
            return false
        }
    }

    public fun isExpired(): bool acquires Timestamp {
        let timer = borrow_global<Timestamp>(@openmove);
        if (timer.deadline <= timestamp::now_seconds() && isStarted() == true) {
            return true
        } else {
            return false
        }
    }
}
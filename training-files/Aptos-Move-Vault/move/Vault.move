module vault::Vault{
	use aptos_framework::coin as Coin;
	use aptos_std::event;
	use std::signer;

	const COIN_NOT_REGISTERED: u64 = 1;
	const VAULT_ALREADY_MOVED: u64 = 2;
	const USER_NOT_DEPOSITED: u64 = 3;
	const BALANCE_NOT_ENOUGHT: u64 = 4;
	const VAULT_PAUSED: u64 = 5;
	const INVALID_ADMIN: u64 = 6;

	struct ManagedCoin {}

	struct VaultHolder has key {
		vault: Coin::Coin<ManagedCoin>,
		paused: bool
	}

	struct UserInfo has key {
		amount: u64,
		amount_change_events: event::EventHandle<AmountWithdrawDepositEvent>
	}

	struct AmountWithdrawDepositEvent has drop, store {
		from_amount: u64,
		to_amount: u64
	}

	public entry fun init_vault(admin: &signer) {
		let addr = signer::address_of(admin);
		if (!Coin::is_account_registered<ManagedCoin>(addr)){
			Coin::register<ManagedCoin>(admin);
		};

		assert!(Coin::is_account_registered<ManagedCoin>(addr), COIN_NOT_REGISTERED);
		assert!(!exists<VaultHolder>(addr), VAULT_ALREADY_MOVED);

		let vault = Coin::zero<ManagedCoin>();
		move_to(admin, VaultHolder {
			vault,
			paused: false
		});
	}

	public entry fun pause_vault(admin: &signer) acquires VaultHolder {
		let addr = signer::address_of(admin);
		assert!(exists<VaultHolder>(addr), INVALID_ADMIN);
		let old_vault_holder = borrow_global_mut<VaultHolder>(addr);
		old_vault_holder.paused = true;
	}

	public entry fun unpause_vault(admin: &signer) acquires VaultHolder {
		let addr = signer::address_of(admin);
		assert!(exists<VaultHolder>(addr), INVALID_ADMIN);
		let old_vault_holder = borrow_global_mut<VaultHolder>(addr);
		old_vault_holder.paused = false;
	}

	public entry fun deposit(user: &signer, amount: u64, vault_account: address) acquires VaultHolder, UserInfo{
		assert!(!*&borrow_global<VaultHolder>(vault_account).paused, VAULT_PAUSED);

		let addr = signer::address_of(user);
		assert!(Coin::is_account_registered<ManagedCoin>(addr), COIN_NOT_REGISTERED);
		if (!exists<UserInfo>(addr)) {
			move_to(user, UserInfo {
				amount: (copy amount),
				amount_change_events: event::new_event_handle<AmountWithdrawDepositEvent>(copy user),
			});
		} else {
			let old_info = borrow_global_mut<UserInfo>(addr);
			let from_amount = *&old_info.amount;
			event::emit_event(&mut old_info.amount_change_events, AmountWithdrawDepositEvent {
				from_amount,
				to_amount: from_amount + (copy amount),
			});
			old_info.amount = old_info.amount + (copy amount);
		};
		let coin = Coin::withdraw<ManagedCoin>(user, amount);
		let vault_holder = borrow_global_mut<VaultHolder>(vault_account);
		Coin::merge<ManagedCoin>(&mut vault_holder.vault, coin);
	}

	public entry fun withdraw(user: &signer, amount: u64,vault_account: address) acquires VaultHolder, UserInfo {
		assert!(!*&borrow_global<VaultHolder>(vault_account).paused, VAULT_PAUSED);

		let addr = signer::address_of(user);
		assert!(Coin::is_account_registered<ManagedCoin>(addr), COIN_NOT_REGISTERED);
		assert!(exists<UserInfo>(addr), USER_NOT_DEPOSITED);

		let current_info = borrow_global_mut<UserInfo>(addr);
		let current_amount = *&current_info.amount;
		assert!(current_amount >= amount, BALANCE_NOT_ENOUGHT);

		event::emit_event(&mut current_info.amount_change_events, AmountWithdrawDepositEvent {
			from_amount: current_amount,
			to_amount: current_amount - (copy amount),
		});
		current_info.amount = current_info.amount - (copy amount);

		let vault_holder = borrow_global_mut<VaultHolder>(vault_account);
		let coins = Coin::extract<ManagedCoin>(&mut vault_holder.vault, amount);
		Coin::deposit<ManagedCoin>(addr, coins);
	}

}


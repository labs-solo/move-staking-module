module TokenDaysDestroyedStaking {
    use std::signer;
    use std::error;
    use std::event;
    use std::option::{Self as Option, Option};
    use aptos_framework::coin::{Self as CoinFramework, Coin};
    use aptos_framework::block;

    // Error codes with descriptive messages
    const E_AMOUNT_ZERO: u64 = 1; // Staking amount cannot be zero
    const E_INSUFFICIENT_BALANCE: u64 = 2; // Insufficient staked balance
    const E_NOT_ADMIN: u64 = 3; // Caller is not the admin
    const E_STAKER_NOT_FOUND: u64 = 4; // Staker resource not found
    const E_OVERFLOW: u64 = 5; // Arithmetic overflow occurred
    const E_ADMIN_ALREADY_INITIALIZED: u64 = 6; // Admin already initialized
    const E_NO_STAKER_RESOURCE: u64 = 7; // No staker resource to destroy
    const E_UNAUTHORIZED: u64 = 8; // Unauthorized access

    // Admin resource
    struct Admin has key {
        authority: address, // The admin's address
    }

    // Staking events
    struct StakingEvents<phantom CoinType> has key {
        stake_event_handle: event::EventHandle<StakeEvent<CoinType>>,
        unstake_event_handle: event::EventHandle<UnstakeEvent<CoinType>>,
    }

    // Stake event
    struct StakeEvent<phantom CoinType> has copy, drop {
        user: address,
        amount: u64,
    }

    // Unstake event
    struct UnstakeEvent<phantom CoinType> has copy, drop {
        user: address,
        amount: u64,
    }

    // Staker resource stored under user's account
    struct Staker<phantom CoinType> has key {
        amount: u64,
        deposit_block: u64,
        token_days_destroyed: u128,
    }

    // Global staking info for tracking total staked per CoinType
    struct GlobalStakingInfo<phantom CoinType> has key {
        total_staked: u64,
    }

    // Initializes the admin account
    public entry fun initialize_admin(admin: &signer) {
        let admin_address = signer::address_of(admin);
        assert!(!exists<Admin>(admin_address), error::invalid_argument(E_ADMIN_ALREADY_INITIALIZED));
        move_to(admin, Admin { authority: admin_address });
    }

    // Initializes staking events and global staking info for a CoinType
    public entry fun initialize_staking_events<CoinType: store + drop>(
        admin: &signer
    ) acquires Admin {
        let admin_address = signer::address_of(admin);
        let admin_resource = borrow_global<Admin>(admin_address);

        // Ensure caller is admin
        assert!(admin_address == admin_resource.authority, error::permission_denied(E_NOT_ADMIN));

        // Initialize event handles if not already present
        if (!exists<StakingEvents<CoinType>>(admin_address)) {
            let stake_event_handle = event::new_event_handle<StakeEvent<CoinType>>(admin);
            let unstake_event_handle = event::new_event_handle<UnstakeEvent<CoinType>>(admin);

            move_to(
                admin,
                StakingEvents<CoinType> {
                    stake_event_handle,
                    unstake_event_handle,
                },
            );
        }

        // Initialize GlobalStakingInfo if not already present
        if (!exists<GlobalStakingInfo<CoinType>>(admin_address)) {
            move_to(
                admin,
                GlobalStakingInfo<CoinType> {
                    total_staked: 0,
                },
            );
        }
    }

    // Stake tokens
    public entry fun stake<CoinType: store + drop>(
        user: &signer,
        treasury_address: address,
        amount: u64
    ) acquires Staker, GlobalStakingInfo {
        assert!(amount > 0, error::invalid_argument(E_AMOUNT_ZERO));
        let user_address = signer::address_of(user);

        // Transfer tokens from user to treasury
        CoinFramework::transfer<CoinType>(user, treasury_address, amount);

        // Update staker data
        if (!exists<Staker<CoinType>>(user_address)) {
            // Create new staker resource
            let staker = Staker<CoinType> {
                amount,
                deposit_block: get_current_block(),
                token_days_destroyed: 0,
            };
            move_to<CoinType>(user, staker);
        } else {
            // Update existing staker resource
            let staker = borrow_global_mut<Staker<CoinType>>(user_address);
            update_token_days_destroyed_internal(staker)?;
            staker.amount = safe_add(staker.amount, amount)?;
            staker.deposit_block = get_current_block();
        }

        // Update global total staked amount
        update_total_staked_internal<CoinType>(amount, true)?;

        // Emit stake event
        emit_stake_event<CoinType>(user_address, amount);
    }

    // Unstake tokens
    public entry fun unstake<CoinType: store + drop>(
        user: &signer,
        treasury: &signer,
        amount: u64
    ) acquires Staker, GlobalStakingInfo {
        assert!(amount > 0, error::invalid_argument(E_AMOUNT_ZERO));
        let user_address = signer::address_of(user);

        // Ensure staker resource exists
        assert!(exists<Staker<CoinType>>(user_address), error::not_found(E_STAKER_NOT_FOUND));
        let staker = borrow_global_mut<Staker<CoinType>>(user_address);

        // Ensure sufficient staked balance
        assert!(staker.amount >= amount, error::insufficient_balance(E_INSUFFICIENT_BALANCE));

        // Update TDD
        update_token_days_destroyed_internal(staker)?;

        // Update staker data
        staker.amount = staker.amount - amount;
        staker.deposit_block = get_current_block();

        // Update global total staked amount
        update_total_staked_internal<CoinType>(amount, false)?;

        // Transfer tokens back to user
        CoinFramework::transfer<CoinType>(treasury, user_address, amount);

        // Emit unstake event
        emit_unstake_event<CoinType>(user_address, amount);
    }

    // Update total staked amount internally
    fun update_total_staked_internal<CoinType: store + drop>(
        amount: u64,
        increase: bool
    ) acquires GlobalStakingInfo {
        let admin_address = get_admin_address();
        let staking_info = borrow_global_mut<GlobalStakingInfo<CoinType>>(admin_address);

        if (increase) {
            staking_info.total_staked = safe_add(staking_info.total_staked, amount)?;
        } else {
            staking_info.total_staked = staking_info.total_staked - amount;
        }
    }

    // Internal function to update TDD
    fun update_token_days_destroyed_internal<CoinType: store + drop>(
        staker: &mut Staker<CoinType>
    ): Result<(), u64> {
        if (staker.amount > 0) {
            let current_block = get_current_block();
            let blocks_elapsed = current_block - staker.deposit_block;

            let tdd_increment = safe_mul(staker.amount as u128, blocks_elapsed as u128)?;
            staker.token_days_destroyed = safe_add(staker.token_days_destroyed, tdd_increment)?;

            staker.deposit_block = current_block;
        }
        Ok(())
    }

    // Calculate total TDD for a user
    public fun calculate_token_days_destroyed<CoinType: store + drop>(
        user_address: address
    ): u128 acquires Staker {
        if (!exists<Staker<CoinType>>(user_address)) {
            return 0;
        }

        let staker = borrow_global<Staker<CoinType>>(user_address);
        let mut current_tdd = staker.token_days_destroyed;

        if (staker.amount > 0) {
            let current_block = get_current_block();
            let blocks_elapsed = current_block - staker.deposit_block;

            let tdd_increment = safe_mul(staker.amount as u128, blocks_elapsed as u128);
            if (tdd_increment.is_err()) {
                // Handle overflow
                abort E_OVERFLOW;
            }

            current_tdd = safe_add(current_tdd, tdd_increment.unwrap());
        }

        current_tdd
    }

    // Get staking details
    public fun get_staking_details<CoinType: store + drop>(
        user_address: address
    ): Option<Staker<CoinType>> acquires Staker {
        if (exists<Staker<CoinType>>(user_address)) {
            let staker = borrow_global<Staker<CoinType>>(user_address);
            Option::some<Staker<CoinType>>(*staker)
        } else {
            Option::none<Staker<CoinType>>()
        }
    }

    // Emergency withdrawal by admin
    public entry fun emergency_withdraw<CoinType: store + drop>(
        admin: &signer,
        treasury: &signer,
        amount: u64
    ) acquires Admin, GlobalStakingInfo {
        let admin_address = signer::address_of(admin);
        let admin_resource = borrow_global<Admin>(admin_address);

        // Ensure caller is admin
        assert!(admin_address == admin_resource.authority, error::permission_denied(E_NOT_ADMIN));

        // Calculate available balance
        let treasury_address = signer::address_of(treasury);
        let treasury_balance = CoinFramework::balance<CoinType>(&treasury_address);
        let staking_info = borrow_global<GlobalStakingInfo<CoinType>>(admin_address);
        let total_staked = staking_info.total_staked;

        let available_balance = treasury_balance - total_staked;
        assert!(available_balance >= amount, error::insufficient_balance(E_INSUFFICIENT_BALANCE));

        // Transfer tokens to admin
        CoinFramework::transfer<CoinType>(treasury, admin_address, amount);

        // (Optional) Emit an emergency withdrawal event
    }

    // Transfer admin rights
    public entry fun transfer_admin(
        admin: &signer,
        new_admin_address: address
    ) acquires Admin {
        let admin_address = signer::address_of(admin);
        let admin_resource = borrow_global_mut<Admin>(admin_address);

        // Ensure caller is the current admin
        assert!(admin_address == admin_resource.authority, error::permission_denied(E_NOT_ADMIN));

        // Update the admin authority
        admin_resource.authority = new_admin_address;
    }

    // Cleanup staker resource
    public entry fun cleanup_staker<CoinType: store + drop>(
        user: &signer
    ) acquires Staker {
        let user_address = signer::address_of(user);
        assert!(exists<Staker<CoinType>>(user_address), error::not_found(E_NO_STAKER_RESOURCE));

        let staker = borrow_global<Staker<CoinType>>(user_address);
        // Ensure staker amount is zero
        assert!(staker.amount == 0, error::invalid_argument(E_INSUFFICIENT_BALANCE));

        move_from<Staker<CoinType>>(user_address);
    }

    // Emit stake event
    fun emit_stake_event<CoinType: store + drop>(
        user_address: address,
        amount: u64
    ) {
        let staking_events = borrow_global_mut<StakingEvents<CoinType>>(get_admin_address());
        event::emit_event(
            &mut staking_events.stake_event_handle,
            StakeEvent<CoinType> {
                user: user_address,
                amount,
            },
        );
    }

    // Emit unstake event
    fun emit_unstake_event<CoinType: store + drop>(
        user_address: address,
        amount: u64
    ) {
        let staking_events = borrow_global_mut<StakingEvents<CoinType>>(get_admin_address());
        event::emit_event(
            &mut staking_events.unstake_event_handle,
            UnstakeEvent<CoinType> {
                user: user_address,
                amount,
            },
        );
    }

    // Safe addition for u64
    fun safe_add(a: u64, b: u64): Result<u64, u64> {
        match a.checked_add(b) {
            Option::some(result) => Ok(result),
            Option::none => Err(E_OVERFLOW),
        }
    }

    // Safe addition for u128
    fun safe_add(a: u128, b: u128): Result<u128, u64> {
        match a.checked_add(b) {
            Option::some(result) => Ok(result),
            Option::none => Err(E_OVERFLOW),
        }
    }

    // Safe multiplication for u128
    fun safe_mul(a: u128, b: u128): Result<u128, u64> {
        match a.checked_mul(b) {
            Option::some(result) => Ok(result),
            Option::none => Err(E_OVERFLOW),
        }
    }

    // Get current block number
    fun get_current_block(): u64 {
        block::get_current_block_number()
    }

    // Get admin address
    fun get_admin_address(): address {
        // For simplicity, we assume the admin address is known
        // Replace with actual logic to retrieve the admin address dynamically
        @0xA550C18 // Placeholder address; replace with actual admin address
    }
}

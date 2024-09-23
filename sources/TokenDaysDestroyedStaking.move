module TokenDaysDestroyedStaking {

    use std::signer;
    use aptos_framework::coin::{Self as CoinFramework, Coin, CoinStore};
    use aptos_framework::block;
    use aptos_framework::event;

    /// The Admin resource contains the authority address.
    struct Admin has key {
        authority: address,
    }

    /// Configuration resource holding the treasury address.
    struct Config has key {
        treasury_address: address,
    }

    /// Staking events for a specific CoinType.
    struct StakingEvents<phantom CoinType> has key {
        event_handle: event::EventHandle<StakingEvent<CoinType>>,
    }

    /// Event emitted when a user stakes or unstakes tokens.
    struct StakingEvent<phantom CoinType> has copy, drop {
        user: address,
        amount: u64,
        is_stake: bool, // true for stake, false for unstake
    }

    /// The Staker resource holds the staking information for a user.
    struct Staker<phantom CoinType> has key {
        amount: u64,
        deposit_block: u64,
        token_days_destroyed: u128,
    }

    /// Global staking info for tracking total staked per CoinType.
    struct GlobalStakingInfo<phantom CoinType> has key {
        total_staked: u64,
    }

    /// Initializes the admin account with the `Admin` resource.
    /// Can only be called once.
    public entry fun initialize_admin(admin: &signer) {
        let admin_address = signer::address_of(admin);
        let module_address = address_of<Self>();
        assert!(!exists<Admin>(module_address), "Admin already initialized");
        move_to(&signer::new_signer(module_address), Admin { authority: admin_address });
    }

    /// Initializes the configuration with the treasury address.
    /// Can only be called once by the admin.
    public entry fun initialize_config(admin: &signer, treasury_address: address) {
        let admin_address = get_admin_address();
        let caller_address = signer::address_of(admin);
        assert!(caller_address == admin_address, "Caller is not the admin");

        let module_address = address_of<Self>();
        assert!(!exists<Config>(module_address), "Config already initialized");
        move_to(&signer::new_signer(module_address), Config { treasury_address });
    }

    /// Stakes tokens by transferring them to the treasury.
    public entry fun stake<CoinType: store + CoinStore>(
        user: &signer,
        amount: u64
    ) acquires Staker, GlobalStakingInfo, StakingEvents {
        assert!(amount > 0, "Amount must be greater than zero");
        let user_address = signer::address_of(user);
        let treasury_address = get_treasury_address();

        // Initialize StakingEvents if not present
        if (!exists<StakingEvents<CoinType>>(address_of<Self>())) {
            let event_handle = event::new_event_handle<StakingEvent<CoinType>>(user);
            move_to(
                &signer::new_signer(address_of<Self>()),
                StakingEvents<CoinType> {
                    event_handle,
                },
            );
        }

        // Initialize GlobalStakingInfo if not present
        if (!exists<GlobalStakingInfo<CoinType>>(address_of<Self>())) {
            move_to(
                &signer::new_signer(address_of<Self>()),
                GlobalStakingInfo<CoinType> {
                    total_staked: 0,
                },
            );
        }

        CoinFramework::transfer<CoinType>(user, treasury_address, amount);

        if (!exists<Staker<CoinType>>(user_address)) {
            move_to(user, Staker<CoinType> {
                amount,
                deposit_block: get_current_block(),
                token_days_destroyed: 0,
            });
        } else {
            let staker = borrow_global_mut<Staker<CoinType>>(user_address);
            update_token_days_destroyed_internal(staker);
            increase_staker_amount(staker, amount);
        }

        update_total_staked_internal<CoinType>(amount, true);
        emit_event<CoinType>(true, user_address, amount);
    }

    /// Unstakes tokens and transfers them back to the user from the treasury.
    public entry fun unstake<CoinType: store + CoinStore>(
        user: &signer,
        amount: u64
    ) acquires Staker, GlobalStakingInfo {
        assert!(amount > 0, "Amount must be greater than zero");
        let user_address = signer::address_of(user);
        let treasury_address = get_treasury_address();
        let treasury_signer = signer::new_signer(treasury_address);

        assert!(exists<Staker<CoinType>>(user_address), "Staker resource not found");

        // Initialize GlobalStakingInfo if not present
        if (!exists<GlobalStakingInfo<CoinType>>(address_of<Self>())) {
            move_to(
                &signer::new_signer(address_of<Self>()),
                GlobalStakingInfo<CoinType> {
                    total_staked: 0,
                },
            );
        }

        let staker = borrow_global_mut<Staker<CoinType>>(user_address);
        assert!(staker.amount >= amount, "Insufficient staked balance");

        update_token_days_destroyed_internal(staker);
        decrease_staker_amount(staker, amount);
        update_total_staked_internal<CoinType>(amount, false);

        CoinFramework::transfer<CoinType>(&treasury_signer, user_address, amount);
        emit_event<CoinType>(false, user_address, amount);
    }

    /// Increases the staker's amount.
    fun increase_staker_amount<CoinType: store>(
        staker: &mut Staker<CoinType>,
        amount: u64
    ) {
        staker.amount = staker.amount + amount;
        staker.deposit_block = get_current_block();
    }

    /// Decreases the staker's amount.
    fun decrease_staker_amount<CoinType: store>(
        staker: &mut Staker<CoinType>,
        amount: u64
    ) {
        staker.amount = staker.amount - amount;
        staker.deposit_block = get_current_block();
    }

    /// Updates the total staked amount internally.
    fun update_total_staked_internal<CoinType: store>(
        amount: u64,
        increase: bool
    ) acquires GlobalStakingInfo {
        let staking_info = borrow_global_mut<GlobalStakingInfo<CoinType>>(address_of<Self>());
        if (increase) {
            staking_info.total_staked = staking_info.total_staked + amount;
        } else {
            assert!(staking_info.total_staked >= amount, "Total staked cannot be negative");
            staking_info.total_staked = staking_info.total_staked - amount;
        }
    }

    /// Internal function to update Token Days Destroyed (TDD).
    fun update_token_days_destroyed_internal<CoinType: store>(
        staker: &mut Staker<CoinType>
    ) {
        if (staker.amount > 0) {
            let current_block = get_current_block();
            let blocks_elapsed = current_block - staker.deposit_block;

            let tdd_increment = staker.amount as u128 * blocks_elapsed as u128;
            staker.token_days_destroyed = staker.token_days_destroyed + tdd_increment;

            staker.deposit_block = current_block;
        }
    }

    /// Calculates the total Token Days Destroyed (TDD) for a user.
    public fun calculate_token_days_destroyed<CoinType: store>(
        user_address: address
    ): u128 acquires Staker {
        if (!exists<Staker<CoinType>>(user_address)) {
            return 0;
        }
        let staker = borrow_global<Staker<CoinType>>(user_address);

        if (staker.amount == 0) {
            return staker.token_days_destroyed;
        }

        let current_block = get_current_block();
        let blocks_elapsed = current_block - staker.deposit_block;
        let tdd_increment = staker.amount as u128 * blocks_elapsed as u128;
        staker.token_days_destroyed + tdd_increment
    }

    /// Retrieves the staked amount for a user.
    public fun get_staked_amount<CoinType: store>(
        user_address: address
    ): Option<u64> acquires Staker {
        if (exists<Staker<CoinType>>(user_address)) {
            let staker = borrow_global<Staker<CoinType>>(user_address);
            Option::some(staker.amount)
        } else {
            Option::none()
        }
    }

    /// Performs an emergency withdrawal by the admin.
    public entry fun emergency_withdraw<CoinType: store + CoinStore>(
        admin: &signer,
        amount: u64
    ) acquires GlobalStakingInfo {
        let admin_address = get_admin_address();
        let caller_address = signer::address_of(admin);
        assert!(caller_address == admin_address, "Caller is not the admin");

        let treasury_address = get_treasury_address();
        let treasury_signer = signer::new_signer(treasury_address);
        let treasury_balance = CoinFramework::balance<CoinType>(&treasury_address);

        // Initialize GlobalStakingInfo if not present
        let total_staked = if (exists<GlobalStakingInfo<CoinType>>(address_of<Self>())) {
            let staking_info = borrow_global<GlobalStakingInfo<CoinType>>(address_of<Self>());
            staking_info.total_staked
        } else {
            0
        };

        let available_balance = treasury_balance - total_staked;
        assert!(available_balance >= amount, "Insufficient available balance");

        CoinFramework::transfer<CoinType>(&treasury_signer, admin_address, amount);
    }

    /// Transfers admin rights to a new address.
    public entry fun transfer_admin(
        admin: &signer,
        new_admin_address: address
    ) acquires Admin {
        let admin_address = get_admin_address();
        let caller_address = signer::address_of(admin);
        assert!(caller_address == admin_address, "Caller is not the admin");

        let admin_resource = borrow_global_mut<Admin>(address_of<Self>());
        admin_resource.authority = new_admin_address;
    }

    /// Cleans up the staker resource if the staked amount is zero.
    public entry fun cleanup_staker<CoinType: store>(
        user: &signer
    ) acquires Staker {
        let user_address = signer::address_of(user);
        assert!(exists<Staker<CoinType>>(user_address), "Staker resource not found");

        let staker = borrow_global<Staker<CoinType>>(user_address);
        assert!(staker.amount == 0, "Cannot clean up staker with non-zero amount");

        move_from<Staker<CoinType>>(user_address);
    }

    /// Emits a stake or unstake event.
    fun emit_event<CoinType: store>(
        is_stake: bool,
        user_address: address,
        amount: u64
    ) acquires StakingEvents {
        let staking_events = borrow_global_mut<StakingEvents<CoinType>>(address_of<Self>());
        let event = StakingEvent<CoinType> { user: user_address, amount, is_stake };
        event::emit_event(&mut staking_events.event_handle, event);
    }

    /// Gets the current block number.
    fun get_current_block(): u64 {
        block::get_current_block_number()
    }

    /// Retrieves the admin address from the Admin resource.
    fun get_admin_address(): address {
        let admin_resource = borrow_global<Admin>(address_of<Self>());
        admin_resource.authority
    }

    /// Retrieves the treasury address from the Config resource.
    fun get_treasury_address(): address {
        let config = borrow_global<Config>(address_of<Self>());
        config.treasury_address
    }
}

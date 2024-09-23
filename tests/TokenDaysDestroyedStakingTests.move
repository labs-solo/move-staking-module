module TokenDaysDestroyedStakingTests {
    use std::signer;
    use std::vector;
    use std::error;
    use std::option::Option;
    use aptos_framework::coin::{Self as CoinFramework, Coin, CoinStore, register};
    use aptos_framework::block;
    use aptos_framework::aptos_coin::{AptosCoin};

    use TokenDaysDestroyedStaking;

    #[test]
    public fun test_staking_flow() {
        // Test accounts
        let admin = @0xA550C18; // Example admin address
        let treasury = @0xB0B;  // Example treasury address
        let user1 = @0xC0DE;    // Example user address

        // Initialize accounts
        create_account(admin);
        create_account(treasury);
        create_account(user1);

        // Initialize CoinStores
        register<AptosCoin>(&signer::borrow_signer(admin));
        register<AptosCoin>(&signer::borrow_signer(treasury));
        register<AptosCoin>(&signer::borrow_signer(user1));

        // Mint tokens to user1
        mint_to_address<AptosCoin>(&signer::borrow_signer(admin), user1, 1_000_000);

        // Initialize admin and events
        TokenDaysDestroyedStaking::initialize_admin(&signer::borrow_signer(admin));
        TokenDaysDestroyedStaking::initialize_staking_events<AptosCoin>(&signer::borrow_signer(admin));

        // User1 stakes tokens
        let stake_amount = 100_000;
        TokenDaysDestroyedStaking::stake<AptosCoin>(
            &signer::borrow_signer(user1),
            treasury,
            stake_amount
        );

        // Verify staking details
        let staker_option = TokenDaysDestroyedStaking::get_staking_details<AptosCoin>(user1);
        assert!(staker_option.is_some(), 100);
        let staker = staker_option.unwrap();
        assert!(staker.amount == stake_amount, 101);

        // Simulate block progression
        simulate_block_progression(10);

        // User1 stakes additional tokens
        let additional_stake = 50_000;
        TokenDaysDestroyedStaking::stake<AptosCoin>(
            &signer::borrow_signer(user1),
            treasury,
            additional_stake
        );

        // Calculate expected TDD
        let expected_tdd = (stake_amount as u128) * (10 as u128);
        let actual_tdd = TokenDaysDestroyedStaking::calculate_token_days_destroyed<AptosCoin>(user1);
        assert!(actual_tdd == expected_tdd, 102);

        // User1 unstakes some tokens
        let unstake_amount = 30_000;
        TokenDaysDestroyedStaking::unstake<AptosCoin>(
            &signer::borrow_signer(user1),
            &signer::borrow_signer(treasury),
            unstake_amount
        );

        // Verify updated staking details
        let staker_option = TokenDaysDestroyedStaking::get_staking_details<AptosCoin>(user1);
        assert!(staker_option.is_some(), 103);
        let staker = staker_option.unwrap();
        let total_staked = stake_amount + additional_stake - unstake_amount;
        assert!(staker.amount == total_staked, 104);

        // Admin transfers admin rights to a new address
        let new_admin = @0xDAD;
        create_account(new_admin);
        TokenDaysDestroyedStaking::transfer_admin(
            &signer::borrow_signer(admin),
            new_admin
        );

        // Attempt to perform admin action with old admin (should fail)
        let admin_withdraw_result = try {
            TokenDaysDestroyedStaking::emergency_withdraw<AptosCoin>(
                &signer::borrow_signer(admin),
                &signer::borrow_signer(treasury),
                10_000
            );
            true
        } catch E_NOT_ADMIN {
            false
        };
        assert!(!admin_withdraw_result, 105);

        // New admin performs emergency withdrawal
        TokenDaysDestroyedStaking::emergency_withdraw<AptosCoin>(
            &signer::borrow_signer(new_admin),
            &signer::borrow_signer(treasury),
            10_000
        );

        // User1 cleans up staker resource
        TokenDaysDestroyedStaking::unstake<AptosCoin>(
            &signer::borrow_signer(user1),
            &signer::borrow_signer(treasury),
            staker.amount
        );
        TokenDaysDestroyedStaking::cleanup_staker<AptosCoin>(
            &signer::borrow_signer(user1)
        );

        // Verify staker resource is destroyed
        let staker_option = TokenDaysDestroyedStaking::get_staking_details<AptosCoin>(user1);
        assert!(staker_option.is_none(), 106);
    }

    // Helper functions

    fun create_account(addr: address) {
        // Simulate account creation
        // In actual tests, accounts would be pre-created or handled differently
    }

    fun mint_to_address<CoinType: store + drop>(
        minter: &signer,
        recipient: address,
        amount: u64
    ) {
        // Mint tokens and transfer to recipient
        CoinFramework::mint<CoinType>(minter, amount);
        CoinFramework::transfer<CoinType>(minter, recipient, amount);
    }

    fun simulate_block_progression(blocks: u64) {
        // Simulate progression of blocks
        // In actual testing, this would depend on the blockchain environment
    }
}

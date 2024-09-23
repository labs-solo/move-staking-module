module TokenDaysDestroyedStakingTests {
    use std::signer;
    use aptos_framework::coin::{Self as CoinFramework, Coin, CoinStore, register};
    use aptos_framework::aptos_coin::AptosCoin;

    use TokenDaysDestroyedStaking;

    #[test]
    public fun test_staking_flow() {
        let admin_address = @0x1000;
        let treasury_address = @0x2000;
        let user1_address = @0x3000;
        let new_admin_address = @0x4000;

        let admin = signer::new_signer(admin_address);
        let user1 = signer::new_signer(user1_address);
        let new_admin = signer::new_signer(new_admin_address);

        CoinFramework::register<AptosCoin>(&admin);
        CoinFramework::register<AptosCoin>(&user1);

        CoinFramework::mint<AptosCoin>(&admin, 1_000_000);
        CoinFramework::transfer<AptosCoin>(&admin, user1_address, 1_000_000);

        TokenDaysDestroyedStaking::initialize_admin(&admin);
        TokenDaysDestroyedStaking::initialize_config(&admin, treasury_address);

        // User stakes AptosCoin without prior admin setup for AptosCoin
        let stake_amount = 100_000;
        TokenDaysDestroyedStaking::stake<AptosCoin>(&user1, stake_amount);

        let staked_amount = TokenDaysDestroyedStaking::get_staked_amount<AptosCoin>(user1_address);
        assert!(staked_amount.is_some(), "Staker should exist after staking");
        assert!(staked_amount.unwrap() == stake_amount, "Staked amount should match the stake amount");

        // User stakes another CoinType (e.g., FakeCoin) without prior admin setup
        // For testing, we define a FakeCoin

        struct FakeCoin has store, copy, drop {}

        // Implement CoinStore for FakeCoin
        impl CoinStore for FakeCoin {
            const MODULE_NAME: &str = "FakeCoin";
            const STRUCT_NAME: &str = "FakeCoin";
        }

        // Register and mint FakeCoin
        CoinFramework::register<FakeCoin>(&user1);
        // Assuming the mint function exists for FakeCoin
        // For testing purposes, we can simulate minting
        // CoinFramework::mint<FakeCoin>(&user1, 500_000);

        // User stakes FakeCoin
        let stake_amount_fake = 50_000;
        TokenDaysDestroyedStaking::stake<FakeCoin>(&user1, stake_amount_fake);

        // Check staked amount for FakeCoin
        let staked_amount_fake = TokenDaysDestroyedStaking::get_staked_amount<FakeCoin>(user1_address);
        assert!(staked_amount_fake.is_some(), "Staker should exist after staking FakeCoin");
        assert!(staked_amount_fake.unwrap() == stake_amount_fake, "Staked amount should match the stake amount for FakeCoin");

        // Unstake AptosCoin
        let unstake_amount = 30_000;
        TokenDaysDestroyedStaking::unstake<AptosCoin>(&user1, unstake_amount);

        let staked_amount = TokenDaysDestroyedStaking::get_staked_amount<AptosCoin>(user1_address);
        assert!(staked_amount.is_some(), "Staker should still exist after unstaking");
        let total_staked = stake_amount - unstake_amount;
        assert!(staked_amount.unwrap() == total_staked, "Staked amount should be updated after unstaking");

        TokenDaysDestroyedStaking::transfer_admin(&admin, new_admin_address);

        let admin_withdraw_result = try {
            TokenDaysDestroyedStaking::emergency_withdraw<AptosCoin>(&admin, 10_000);
            true
        } catch _e {
            false
        };
        assert!(!admin_withdraw_result, "Old admin should not be able to perform admin actions");

        TokenDaysDestroyedStaking::emergency_withdraw<AptosCoin>(&new_admin, 10_000);

        TokenDaysDestroyedStaking::unstake<AptosCoin>(&user1, total_staked);
        TokenDaysDestroyedStaking::cleanup_staker<AptosCoin>(&user1);

        let staked_amount = TokenDaysDestroyedStaking::get_staked_amount<AptosCoin>(user1_address);
        assert!(staked_amount.is_none(), "Staker resource should be destroyed after cleanup");

        // Cleanup FakeCoin staking
        TokenDaysDestroyedStaking::unstake<FakeCoin>(&user1, stake_amount_fake);
        TokenDaysDestroyedStaking::cleanup_staker<FakeCoin>(&user1);

        let staked_amount_fake = TokenDaysDestroyedStaking::get_staked_amount<FakeCoin>(user1_address);
        assert!(staked_amount_fake.is_none(), "Staker resource for FakeCoin should be destroyed after cleanup");
    }
}

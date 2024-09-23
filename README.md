# Token Days Destroyed Staking Module

## Overview

The **Token Days Destroyed (TDD) Staking Module** is a smart contract implemented in the Move programming language for Move-based blockchains (e.g., Aptos). It allows users to stake any fungible tokens (FTs) they wish, without requiring prior setup or initialization by an admin for that token type. The module calculates Token Days Destroyed (TDD) based on the amount staked and the number of blocks that have passed since staking.

Users pay for the resources necessary to stake new tokens, and the contract ensures that one user's actions do not affect another user's resources, maintaining resource isolation and security.

## Statement of Intended Behavior

### Overview

The staking contract allows users to stake any cryptocurrency token (`CoinType`) they wish, without requiring prior setup or initialization by the admin for that token type. Users can stake and unstake tokens independently for each `CoinType`, and the contract maintains separate staking records for each `CoinType` per user. The contract tracks the staked amount and token days destroyed (TDD) for each token type individually.

An admin account is responsible for initializing the contract and setting the treasury address where staked tokens are held. The admin can perform emergency withdrawals of tokens not part of the total staked amounts and can transfer admin rights to another address. The contract emits events for staking and unstaking actions for each `CoinType` to facilitate tracking and transparency.

Users pay for the resources necessary to stake new `CoinType`s, and the contract ensures that one user's actions do not affect another user's resources, maintaining resource isolation and security.

### Detailed Intended Behavior with User-Initiated `CoinType` Staking

1. **Initialization**

   - **Admin Initialization**
     - The `initialize_admin` function allows the contract deployer to set up the admin account.
     - It can only be called once to prevent reinitialization.

   - **Configuration Initialization**
     - The `initialize_config` function allows the admin to set the treasury address where staked tokens are held.
     - It can only be called once.

2. **Staking Tokens**

   - **User-Initiated `CoinType` Staking**
     - Users can stake any `CoinType` without prior admin setup.
     - The `stake` function checks if the necessary resources for the `CoinType` exist, and if not, initializes them.
     - Users pay for the gas costs associated with resource initialization.

   - **Stake Function**
     - Users can stake tokens of different types by calling the `stake` function with the specific `CoinType` and amount.
     - The function transfers the specified amount from the user's account to the treasury address for that token.
     - For each `CoinType`, the user has a separate `Staker<CoinType>` resource under their address.
     - The staked amounts and TDD are tracked separately for each `CoinType`.
     - The total staked amount for each `CoinType` is updated in the global staking info.
     - A `StakingEvent<CoinType>` is emitted to record the staking action for that token.

3. **Unstaking Tokens**

   - **Unstake Function**
     - Users can unstake tokens by calling the `unstake` function with the specific `CoinType` and amount.
     - The function transfers the specified amount from the treasury address back to the user's account for that token.
     - The user's staked amount and TDD for that `CoinType` are updated accordingly.
     - The total staked amount for the `CoinType` is updated in the global staking info.
     - A `StakingEvent<CoinType>` is emitted to record the unstaking action for that token.

4. **Token Days Destroyed (TDD)**

   - **Per-Token TDD Tracking**
     - The contract keeps track of TDD separately for each `CoinType` a user stakes.
     - TDD is calculated based on the amount staked and the duration for which it was staked for each token type.
     - Functions like `calculate_token_days_destroyed` operate per `CoinType`.

5. **Admin Functions**

   - **Emergency Withdrawal**
     - The admin can perform an emergency withdrawal of tokens not part of the total staked amounts.
     - The function ensures that the total staked tokens are not affected.

   - **Transfer of Admin Rights**
     - The admin can transfer their rights to a new admin address using the `transfer_admin` function.

6. **Cleanup of Staker Resource**

   - **Cleanup Function**
     - Users can call `cleanup_staker` with the specific `CoinType` to remove their `Staker<CoinType>` resource if their staked amount is zero for that token.
     - This helps in freeing up storage space when a user no longer has any staked tokens of a particular type.

7. **Event Emission**

   - **Per-Token Staking Events**
     - The contract emits events for staking and unstaking actions separately for each `CoinType`.
     - Events include the user's address, the amount staked or unstaked, and a flag indicating the action type.

8. **Access Control**

   - **Admin-Only Functions**
     - Functions like `initialize_config`, `emergency_withdraw`, and `transfer_admin` are restricted to the admin account.

   - **User Functions**
     - Functions like `stake`, `unstake`, `calculate_token_days_destroyed`, `get_staked_amount`, and `cleanup_staker` are available to users for each `CoinType`.

9. **Security Measures**

   - **Assertions and Checks**
     - The contract includes assertions to prevent invalid states per `CoinType`, such as staking or unstaking zero tokens, or unstaking more than the staked amount.
     - Arithmetic operations rely on Move's built-in overflow checks.
     - Access control checks ensure that only authorized accounts can perform certain actions.
     - Type constraints ensure that only valid coin types can be staked.

10. **Modularity and Extensibility**

    - **Generic Coin Type**
      - The contract is generic over `CoinType`, allowing it to support staking for different types of tokens.
    - **Resource Management**
      - The use of per-token resources for stakers and global staking info ensures proper management and protection of data for each token type.
      - Users pay for the resources they initialize, and resource isolation ensures that one user's actions do not affect others.

## Security Considerations

#### 1. User-Initiated `CoinType` Staking

- **Implementation:**
  - The `stake` function now initializes `StakingEvents` and `GlobalStakingInfo` resources for a `CoinType` if they do not exist.
  - Users pay for the resource creation costs.

- **Security Considerations:**
  - **Type Constraints:**
    - The `CoinType` is constrained by `store + CoinStore`, ensuring only valid coin types that implement the `CoinStore` trait can be staked.
    - **Risk Mitigated:** Prevents users from staking arbitrary types that are not valid coins.

  - **Resource Spamming:**
    - **Risk:** Users could create numerous resources for different `CoinType`s, consuming storage and potentially affecting network performance.
    - **Mitigation:**
      - Users pay the gas fees associated with resource creation, providing a financial disincentive for spamming.
      - Storage costs in the blockchain platform further discourage unnecessary resource creation.
    - **Conclusion:** The risk is adequately mitigated.

  - **Interference with Other Users:**
    - Resources are parameterized by `CoinType` and stored under the user's address (for `Staker`) or module address (for global resources).
    - **Risk Mitigated:** Users cannot access or modify other users' resources, maintaining resource isolation.

#### 2. Adjustments to Other Functions

- **Unstake Function:**
  - Modified to handle cases where `GlobalStakingInfo` might not exist by initializing it if absent.
  - **Security Consideration:** Ensures consistent behavior and prevents potential errors when unstaking tokens that haven't been staked before globally.

- **Emergency Withdrawal:**
  - Adjusted to handle cases where `GlobalStakingInfo` might not exist, assuming total staked is zero in such cases.
  - **Security Consideration:** Prevents incorrect calculations of available balance for withdrawal.

#### 3. Access Control and Authorization

- **Admin Functions:**
  - Functions like `initialize_config`, `emergency_withdraw`, and `transfer_admin` still require admin privileges.
  - **Security Consideration:** Admin-only functions are protected, and admin rights are not compromised by the changes.

#### 4. Assertions and Error Handling

- **Assertions:**
  - All critical functions include assertions to prevent invalid operations, such as staking zero tokens or unstaking more than the staked amount.
  - **Security Consideration:** Prevents invalid state changes and maintains contract integrity.

- **Overflow Checks:**
  - Move's built-in overflow checks handle arithmetic operations, ensuring safe calculations.
  - **Security Consideration:** Prevents integer overflows and underflows.

#### 5. Event Emission

- **Per-Token Events:**
  - Events are correctly emitted for staking and unstaking actions, with `CoinType` parameterization ensuring they are associated with the correct token.
  - **Security Consideration:** Event handling is secure and provides transparency.

#### 6. Resource Management

- **User-Paid Resources:**
  - Users are responsible for paying the gas fees for resource initialization, aligning costs with resource usage.
  - **Security Consideration:** Encourages responsible use and mitigates potential abuse.

- **Resource Isolation:**
  - Each user's resources are managed independently, with no shared mutable state that could lead to race conditions or interference.
  - **Security Consideration:** Maintains security and data integrity across users.

#### 7. Potential Security Weaknesses and Mitigations

- **Arbitrary `CoinType` Staking:**
  - **Risk:** Users might attempt to stake tokens that are malicious or not intended for staking.
  - **Mitigation:**
    - The `CoinStore` trait constraint ensures only registered coin types can be staked.
    - **Recommendation:** Consider implementing additional validation if necessary, such as checking against a whitelist of approved tokens.

- **Denial-of-Service (DoS) via Resource Creation:**
  - **Risk:** Excessive resource creation could strain network resources.
  - **Mitigation:**
    - Gas fees and storage costs act as deterrents.
    - **Recommendation:** Monitor resource usage and consider setting limits if necessary.

- **Security of External Calls:**
  - All external calls are to standard library functions (e.g., `CoinFramework::transfer`), which are considered secure.
  - **Security Consideration:** No vulnerabilities identified related to external calls.

#### 8. Testing and Validation

- **Comprehensive Tests:**
  - The test suite includes scenarios where users stake multiple `CoinType`s without prior admin setup.
  - **Security Consideration:** Testing verifies that the contract behaves correctly under the new functionality.

- **Edge Cases:**
  - Tests cover edge cases such as unstaking when resources do not exist and ensure appropriate error handling.
  - **Security Consideration:** Ensures robustness of the contract.

#### 9. Conclusion

- **Overall Assessment:**
  - The contract modifications successfully allow users to stake any `CoinType` without prior admin setup while maintaining security.
  - Resource isolation and type constraints prevent users from affecting other users' resources or staking invalid tokens.

- **Security Posture:**
  - Strong, with potential risks adequately mitigated through design choices and Move's safety features.

- **Recommendations:**
  - **Optional Enhancements:**
    - Implement additional validation for `CoinType` if desired.
    - Monitor resource creation and usage patterns.
  - **Documentation:**
    - Update documentation to reflect the changes and inform users about the ability to stake any `CoinType`.
    - Provide guidance on acceptable `CoinType`s and any limitations.

## Key Features

- **Users Can Stake Any CoinType**: Users can stake any fungible token without prior admin setup, paying for the necessary resources themselves.
- **Accurate Tracking of Total Staked Tokens**: Introduces a global resource to track the total staked amount for each token type (`CoinType`), updating whenever users stake or unstake tokens.
- **Configurable Admin Resource**: Stores the admin's address in a resource that can be updated via a governance process, allowing for admin transfer functionality.
- **Atomic Transactions and Concurrency Control**: Ensures staking and unstaking operations are atomic and isolated, with Move's resource model preventing conflicting transactions.
- **Reuse of `Staker` Resource**: Retains the `Staker` resource even when the staked amount reaches zero, providing an optional cleanup function for users.
- **Enhanced Error Messages**: Utilizes descriptive error messages that are accessible and meaningful to users.

## Security Guarantees

- **Exclusive Control Over Staked Tokens**: Only the staker can withdraw their staked tokens; neither the admin nor the treasury can access them.
- **Protection Against Unauthorized Access**: Move's resource and access control mechanisms enforce strict ownership rules.
- **Admin's Limited Authority**: The admin cannot withdraw staked tokens belonging to users; administrative functions are restricted.
- **Safe and Atomic Operations**: Transactions are atomic, ensuring state changes are fully applied or not at all.
- **Accurate Total Staked Tracking**: Prevents the admin or treasury from inadvertently accessing staked tokens.
- **Concurrency Control**: Prevents reentrancy and race conditions.
- **User-Paid Resource Creation**: Users pay for the resources they initialize, aligning costs with resource usage and discouraging abuse.
- **Resource Isolation**: Each user's resources are managed independently, maintaining data integrity and security.

## Repository Structure

- `README.md`: Project documentation.
- `Move.toml`: Move package configuration file.
- `sources/`: Contains the staking module source code.
- `tests/`: Contains unit tests for the staking module.

## Prerequisites

- **Move CLI**: Installed on your machine. [Move CLI Installation Guide](https://move-language.github.io/move/cli.html)
- **Git**: Version control system installed.
- **Aptos Node or Network Access**: Access to the target blockchain you're deploying to.

## Installation

### Clone the Repository

```bash
git clone https://github.com/your-username/your-github-repo.git
cd your-github-repo
```

### Install Dependencies

Ensure you have the necessary dependencies specified in `Move.toml`.

### Building the Project

Compile the Move modules:

```bash
move package build
```

This command compiles the Move modules and checks for any errors.

### Running Tests

Execute the unit tests:

```bash
move package test
```

This command runs the unit tests located in the `tests/` directory, ensuring that the staking module functions as expected.

### Deployment

To deploy the modules to the blockchain, use the following command:

```bash
move package publish --url <node_url> --private-key <your_private_key>
```

- `<node_url>`: The URL of the blockchain node you're connecting to.
- `<your_private_key>`: Your private key for the account deploying the module.

**Note**: Make sure you understand the security implications of using your private key in commands. Consider using environment variables or a secure key management system.

## Usage

### Initial Setup

#### Initialize the Admin Account

This step only needs to be done once by the admin.

```move
TokenDaysDestroyedStaking::initialize_admin(&admin_signer);
```

#### Initialize Configuration with Treasury Address

Set the treasury address where staked tokens will be held.

```move
TokenDaysDestroyedStaking::initialize_config(&admin_signer, treasury_address);
```

### Staking Tokens

Users can stake tokens by calling the `stake` function.

```move
TokenDaysDestroyedStaking::stake<CoinType>(&user_signer, amount);
```

- `user_signer`: The signer's account of the user staking tokens.
- `CoinType`: The type of token being staked (e.g., `AptosCoin`).
- `amount`: The amount of tokens to stake (must be greater than zero).

**Example:**

```move
TokenDaysDestroyedStaking::stake<AptosCoin>(&user_signer, 100_000);
```

### Unstaking Tokens

Users can unstake tokens and receive them back from the treasury.

```move
TokenDaysDestroyedStaking::unstake<CoinType>(&user_signer, amount);
```

- `user_signer`: The signer's account of the user unstaking tokens.
- `CoinType`: The type of token being unstaked.
- `amount`: The amount of tokens to unstake (must be greater than zero).

**Example:**

```move
TokenDaysDestroyedStaking::unstake<AptosCoin>(&user_signer, 50_000);
```

### Calculating Token Days Destroyed (TDD)

Users can calculate their total TDD for a specific `CoinType`.

```move
let tdd = TokenDaysDestroyedStaking::calculate_token_days_destroyed<CoinType>(user_address);
```

- `user_address`: The address of the user whose TDD is being calculated.
- `tdd`: The returned Token Days Destroyed value (`u128`).

**Example:**

```move
let tdd = TokenDaysDestroyedStaking::calculate_token_days_destroyed<AptosCoin>(user_address);
```

### Getting Staked Amount

Users can retrieve their staked amount for a specific `CoinType`.

```move
let staked_amount = TokenDaysDestroyedStaking::get_staked_amount<CoinType>(user_address);
```

- `staked_amount`: An `Option<u64>` containing the user's staked amount if they have staked tokens.

**Example:**

```move
let staked_amount = TokenDaysDestroyedStaking::get_staked_amount<AptosCoin>(user_address);
```

### Cleaning Up Staker Resource

Users can destroy their `Staker` resource if they have a zero staked amount for a specific `CoinType`.

```move
TokenDaysDestroyedStaking::cleanup_staker<CoinType>(&user_signer);
```

**Example:**

```move
TokenDaysDestroyedStaking::cleanup_staker<AptosCoin>(&user_signer);
```

## Admin Functions

### Transferring Admin Rights

The admin can transfer admin rights to a new address.

```move
TokenDaysDestroyedStaking::transfer_admin(&admin_signer, new_admin_address);
```

- `new_admin_address`: The address of the new admin.

### Emergency Withdrawal

The admin can withdraw tokens not part of the staked balances.

```move
TokenDaysDestroyedStaking::emergency_withdraw<CoinType>(&admin_signer, amount);
```

- `CoinType`: The type of token to withdraw.
- `amount`: The amount to withdraw.

**Note**: The admin cannot withdraw tokens that are part of the staked balances.

## Error Handling

The module uses descriptive error messages to help identify issues. Assertions are used to enforce conditions, and Move's built-in error handling will abort transactions if assertions fail.

## Testing

The module includes unit tests located in the `tests/` directory. These tests cover various scenarios, including:

- Staking and unstaking tokens without prior admin setup for the `CoinType`.
- Calculating Token Days Destroyed.
- Transferring admin rights.
- Ensuring only the staker can withdraw their tokens.
- Verifying that the admin cannot access stakers' tokens.

To run the tests:

```bash
move package test
```

## Contributing

We welcome contributions from the team! Please follow these guidelines:

1. Fork the repository and create a new branch for your feature or bug fix.
2. Ensure all tests pass before submitting a pull request.
3. Follow coding standards: Maintain consistent code formatting and documentation.
4. Write tests for new features or bug fixes.
5. Submit a Pull Request: Provide a clear description of your changes and any relevant issue numbers.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contact

For questions or discussions, please open an issue in the repository or contact the project maintainer:

- **Your Name**
- **Email**: your.email@example.com

## Appendix

### Setting Up Development Environment

- **Install Move CLI**: Follow the instructions on the [Move CLI Installation Guide](https://move-language.github.io/move/cli.html).
- **Set Up Aptos Environment**: If deploying to Aptos, ensure you have access to an Aptos node or testnet.

### Helpful Commands

- **Compile Modules**: `move package build`
- **Run Tests**: `move package test`
- **Publish Modules**: `move package publish --url <node_url> --private-key <your_private_key>`
- **Clean Build Artifacts**: `move package clean`

### Troubleshooting

- **Compilation Errors**: Ensure all dependencies are correctly specified in `Move.toml`.
- **Test Failures**: Check the error messages and ensure the tests are updated to reflect any changes in the module.

### Dependencies

- **Aptos Framework**: The module depends on the Aptos Framework for standard functionalities like `Coin`, `CoinStore`, and `Block`. Ensure the dependencies are correctly specified in your `Move.toml`:

```toml
[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "main" }
```

## Conclusion

This README file provides all the necessary information for your team to understand, build, test, deploy, and use the Token Days Destroyed Staking Module. It serves as a central reference point for collaboration and project maintenance, incorporating the detailed intended behavior, auditor's comments, and updated module usage instructions.
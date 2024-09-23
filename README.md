# Token Days Destroyed Staking Module

## Overview

The **Token Days Destroyed (TDD) Staking Module** is a smart contract implemented in the Move programming language for Move-based blockchains (e.g., Aptos). It allows users to stake fungible tokens (FTs) and calculates Token Days Destroyed (TDD) based on the amount staked and the number of blocks that have passed since staking.

## Key Features

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

#### Initialize Staking Events for a Coin Type

Initialize staking events and global staking info for a specific `CoinType` (e.g., `AptosCoin`).

```move
TokenDaysDestroyedStaking::initialize_staking_events<AptosCoin>(&admin_signer);
```

### Staking Tokens

Users can stake tokens by calling the stake function.

```move
TokenDaysDestroyedStaking::stake<AptosCoin>(&user_signer, treasury_address, amount);
```

- `user_signer`: The signer's account of the user staking tokens.
- `treasury_address`: The address of the treasury account where tokens are held.
- `amount`: The amount of tokens to stake (must be greater than zero).

### Unstaking Tokens

Users can unstake tokens and receive them back from the treasury.

```move
TokenDaysDestroyedStaking::unstake<AptosCoin>(&user_signer, &treasury_signer, amount);
```

- `user_signer`: The signer's account of the user unstaking tokens.
- `treasury_signer`: The signer's account of the treasury (required to transfer tokens back).
- `amount`: The amount of tokens to unstake (must be greater than zero).

### Calculating Token Days Destroyed (TDD)

Users can calculate their total TDD.

```move
let tdd = TokenDaysDestroyedStaking::calculate_token_days_destroyed<AptosCoin>(user_address);
```

- `user_address`: The address of the user whose TDD is being calculated.
- `tdd`: The returned Token Days Destroyed value (u128).

### Getting Staking Details

Users can retrieve their staking details.

```move
let staking_details = TokenDaysDestroyedStaking::get_staking_details<AptosCoin>(user_address);
```

- `staking_details`: An `Option<Staker<CoinType>>` containing the user's staking information if they have staked tokens.

### Cleaning Up Staker Resource

Users can destroy their `Staker` resource if they have a zero staked amount.

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
TokenDaysDestroyedStaking::emergency_withdraw<AptosCoin>(&admin_signer, &treasury_signer, amount);
```

**Note**: The admin cannot withdraw tokens that are part of the staked balances.

## Error Handling

The module uses descriptive error codes to help identify issues:

- **E_AMOUNT_ZERO (1)**: Staking amount cannot be zero.
- **E_INSUFFICIENT_BALANCE (2)**: Insufficient staked balance.
- **E_NOT_ADMIN (3)**: Caller is not the admin.
- **E_STAKER_NOT_FOUND (4)**: Staker resource not found.
- **E_OVERFLOW (5)**: Arithmetic overflow occurred.
- **E_ADMIN_ALREADY_INITIALIZED (6)**: Admin already initialized.
- **E_NO_STAKER_RESOURCE (7)**: No staker resource to destroy.
- **E_UNAUTHORIZED (8)**: Unauthorized access.

## Testing

The module includes unit tests located in the `tests/` directory. These tests cover various scenarios, including:

- Staking and unstaking tokens.
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

- **Install Move CLI**: Follow the instructions on the Move CLI Installation Guide.
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

- **Aptos Framework**: The module depends on the Aptos Framework for standard functionalities like Coin, CoinStore, and Block. Ensure the dependencies are correctly specified in your `Move.toml`:

```toml
[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "main" }
```

## Conclusion

This README.md file provides all the necessary information for your team to understand, build, test, deploy, and use the Token Days Destroyed Staking Module. It serves as a central reference point for collaboration and project maintenance.

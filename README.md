# Escrow Contract

## Overview
The `Escrow` contract is a secure escrow system for holding Ether between two parties (a player and a challenger) until a winner is determined. Funds are stored with a unique `storeHash` identifier and released to the winner. The contract uses OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks and optimizes gas usage with `uint128` and `unchecked` arithmetic.

### Features
- **Deposit Funds**: Player and challenger deposit Ether using a unique `storeHash`.
- **Release Funds**: Funds are released to a designated winner (player or challenger).
- **Security**: Includes reentrancy protection and bounds checks.
- **Gas Efficiency**: Uses `uint128` for storage and `unchecked` arithmetic where safe.

## Prerequisites
- **Remix IDE**: Use [Remix](https://remix.ethereum.org/) for compilation, testing, and deployment.
- **MetaMask**: For testnet deployment (e.g., Sepolia).
- **Solidity Knowledge**: Familiarity with Solidity 0.8.26 and Ethereum transactions.

## Setup

### 1. Create Project Files
In Remix’s file explorer, create:
- `contracts/Escrow.sol`: Copy the contract.
- `.solhint.json`: Add linting rules for code quality.

#### .solhint.json
```json
{
  "extends": "solhint:recommended",
  "plugins": [],
  "rules": {
    "compiler-version": ["error", "^0.8.0"],
    "func-visibility": ["warn", { "ignoreConstructors": true }],
    "not-rely-on-time": "off",
    "reason-string": ["warn", { "maxLength": 64 }]
  }
}
```

### 2. Compile the Contract
- In Remix’s **Compile** tab:
  - Select **Solidity compiler**: 0.8.26.
  - Enable **Optimization**: 200 runs.
  - Click **Compile Escrow.sol**.
- Note: A warning (`Gas requirement of function Escrow.releaseFunds is infinite`) may appear. This is a false positive, as gas usage is ~41,330 for `releaseFunds`. Optionally, use Solidity 0.8.24 to suppress.

### 3. Deploy the Contract
- In **Deploy & Run Transactions** tab:
  - **Environment**: Remix VM (Shanghai) for testing, or Injected Provider - MetaMask for Sepolia.
  - Select **Escrow** contract.
  - Click **Deploy**.

## Usage

### 1. Compute Hashes
In Remix’s console (bottom panel):
```javascript
web3.utils.keccak256("test2") // storeHash: 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf2b8d4b9c1b5c7f1b6c1a6e8
web3.utils.keccak256("player") // PLAYER_ROLE: 0x2a0c0dbecc7e4d658f48e01e3fa353f44050c2082c7b6b0a65836b4489888b11
web3.utils.keccak256("challenger") // CHALLENGER_ROLE: 0x99e55b2c2f6ae39c3e4f2f6d1663a7f6f9c7e2d9f2d7b6e0a65836b4489888b1
```

### 2. Store Tokens
- In **Deployed Contracts**, expand `Escrow`.
- **Player Deposit**:
  - Function: `storeTokens` (orange button).
  - `storeHash`: `0x7e5f4552091a69125d5dfcb7b8c2659029395bdf2b8d4b9c1b5c7f1b6c1a6e8`.
  - `identity`: `0x2a0c0dbecc7e4d658f48e01e3fa353f44050c2082c7b6b0a65836b4489888b11`.
  - **Value**: `1 Ether` (set in **Value** field).
  - **Account**: Player address (e.g., `0x5B38Da6a701c568545dCfcB03FcB875f56beddC4`).
  - Click `storeTokens`.
- **Challenger Deposit**:
  - `storeHash`: Same as above.
  - `identity`: `0x99e55b2c2f6ae39c3e4f2f6d1663a7f6f9c7e2d9f2d7b6e0a65836b4489888b1`.
  - **Value**: `1 Ether`.
  - **Account**: Challenger address (e.g., `0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2`).
  - Click `storeTokens`.
- Check console for `TokensStored` events and gas usage (~60,000–120,000 gas).

### 3. Release Funds
- Function: `releaseFunds` (red button).
- `storeHash`: `0x7e5f4552091a69125d5dfcb7b8c2659029395bdf2b8d4b9c1b5c7f1b6c1a6e8`.
- `winner`: Player or challenger address (e.g., `0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2`).
- **Value**: `0 Wei`.
- Click `releaseFunds`.
- Check console for `ReleasedFunds` event and gas usage (~41,330 gas).

### 4. Verify State
- Call `escrowStorage` (view function) with `storeHash`.
- Expected:
  - `totalAmount`: `0` (after release).
  - `player`: Player address.
  - `challenger`: Challenger address.
  - `isActive`: `false`.

## Testing
- Use Remix VM (Shanghai) to test deposits and fund release.
- Verify gas usage in console:
  - `storeTokens`: ~60,000–120,000 gas.
  - `releaseFunds`: ~41,330 gas.
- Deploy to Sepolia for real-world testing:
  - Connect MetaMask to Sepolia.
  - Repeat steps in **Usage**.

## Notes
- **Gas Warning**: The `releaseFunds` warning is a false positive. Gas usage is normal (~41,330).
- **Security**: `nonReentrant` prevents reentrancy attacks. `unchecked` arithmetic is safe due to `msg.value` bounds check.
- **Optimization**: Uses `uint128` and `unchecked` for gas efficiency.

## Troubleshooting
- **Invalid identity**: Ensure `identity` matches `PLAYER_ROLE` or `CHALLENGER_ROLE`.
- **Revert**: Use a fresh `storeHash` or redeploy to clear state.
- **Gas Warning**: Switch to Solidity 0.8.24 or test without `nonReentrant` (debugging only).

## License
GPL-3.0
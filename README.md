# Simple Token Bridge

A cross-chain token bridge implementation using LayerZero protocol, enabling seamless token transfers from Sepolia to Holesky testnets.

## Overview

This project implements a token bridge that allows users to transfer tokens between different blockchain networks (Sepolia and Holesky) using LayerZero's cross-chain messaging protocol. The bridge consists of three main components:

1. Origin ERC20 Token (Sepolia)
2. Token Bridge Contract (Sepolia)
3. Wrapped Token Contract (Holesky)

## Deployed Contracts

### Sepolia Testnet

- Origin ERC20 Token: [0x40bbad54fe7d8d7d079d56c7b90be2d298cb29b6](https://sepolia.etherscan.io/address/0x40bbad54fe7d8d7d079d56c7b90be2d298cb29b6)
- Token Bridge: [0x86e8b4731ee7e7c00bb0dc4d9172976caa639201](https://sepolia.etherscan.io/address/0x86e8b4731ee7e7c00bb0dc4d9172976caa639201)

### Holesky Testnet

- Wrapped Token: [0x6eeb0f8829ca6e9acc45b25e7b936758e8a714e1](https://holesky.etherscan.io/address/0x6eeb0f8829ca6e9acc45b25e7b936758e8a714e1)

## Example Transactions

### Bridge Transaction

- Approve: [0xc8247ce4ff602dec13def43e43499a6ef6065199351746a71ac7af233448e626](https://sepolia.etherscan.io/tx/0xc8247ce4ff602dec13def43e43499a6ef6065199351746a71ac7af233448e626)
- Sepolia: [0xd5871e3dedcb1af8cf88a3d44a87f6b85187be333a4d5f3801d61c16e916a342](https://sepolia.etherscan.io/tx/0xd5871e3dedcb1af8cf88a3d44a87f6b85187be333a4d5f3801d61c16e916a342)
- Holesky: [0x8c838f57d60e1da003a089fefc2a29a4e417f356af15b44f06a3fbde088e66fb](https://holesky.etherscan.io/tx/0x8c838f57d60e1da003a089fefc2a29a4e417f356af15b44f06a3fbde088e66fb)
- LayerZero: [0xd5871e3dedcb1af8cf88a3d44a87f6b85187be333a4d5f3801d61c16e916a342](https://testnet.layerzeroscan.com/tx/0xd5871e3dedcb1af8cf88a3d44a87f6b85187be333a4d5f3801d61c16e916a342)

## Prerequisites

- Node.js (v16 or higher)
- Yarn package manager
- Foundry (Forge)

## Installation

1. Clone the repository:

```bash
git clone <repository-url>
```

2. Install dependencies:

```bash
forge install
yarn
```

## Development

### Code Quality

```bash
# Run linter
yarn lint

# Format code
make format
```

### Testing

```bash
# Run tests
make test

# Generate coverage report
make coverage-html
```

### Deployment

```bash
make deploy
```

## Project Structure

- `src/` - Smart contract source files
- `test/` - Test files
- `script/` - Deployment scripts
- `lib/` - External dependencies

## Usage Instructions

### Bridge Tokens from Sepolia to Holesky

1. **Approve Tokens**

```solidity
// Approve the bridge contract to spend your tokens
await originToken.approve(bridgeAddress, amount);
```

2. **Bridge Tokens**

```solidity
// Bridge tokens to Holesky
// There are some fee consideration required via Layerzero
await bridge.lockTokens(amount, recipientAddress);
```

## Technical Q&A

### 1. Oracle Risks and Mitigation

**Risks:**

- Centralized control over cross-chain messages
- Network downtime or censorship

**Mitigation Strategies:**

- Implement a multi-oracle system with consensus (DVN)
- Require block depth using Layerzero lib
- Use LayerZero's built-in security features
- Implement rate limiting and transaction caps

### 2. Recovery Mechanism (Not Preferred)

If Chain B (Holesky) fails, Admin can help user to refund his fund.

1. **Emergency Withdrawal**

```solidity
// Only callable by admin after verification
function emergencyWithdraw(
    address token,
    address recipient,
    uint256 amount
) external onlyAdmin {
    require(emergencyMode, "Not in emergency mode");
    IERC20(token).transfer(recipient, amount);
}
```

2. **Recovery Process:**

- Admin verifies the failure
- Activates emergency mode
- Users submit proof of their locked tokens
- Admin processes withdrawal requests
- Users receive their original tokens on Chain A

### 3. Cross-Chain Validation

To ensure oracle integrity:

1. **Message Verification:**

- Done by layerzero DVN

2. **Security Measures:**

- Implement message replay protection
- Verify message source chain
- Use LayerZero's built-in message validation

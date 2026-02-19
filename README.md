# EVM DeFi Lending Protocol

A complete Solidity-based DeFi lending protocol inspired by Aave V3, built on EVM-compatible blockchains. This protocol enables users to supply assets as collateral, borrow against their collateral, and earn interest on supplied assets.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contact](#contact)

## ✨ Features

### Core Functionality

- **Asset Supplying**: Users can supply ERC20 tokens to earn interest
- **Borrowing**: Users can borrow assets against their supplied collateral
- **Variable Interest Rates**: Dynamic interest rates based on utilization
- **Flash Loans**: Uncollateralized loans within a single transaction
- **Liquidation**: Automatic liquidation of undercollateralized positions
- **Interest Accrual**: Real-time interest accrual for both suppliers and borrowers

### Technical Features

- **Multiple Reserves**: Support for multiple ERC20 assets (DAI, USDC, WETH, etc.)
- **Price Oracles**: Integration with price oracles for collateral valuation
- **Access Control**: Role-based access control for admin functions
- **Pausability**: Emergency pause functionality
- **Reentrancy Protection**: Guards against reentrancy attacks
- **Gas Optimized**: Efficient storage and computation patterns

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Users                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      Pool Contract                          │
│  (Main entry point for all user interactions)               │
│  - supply()                                                  │
│  - withdraw()                                               │
│  - borrow()                                                 │
│  - repay()                                                  │
│  - flashLoan()                                              │
│  - liquidationCall()                                         │
└──────┬──────────────┬──────────────┬────────────────────────┘
       │              │              │
       ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   AToken    │ │ VariableDebt│ │ StableDebt  │
│  (Supply)   │ │    Token    │ │    Token    │
└─────────────┘ └─────────────┘ └─────────────┘
       │              │              │
       └──────────────┴──────────────┘
                     │
       ┌─────────────┴─────────────┐
       │                           │
       ▼                           ▼
┌──────────────┐          ┌──────────────────┐
│ Price Oracle │          │ Interest Rate    │
│              │          │ Strategy         │
└──────────────┘          └──────────────────┘
```

### Contract Components

1. **Pool**: Main contract handling all user interactions
2. **AToken**: Interest-bearing tokens representing supplied assets
3. **VariableDebtToken**: Tokens representing variable-rate debt
4. **StableDebtToken**: Tokens representing stable-rate debt
5. **DefaultReserveInterestRateStrategy**: Calculates interest rates based on utilization
6. **PriceOracle**: Provides asset prices for collateral valuation

## 📁 Project Structure

```
evm-defi-lending-protocol/
├── contracts/
│   ├── interfaces/
│   │   ├── IPool.sol
│   │   ├── IAToken.sol
│   │   ├── IDebtToken.sol
│   │   ├── IPriceOracle.sol
│   │   ├── IInterestRateStrategy.sol
│   │   └── IFlashLoanReceiver.sol
│   ├── libraries/
│   │   ├── ReserveConfiguration.sol
│   │   ├── WadRayMath.sol
│   │   └── MathUtils.sol
│   ├── protocol/
│   │   ├── pool/
│   │   │   ├── Pool.sol
│   │   │   └── DefaultReserveInterestRateStrategy.sol
│   │   ├── tokenization/
│   │   │   ├── AToken.sol
│   │   │   ├── VariableDebtToken.sol
│   │   │   └── StableDebtToken.sol
│   │   ├── oracle/
│   │   │   └── PriceOracle.sol
│   │   └── libraries/
│   │       └── types/
│   │           └── DataTypes.sol
│   └── mocks/
│       ├── MockERC20.sol
│       ├── MockDAI.sol
│       ├── MockUSDC.sol
│       ├── MockWETH.sol
│       ├── MockChainlinkAggregator.sol
│       └── MockFlashLoanReceiver.sol
├── scripts/
│   └── deploy.js
├── test/
│   ├── Pool.test.js
│   ├── AToken.test.js
│   └── InterestRateStrategy.test.js
├── hardhat.config.js
├── helper-hardhat-config.js
├── package.json
└── README.md
```

## 🚀 Setup

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Git

### Installation

1. Clone the repository:
```bash
cd lending-protocol-1/evm-defi-lending-protocol
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

3. Create a `.env` file (optional, for testnet deployment):
```bash
cp .env.example .env
```

Edit `.env` and add your private key and RPC URLs:
```
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_key
ETHERSCAN_API_KEY=your_etherscan_api_key
```

4. Compile the contracts:
```bash
npx hardhat compile
```

## 🧪 Testing

Run the test suite:

```bash
npx hardhat test
```

Run specific test files:

```bash
npx hardhat test test/Pool.test.js
npx hardhat test test/AToken.test.js
npx hardhat test test/InterestRateStrategy.test.js
```

Run tests with gas reporting:

```bash
REPORT_GAS=true npx hardhat test
```

### Test Coverage

The test suite covers:
- ✅ Asset supplying and withdrawal
- ✅ Borrowing and repayment
- ✅ Interest rate calculations
- ✅ Flash loans
- ✅ Liquidation mechanics
- ✅ Edge cases (zero amounts, insufficient balance, etc.)

## 🚢 Deployment

### Local Network

1. Start a local Hardhat node:
```bash
npx hardhat node
```

2. In another terminal, deploy to localhost:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

### Testnet Deployment (Sepolia)

1. Ensure your `.env` file is configured with:
   - `PRIVATE_KEY`: Your wallet private key
   - `SEPOLIA_RPC_URL`: Sepolia RPC endpoint
   - `ETHERSCAN_API_KEY`: Etherscan API key (for verification)

2. Deploy to Sepolia:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

3. Verify contracts (optional):
```bash
npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## 📧 Contact

- Telegram: https://t.me/rouncey
- Twitter: https://x.com/rouncey_


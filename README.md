# 🏆 Synthetic Asset Tokenization

> 🚀 **Mint synthetic tokens pegged to real-world assets like gold through oracle integration**

A Clarity smart contract that enables users to create synthetic tokens backed by STX collateral and pegged to external asset prices via oracles. Perfect for learning oracle integration and collateralized debt positions (CDPs).

## ✨ Features

- 🥇 **Synthetic Gold Tokens (sGOLD)** - Tokens pegged to gold prices
- 🏦 **Collateral Management** - Deposit STX as collateral to mint synthetic assets
- 📊 **Oracle Price Integration** - Real-time asset price feeds for accurate pegging
- ⚖️ **Liquidation System** - Automatic liquidation when collateral ratios drop too low
- 🛡️ **Safety Parameters** - Configurable collateral ratios and liquidation thresholds
- 💰 **Standard Token Features** - Transfer, approve, allowance functionality

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   User Wallet   │───▶│   Contract   │◀──▶│  Price Oracle   │
└─────────────────┘    └──────────────┘    └─────────────────┘
        │                       │
        ▼                       ▼
┌─────────────────┐    ┌──────────────┐
│ STX Collateral  │    │ sGOLD Tokens │
└─────────────────┘    └──────────────┘
```

## 🎯 Core Concepts

### Collateral Ratio
- **Minimum Ratio**: 150% (configurable)
- **Liquidation Threshold**: 120% (configurable)
- Users must maintain adequate collateral to avoid liquidation

### Oracle Integration
- External price feeds update asset prices
- Price freshness validation (max 1 hour old)
- Only authorized oracles can update prices

## 🚦 Getting Started

### Prerequisites

- 📦 [Clarinet](https://github.com/hirosystems/clarinet) installed
- 💼 STX wallet for testing
- 🔧 Node.js for additional tooling

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Synthetic-Asset-Tokenization
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Check contract syntax**
   ```bash
   clarinet check
   ```

4. **Run tests**
   ```bash
   clarinet test
   ```

## 🎮 Usage Guide

### 1. 💰 Deposit Collateral

First, deposit STX as collateral to back your synthetic tokens:

```clarity
(contract-call? .synthetic-asset-tokenization deposit-collateral)
```

### 2. 🏭 Mint Synthetic Tokens

Mint sGOLD tokens against your collateral:

```clarity
(contract-call? .synthetic-asset-tokenization mint-synthetic u1000000)
```

### 3. 🔥 Burn Synthetic Tokens

Reduce your debt by burning synthetic tokens:

```clarity
(contract-call? .synthetic-asset-tokenization burn-synthetic u500000)
```

### 4. 🏧 Withdraw Collateral

Withdraw excess collateral (maintaining minimum ratio):

```clarity
(contract-call? .synthetic-asset-tokenization withdraw-collateral u100000000)
```

### 5. ⚡ Liquidation

Liquidate undercollateralized positions:

```clarity
(contract-call? .synthetic-asset-tokenization liquidate 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX723QGB2JYT u1000000)
```

## 🔧 Admin Functions

### Update Oracle Price (Oracle Only)
```clarity
(contract-call? .synthetic-asset-tokenization set-oracle-price u50000000)
```

### Update Oracle Address (Owner Only)
```clarity
(contract-call? .synthetic-asset-tokenization update-oracle-address 'SP2ORACLE...)
```

### Update Collateral Parameters (Owner Only)
```clarity
(contract-call? .synthetic-asset-tokenization update-collateral-params u160 u130)
```

## 📊 Read-Only Functions

### Check Token Information
```clarity
(contract-call? .synthetic-asset-tokenization get-name)
(contract-call? .synthetic-asset-tokenization get-symbol) 
(contract-call? .synthetic-asset-tokenization get-total-supply)
(contract-call? .synthetic-asset-tokenization get-balance 'SP1HTBVD...)
```

### Check Collateral Position
```clarity
(contract-call? .synthetic-asset-tokenization get-collateral-position 'SP1HTBVD...)
(contract-call? .synthetic-asset-tokenization get-collateral-ratio 'SP1HTBVD...)
(contract-call? .synthetic-asset-tokenization is-position-liquidatable 'SP1HTBVD...)
```

### Oracle Information
```clarity
(contract-call? .synthetic-asset-tokenization get-oracle-price)
(contract-call? .synthetic-asset-tokenization get-oracle-timestamp)
```

## ⚠️ Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Not token owner |
| u102 | Invalid amount |
| u103 | Insufficient balance |
| u104 | Invalid oracle |
| u105 | Price too old |
| u106 | Collateral ratio too low |
| u107 | Insufficient collateral |
| u108 | Position not found |
| u109 | Liquidation threshold not met |

## 🧪 Testing

Run the test suite to verify contract functionality:

```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/synthetic-asset-tokenization_test.ts
```

## 🔒 Security Considerations

- 🛡️ **Oracle Security**: Only authorized oracles can update prices
- ⏰ **Price Freshness**: Prices must be updated within the maximum age limit
- 💵 **Collateral Ratios**: Enforced minimum ratios prevent undercollateralization
- 🚨 **Liquidation Protection**: Automatic liquidation protects the system from bad debt
- 🔐 **Access Control**: Owner-only functions for critical system parameters

## 🛠️ Development

### Project Structure

```
contracts/
├── synthetic-asset-tokenization.clar  # Main contract
settings/
├── Devnet.toml                       # Development settings
├── Mainnet.toml                      # Mainnet settings
└── Testnet.toml                      # Testnet settings
tests/
└── synthetic-asset-tokenization_test.ts  # Test suite
```

### Key Parameters

- **Token Name**: "Synthetic Gold Token"
- **Token Symbol**: "sGOLD"
- **Decimals**: 6
- **Min Collateral Ratio**: 150%
- **Liquidation Threshold**: 120%
- **Max Price Age**: 3600 blocks (~1 hour)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

- 📚 [Clarity Documentation](https://docs.stacks.co/docs/clarity)
- 🛠️ [Clarinet Documentation](https://github.com/hirosystems/clarinet)
- 💬 [Stacks Discord](https://discord.gg/stacks)

---

⭐ **Star this repository if you found it helpful!**

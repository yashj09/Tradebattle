forge script script/DeployUniCompeteHook.sol:DeployUniCompeteHook --rpc-url http://localhost:8545 --broadcast


forge script script/DeployUniCompeteHook.sol:DeployUniCompeteHook --rpc-url http://localhost:8545 --broadcast --skip-simulation --legacy





forge script script/DeployUniCompeteHook.sol:DeployUniCompeteHook --rpc-url http://localhost:8545 --broadcast --skip-simulation




forge script script/DeployUniCompeteHook.sol:DeployUniCompeteHook \
    --rpc-url sepolia \
    --broadcast 





# Sepolia RPC URL
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

# Holesky RPC URL  
HOLESKY_RPC_URL=https://ethereum-holesky-rpc.publicnode.com

forge script script/DeployHookWithMining.s.sol:DeployHookWithMining  \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast  \
    -vvvv
forge script script/DeployHookWithMining.s.sol:DeployHookWithMining  \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast  \
    -vvvv
forge script script/CreateCompetition.s.sol  \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast  \
    -vvvv

    forge script script/DeployHookWithMining.s.sol:DeployHookWithMining \
    --rpc-url http://localhost:8545 \
    --broadcast \
    -vvvv

# UniCompete Hook

A Uniswap v4 hook that creates trading competitions with LP incentives and real-time price feeds.

## 🌟 Updates for Real Testnet Deployment

### Real Chainlink Price Feeds
- **NO MORE MOCKS**: Now uses real Chainlink price feeds on Sepolia
- Real-time ETH/USD pricing from Chainlink's official Sepolia feed
- Production-ready architecture for mainnet deployment

### Sepolia Testnet Configuration

#### Contract Addresses (Sepolia)
```
PoolManager:    0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A
WETH:          0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
USDC:          0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
ETH/USD Feed:  0x694AA1769357215DE4FAC081bf1f309aDC325306
```

## 🚀 Deployment on Sepolia

### Prerequisites
1. **Sepolia ETH**: Get testnet ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
2. **Private Key**: Set up your private key in environment
3. **RPC URL**: Use a reliable Sepolia RPC endpoint

### Environment Setup
```bash
# Set your private key (with 0x prefix)
export PRIVATE_KEY=0x1234567890abcdef...

# Optional: Set existing hook address to skip deployment
export DEPLOYED_HOOK_ADDRESS=0x...
```

### Deploy the Hook
```bash
# Deploy on Sepolia with real price feeds
forge script script/DeployHookWithMining.s.sol:DeployHookWithMining \
  --fork-url https://rpc.sepolia.org \
  --broadcast \
  --verify \
  -vvvv
```

### Create a Competition
```bash
# Create a test competition
forge script script/CreateCompetition.s.sol:CreateCompetition \
  --fork-url https://rpc.sepolia.org \
  --broadcast \
  -vvvv
```

## 💰 Real Price Feed Integration

### Chainlink ETH/USD Feed
- **Address**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- **Network**: Sepolia Testnet
- **Decimals**: 8
- **Updates**: Real-time price updates from Chainlink oracles

### Entry Fee Calculation
Entry fees are dynamically calculated using real ETH prices:
- **Standard Competition**: $10 USD (converted to ETH)
- **Premium Competition**: $50 USD (WETH/USDC pools)

Example with ETH at $3,000:
- Standard fee: ~0.0033 ETH
- Premium fee: ~0.0167 ETH

## 🏆 Competition Types

### Standard Competitions
- **Pools**: Most token pairs
- **Entry Fee**: $10 USD worth of ETH
- **Duration**: 24 hours
- **Qualification**: Min 2 trades, $100 volume

### Premium Competitions 
- **Pools**: WETH/USDC pairs
- **Entry Fee**: $50 USD worth of ETH
- **Duration**: 24 hours
- **Enhanced Rewards**: Higher prize pools

## 🧪 Testing Guide

### 1. Deploy Hook
```bash
forge script script/DeployHookWithMining.s.sol:DeployHookWithMining \
  --fork-url https://rpc.sepolia.org \
  --broadcast
```

### 2. Verify Deployment
Check that the hook:
- ✅ Has correct Sepolia addresses
- ✅ Can access Chainlink price feed
- ✅ Calculates entry fees properly

### 3. Create Competition
```bash
forge script script/CreateCompetition.s.sol:CreateCompetition \
  --fork-url https://rpc.sepolia.org \
  --broadcast
```

### 4. Verify Competition
Check that the competition:
- ✅ Uses real-time ETH pricing
- ✅ Sets correct entry fees
- ✅ Identifies premium pools correctly

## 🔍 Key Improvements

### ✅ Real Price Feeds
- Replaced all mock price feeds with real Chainlink oracles
- Entry fees now fluctuate with real ETH prices
- Production-ready price feed integration

### ✅ Network Configuration
- Clean separation of network-specific addresses
- Easy switching between networks (Sepolia, Mainnet, etc.)
- Centralized configuration management

### ✅ Robust Deployment
- Proper CREATE2 mining for hook addresses
- Comprehensive error handling
- Detailed deployment verification

### ✅ Enhanced Testing
- Real testnet environment testing
- Live price feed validation
- Complete end-to-end workflows

## 📊 Competition Mechanics

### Trader Competitions
1. **Entry**: Pay ETH entry fee (calculated from USD using Chainlink)
2. **Trading**: Execute swaps in the competition pool
3. **Tracking**: Portfolio value tracked in real-time
4. **Rewards**: Top performers share prize pool

### LP Competitions
1. **Entry**: Provide liquidity to competition pool
2. **Stickiness**: Maintain liquidity during volatile periods
3. **Consistency**: Build consistency score over time
4. **Rewards**: Earn from fee sharing and donations

## 🛠 Development

### Local Testing
```bash
# Compile contracts
forge build

# Run tests
forge test

# Deploy locally
forge script script/DeployHookWithMining.s.sol:DeployHookWithMining
```

### Network Support
- ✅ **Sepolia**: Full support with real price feeds
- 🚧 **Mainnet**: Ready for v4 launch
- 🚧 **Arbitrum**: Configuration ready
- 🚧 **Base**: Configuration ready

## 📝 Contract Architecture

### UniCompeteHook
- Main hook contract with competition logic
- Real Chainlink price feed integration
- Dynamic entry fee calculation
- Portfolio tracking and rewards

### NetworkConfig
- Centralized network configuration
- Real addresses for all supported networks
- Easy network switching

## 🔗 Useful Links

- [Chainlink Sepolia Feeds](https://docs.chain.link/data-feeds/price-feeds/addresses#sepolia-testnet)
- [Uniswap v4 Hooks](https://docs.uniswap.org/contracts/v4/overview)
- [Sepolia Testnet Faucet](https://sepoliafaucet.com/)

---

**Ready for real testnet deployment with production-grade price feeds!** 🚀
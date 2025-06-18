// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title NetworkConfig
 * @notice Centralized configuration for different networks
 * @dev Provides real addresses for mainnet and testnets (no mocks)
 */
library NetworkConfig {
    struct NetworkAddresses {
        address poolManager;
        address weth;
        address usdc;
        address ethUsdPriceFeed;
        string networkName;
    }

    uint256 constant MAINNET_CHAIN_ID = 1;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    uint256 constant BASE_CHAIN_ID = 8453;

    function getNetworkConfig(uint256 chainId) internal pure returns (NetworkAddresses memory) {
        if (chainId == SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (chainId == MAINNET_CHAIN_ID) {
            return getMainnetConfig();
        } else if (chainId == ARBITRUM_CHAIN_ID) {
            return getArbitrumConfig();
        } else if (chainId == BASE_CHAIN_ID) {
            return getBaseConfig();
        } else {
            revert("Unsupported network");
        }
    }

    function getSepoliaConfig() internal pure returns (NetworkAddresses memory) {
        return NetworkAddresses({
            poolManager: 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A, // Official v4 PoolManager on Sepolia
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9, // Official WETH on Sepolia
            usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Official USDC on Sepolia
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // Chainlink ETH/USD on Sepolia
            networkName: "Sepolia Testnet"
        });
    }

    function getMainnetConfig() internal pure returns (NetworkAddresses memory) {
        return NetworkAddresses({
            poolManager: address(0), // To be set when v4 launches on mainnet
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH on mainnet
            usdc: 0xa0b86a33E6441d1e7c91aE0C63C4E79F2a5a7fB6, // USDC on mainnet
            ethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // Chainlink ETH/USD on mainnet
            networkName: "Ethereum Mainnet"
        });
    }

    function getArbitrumConfig() internal pure returns (NetworkAddresses memory) {
        return NetworkAddresses({
            poolManager: address(0), // To be set when v4 launches on Arbitrum
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH on Arbitrum
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // USDC on Arbitrum
            ethUsdPriceFeed: 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612, // Chainlink ETH/USD on Arbitrum
            networkName: "Arbitrum One"
        });
    }

    function getBaseConfig() internal pure returns (NetworkAddresses memory) {
        return NetworkAddresses({
            poolManager: address(0), // To be set when v4 launches on Base
            weth: 0x4200000000000000000000000000000000000006, // WETH on Base
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // USDC on Base
            ethUsdPriceFeed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70, // Chainlink ETH/USD on Base
            networkName: "Base"
        });
    }

    function getCurrentNetwork() internal view returns (NetworkAddresses memory) {
        return getNetworkConfig(block.chainid);
    }
}

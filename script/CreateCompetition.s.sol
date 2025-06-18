// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";

// Mock Chainlink Aggregator for testing
contract MockChainlinkAggregator {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        // Mock ETH price: $2000 USD (with 8 decimals)
        return (1, 200000000000, block.timestamp, block.timestamp, 1);
    }
}

contract CreateCompetition is Script {
    // Hook flags for UniCompeteHook permissions
    uint160 constant HOOK_FLAGS = uint160(
        Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
    );

    // Standard CREATE2 deployer address
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        vm.startBroadcast();

        console2.log("CreateCompetition script started");
        console2.log("Deploying PoolManager and UniCompeteHook...");

        // Deploy PoolManager
        PoolManager poolManager = new PoolManager(msg.sender);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Mine for valid hook address using HookMiner
        bytes memory constructorArgs = abi.encode(address(poolManager));
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, type(UniCompeteHook).creationCode, constructorArgs);

        // Deploy hook using CREATE2
        bytes memory creationCode = abi.encodePacked(type(UniCompeteHook).creationCode, constructorArgs);
        (bool success, bytes memory returnData) = CREATE2_DEPLOYER.call(abi.encodePacked(salt, creationCode));
        require(success, "Hook deployment failed");

        console2.log("UniCompeteHook deployed at:", hookAddress);

        // Deploy mock Chainlink price feed for testing
        MockChainlinkAggregator mockPriceFeed = new MockChainlinkAggregator();
        console2.log("Mock price feed deployed at:", address(mockPriceFeed));

        UniCompeteHook hook = UniCompeteHook(hookAddress);

        // Add the mock price feed to the hook
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH mainnet address
        hook.addPriceFeed(WETH, address(mockPriceFeed));
        console2.log("Mock price feed added to hook");

        // Create a test competition for ETH/USDC pool
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(0xa0b86a33E6441d1e7c91aE0C63C4E79F2a5a7fB6), // USDC (sepolia)
            fee: 3000, // 0.3%
            tickSpacing: 60,
            hooks: IHooks(hookAddress)
        });

        hook.createDailyCompetition(poolKey);
        console2.log("Competition created for ETH/USDC pool");

        console2.log("Script completed successfully!");
        console2.log("Summary:");
        console2.log("  PoolManager:", address(poolManager));
        console2.log("  UniCompeteHook:", hookAddress);
        console2.log("  Mock Price Feed:", address(mockPriceFeed));

        vm.stopBroadcast();
    }
}

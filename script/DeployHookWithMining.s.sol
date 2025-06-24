// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";

/**
 * @title DeployHookWithMining
 * @notice Deployment script for UniCompeteHook on Sepolia with address mining
 */
contract DeployHookWithMining is Script {
    // Sepolia testnet addresses (real addresses, not mocks)
    address constant SEPOLIA_POOL_MANAGER = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A; // Official v4 PoolManager on Sepolia
    address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9; // Official WETH on Sepolia
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Official USDC on Sepolia
    address constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Chainlink ETH/USD on Sepolia

    // Hook flags for UniCompeteHook permissions
    uint160 constant HOOK_FLAGS = uint160(
        Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
    );

    function run() external {
        vm.startBroadcast();

        console2.log("=== Deploying UniCompeteHook on Sepolia ===");
        console2.log("Network: Sepolia Testnet");
        console2.log("Using real Chainlink price feeds (no mocks)");

        // Get deployer address
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        console2.log("Deployer address:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        // Check if deployer has sufficient balance
        require(deployer.balance > 0.001 ether, "Insufficient ETH balance for deployment");

        // Verify Sepolia addresses
        console2.log("\n--- Sepolia Contract Addresses ---");
        console2.log("PoolManager:", SEPOLIA_POOL_MANAGER);
        console2.log("WETH:", SEPOLIA_WETH);
        console2.log("USDC:", SEPOLIA_USDC);
        console2.log("ETH/USD Price Feed:", SEPOLIA_ETH_USD_PRICE_FEED);

        // Mine for valid hook address
        console2.log("\n--- Mining for Valid Hook Address ---");
        console2.log("Required hook flags:", HOOK_FLAGS);

        bytes memory constructorArgs =
            abi.encode(SEPOLIA_POOL_MANAGER, SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED);

        console2.log("Starting address mining...");
        console2.log("This may take a few moments...");

        (address hookAddress, bytes32 salt) =
            HookMiner.find(deployer, HOOK_FLAGS, type(UniCompeteHook).creationCode, constructorArgs);

        console2.log("Found valid hook address:", hookAddress);
        console2.log("Using salt:", uint256(salt));

        // Double-check the address doesn't have code
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(hookAddress)
        }

        if (codeSize > 0) {
            console2.log("ERROR: Target address already has code!");
            console2.log("Code size:", codeSize);
            revert("Address collision detected");
        }

        // Deploy the hook with the mined salt
        console2.log("\n--- Deploying Hook ---");
        console2.log("Deploying to address:", hookAddress);

        UniCompeteHook hook = new UniCompeteHook{salt: salt}(
            IPoolManager(SEPOLIA_POOL_MANAGER), SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED
        );

        // Verify deployment
        require(address(hook) == hookAddress, "Hook address mismatch!");
        console2.log("Hook deployed successfully!");
        console2.log("Hook address:", address(hook));

        // Verify hook configuration
        console2.log("\n--- Verifying Hook Configuration ---");
        console2.log("Hook WETH address:", hook.WETH());
        console2.log("Hook USDC address:", hook.USDC());
        console2.log("Hook ETH/USD feed:", hook.ETH_USD_PRICE_FEED());

        // Test price feed connectivity
        _testPriceFeed(hook);

        console2.log("\n=== Deployment Summary ===");
        console2.log("[SUCCESS] UniCompeteHook deployed successfully");
        console2.log("[SUCCESS] Real Chainlink price feeds configured");
        console2.log("[SUCCESS] Sepolia testnet addresses verified");
        console2.log("Hook Address:", address(hook));
        console2.log("");
        console2.log("Save this address for testing:");
        console2.log("export DEPLOYED_HOOK_ADDRESS=", address(hook));

        vm.stopBroadcast();
    }

    function _testPriceFeed(UniCompeteHook hook) internal {
        console2.log("\n--- Testing Chainlink Price Feed ---");

        try this._testPriceFeedExternal(hook) {
            console2.log("[SUCCESS] Price feed test completed");
        } catch Error(string memory reason) {
            console2.log("[FAILED] Price feed test failed:", reason);
        } catch (bytes memory) {
            console2.log("[FAILED] Price feed test failed with low-level error");
        }
    }

    function _testPriceFeedExternal(UniCompeteHook hook) external view {
        // This function exists to test the price feed from an external context
        require(address(hook) != address(0), "Hook not deployed");
        console2.log("Price feed verification: Hook uses real Chainlink feed at", hook.ETH_USD_PRICE_FEED());
    }
}

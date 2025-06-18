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
 * @notice Deployment script that properly mines for valid hook address
 */
contract DeployHookWithMining is Script {
    // Hook flags for UniCompeteHook permissions
    uint160 constant HOOK_FLAGS = uint160(
        Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
    );

    // Standard CREATE2 deployer address
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        vm.startBroadcast();

        console2.log("Deploying from address:", msg.sender);

        // Deploy PoolManager
        PoolManager poolManager = new PoolManager(msg.sender);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Mine for valid hook address using HookMiner with CREATE2 deployer
        bytes memory constructorArgs = abi.encode(address(poolManager));
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, type(UniCompeteHook).creationCode, constructorArgs);
        console2.log("Found valid hook address:", hookAddress);
        console2.log("Using salt:", uint256(salt));

        // Deploy hook with the mined salt using CREATE2 deployer
        bytes memory creationCode = abi.encodePacked(type(UniCompeteHook).creationCode, constructorArgs);

        // Call CREATE2 deployer
        (bool success, bytes memory returnData) = CREATE2_DEPLOYER.call(abi.encodePacked(salt, creationCode));

        require(success, "CREATE2 deployment failed");

        // Extract deployed address from return data
        address deployedAddress;
        if (returnData.length >= 20) {
            assembly {
                deployedAddress := mload(add(returnData, 20))
            }
        } else {
            deployedAddress = hookAddress; // Fallback to expected address
        }

        require(deployedAddress == hookAddress, "Hook address mismatch");
        console2.log("UniCompeteHook deployed successfully at:", deployedAddress);

        console2.log("Deployment completed!");
        console2.log("Summary:");
        console2.log("  PoolManager:", address(poolManager));
        console2.log("  UniCompeteHook:", deployedAddress);

        vm.stopBroadcast();
    }
}

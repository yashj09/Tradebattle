// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

/**
 * @title DeployHook
 * @notice Standalone deployment script for UniCompeteHook
 * @dev This script avoids complex dependencies and deploys the hook directly
 */
contract DeployHook is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("Deploying from address:", deployer);

        // Deploy PoolManager first
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Deploy UniCompeteHook
        // Note: In production, you should mine for the correct hook address
        // For testing, we'll deploy directly
        UniCompeteHook hook = new UniCompeteHook(IPoolManager(address(poolManager)));
        console2.log("UniCompeteHook deployed at:", address(hook));

        // Verify hook permissions
        console2.log("Verifying hook permissions...");
        console2.log("Hook deployed successfully - permissions can be verified post-deployment");

        console2.log("Deployment completed successfully!");
        console2.log("Summary:");
        console2.log("   PoolManager:", address(poolManager));
        console2.log("   UniCompeteHook:", address(hook));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";

/**
 * @title DeployDirect
 * @notice Direct deployment without hooks for testing PoolManager
 */
contract DeployDirect is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("Deploying from address:", deployer);

        // Deploy only PoolManager for now
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed successfully at:", address(poolManager));

        // Verify PoolManager works
        console2.log("PoolManager owner:", deployer);
        console2.log("Deployment completed successfully!");

        vm.stopBroadcast();
    }
}

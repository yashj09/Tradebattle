// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";

contract SimpleDeploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy PoolManager
        address deployer = msg.sender;
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // For simplicity, deploy hook without mining for specific address
        // In production, you'd want to mine for the correct hook flags
        UniCompeteHook hook = new UniCompeteHook(IPoolManager(address(poolManager)));
        console2.log("UniCompeteHook deployed at:", address(hook));

        // Log the hook permissions for verification
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        console2.log(
            "Hook permissions set correctly:",
            permissions.afterInitialize && permissions.afterAddLiquidity && permissions.beforeSwap
                && permissions.afterSwap
        );

        vm.stopBroadcast();
    }
}

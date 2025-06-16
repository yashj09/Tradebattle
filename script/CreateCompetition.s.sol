// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";

contract CreateCompetition is Script {
    function run() external {
        vm.startBroadcast();

        // For now, we'll just simulate creating a competition
        // In a real scenario, you'd need to deploy the hook first
        console2.log("CreateCompetition script started");
        console2.log("Note: This requires a deployed UniCompeteHook address");
        
        // Example of how to use it with a deployed hook:
        // address hookAddress = 0x1234567890123456789012345678901234567890; // Replace with actual deployed hook
        // UniCompeteHook hook = UniCompeteHook(hookAddress);

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

        vm.stopBroadcast();
    }
}

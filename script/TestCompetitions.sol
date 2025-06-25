// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/**
 * @title TestCompetitions
 * @notice Test script for UniCompeteHook functionality
 */
contract TestCompetitions is Script {
    // Your deployed hook address
    address constant HOOK_ADDRESS = 0x30855F7bA0105515CC9C383eF46E09A7ea7A15d0;

    // Sepolia token addresses
    address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant SEPOLIA_POOL_MANAGER = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;

    function run() external {
        vm.startBroadcast();

        UniCompeteHook hook = UniCompeteHook(HOOK_ADDRESS);

        console2.log("=== Testing UniCompete Hook ===");
        console2.log("Hook Address:", address(hook));
        console2.log("Current Competition Counter:", hook.competitionCounter());

        // Create a test pool key for WETH/USDC
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(SEPOLIA_WETH < SEPOLIA_USDC ? SEPOLIA_WETH : SEPOLIA_USDC),
            currency1: Currency.wrap(SEPOLIA_WETH < SEPOLIA_USDC ? SEPOLIA_USDC : SEPOLIA_WETH),
            fee: 3000, // 0.3% fee
            tickSpacing: 60,
            hooks: hook
        });

        console2.log("\n--- Creating Daily Competition ---");
        console2.log("Pool Currency0:", Currency.unwrap(poolKey.currency0));
        console2.log("Pool Currency1:", Currency.unwrap(poolKey.currency1));
        console2.log("Pool Fee:", poolKey.fee);

        // Create a competition
        try hook.createDailyCompetition(poolKey) {
            console2.log("Competition created successfully!");
        } catch Error(string memory reason) {
            console2.log("Competition creation failed:", reason);
        } catch (bytes memory) {
            console2.log("Competition creation failed with low-level error");
        }

        // Check the new competition counter
        uint256 newCounter = hook.competitionCounter();
        console2.log("New Competition Counter:", newCounter);

        if (newCounter > 0) {
            console2.log("\n--- Testing Competition Info ---");
            try hook.getCompetitionInfo(newCounter) returns (UniCompeteHook.CompetitionInfo memory info) {
                console2.log("Competition ID:", info.id);
                console2.log("Start Time:", info.startTime);
                console2.log("End Time:", info.endTime);
                console2.log("Entry Fee:", info.entryFee);
                console2.log("Participant Count:", info.participantCount);
                console2.log("Is Active:", info.isActive);
            } catch {
                console2.log("Could not get competition info");
            }
        }

        vm.stopBroadcast();

        console2.log("\n=== Test Complete ===");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleCompeteHook} from "../src/SimpleCompeteHook.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

/**
 * @title DeploySimpleHook
 * @notice Deployment script for SimpleCompeteHook with minimal permissions
 */
contract DeploySimpleHook is Script {
    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("Deploying from address:", deployer);

        // Deploy PoolManager
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Calculate required hook flags for afterSwap only
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        console2.log("Required hook flags:", flags);

        // Try to find a working salt
        (address hookAddress, uint256 salt) = findValidSalt(deployer, address(poolManager), flags);
        console2.log("Found valid hook address:", hookAddress);
        console2.log("Using salt:", salt);

        // Deploy SimpleCompeteHook with the found salt
        SimpleCompeteHook hook = new SimpleCompeteHook{salt: bytes32(salt)}(IPoolManager(address(poolManager)));

        require(address(hook) == hookAddress, "Hook address mismatch");
        console2.log("SimpleCompeteHook deployed at:", address(hook));

        // Test the hook
        console2.log("Testing hook...");
        console2.log("Initial participant status:", hook.checkParticipant(deployer));

        hook.joinCompetition();
        console2.log("After joining:", hook.checkParticipant(deployer));
        console2.log("Trade count:", hook.getTradeCount(deployer));

        console2.log("Deployment and testing completed successfully!");

        vm.stopBroadcast();
    }

    function findValidSalt(address deployer, address poolManager, uint160 flags)
        internal
        view
        returns (address, uint256)
    {
        bytes memory constructorArgs = abi.encode(poolManager);
        bytes memory creationCode = abi.encodePacked(type(SimpleCompeteHook).creationCode, constructorArgs);

        // Try a few different salts
        for (uint256 salt = 0; salt < 10000; salt++) {
            address hookAddress = computeAddress(deployer, salt, creationCode);

            // Check if the address matches the required flags
            if (uint160(hookAddress) & Hooks.ALL_HOOK_MASK == flags) {
                return (hookAddress, salt);
            }
        }

        revert("Could not find valid hook address");
    }

    function computeAddress(address deployer, uint256 salt, bytes memory creationCode)
        internal
        pure
        returns (address)
    {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xFF), deployer, bytes32(salt), keccak256(creationCode)));
        return address(uint160(uint256(hash)));
    }
}

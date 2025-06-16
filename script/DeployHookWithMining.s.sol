// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

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

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("Deploying from address:", deployer);

        // Deploy PoolManager
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Mine for valid hook address
        (address hookAddress, uint256 salt) = mineSalt(deployer, address(poolManager));
        console2.log("Found valid hook address:", hookAddress);
        console2.log("Using salt:", salt);

        // Deploy hook with the mined salt
        UniCompeteHook hook = new UniCompeteHook{salt: bytes32(salt)}(IPoolManager(address(poolManager)));

        require(address(hook) == hookAddress, "Hook address mismatch");
        console2.log("UniCompeteHook deployed successfully at:", address(hook));

        console2.log("Deployment completed!");
        console2.log("Summary:");
        console2.log("  PoolManager:", address(poolManager));
        console2.log("  UniCompeteHook:", address(hook));

        vm.stopBroadcast();
    }

    function mineSalt(address deployer, address poolManager) internal view returns (address, uint256) {
        bytes memory constructorArgs = abi.encode(poolManager);
        bytes memory creationCode = abi.encodePacked(type(UniCompeteHook).creationCode, constructorArgs);

        uint256 salt = 0;
        address hookAddress;

        console2.log("Mining for valid hook address...");
        console2.log("Required flags:", HOOK_FLAGS);

        // Mine for up to 100,000 iterations
        for (salt = 0; salt < 100000; salt++) {
            hookAddress = computeAddress(deployer, salt, creationCode);

            // Check if the address matches the required flags
            if (uint160(hookAddress) & Hooks.ALL_HOOK_MASK == HOOK_FLAGS) {
                console2.log("Found valid address after", salt, "iterations");
                return (hookAddress, salt);
            }

            // Log progress every 10,000 iterations
            if (salt % 10000 == 0 && salt > 0) {
                console2.log("Checked", salt, "addresses...");
            }
        }

        revert("Could not find valid hook address within 100,000 iterations");
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

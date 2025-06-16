// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

contract Deploy is Script {
    // CREATE2 Deployer Proxy
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy PoolManager
        address deployer = vm.addr(deployerPrivateKey);
        PoolManager poolManager = new PoolManager(deployer);
        console2.log("PoolManager deployed at:", address(poolManager));

        // Calculate hook address with correct flags
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
        );

        // Mine for hook address
        bytes memory constructorArgs = abi.encode(poolManager);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(UniCompeteHook).creationCode, constructorArgs);

        // Deploy the hook
        UniCompeteHook hook = new UniCompeteHook{salt: salt}(IPoolManager(address(poolManager)));
        require(address(hook) == hookAddress, "Hook address mismatch");

        console2.log("UniCompeteHook deployed at:", address(hook));

        vm.stopBroadcast();
    }
}

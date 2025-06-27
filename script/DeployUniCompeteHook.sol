// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";

contract DeployUniCompeteHook is Script {
    address constant SEPOLIA_POOL_MANAGER = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;
    address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    uint160 constant HOOK_FLAGS = uint160(
        Hooks.AFTER_INITIALIZE_FLAG // 0x0001
            | Hooks.AFTER_ADD_LIQUIDITY_FLAG // 0x0010
            | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG // 0x0040
            | Hooks.BEFORE_SWAP_FLAG // 0x0080
            | Hooks.AFTER_SWAP_FLAG // 0x0100
            | Hooks.AFTER_DONATE_FLAG // 0x1000
    );

    function run() external {
        console2.log("=== Working UniCompete Hook Deployment ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("Network: Sepolia Testnet");

        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("Deployer:", deployer);
        console2.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        require(deployer.balance >= 0.001 ether, "Need at least 0.001 ETH");

        console2.log("\n--- Network Configuration ---");
        console2.log("Pool Manager:", SEPOLIA_POOL_MANAGER);
        console2.log("WETH:", SEPOLIA_WETH);
        console2.log("USDC:", SEPOLIA_USDC);
        console2.log("ETH/USD Feed:", SEPOLIA_ETH_USD_PRICE_FEED);

        console2.log("\n--- CREATE2 Deployer Check ---");
        console2.log("CREATE2 Deployer:", CREATE2_DEPLOYER);
        console2.log("CREATE2 Deployer code size:", CREATE2_DEPLOYER.code.length);

        if (CREATE2_DEPLOYER.code.length == 0) {
            console2.log("CREATE2 deployer not found, using regular deployment");
            _deployRegular(deployer);
        } else {
            console2.log(" CREATE2 deployer found, using mining deployment");
            _deployWithMining(deployer);
        }

        vm.stopBroadcast();
    }

    function _deployRegular(address deployer) internal {
        console2.log("\n--- Regular Deployment (No Mining) ---");

        UniCompeteHook hook = new UniCompeteHook(
            IPoolManager(SEPOLIA_POOL_MANAGER), SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED
        );

        console2.log(" Hook deployed at:", address(hook));
        _verifyDeployment(hook);

        console2.log(" NOTE: This hook address doesn't have permission flags.");
        console2.log("   It can be used for testing but won't work with actual pools.");
        console2.log("   For production, you need mining deployment.");
    }

    function _deployWithMining(address deployer) internal {
        console2.log("\n--- Mining Deployment ---");
        console2.log("Hook flags required:", HOOK_FLAGS);

        bytes memory constructorArgs =
            abi.encode(SEPOLIA_POOL_MANAGER, SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED);

        console2.log("Mining for valid hook address...");

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, type(UniCompeteHook).creationCode, constructorArgs);

        console2.log("Found hook address:", hookAddress);
        console2.log("Salt:", uint256(salt));

        if (hookAddress.code.length > 0) {
            console2.log("ERROR: Mined address already has code!");
            console2.log("This means a contract already exists at:", hookAddress);
            console2.log("Falling back to regular deployment...");
            _deployRegular(deployer);
            return;
        }

        console2.log("Mined address is available, proceeding with deployment...");

        console2.log("Deploying with CREATE2...");

        UniCompeteHook hook = new UniCompeteHook{salt: salt}(
            IPoolManager(SEPOLIA_POOL_MANAGER), SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED
        );

        console2.log("CREATE2 deployment successful!");

        require(address(hook) == hookAddress, "Address mismatch!");

        console2.log("Hook deployed with mining at:", address(hook));
        _verifyDeployment(hook);

        uint160 addressFlags = uint160(address(hook)) & 0x3FFF;
        console2.log("Address flags:", addressFlags);
        console2.log("Expected flags:", HOOK_FLAGS);

        if (addressFlags == HOOK_FLAGS) {
            console2.log("Permission flags match!");
        } else {
            console2.log("Permission flags mismatch!");
        }
    }

    function _verifyDeployment(UniCompeteHook hook) internal view {
        console2.log("\n--- Deployment Verification ---");
        console2.log("Hook WETH:", hook.WETH());
        console2.log("Hook USDC:", hook.USDC());
        console2.log("Hook Price Feed:", hook.ETH_USD_PRICE_FEED());
        console2.log("Competition Counter:", hook.competitionCounter());

        try hook.getHookPermissions() returns (Hooks.Permissions memory perms) {
            console2.log("Hook permissions accessible");
            console2.log("After Initialize:", perms.afterInitialize);
            console2.log("Before Swap:", perms.beforeSwap);
            console2.log("After Swap:", perms.afterSwap);
        } catch {
            console2.log("Could not read hook permissions");
        }

        console2.log("\n=== Deployment Complete ===");
        console2.log("Hook Address:", address(hook));
        console2.log("Save this:");
        console2.log("export HOOK_ADDRESS=", address(hook));
    }
}

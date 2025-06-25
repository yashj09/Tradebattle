// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {UniCompeteHook} from "../src/UniCompeteHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/**
 * @title CreateCompetition
 * @notice FIXED - Deployment and testing script for Sepolia testnet
 */
contract CreateCompetition is Script {
    // Sepolia testnet addresses
    address constant SEPOLIA_POOL_MANAGER = 0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A;
    address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // Hook flags matching your working deployment
    uint160 constant HOOK_FLAGS = uint160(
        Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_DONATE_FLAG
    );

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;
        console2.log("=== CreateCompetition Script ===");
        console2.log("Deployer:", deployer);
        console2.log("Balance:", deployer.balance / 1e18, "ETH");

        // Step 1: Get or deploy hook
        UniCompeteHook hook = _getOrDeployHook();
        console2.log("Using hook at:", address(hook));

        // Step 2: Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(SEPOLIA_WETH < SEPOLIA_USDC ? SEPOLIA_WETH : SEPOLIA_USDC),
            currency1: Currency.wrap(SEPOLIA_WETH < SEPOLIA_USDC ? SEPOLIA_USDC : SEPOLIA_WETH),
            fee: 3000, // 0.3% fee
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        console2.log("\n--- Creating Competition ---");
        console2.log("Currency0:", Currency.unwrap(poolKey.currency0));
        console2.log("Currency1:", Currency.unwrap(poolKey.currency1));

        // Step 3: Create competition
        uint256 beforeCount = hook.competitionCounter();

        try hook.createDailyCompetition(poolKey) {
            uint256 afterCount = hook.competitionCounter();
            console2.log("Competition created successfully!");
            console2.log("Competition ID:", afterCount);
            console2.log("Competitions before:", beforeCount);
            console2.log("Competitions after:", afterCount);

            // Get competition details
            if (afterCount > 0) {
                UniCompeteHook.CompetitionInfo memory info = hook.getCompetitionInfo(afterCount);
                console2.log("\n--- Competition Details ---");
                console2.log("ID:", info.id);
                console2.log("Start Time:", info.startTime);
                console2.log("End Time:", info.endTime);
                console2.log("Entry Fee:", info.entryFee);
                console2.log("Participants:", info.participantCount);
                console2.log("Active:", info.isActive);
            }

            // Test price feed
            _testPriceFeed(hook);
        } catch Error(string memory reason) {
            console2.log("Competition creation failed:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Competition creation failed with low-level error");
            console2.logBytes(lowLevelData);
        }

        vm.stopBroadcast();
        console2.log("\n=== Script Complete ===");
    }

    function _getOrDeployHook() internal returns (UniCompeteHook) {
        // Check for existing hook address
        address existingHook = vm.envOr("DEPLOYED_HOOK_ADDRESS", address(0));

        if (existingHook != address(0)) {
            console2.log(" Using existing hook:", existingHook);
            return UniCompeteHook(existingHook);
        }

        console2.log(" Deploying new hook...");

        // Deploy new hook
        bytes memory constructorArgs =
            abi.encode(SEPOLIA_POOL_MANAGER, SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED);

        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, HOOK_FLAGS, type(UniCompeteHook).creationCode, constructorArgs);

        console2.log("Mined hook address:", hookAddress);
        console2.log("Salt:", uint256(salt));

        UniCompeteHook hook = new UniCompeteHook{salt: salt}(
            IPoolManager(SEPOLIA_POOL_MANAGER), SEPOLIA_WETH, SEPOLIA_USDC, SEPOLIA_ETH_USD_PRICE_FEED
        );

        require(address(hook) == hookAddress, "Address mismatch");
        console2.log("New hook deployed:", address(hook));

        return hook;
    }

    function _testPriceFeed(UniCompeteHook hook) internal {
        console2.log("\n--- Testing Price Feed ---");

        try hook.addPriceFeed(SEPOLIA_WETH, SEPOLIA_ETH_USD_PRICE_FEED) {
            console2.log("Price feed configured");
        } catch {
            console2.log("Price feed already configured");
        }

        // Test price feed data
        address feedAddr = hook.ETH_USD_PRICE_FEED();
        console2.log("Price feed address:", feedAddr);

        if (feedAddr == SEPOLIA_ETH_USD_PRICE_FEED) {
            console2.log(" Price feed correctly configured");
        } else {
            console2.log("Price feed mismatch");
        }
    }
}

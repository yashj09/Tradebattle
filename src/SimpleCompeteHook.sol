// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

/**
 * @title SimpleCompeteHook
 * @notice A simplified version of UniCompeteHook for testing and development
 * @dev Uses minimal permissions to avoid hook address validation issues
 */
contract SimpleCompeteHook is BaseHook {
    // Simple state for testing
    mapping(address => uint256) public userTradeCount;
    mapping(address => bool) public isParticipant;

    // Events
    event UserJoined(address indexed user);
    event TradeRecorded(address indexed user, uint256 tradeCount);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true, // Only afterSwap permission
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Join competition function
    function joinCompetition() external {
        require(!isParticipant[msg.sender], "Already joined");
        isParticipant[msg.sender] = true;
        emit UserJoined(msg.sender);
    }

    // Hook implementation - tracks trades
    function _afterSwap(address sender, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        override
        returns (bytes4, int128)
    {
        if (isParticipant[sender]) {
            userTradeCount[sender]++;
            emit TradeRecorded(sender, userTradeCount[sender]);
        }

        return (BaseHook.afterSwap.selector, 0);
    }

    // View functions
    function getTradeCount(address user) external view returns (uint256) {
        return userTradeCount[user];
    }

    function checkParticipant(address user) external view returns (bool) {
        return isParticipant[user];
    }
}

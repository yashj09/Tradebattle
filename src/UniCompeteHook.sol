// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IUniCompete.sol";

/**
 * @title UniCompeteHook
 * @notice A Uniswap v4 hook that creates trading competitions with LP incentives
 * @dev Implements trading competitions with portfolio tracking and LP stickiness rewards
 * @dev Updated for Uniswap v4 with correct interface implementations
 */
contract UniCompeteHook is BaseHook, IUniCompete {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    // Competition structures
    struct Competition {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 entryFee;
        uint256 prizePool;
        uint256 participantCount;
        bool finalized;
        bool isPremiumPool;
        address[] participants;
        PoolKey poolKey;
    }

    struct UserEntry {
        uint256 competitionId;
        uint256 entryTime;
        uint256 initialPortfolioValue;
        uint256 finalPortfolioValue;
        uint256 tradeCount;
        uint256 totalVolume;
        bool qualified;
    }

    struct LPEntry {
        uint256 competitionId;
        uint256 entryTime;
        uint256 liquidityProvided;
        uint256 feesGenerated;
        uint256 volumeFacilitated;
        bool qualified;
        // LP Stickiness tracking
        uint256 daysActive;
        uint256 volatilityPeriods;
        uint256 consistencyScore;
        uint256 lastActiveTime;
    }

    // State variables
    mapping(uint256 => Competition) public competitions;
    mapping(address => mapping(uint256 => UserEntry)) public userEntries;
    mapping(address => mapping(uint256 => LPEntry)) public lpEntries;
    mapping(PoolId => uint256) public activeCompetitions;
    mapping(address => AggregatorV3Interface) public priceFeeds;

    uint256 public competitionCounter;

    // Constants
    uint256 public constant ENTRY_FEE_USD = 10; // $10 USD
    uint256 public constant PREMIUM_ENTRY_FEE_USD = 50; // $50 USD for premium pools
    uint256 public constant MIN_PORTFOLIO_VALUE = 50; // $50 USD
    uint256 public constant MIN_TRADES = 2;
    uint256 public constant MIN_VOLUME = 100; // $100 USD
    uint256 public constant COMPETITION_DURATION = 24 hours;
    uint256 public constant STICKINESS_THRESHOLD = 7 days;
    uint256 public constant VOLATILITY_THRESHOLD = 500; // 5% in basis points

    // Network-specific token addresses
    address public immutable WETH;
    address public immutable USDC;
    address public immutable ETH_USD_PRICE_FEED;

    // Events
    event CompetitionCreated(uint256 indexed competitionId, PoolKey poolKey, bool isPremium);
    event UserJoinedCompetition(address indexed user, uint256 indexed competitionId);
    event LPJoinedCompetition(address indexed lp, uint256 indexed competitionId);
    event CompetitionFinalized(uint256 indexed competitionId, address[] winners);
    event StickinessScoreUpdated(address indexed lp, uint256 indexed competitionId, uint256 score);

    constructor(IPoolManager _poolManager, address _weth, address _usdc, address _ethUsdPriceFeed)
        BaseHook(_poolManager)
    {
        WETH = _weth;
        USDC = _usdc;
        ETH_USD_PRICE_FEED = _ethUsdPriceFeed;

        // Initialize price feeds for this network
        _initializePriceFeeds();
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /**
     * @notice Create a daily competition for a specific pool
     * @param key The pool key for the competition
     */
    function createDailyCompetition(PoolKey memory key) external override {
        competitionCounter++;

        bool isPremium = _isPremiumPool(key);
        uint256 entryFeeAmount = isPremium ? _getPremiumEntryFeeETH() : _getStandardEntryFeeETH();

        competitions[competitionCounter] = Competition({
            id: competitionCounter,
            startTime: block.timestamp,
            endTime: block.timestamp + COMPETITION_DURATION,
            entryFee: entryFeeAmount,
            prizePool: 0,
            participantCount: 0,
            finalized: false,
            isPremiumPool: isPremium,
            participants: new address[](0),
            poolKey: key
        });

        PoolId poolId = key.toId();
        activeCompetitions[poolId] = competitionCounter;

        emit CompetitionCreated(competitionCounter, key, isPremium);
    }

    /**
     * @notice Join a competition as a trader
     * @param competitionId The ID of the competition to join
     */
    function joinCompetition(uint256 competitionId) external payable override {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp < comp.endTime, "Competition ended");
        require(msg.value >= comp.entryFee, "Insufficient entry fee");
        require(userEntries[msg.sender][competitionId].entryTime == 0, "Already joined");

        uint256 portfolioValue = _getPortfolioValue(msg.sender, comp.poolKey);
        require(portfolioValue >= MIN_PORTFOLIO_VALUE * 1e18, "Portfolio too small");

        // Record entry
        userEntries[msg.sender][competitionId] = UserEntry({
            competitionId: competitionId,
            entryTime: block.timestamp,
            initialPortfolioValue: portfolioValue,
            finalPortfolioValue: 0,
            tradeCount: 0,
            totalVolume: 0,
            qualified: false
        });

        comp.participants.push(msg.sender);
        comp.participantCount++;
        comp.prizePool += msg.value;

        emit UserJoinedCompetition(msg.sender, competitionId);
    }

    /**
     * @notice Join a competition as a liquidity provider
     * @param competitionId The ID of the competition to join
     */
    function joinCompetitionAsLP(uint256 competitionId) external override {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp < comp.endTime, "Competition ended");
        require(lpEntries[msg.sender][competitionId].entryTime == 0, "Already joined");

        uint256 liquidityAmount = _getLPPosition(msg.sender, comp.poolKey);
        require(liquidityAmount > 0, "No liquidity position");

        lpEntries[msg.sender][competitionId] = LPEntry({
            competitionId: competitionId,
            entryTime: block.timestamp,
            liquidityProvided: liquidityAmount,
            feesGenerated: 0,
            volumeFacilitated: 0,
            qualified: false,
            daysActive: 0,
            volatilityPeriods: 0,
            consistencyScore: 0,
            lastActiveTime: block.timestamp
        });

        emit LPJoinedCompetition(msg.sender, competitionId);
    }

    /**
     * @notice Get competition information
     * @param competitionId The ID of the competition
     * @return CompetitionInfo struct with competition details
     */
    function getCompetitionInfo(uint256 competitionId) external view override returns (CompetitionInfo memory) {
        Competition storage comp = competitions[competitionId];
        return CompetitionInfo({
            id: comp.id,
            startTime: comp.startTime,
            endTime: comp.endTime,
            entryFee: comp.entryFee,
            participantCount: comp.participantCount,
            isActive: block.timestamp < comp.endTime && !comp.finalized
        });
    }

    // Hook implementations with correct signatures
    function _afterInitialize(address, PoolKey calldata, uint160, int24) internal pure override returns (bytes4) {
        return BaseHook.afterInitialize.selector;
    }

    function _beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        uint256 competitionId = activeCompetitions[poolId];

        if (competitionId > 0 && userEntries[sender][competitionId].entryTime > 0) {
            _updateUserStats(sender, competitionId, params, delta);
        }

        return (BaseHook.afterSwap.selector, 0);
    }

    function _afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        uint256 competitionId = activeCompetitions[poolId];

        if (competitionId > 0 && lpEntries[sender][competitionId].entryTime > 0) {
            _updateLPStats(sender, competitionId, params, delta);
        }

        return (BaseHook.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function _afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata
    ) internal override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        uint256 competitionId = activeCompetitions[poolId];

        if (competitionId > 0 && lpEntries[sender][competitionId].entryTime > 0) {
            _updateLPStats(sender, competitionId, params, delta);
        }

        return (BaseHook.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function _afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        return BaseHook.afterDonate.selector;
    }

    /**
     * @notice Finalize competition and distribute prizes
     * @param competitionId The ID of the competition to finalize
     */
    function finalizeCompetition(uint256 competitionId) external override {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp > comp.endTime, "Competition not ended");
        require(!comp.finalized, "Already finalized");

        // Calculate final scores and determine winners
        address[] memory winners = _calculateWinners(competitionId);
        _distributePrizes(competitionId, winners);
        _distributeLPRewards(competitionId);

        comp.finalized = true;
        emit CompetitionFinalized(competitionId, winners);
    }

    // Internal functions
    function _updateUserStats(address user, uint256 competitionId, SwapParams calldata params, BalanceDelta delta)
        internal
    {
        UserEntry storage entry = userEntries[user][competitionId];
        entry.tradeCount++;

        // Calculate trade volume
        uint256 volume = _calculateTradeVolume(params, delta);
        entry.totalVolume += volume;

        // Check qualification
        if (entry.tradeCount >= MIN_TRADES && entry.totalVolume >= MIN_VOLUME * 1e18) {
            entry.qualified = true;
        }
    }

    function _updateLPStats(
        address lp,
        uint256 competitionId,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta
    ) internal {
        LPEntry storage entry = lpEntries[lp][competitionId];

        // Update liquidity metrics
        if (params.liquidityDelta > 0) {
            entry.liquidityProvided += uint256(int256(params.liquidityDelta));
        }

        // Update stickiness metrics
        _updateLPStickiness(lp, competitionId);
        entry.lastActiveTime = block.timestamp;
        entry.qualified = true;
    }

    function _updateLPStickiness(address lp, uint256 competitionId) internal {
        LPEntry storage entry = lpEntries[lp][competitionId];
        Competition storage comp = competitions[competitionId];

        // Calculate days active
        uint256 daysSinceEntry = (block.timestamp - entry.entryTime) / 1 days;
        entry.daysActive = daysSinceEntry;

        // Check if maintaining liquidity during volatility
        if (_isVolatilePeriod(comp.poolKey)) {
            entry.volatilityPeriods++;
        }

        // Calculate consistency score
        entry.consistencyScore = _calculateConsistencyScore(entry);

        emit StickinessScoreUpdated(lp, competitionId, entry.consistencyScore);
    }

    function _calculateWinners(uint256 competitionId) internal returns (address[] memory) {
        Competition storage comp = competitions[competitionId];
        address[] memory winners = new address[](3);

        // Simple implementation - find top 3 performers by P&L
        uint256 maxReturn = 0;
        for (uint256 i = 0; i < comp.participants.length; i++) {
            address user = comp.participants[i];
            UserEntry storage entry = userEntries[user][competitionId];

            if (entry.qualified) {
                entry.finalPortfolioValue = _getPortfolioValue(user, comp.poolKey);
                uint256 returnPct = (entry.finalPortfolioValue * 100) / entry.initialPortfolioValue;

                if (returnPct > maxReturn) {
                    maxReturn = returnPct;
                    winners[0] = user;
                }
            }
        }

        return winners;
    }

    function _distributePrizes(uint256 competitionId, address[] memory winners) internal {
        Competition storage comp = competitions[competitionId];
        uint256 totalPrize = comp.prizePool;

        // 90% of prize pool goes to winners, 10% platform fee
        uint256 winnersPrize = (totalPrize * 90) / 100;

        if (winners[0] != address(0)) {
            payable(winners[0]).transfer((winnersPrize * 70) / 100); // 70% to first
        }
        if (winners[1] != address(0)) {
            payable(winners[1]).transfer((winnersPrize * 20) / 100); // 20% to second
        }
        if (winners[2] != address(0)) {
            payable(winners[2]).transfer((winnersPrize * 10) / 100); // 10% to third
        }
    }

    function _distributeLPRewards(uint256 competitionId) internal {
        Competition storage comp = competitions[competitionId];

        // 5% of total prize pool goes to LPs as rewards
        uint256 lpRewardPool = (comp.prizePool * 5) / 100;

        if (lpRewardPool > 0) {
            // Use Uniswap v4's donate function to reward LPs
            _donateToLPs(comp.poolKey, lpRewardPool);
        }
    }

    function _donateToLPs(PoolKey memory key, uint256 amount) internal {
        // Implementation for donating rewards to LPs using v4's donate function
        if (amount > 0) {
            // Split donation between both currencies in the pool
            uint256 amount0 = amount / 2;
            uint256 amount1 = amount / 2;

            // Note: In production, implement proper currency conversion
            poolManager.donate(key, amount0, amount1, "");
        }
    }

    function _isPremiumPool(PoolKey memory key) internal view returns (bool) {
        return (Currency.unwrap(key.currency0) == WETH && Currency.unwrap(key.currency1) == USDC)
            || (Currency.unwrap(key.currency0) == USDC && Currency.unwrap(key.currency1) == WETH);
    }

    function _getStandardEntryFeeETH() internal view returns (uint256) {
        return _convertUSDToETH(ENTRY_FEE_USD);
    }

    function _getPremiumEntryFeeETH() internal view returns (uint256) {
        return _convertUSDToETH(PREMIUM_ENTRY_FEE_USD);
    }

    function _convertUSDToETH(uint256 usdAmount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[WETH];
        require(address(priceFeed) != address(0), "Price feed not available");

        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");

        // Price is in 8 decimals, convert to 18 decimals
        return (usdAmount * 1e18) / (uint256(price) * 1e10);
    }

    function _getPortfolioValue(address user, PoolKey memory key) internal view returns (uint256) {
        // Simplified portfolio calculation
        return 100e18; // Placeholder
    }

    function _getLPPosition(address lp, PoolKey memory key) internal view returns (uint256) {
        // Get LP's position size in the pool
        return 1e18; // Placeholder
    }

    function _calculateTradeVolume(SwapParams calldata params, BalanceDelta delta) internal pure returns (uint256) {
        int256 amountSpecified = params.amountSpecified;
        return uint256(amountSpecified < 0 ? -amountSpecified : amountSpecified);
    }

    function _isVolatilePeriod(PoolKey memory) internal view returns (bool) {
        return false; // Placeholder
    }

    function _calculateConsistencyScore(LPEntry memory entry) internal pure returns (uint256) {
        uint256 baseScore = entry.daysActive * 10;
        uint256 volatilityBonus = entry.volatilityPeriods * 5;
        return baseScore + volatilityBonus;
    }

    function _initializePriceFeeds() internal {
        priceFeeds[WETH] = AggregatorV3Interface(ETH_USD_PRICE_FEED);
    }

    // Admin function to add new price feeds
    function addPriceFeed(address token, address priceFeedAddress) external {
        priceFeeds[token] = AggregatorV3Interface(priceFeedAddress);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";

interface IUniCompete {
    struct CompetitionInfo {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 entryFee;
        uint256 participantCount;
        bool isActive;
    }

    function createDailyCompetition(PoolKey memory key) external;
    function joinCompetition(uint256 competitionId) external payable;
    function joinCompetitionAsLP(uint256 competitionId) external;
    function finalizeCompetition(uint256 competitionId) external;
    function getCompetitionInfo(uint256 competitionId) external view returns (CompetitionInfo memory);
}

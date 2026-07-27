// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IPredictionMarket
/// @notice Interface for the Prediction Market contract
interface IPredictionMarket {
    struct Market {
        string question;
        uint128 outcomeYes;
        uint128 outcomeNo;
        uint40 deadline;
        uint8 status;
        bool result;
        uint16 feeBps;
    }

    function markets(uint256 id) external view returns (
        string memory question,
        uint128 outcomeYes,
        uint128 outcomeNo,
        uint40 deadline,
        uint8 status,
        bool result,
        uint16 feeBps
    );

    function resolveMarket(uint256 marketId, bool result) external;

    function disputeResolve(uint256 marketId, bool result) external;
}

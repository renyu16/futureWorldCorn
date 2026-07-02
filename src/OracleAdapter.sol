// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@chainlink/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./PredictionMarket.sol";

contract OracleAdapter {
    PredictionMarket public market;
    address public keeper;

    struct FeedConfig {
        AggregatorV3Interface feed;
        uint256 threshold;
        bool isAbove;
    }
    mapping(uint256 => FeedConfig) public feedConfigs;
    mapping(uint256 => bool) public pushResults;

    event Resolved(uint256 indexed marketId, bool result);

    modifier onlyKeeper() {
        require(msg.sender == keeper, "not keeper");
        _;
    }

    constructor(address _market, address _keeper) {
        market = PredictionMarket(_market);
        keeper = _keeper;
    }

    function configureFeed(uint256 marketId, address feedAddr, uint256 threshold, bool isAbove) external onlyKeeper {
        feedConfigs[marketId] = FeedConfig(AggregatorV3Interface(feedAddr), threshold, isAbove);
    }

    function resolveWithFeed(uint256 marketId) external onlyKeeper {
        FeedConfig memory cfg = feedConfigs[marketId];
        (, int256 price,,,) = cfg.feed.latestRoundData();
        bool result = cfg.isAbove ? uint256(price) > cfg.threshold : uint256(price) < cfg.threshold;
        market.resolveMarket(marketId, result);
        emit Resolved(marketId, result);
    }

    function pushResult(uint256 marketId, bool result) external onlyKeeper {
        pushResults[marketId] = result;
        market.resolveMarket(marketId, result);
        emit Resolved(marketId, result);
    }
}

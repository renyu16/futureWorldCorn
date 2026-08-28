// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";
import "../src/HumanHouse.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BatchTestSetup is Script {
    address constant CORN = 0x7440503d25A38513919203E58DB70d3Ee14197ed;
    address constant MARKET = 0x9Cb69cb7DA9677B3A122A6a4E402398a6DF4a026;
    address constant HUMAN_HOUSE = 0xD1062855477c08bFf3C852fc42844CA35Db32C72;

    function run() external {
        uint256 aiDevAKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");
        uint256 aiDevBKey = vm.envUint("AI_DEV_B_PRIVATE_KEY");
        address aiDevB = vm.addr(aiDevBKey);

        PredictionMarket market = PredictionMarket(payable(MARKET));

        // === Part A: AI_DEV_A transfers CORN to B + bets ===
        vm.startBroadcast(aiDevAKey);

        IERC20(CORN).transfer(aiDevB, 50000e18);
        IERC20(CORN).approve(MARKET, type(uint256).max);
        market.bet(1, PredictionMarket.Outcome.YES, 1000e18);
        market.bet(2, PredictionMarket.Outcome.YES, 2000e18);
        market.bet(3, PredictionMarket.Outcome.NO, 500e18);
        market.bet(4, PredictionMarket.Outcome.YES, 1500e18);
        market.bet(5, PredictionMarket.Outcome.YES, 800e18);

        vm.stopBroadcast();
        console.log("Part A done: A bets");

        // === Part B: AI_DEV_B bets ===
        vm.startBroadcast(aiDevBKey);

        IERC20(CORN).approve(MARKET, type(uint256).max);
        market.bet(1, PredictionMarket.Outcome.NO, 800e18);
        market.bet(2, PredictionMarket.Outcome.NO, 1200e18);
        market.bet(3, PredictionMarket.Outcome.YES, 600e18);
        market.bet(4, PredictionMarket.Outcome.NO, 900e18);
        market.bet(5, PredictionMarket.Outcome.NO, 400e18);
        market.bet(6, PredictionMarket.Outcome.YES, 700e18);
        market.bet(7, PredictionMarket.Outcome.NO, 400e18);
        market.bet(8, PredictionMarket.Outcome.YES, 300e18);

        vm.stopBroadcast();
        console.log("Part B done: B bets");

        // === Part C: AI_DEV_A bets more on remaining markets ===
        vm.startBroadcast(aiDevAKey);

        market.bet(6, PredictionMarket.Outcome.NO, 600e18);
        market.bet(7, PredictionMarket.Outcome.YES, 1000e18);
        market.bet(8, PredictionMarket.Outcome.NO, 500e18);

        // Approve + raise dispute on market 1
        IERC20(CORN).approve(HUMAN_HOUSE, 10000e18);
        HumanHouse(payable(HUMAN_HOUSE)).raiseDispute(
            1,
            HumanHouse.DisputeType.OracleResult,
            unicode"市场1结果可能存在争议，需要重新验证"
        );

        // Raise dispute on market 3
        HumanHouse(payable(HUMAN_HOUSE)).raiseDispute(
            3,
            HumanHouse.DisputeType.MarketContent,
            unicode"市场3问题描述不够明确，存在歧义"
        );

        vm.stopBroadcast();
        console.log("Part C done: more bets + disputes");
    }
}

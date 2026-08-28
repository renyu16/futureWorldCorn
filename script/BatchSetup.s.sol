// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";
import "../src/GovCrownToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BatchSetup is Script {
    address constant CORN_TOKEN = 0x7440503d25A38513919203E58DB70d3Ee14197ed;
    address constant MARKET_PROXY = 0x9Cb69cb7DA9677B3A122A6a4E402398a6DF4a026;
    address constant GOV_CORN = 0x4b662FE6692a2ba04eED0C73E464c569fAe6faaD;

    function run() external {
        uint256 deployerKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");

        PredictionMarket market = PredictionMarket(payable(MARKET_PROXY));

        uint40 baseDeadline = uint40(block.timestamp + 1 days);

        vm.startBroadcast(deployerKey);

        market.createMarket(unicode"BTC 2026年底能突破15万美元吗？", baseDeadline + 7 days, 200);
        market.createMarket(unicode"ETH 2026年底能突破1万美元吗？", baseDeadline + 14 days, 200);
        market.createMarket(unicode"World Chain 2026年TVL能突破10亿美元吗？", baseDeadline + 21 days, 200);
        market.createMarket(unicode"2026年全球GDP增速能超过3.5%吗？", baseDeadline + 28 days, 200);
        market.createMarket(unicode"AI 2026年底前能通过图灵测试吗？", baseDeadline + 35 days, 200);
        market.createMarket(unicode"2026年Solana市值能超过以太坊吗？", baseDeadline + 42 days, 200);
        market.createMarket(unicode"CornToken 2026年底前市值能进Top 100吗？", baseDeadline + 49 days, 200);
        market.createMarket(unicode"2026年底全球加密货币用户能突破10亿吗？", baseDeadline + 56 days, 200);

        IERC20(CORN_TOKEN).approve(GOV_CORN, 10000e18);
        (bool ok, ) = GOV_CORN.call(abi.encodeWithSignature("deposit(uint256)", 10000e18));
        require(ok, "govCORN deposit failed");

        vm.stopBroadcast();

        console.log("Done: 8 markets + 10000 govCORN");
    }
}

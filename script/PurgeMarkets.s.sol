// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";

/// @dev Deploy a new PredictionMarket implementation, upgrade the on-chain proxy,
///      and purge all markets back to marketCount == 0 (onlyOwner).
///
/// Required env vars:
///   DEPLOYER_PRIVATE_KEY – the OWNER key of the proxy (AI_DEV_A, NOT the keeper key)
///   MARKET_PROXY         – address of the live PredictionMarket proxy
contract PurgeMarkets is Script {
    function run() external {
        uint256 ownerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address marketProxy = vm.envAddress("MARKET_PROXY");

        vm.startBroadcast(ownerKey);

        PredictionMarket newImpl = new PredictionMarket();
        PredictionMarket(payable(marketProxy)).upgradeToAndCall(address(newImpl), "");

        uint256 before = PredictionMarket(payable(marketProxy)).marketCount();
        require(before > 0, "nothing to purge");
        PredictionMarket(payable(marketProxy)).resetMarketCount(0);
        uint256 marketCountAfter = PredictionMarket(payable(marketProxy)).marketCount();
        require(marketCountAfter == 0, "purge failed");

        vm.stopBroadcast();
    }
}

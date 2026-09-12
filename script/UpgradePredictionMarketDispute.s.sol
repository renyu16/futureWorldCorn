// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";

/// @dev Deploy a new PredictionMarket implementation (dispute fixes) and upgrade the proxy.
///      Owner key (AI_DEV_A_PRIVATE_KEY) must be used — upgradeToAndCall requires owner.
///
/// Required env vars (in .env):
///   AI_DEV_A_PRIVATE_KEY – owner private key
///   MARKET_PROXY         – address of the live PredictionMarket proxy
contract UpgradePredictionMarketDispute is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");
        address marketProxy = vm.envAddress("MARKET_PROXY");

        vm.startBroadcast(deployerKey);

        PredictionMarket newImpl = new PredictionMarket();
        PredictionMarket(payable(marketProxy)).upgradeToAndCall(address(newImpl), "");

        vm.stopBroadcast();

        console.log("New PredictionMarket implementation:", address(newImpl));
        console.log("Proxy:", marketProxy);
    }
}
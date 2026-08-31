// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";

/// @dev Deploy a new PredictionMarket implementation and upgrade the on-chain proxy.
///      Optionally grant marketCreator to a first address.
///
/// Required env vars (add to .env):
///   DEPLOYER_PRIVATE_KEY   – owner key that deployed the proxy
///   MARKET_PROXY           – address of the live PredictionMarket proxy
///
/// Optional env vars:
///   MARKET_CREATOR         – address to whitelist (true); omit to skip
contract UpgradePredictionMarketMarketCreator is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address marketProxy = vm.envAddress("MARKET_PROXY");
        address marketCreator = vm.envOr("MARKET_CREATOR", address(0));

        vm.startBroadcast(deployerKey);

        PredictionMarket newImpl = new PredictionMarket();
        PredictionMarket(payable(marketProxy)).upgradeToAndCall(address(newImpl), "");

        if (marketCreator != address(0)) {
            PredictionMarket(marketProxy).setMarketCreator(marketCreator, true);
        }

        vm.stopBroadcast();
    }
}
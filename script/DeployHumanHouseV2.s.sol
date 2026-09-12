// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";
import "../src/HumanHouse.sol";
import "../src/mocks/MockWorldIdRouter.sol";

/// @dev Redeploy HumanHouse with the dispute v2 code:
///      dynamic dispute deposit, pending-dispute claim freeze, mockWorldId flag.
///
///      Storage note: HumanHouse is NOT upgradeable, so it must be redeployed.
///      Sets the new HumanHouse as a resolver on PredictionMarket.
///
/// Required env vars (in .env):
///   AI_DEV_A_PRIVATE_KEY – owner private key (owner of PredictionMarket)
///   CORN_TOKEN           – token address (defaults to known deployment)
///   MARKET_PROXY         – PredictionMarket proxy (defaults to known deployment)
contract DeployHumanHouseV2 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");
        address cornToken = vm.envOr("CORN_TOKEN", address(0x7440503d25A38513919203E58DB70d3Ee14197ed));
        address marketProxy = vm.envOr(
            "MARKET_PROXY",
            address(0x9Cb69cb7DA9677B3A122A6a4E402398a6DF4a026)
        );

        uint256 baseDeposit = vm.envOr("DISPUTE_DEPOSIT", uint256(1000e18));
        string memory appId = vm.envOr("WORLD_ID_APP_ID", string("app_staging_human_house"));
        string memory actionId = vm.envOr("WORLD_ID_ACTION_ID", string("human_house_vote"));

        vm.startBroadcast(deployerKey);

        MockWorldIdRouter router = new MockWorldIdRouter();

        HumanHouse humanHouse = new HumanHouse(
            cornToken,
            marketProxy,
            baseDeposit,
            IWorldID(address(router)),
            appId,
            actionId
        );

        PredictionMarket(marketProxy).setResolver(address(humanHouse), true);

        vm.stopBroadcast();

        console.log("New HumanHouse:", address(humanHouse));
        console.log("MockWorldIdRouter:", address(router));
        console.log("PredictionMarket proxy:", marketProxy);
    }
}
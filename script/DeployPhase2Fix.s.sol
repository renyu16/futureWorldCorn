// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/GovCrownToken.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";

contract DeployPhase2Fix is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address cornToken = vm.envAddress("CORN_TOKEN");
        address marketProxy = vm.envAddress("MARKET_PROXY");
        address safeAddress = vm.envAddress("SAFE_ADDRESS");

        vm.startBroadcast(deployerKey);

        GovCrownToken govCorn = new GovCrownToken(IERC20(cornToken));

        address[] memory proposers = new address[](1);
        proposers[0] = safeAddress;
        TimelockController timelock = new TimelockController(
            2 days, proposers, new address[](0), msg.sender
        );
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        PredictionMarket(marketProxy).transferOwnership(address(timelock));
        CornToken(cornToken).transferOwnership(address(timelock));

        vm.stopBroadcast();
    }
}

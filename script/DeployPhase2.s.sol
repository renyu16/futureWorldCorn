// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/GovCrownToken.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";

contract DeployPhase2 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address cornToken = vm.envAddress("CORN_TOKEN_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY_ADDRESS");
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        uint256 minDelay = vm.envOr("TIMELOCK_DELAY", uint256(2 days));

        vm.startBroadcast(deployerKey);

        GovCrownToken govCorn = new GovCrownToken(IERC20(cornToken));

        address[] memory proposers = new address[](1);
        proposers[0] = safeAddress;
        TimelockController timelock = new TimelockController(
            minDelay, proposers, new address[](0), deployer
        );
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        PredictionMarket market = PredictionMarket(marketProxy);
        market.transferOwnership(address(timelock));

        CornToken token = CornToken(cornToken);
        token.transferOwnership(address(timelock));

        vm.stopBroadcast();
    }
}

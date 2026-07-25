// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";

contract TransferToTimelock is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY");
        address tokenAddress = vm.envAddress("CORN_TOKEN");
        uint256 minDelay = vm.envOr("TIMELOCK_DELAY", uint256(2 days));

        vm.startBroadcast(deployerKey);

        TimelockController timelock = new TimelockController(
            minDelay,
            new address[](0),
            new address[](0),
            deployer
        );

        timelock.grantRole(timelock.PROPOSER_ROLE(), safeAddress);
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        PredictionMarket market = PredictionMarket(marketProxy);
        market.transferOwnership(address(timelock));

        CornToken token = CornToken(tokenAddress);
        token.transferOwnership(address(timelock));

        vm.stopBroadcast();
    }
}

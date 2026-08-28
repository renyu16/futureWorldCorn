// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract FixTimelock is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");
        address timelockAddr = 0xe968028334F779C0767A7Bcd96905083c0c3FDA8;

        vm.startBroadcast(deployerKey);

        TimelockController timelock = TimelockController(payable(timelockAddr));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        vm.stopBroadcast();
        console.log("Executor role granted to address(0)");
    }
}

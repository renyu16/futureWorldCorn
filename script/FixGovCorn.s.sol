// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/GovCrownToken.sol";
import "../src/TokenHouse.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

interface IDeposit {
    function depositFor(address account, uint256 amount) external returns (bool);
}

contract FixGovCorn is Script {
    address constant CORN = 0x7440503d25A38513919203E58DB70d3Ee14197ed;
    address constant TIMELOCK = 0xe968028334F779C0767A7Bcd96905083c0c3FDA8;
    bytes32 constant PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;

    function run() external {
        uint256 deployerKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        uint256 aiDevBKey = vm.envUint("AI_DEV_B_PRIVATE_KEY");
        address aiDevB = vm.addr(aiDevBKey);

        vm.startBroadcast(deployerKey);

        GovCrownToken govCorn = new GovCrownToken(IERC20(CORN));
        console.log("New GovCORN:", address(govCorn));

        TimelockController timelock = TimelockController(payable(TIMELOCK));
        TokenHouse tokenHouse = new TokenHouse(IVotes(address(govCorn)), timelock);
        console.log("New TokenHouse:", address(tokenHouse));

        timelock.grantRole(PROPOSER_ROLE, address(tokenHouse));

        IERC20(CORN).approve(address(govCorn), 100000e18);
        IDeposit(address(govCorn)).depositFor(deployer, 50000e18);
        govCorn.delegate(deployer);

        vm.stopBroadcast();
        console.log("Part 1 done");

        vm.startBroadcast(aiDevBKey);

        IERC20(CORN).approve(address(govCorn), 60000e18);
        IDeposit(address(govCorn)).depositFor(aiDevB, 20000e18);
        govCorn.delegate(aiDevB);

        vm.stopBroadcast();
        console.log("Part 2 done");
    }
}

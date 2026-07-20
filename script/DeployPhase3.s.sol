// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "../src/TokenHouse.sol";
import "../src/HumanHouse.sol";

/**
 * Phase 3 部署脚本：部署 TokenHouse 和 HumanHouse，配置 Timelock 角色。
 *
 * 前提条件：部署者必须拥有 TimelockController 的 DEFAULT_ADMIN_ROLE。
 * 在 Phase 2 中，admin 角色被撤销，Timelock 自管理。
 * 如需重新授予 admin 角色进行 Phase 3 部署，需通过 Safe 多签发起 Timelock 提案。
 */
contract DeployPhase3 is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address govCorn = vm.envAddress("GOV_CORN_ADDRESS");
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address cornToken = vm.envAddress("CORN_TOKEN_ADDRESS");
        address marketProxy = vm.envAddress("MARKET_PROXY_ADDRESS");
        uint256 disputeDeposit = vm.envOr("DISPUTE_DEPOSIT", uint256(1000e18));

        vm.startBroadcast(deployerKey);

        TimelockController timelock = TimelockController(payable(timelockAddr));

        TokenHouse tokenHouse = new TokenHouse(IVotes(govCorn), timelock);
        HumanHouse humanHouse = new HumanHouse(cornToken, marketProxy, disputeDeposit);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(humanHouse));

        vm.stopBroadcast();
    }
}

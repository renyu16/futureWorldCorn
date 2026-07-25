// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../../src/CornToken.sol";
import "../../src/PredictionMarket.sol";
import "../../src/OracleAdapter.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice 部署脚本 anvil dry-run（任务8）：复刻 Deploy.s.sol + TransferToTimelock.s.sol
/// 在本地 anvil 验证"部署后所有权转移至 TimelockController"的核心不变量，无需外部 RPC。
contract DeployDryRunTest is Test {
    address deployer = address(0xBEEF);
    address safe = address(0xCAFE); // 占位 Safe 多签地址（生产为真实 Safe）

    function test_DeployAndTransferToTimelock() public {
        vm.startPrank(deployer);

        CornToken token = new CornToken();

        PredictionMarket implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector, address(token), address(0x3), deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        PredictionMarket market = PredictionMarket(address(proxy));

        OracleAdapter adapter = new OracleAdapter(address(market), deployer);
        market.setResolver(address(adapter), true);

        // 复刻 TransferToTimelock.s.sol 核心顺序
        TimelockController timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            deployer
        );
        timelock.grantRole(timelock.PROPOSER_ROLE(), safe);
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.grantRole(timelock.DEFAULT_ADMIN_ROLE(), address(timelock));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        market.transferOwnership(address(timelock));
        token.transferOwnership(address(timelock));

        vm.stopPrank();

        // Ownable2Step: timelock must accept ownership (PredictionMarket only)
        vm.prank(address(timelock));
        market.acceptOwnership();

        // 断言部署后核心不变量：所有权已转移至 Timelock
        assertEq(address(market.owner()), address(timelock));
        assertEq(address(token.owner()), address(timelock));
        // Timelock 自管 admin，deployer 已无 admin；Safe 为 proposer
        assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), deployer));
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), safe));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)));
    }
}

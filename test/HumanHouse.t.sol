// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "../src/HumanHouse.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HumanHouseTest is Test {
    CornToken corn;
    PredictionMarket market;
    HumanHouse humanHouse;
    address feeCollector = address(0x99);
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        corn = new CornToken();

        PredictionMarket impl = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(corn), feeCollector, address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        market = PredictionMarket(address(proxy));

        market.createMarket("Will ETH reach $10k?", uint40(block.timestamp + 7 days), 0);

        // Fund alice
        corn.transfer(alice, 10000e18);
        vm.startPrank(alice);
        corn.approve(address(market), 1000e18);
        market.bet(1, PredictionMarket.Outcome.YES, 1000e18);
        vm.stopPrank();

        // Fund bob
        corn.transfer(bob, 10000e18);

        humanHouse = new HumanHouse(address(corn), address(market), 1000e18);
    }

    function test_RaiseDispute() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        (,, HumanHouse.DisputeState state,,,,,,) = humanHouse.disputes(1);
        assertEq(uint8(state), uint8(HumanHouse.DisputeState.Active));
    }

    function test_ExecuteDispute_Approved() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);
        market.setResolver(address(humanHouse), true);

        // Raise dispute
        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        // Vote in favor
        humanHouse.vote(1, true);

        // Warp past deadline
        vm.warp(block.timestamp + 6 days);

        uint256 aliceBalanceBefore = corn.balanceOf(alice);
        humanHouse.executeDispute(1);
        uint256 aliceBalanceAfter = corn.balanceOf(alice);

        (,, HumanHouse.DisputeState state,,,,,,) = humanHouse.disputes(1);
        assertEq(uint8(state), uint8(HumanHouse.DisputeState.Approved));
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 1000e18);

        (,,,,, bool marketResult,) = market.markets(1);
        assertTrue(!marketResult); // result flipped from true to false
    }

    function test_ExecuteDispute_Rejected() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        // Raise dispute
        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        // Vote against
        humanHouse.vote(1, false);

        // Warp past deadline
        vm.warp(block.timestamp + 6 days);

        uint256 aliceBalanceBefore = corn.balanceOf(alice);
        humanHouse.executeDispute(1);
        uint256 aliceBalanceAfter = corn.balanceOf(alice);

        (,, HumanHouse.DisputeState state,,,,,,) = humanHouse.disputes(1);
        assertEq(uint8(state), uint8(HumanHouse.DisputeState.Rejected));
        assertEq(aliceBalanceAfter, aliceBalanceBefore);
    }

    function test_DisputeDepositRequiresApproval() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        vm.expectRevert();
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "No approval");
        vm.stopPrank();
    }

    function test_OnlyOwnerCanSetParams() public {
        vm.startPrank(alice);
        vm.expectRevert();
        humanHouse.setDisputeDeposit(2000e18);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert();
        humanHouse.setVotingPeriod(3 days);
        vm.stopPrank();
    }

    // ===== 追加（任务3）：vote 防重复与投票期 =====

    function test_DoubleVoteReverts() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        humanHouse.vote(1, true);
        vm.expectRevert("already voted");
        humanHouse.vote(1, true);
    }

    function test_VoteAfterDeadlineReverts() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        // votingPeriod = 5 days，dispute deadline ≈ 13 days；warp 6 days → 14 days 已过窗
        vm.warp(block.timestamp + 6 days);
        vm.expectRevert("voting ended");
        humanHouse.vote(1, true);
    }

    // 注：whenNotPaused 修饰 raiseDispute/vote，但 HumanHouse 未暴露 external pause()，
    // 故无法在本地（不改源码）触发 pause。paused 路径列为 GAP-2（见执行记录）。

    // ===== 追加（任务4）：executeDispute 时间窗、二次执行、withdrawFees =====

    function test_ExecuteBeforeDeadlineReverts() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        // 未过 votingPeriod，不应执行
        vm.expectRevert("voting not ended");
        humanHouse.executeDispute(1);
    }

    function test_ExecuteTwiceReverts() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        humanHouse.vote(1, false); // votesAgainst > votesFor → Rejected
        vm.warp(block.timestamp + 6 days);
        humanHouse.executeDispute(1);

        vm.expectRevert("not active");
        humanHouse.executeDispute(1);
    }

    function test_WithdrawFeesAfterReject() public {
        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        humanHouse.vote(1, false);
        vm.warp(block.timestamp + 6 days);
        humanHouse.executeDispute(1); // Rejected，押金被没收留合约

        // owner 为本测试合约（setUp 中 new HumanHouse 的 msg.sender = this）
        uint256 ownerBalBefore = corn.balanceOf(address(this));
        humanHouse.withdrawFees();
        uint256 ownerBalAfter = corn.balanceOf(address(this));
        assertEq(ownerBalAfter - ownerBalBefore, 1000e18);
    }

    // ===== GAP-1 验证：争议批准后实际修改市场结果 =====
    function test_DisputeApprovedFlipsMarketResult() public {
        // Add HumanHouse as resolver
        market.setResolver(address(humanHouse), true);

        vm.warp(block.timestamp + 8 days);
        market.resolveMarket(1, true);
        (,,,,, bool originalResult,) = market.markets(1);
        assertTrue(originalResult);

        vm.startPrank(alice);
        corn.approve(address(humanHouse), 1000e18);
        humanHouse.raiseDispute(1, HumanHouse.DisputeType.OracleResult, "Wrong result");
        vm.stopPrank();

        humanHouse.vote(1, true);
        vm.warp(block.timestamp + 6 days);
        humanHouse.executeDispute(1);

        (,,,,, bool newResult,) = market.markets(1);
        assertTrue(!newResult); // result should be flipped (now false)
    }
}

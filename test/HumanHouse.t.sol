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
}

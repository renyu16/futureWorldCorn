// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../../src/CornToken.sol";
import "../../src/PredictionMarket.sol";
import "../../src/OracleAdapter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PredictionMarketIntegrationTest is Test {
    CornToken token;
    PredictionMarket pm;
    address alice = address(0x1);
    address bob = address(0x2);
    address feeCollector = address(0x3);

    uint40 constant DEADLINE = 100;
    string constant QUESTION = "Will ETH reach $10k by Dec 2026?";

    function setUp() public {
        vm.warp(1);
        token = new CornToken();
        PredictionMarket implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(token),
            feeCollector,
            address(this)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        pm = PredictionMarket(address(proxy));

        token.transfer(alice, 10_000 ether);
        token.transfer(bob, 10_000 ether);

        vm.prank(alice);
        token.approve(address(pm), type(uint256).max);
        vm.prank(bob);
        token.approve(address(pm), type(uint256).max);
    }

    function test_FullPredictionFlow() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();
        assertEq(marketId, 1);

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);
        assertEq(pm.sharesYes(marketId, alice), 1000);

        vm.prank(bob);
        pm.bet(marketId, PredictionMarket.Outcome.NO, 500);
        assertEq(pm.sharesNo(marketId, bob), 500);

        (, uint128 outcomeYes, uint128 outcomeNo,,,,,,,) = pm.markets(marketId);
        assertEq(outcomeYes, 1000);
        assertEq(outcomeNo, 500);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(marketId, true);

        (,,,,, bool result,,,,) = pm.markets(marketId);
        assertEq(result, true);

        assertEq(pm.claimFrozen(marketId), true);

        vm.warp(block.timestamp + 24 hours + 1);
        pm.unlockClaims(marketId);
        assertEq(pm.claimFrozen(marketId), false);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(marketId);
        uint256 aliceReward = token.balanceOf(alice) - aliceBalanceBefore;
        assertEq(aliceReward, 1490);

        vm.prank(bob);
        vm.expectRevert("no winnings");
        pm.claimReward(marketId);

        uint256 feeBalance = token.balanceOf(feeCollector);
        assertEq(feeBalance, 10);

        assertEq(token.balanceOf(address(pm)), 0);
    }

    function test_ResolutionViaOraclePush() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();

        address keeper = address(0x42);
        OracleAdapter adapter = new OracleAdapter(address(pm), keeper);
        pm.setResolver(address(adapter), true);

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);

        vm.prank(keeper);
        adapter.pushResult(marketId, true);

        (,,,,, bool result,,,,) = pm.markets(marketId);
        assertEq(result, true);

        vm.warp(block.timestamp + 24 hours + 1);
        pm.unlockClaims(marketId);

        vm.prank(alice);
        pm.claimReward(marketId);
        assertEq(token.balanceOf(alice), 10_000 ether);
    }

    function test_ClaimFrozenDuringDisputeWindow() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(marketId, true);

        assertEq(pm.claimFrozen(marketId), true);

        vm.prank(alice);
        vm.expectRevert("claims frozen: dispute window open");
        pm.claimReward(marketId);

        vm.warp(block.timestamp + 24 hours + 1);
        pm.unlockClaims(marketId);

        vm.prank(alice);
        pm.claimReward(marketId);
        assertEq(pm.claimed(marketId, alice), true);
    }

    function test_DisputeResolvePreventsUnlock() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();
        address resolver = address(0x99);
        pm.setResolver(resolver, true);

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);
        vm.prank(bob);
        pm.bet(marketId, PredictionMarket.Outcome.NO, 500);

        vm.warp(DEADLINE + 1);
        vm.prank(resolver);
        pm.resolveMarket(marketId, true);

        vm.prank(resolver);
        pm.disputeResolve(marketId, false);

        vm.warp(block.timestamp + 24 hours + 1);

        // window passed but disputeCount > 0 -> auto unlock / claim stay blocked
        vm.expectRevert("dispute exists");
        pm.unlockClaims(marketId);

        vm.prank(alice);
        vm.expectRevert("claims frozen: dispute in progress");
        pm.claimReward(marketId);

        (,,,,, bool result,,,,) = pm.markets(marketId);
        assertEq(result, false);
        assertEq(pm.disputeCount(marketId), 1);

        // only a resolver can unfreeze after an active dispute
        vm.prank(resolver);
        pm.unfreezeClaims(marketId);
        assertEq(pm.claimFrozen(marketId), false);
        assertEq(pm.disputeLocked(marketId), true);
    }

    function test_DisputeResolveAntiRepetition() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();
        address resolver = address(0x99);
        pm.setResolver(resolver, true);

        vm.warp(DEADLINE + 1);
        vm.prank(resolver);
        pm.resolveMarket(marketId, true);

        vm.prank(resolver);
        pm.disputeResolve(marketId, false);

        (,,,,, bool result,,,,) = pm.markets(marketId);
        assertEq(result, false);
        assertEq(pm.disputeCount(marketId), 1);

        vm.prank(resolver);
        pm.disputeResolve(marketId, true);

        (,,,,, bool result2,,,,) = pm.markets(marketId);
        assertEq(result2, true);
        assertEq(pm.disputeCount(marketId), 2);
    }

    function test_DynamicDeposit() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 10000);

        vm.startPrank(address(this));
        token.transfer(address(0x50), 100_000 ether);
        token.approve(address(pm), type(uint256).max);

        assertEq(pm.getMarketPool(marketId), 10000);
    }

    function test_UnlockClaimsAuto() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(marketId, true);

        vm.warp(block.timestamp + 24 hours + 1);
        vm.prank(alice);
        pm.claimReward(marketId);

        assertEq(pm.claimFrozen(marketId), false);
        assertEq(pm.disputeLocked(marketId), true);
    }

    function test_PendingDisputeBlocksClaimAfterWindow() public {
        pm.createMarket(QUESTION, DEADLINE, 200, "", "", "");
        uint256 marketId = pm.marketCount();

        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(marketId, true);

        // HumanHouse raises a dispute -> pending, claims must stay frozen
        pm.freezeClaims(marketId);

        // 24h window passes while the 5-day vote is still running
        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(alice);
        vm.expectRevert("claims frozen: dispute in progress");
        pm.claimReward(marketId);

        vm.expectRevert("dispute in progress");
        pm.unlockClaims(marketId);

        // dispute concludes -> unfreeze, claims work again
        pm.unfreezeClaims(marketId);
        assertEq(pm.claimFrozen(marketId), false);

        vm.prank(alice);
        pm.claimReward(marketId);
        assertEq(pm.claimed(marketId, alice), true);
    }
}

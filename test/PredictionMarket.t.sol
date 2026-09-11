// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PredictionMarketTest is Test {
    CornToken token;
    PredictionMarket pm;
    address alice = address(0x1);
    address bob = address(0x2);
    address feeCollector = address(0x3);

    uint40 constant DEADLINE = 1_000_000;
    string constant QUESTION = "Will ETH reach $10k?";

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

    function _createMarket() internal returns (uint256) {
        return _createMarket(200);
    }

    function _createMarket(uint16 feeBps) internal returns (uint256) {
        pm.createMarket(QUESTION, DEADLINE, feeBps);
        return pm.marketCount();
    }

    // ======== TESTS ========

    function test_CreateMarket() public {
        uint256 id = _createMarket();
        assertEq(id, 1);

        (string memory question,,, uint40 deadline,,, uint16 feeBps) = pm.markets(1);
        assertEq(question, QUESTION);
        assertEq(deadline, DEADLINE);
        assertEq(feeBps, 200);
    }

    function test_Bet() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        assertEq(pm.sharesYes(id, alice), 1000);
        assertEq(pm.sharesNo(id, alice), 0);

        (, uint128 outcomeYes,,,,,) = pm.markets(1);
        assertEq(outcomeYes, 1000);
    }

    function test_BetRevertsAfterDeadline() public {
        uint256 id = _createMarket();

        vm.warp(DEADLINE + 1);

        vm.prank(alice);
        vm.expectRevert("betting closed");
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);
    }

    function test_ResolveYes() public {
        uint256 id = _createMarket();

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, true);

        (,,,, PredictionMarket.MarketStatus status, bool result,) = pm.markets(1);
        assertEq(uint8(status), uint8(PredictionMarket.MarketStatus.Resolved));
        assertEq(result, true);
    }

    function test_ClaimReward() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.prank(bob);
        pm.bet(id, PredictionMarket.Outcome.NO, 500);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, true);

        uint256 balanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(id);
        uint256 balanceAfter = token.balanceOf(alice);

        // reward = 1000 (stake) + (1000 * (500 - 10)) / 1000 = 1000 + 490 = 1490
        assertEq(balanceAfter - balanceBefore, 1490);
        assertTrue(pm.claimed(id, alice));
    }

    function test_ClaimRevertsBeforeResolve() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.expectRevert("not resolved");
        pm.claimReward(id);
    }

    function test_MultipleBets() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.prank(bob);
        pm.bet(id, PredictionMarket.Outcome.NO, 500);

        assertEq(pm.sharesYes(id, alice), 1000);
        assertEq(pm.sharesNo(id, bob), 500);
        assertEq(pm.sharesYes(id, bob), 0);
        assertEq(pm.sharesNo(id, alice), 0);

        (, uint128 outcomeYes, uint128 outcomeNo,,,,) = pm.markets(1);
        assertEq(outcomeYes, 1000);
        assertEq(outcomeNo, 500);
    }

    function test_DefaultFee() public {
        assertEq(pm.defaultFeeBps(), 200);
    }

    function test_SetMarketFee() public {
        uint256 id = _createMarket(50);

        (,,,,,, uint16 feeBps) = pm.markets(id);
        assertEq(feeBps, 50);
    }

    function test_FeeCollected() public {
        uint256 id = _createMarket(200);

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.prank(bob);
        pm.bet(id, PredictionMarket.Outcome.NO, 500);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, true);

        uint256 feeCollectorBefore = token.balanceOf(feeCollector);
        vm.prank(alice);
        pm.claimReward(id);
        uint256 feeCollectorAfter = token.balanceOf(feeCollector);
        uint256 feeCollected = feeCollectorAfter - feeCollectorBefore;

        // fee = losingPool * feeBps / 10000 = 500 * 200 / 10000 = 10
        assertEq(feeCollected, 10);
    }

    function test_OnlyOwnerCreate() public {
        vm.prank(alice);
        vm.expectRevert("unauthorized");
        pm.createMarket(QUESTION, DEADLINE, 200);
    }

    function test_MarketCreatorCanCreate() public {
        pm.setMarketCreator(bob, true);

        vm.prank(bob);
        pm.createMarket(QUESTION, DEADLINE, 200);

        assertEq(pm.marketCount(), 1);
        assertTrue(pm.marketCreators(bob));
    }

    function test_MarketCreatorRemovedCannotCreate() public {
        pm.setMarketCreator(bob, true);
        pm.setMarketCreator(bob, false);
        assertFalse(pm.marketCreators(bob));

        vm.prank(bob);
        vm.expectRevert("unauthorized");
        pm.createMarket(QUESTION, DEADLINE, 200);
    }

    function test_SetMarketCreatorOnlyOwner() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        pm.setMarketCreator(alice, true);
        assertFalse(pm.marketCreators(alice));
    }

    // ======== resetMarketCount (admin purge) ========

    function _threeMarkets() internal {
        pm.createMarket(QUESTION, DEADLINE, 200);         // id 1
        pm.createMarket("Q2", DEADLINE, 200);             // id 2
        pm.createMarket("Q3", DEADLINE, 200);             // id 3
    }

    function test_ResetMarketCountToZeroPurgesStructs() public {
        _threeMarkets();
        assertEq(pm.marketCount(), 3);

        pm.resetMarketCount(0);

        assertEq(pm.marketCount(), 0);
        (string memory q,,,,,,) = pm.markets(1);
        assertEq(q, "");
        (string memory q2,,,,,,) = pm.markets(3);
        assertEq(q2, "");
    }

    function test_ResetMarketCountToZeroAllowsRebuildFromId1() public {
        _threeMarkets();
        pm.resetMarketCount(0);

        pm.createMarket(QUESTION, DEADLINE, 200);
        assertEq(pm.marketCount(), 1);

        (string memory q,,,,, bool result,) = pm.markets(1);
        assertEq(q, QUESTION);
        assertEq(pm.marketCount(), 1);
        assertEq(result, false);
    }

    function test_ResetMarketCountPartial() public {
        _threeMarkets();
        // remove only market 3
        pm.resetMarketCount(2);
        assertEq(pm.marketCount(), 2);

        (string memory q1,,,,,,) = pm.markets(1);
        assertEq(q1, QUESTION);
        (string memory q3,,,,,,) = pm.markets(3);
        assertEq(q3, "");

        // reuse id 3
        pm.createMarket("Q3new", DEADLINE, 200);
        assertEq(pm.marketCount(), 3);
        (string memory q3new,,,,,,) = pm.markets(3);
        assertEq(q3new, "Q3new");
    }

    function test_ResetMarketCountClearsStructTotals() public {
        uint256 id = _createMarket();
        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        (, uint128 outcomeYes,,,,,) = pm.markets(id);
        assertEq(outcomeYes, 1000);

        pm.resetMarketCount(0);

        // struct totals cleared with the market struct
        (, uint128 oy,,,,,) = pm.markets(id);
        assertEq(oy, 0);
        assertEq(pm.marketCount(), 0);
    }

    function test_ReusedIdGetsFreshStruct() public {
        uint256 id = _createMarket();
        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        pm.resetMarketCount(0);

        pm.createMarket("Fresh", DEADLINE, 200);
        assertEq(pm.marketCount(), 1);
        (string memory q, uint128 oy,,,,,) = pm.markets(1);
        assertEq(q, "Fresh");
        assertEq(oy, 0);
    }

    function test_ResetMarketCountOnlyOwner() public {
        _threeMarkets();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        pm.resetMarketCount(0);
    }

    function test_ResetMarketCountCannotIncrease() public {
        _threeMarkets();
        vm.expectRevert("cannot increase");
        pm.resetMarketCount(5);
    }

    // ======== 单边市场结算（修复：空边获胜时退款，不锁死资金）=======

    /// 只有 YES 下注、NO 无人下注，且结果 = NO（空边"赢"）：
    /// 没有真正的赢家，应全额退回下注者本金，不能锁死在合约里。
    function test_RefundWhenEmptySideWins_YesOnly() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, false); // NO 赢，但 NO 边无人下注

        uint256 balPre = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(id);
        uint256 balPost = token.balanceOf(alice);

        // 全额退款，无收益
        assertEq(balPost - balPre, 1000);
        // 平台不抽取手续费
        assertEq(token.balanceOf(feeCollector), 0);
        // 合约内不残留资金
        assertEq(token.balanceOf(address(pm)), 0);
    }

    /// 对称：只有 NO 下注、YES 无人下注，且结果 = YES（空边"赢"）。
    function test_RefundWhenEmptySideWins_NoOnly() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.NO, 750);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, true); // YES 赢，但 YES 边无人下注

        uint256 balPre = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(id);
        uint256 balPost = token.balanceOf(alice);

        assertEq(balPost - balPre, 750);
        assertEq(token.balanceOf(feeCollector), 0);
        assertEq(token.balanceOf(address(pm)), 0);
    }

    /// 单边市场、有下注的一边获胜：下注者拿回本金（无败池可分，无收益）。
    function test_SingleSide_OwnSideWins_ReturnsPrincipalOnly() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, true); // YES 赢，正是有下注的一边

        uint256 balPre = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(id);
        uint256 balPost = token.balanceOf(alice);

        assertEq(balPost - balPre, 1000); // 本金，无收益
        assertEq(token.balanceOf(address(pm)), 0);
    }

    /// 双人分摊时的退款：每人按自己的下注额全额退回。
    function test_RefundEmptySide_DistributesToAllBettors() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 600);
        vm.prank(bob);
        pm.bet(id, PredictionMarket.Outcome.YES, 400);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, false); // NO 空边赢 -> 退款

        uint256 aPre = token.balanceOf(alice);
        uint256 bPre = token.balanceOf(bob);
        vm.prank(alice);
        pm.claimReward(id);
        vm.prank(bob);
        pm.claimReward(id);
        uint256 aPost = token.balanceOf(alice);
        uint256 bPost = token.balanceOf(bob);

        assertEq(aPost - aPre, 600);
        assertEq(bPost - bPre, 400);
        assertEq(token.balanceOf(address(pm)), 0);
    }

    /// 退款后二次领取应被禁止（claimed 标记生效）。
    function test_RefundCannotClaimTwice() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, false);

        vm.prank(alice);
        pm.claimReward(id);

        vm.prank(alice);
        vm.expectRevert("already claimed");
        pm.claimReward(id);
    }

    /// 没有下注的地址在退款场景下不应能领走资金。
    function test_Refund_NonBettorGetsNothing() public {
        uint256 id = _createMarket();

        vm.prank(alice);
        pm.bet(id, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);
        pm.resolveMarket(id, false);

        address carol = address(0x4);
        vm.prank(carol);
        vm.expectRevert("no winnings");
        pm.claimReward(id);
    }
}

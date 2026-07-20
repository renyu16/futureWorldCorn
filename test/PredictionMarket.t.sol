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
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        pm.createMarket(QUESTION, DEADLINE, 200);
    }
}

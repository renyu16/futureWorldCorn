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
        // 1. Create market
        pm.createMarket(QUESTION, DEADLINE, 200);
        uint256 marketId = pm.marketCount();
        assertEq(marketId, 1);

        // 2. Alice bets YES (1000 tokens)
        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);
        assertEq(pm.sharesYes(marketId, alice), 1000);

        // 3. Bob bets NO (500 tokens)
        vm.prank(bob);
        pm.bet(marketId, PredictionMarket.Outcome.NO, 500);
        assertEq(pm.sharesNo(marketId, bob), 500);

        // Verify pool totals
        (, uint128 outcomeYes, uint128 outcomeNo,,,) = pm.markets(marketId);
        assertEq(outcomeYes, 1000);
        assertEq(outcomeNo, 500);

        // 4. Fast-forward past deadline
        vm.warp(DEADLINE + 1);

        // 5. Resolve as YES
        pm.resolveMarket(marketId, true);
        (,,,, PredictionMarket.MarketStatus status, bool result,) = pm.markets(marketId);
        assertEq(uint8(status), uint8(PredictionMarket.MarketStatus.Resolved));
        assertEq(result, true);

        // 6. Alice claims reward
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        vm.prank(alice);
        pm.claimReward(marketId);
        uint256 aliceReward = token.balanceOf(alice) - aliceBalanceBefore;

        // Expected: 1000 (stake) + (1000 * (500 - 10)) / 1000 = 1490
        assertEq(aliceReward, 1490);

        // 7. Bob tries to claim — reverts (no winning shares)
        vm.prank(bob);
        vm.expectRevert("no winnings");
        pm.claimReward(marketId);

        // 8. Verify fee collected
        uint256 feeBalance = token.balanceOf(feeCollector);
        assertEq(feeBalance, 10); // 500 * 200 / 10000 = 10

        // 9. Verify contract has no leftover tokens
        assertEq(token.balanceOf(address(pm)), 0);
    }

    function test_ResolutionViaOraclePush() public {
        // Integration with OracleAdapter
        // 1. Create market, deploy OracleAdapter
        pm.createMarket(QUESTION, DEADLINE, 200);
        uint256 marketId = pm.marketCount();

        address keeper = address(0x42);
        OracleAdapter adapter = new OracleAdapter(address(pm), keeper);
        pm.setResolver(address(adapter), true);

        // 2. Alice bets YES
        vm.prank(alice);
        pm.bet(marketId, PredictionMarket.Outcome.YES, 1000);

        vm.warp(DEADLINE + 1);

        // 3. Keeper resolves via push
        vm.prank(keeper);
        adapter.pushResult(marketId, true);

        // 4. Verify resolved
        (,,,, PredictionMarket.MarketStatus status,,) = pm.markets(marketId);
        assertEq(uint8(status), uint8(PredictionMarket.MarketStatus.Resolved));

        // 5. Alice claims
        vm.prank(alice);
        pm.claimReward(marketId);
        assertEq(token.balanceOf(alice), 10_000 ether);
    }
}

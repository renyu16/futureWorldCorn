// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "../src/OracleAdapter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockAggregator {
    int256 private _price;

    function setPrice(int256 price) external { _price = price; }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _price, 0, 0, 0);
    }
    function decimals() external view returns (uint8) { return 8; }
    function description() external view returns (string memory) { return "mock"; }
    function version() external view returns (uint256) { return 1; }
    function getRoundData(uint80) external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _price, 0, 0, 0);
    }
}

contract OracleAdapterTest is Test {
    CornToken token;
    PredictionMarket pm;
    OracleAdapter adapter;
    MockAggregator aggregator;
    address keeper = address(0x42);
    address feeCollector = address(0x3);
    address alice = address(0x1);
    uint256 marketId;
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
        aggregator = new MockAggregator();

        pm.createMarket(QUESTION, DEADLINE, 200);
        marketId = pm.marketCount();

        adapter = new OracleAdapter(address(pm), keeper);
        pm.setResolver(address(adapter), true);
    }

    function test_ResolveViaDataFeed() public {
        aggregator.setPrice(15000);
        vm.prank(keeper);
        adapter.configureFeed(marketId, address(aggregator), 10000, true);

        vm.warp(DEADLINE + 1);
        vm.prank(keeper);
        adapter.resolveWithFeed(marketId);

        (,,,, PredictionMarket.MarketStatus status, bool result,) = pm.markets(marketId);
        assertEq(uint8(status), uint8(PredictionMarket.MarketStatus.Resolved));
        assertEq(result, true);
    }

    function test_ResolveViaPush() public {
        vm.warp(DEADLINE + 1);
        vm.prank(keeper);
        adapter.pushResult(marketId, true);

        (,,,, PredictionMarket.MarketStatus status, bool result,) = pm.markets(marketId);
        assertEq(uint8(status), uint8(PredictionMarket.MarketStatus.Resolved));
        assertEq(result, true);
    }

    function test_ResolveUnauthorized() public {
        vm.warp(DEADLINE + 1);
        vm.prank(alice);
        vm.expectRevert("not keeper");
        adapter.pushResult(marketId, true);
    }
}

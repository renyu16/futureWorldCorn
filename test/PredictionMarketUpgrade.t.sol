// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PredictionMarketV2 is PredictionMarket {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function version() external pure returns (string memory) {
        return "v2";
    }
}

contract PredictionMarketUpgradeTest is Test {
    CornToken token;
    PredictionMarket implementation;
    PredictionMarket proxy;
    PredictionMarket wrapped;
    address feeCollector = address(0x3);

    function setUp() public {
        token = new CornToken();
        implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(token),
            feeCollector,
            address(this)
        );
        ERC1967Proxy erc1967Proxy = new ERC1967Proxy(address(implementation), initData);
        proxy = PredictionMarket(address(erc1967Proxy));
        wrapped = PredictionMarket(address(erc1967Proxy));
    }

    function test_ProxyInitialized() public {
        assertEq(address(wrapped.token()), address(token));
        assertEq(wrapped.feeCollector(), feeCollector);
        assertEq(wrapped.defaultFeeBps(), 200);
    }

    function test_ProxyMarketCreation() public {
        wrapped.createMarket("test?", 1_000_000, 200);
        assertEq(wrapped.marketCount(), 1);
    }

    function test_Upgrade() public {
        PredictionMarketV2 implV2 = new PredictionMarketV2();
        wrapped.upgradeToAndCall(address(implV2), "");
        PredictionMarketV2 upgraded = PredictionMarketV2(address(wrapped));
        assertEq(address(upgraded.token()), address(token));
        assertEq(upgraded.feeCollector(), feeCollector);
    }
}

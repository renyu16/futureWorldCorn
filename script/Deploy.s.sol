// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "../src/OracleAdapter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Deploy is Script {
    CornToken public token;
    PredictionMarket public market;
    OracleAdapter public adapter;
    address public feeCollector;
    address public keeper;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        feeCollector = vm.envOr("FEE_COLLECTOR", deployer);
        keeper = vm.envOr("KEEPER", deployer);

        vm.startBroadcast(deployerKey);

        token = new CornToken();

        PredictionMarket implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(token),
            feeCollector,
            deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        market = PredictionMarket(address(proxy));

        adapter = new OracleAdapter(address(market), keeper);
        market.setResolver(address(adapter), true);

        vm.stopBroadcast();
    }
}

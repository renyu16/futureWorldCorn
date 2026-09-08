// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";

/// @dev Grant marketCreator role to a dev address on the live proxy.
///   forge script script/GrantMarketCreator.s.sol:GrantMarketCreator --rpc-url $RPC_URL --private-key $PK --broadcast
///   Env: MARKET_PROXY, MARKET_CREATOR
contract GrantMarketCreator is Script {
    function run() external {
        uint256 pk = vm.envUint("GRANT_PK");
        address proxy = vm.envAddress("MARKET_PROXY");
        address creator = vm.envAddress("MARKET_CREATOR");

        vm.startBroadcast(pk);
        PredictionMarket(payable(proxy)).setMarketCreator(creator, true);
        vm.stopBroadcast();

        console2.log("marketCreator granted:", creator);
    }
}
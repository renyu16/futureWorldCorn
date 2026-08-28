// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";
import "../src/TokenHouse.sol";

contract CreateProposal is Script {
    address constant MARKET = 0x9Cb69cb7DA9677B3A122A6a4E402398a6DF4a026;
    address constant TOKEN_HOUSE = 0x70Edf96015fE901c44b6b61Ad5CcB9884B545DE9;

    function run() external {
        uint256 aiDevAKey = vm.envUint("AI_DEV_A_PRIVATE_KEY");

        vm.startBroadcast(aiDevAKey);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = MARKET;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("setDefaultFee(uint16)", 150);

        TokenHouse(payable(TOKEN_HOUSE)).propose(
            targets, values, calldatas, unicode"提案：将市场默认手续费从2%降低到1.5%"
        );

        vm.stopBroadcast();
        console.log("Proposal created");
    }
}

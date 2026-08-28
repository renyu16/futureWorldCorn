// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/CornToken.sol";
import "../src/PredictionMarket.sol";
import "../src/OracleAdapter.sol";
import "../src/GovCrownToken.sol";
import "../src/TokenHouse.sol";
import "../src/HumanHouse.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address feeCollector = vm.envOr("FEE_COLLECTOR", deployer);
        address keeper = vm.envOr("KEEPER", deployer);
        address safeAddress = vm.envAddress("SAFE_ADDRESS");
        address worldIdRouter = vm.envAddress("WORLD_ID_ROUTER_ADDRESS");
        string memory appId = vm.envString("WORLD_ID_APP_ID");
        string memory actionId = vm.envOr("WORLD_ID_ACTION_ID", string("human_house_vote"));
        uint256 disputeDeposit = vm.envOr("DISPUTE_DEPOSIT", uint256(1000e18));

        vm.startBroadcast(deployerKey);

        // Phase 1: Core contracts
        CornToken token = new CornToken();
        PredictionMarket implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(token),
            feeCollector,
            deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        PredictionMarket market = PredictionMarket(address(proxy));
        OracleAdapter adapter = new OracleAdapter(address(market), keeper);
        market.setResolver(address(adapter), true);

        // Phase 2: Governance (keep admin with deployer)
        GovCrownToken govCorn = new GovCrownToken(IERC20(address(token)));
        address[] memory proposers = new address[](1);
        proposers[0] = safeAddress;
        TimelockController timelock = new TimelockController(
            2 days, proposers, new address[](0), deployer
        );
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        // NOTE: deployer keeps DEFAULT_ADMIN_ROLE for Phase 3 deployment

        // Phase 3: Houses
        TokenHouse tokenHouse = new TokenHouse(IVotes(address(govCorn)), timelock);
        HumanHouse humanHouse = new HumanHouse(
            address(token),
            address(market),
            disputeDeposit,
            IWorldID(worldIdRouter),
            appId,
            actionId
        );

        // Grant proposer roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(humanHouse));

        // Transfer core ownership to timelock
        market.transferOwnership(address(timelock));
        token.transferOwnership(address(timelock));

        // Revoke deployer admin after everything is set up
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();
    }
}

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
    struct Cfg {
        address deployer;
        address feeCollector;
        address keeper;
        address safeAddress;
        address worldIdRouter;
        uint256 disputeDeposit;
        string appId;
        string actionId;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        Cfg memory cfg = _readCfg();
        vm.startBroadcast(deployerKey);
        _deployAll(cfg);
        vm.stopBroadcast();
    }

    function _readCfg() internal returns (Cfg memory cfg) {
        cfg.deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        cfg.feeCollector = vm.envOr("FEE_COLLECTOR", cfg.deployer);
        cfg.keeper = vm.envOr("KEEPER", cfg.deployer);
        cfg.safeAddress = vm.envAddress("SAFE_ADDRESS");
        cfg.worldIdRouter = vm.envAddress("WORLD_ID_ROUTER_ADDRESS");
        cfg.disputeDeposit = vm.envOr("DISPUTE_DEPOSIT", uint256(1000e18));
        cfg.appId = vm.envString("WORLD_ID_APP_ID");
        cfg.actionId = vm.envOr("WORLD_ID_ACTION_ID", string("human_house_vote"));
    }

    function _deployAll(Cfg memory cfg) internal {
        (CornToken token, PredictionMarket market) = _deployCore(cfg);
        GovCrownToken govCorn = _deployGovernance(token, cfg);
        TimelockController timelock = _createTimelock(cfg);
        TokenHouse tokenHouse = new TokenHouse(IVotes(address(govCorn)), timelock);
        HumanHouse humanHouse = new HumanHouse(
            address(token),
            address(market),
            cfg.disputeDeposit,
            IWorldID(cfg.worldIdRouter),
            cfg.appId,
            cfg.actionId
        );
        _finalize(token, market, timelock, tokenHouse, humanHouse, cfg);
    }

    function _deployCore(Cfg memory cfg)
        internal
        returns (CornToken token, PredictionMarket market)
    {
        token = new CornToken();
        PredictionMarket implementation = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(token),
            cfg.feeCollector,
            cfg.deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        market = PredictionMarket(address(proxy));
        OracleAdapter adapter = new OracleAdapter(address(market), cfg.keeper);
        market.setResolver(address(adapter), true);
    }

    function _deployGovernance(CornToken token, Cfg memory cfg)
        internal
        returns (GovCrownToken govCorn)
    {
        govCorn = new GovCrownToken(IERC20(address(token)));
    }

    function _createTimelock(Cfg memory cfg) internal returns (TimelockController timelock) {
        address[] memory proposers = new address[](1);
        proposers[0] = cfg.safeAddress;
        timelock = new TimelockController(2 days, proposers, new address[](0), cfg.deployer);
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        // NOTE: deployer keeps DEFAULT_ADMIN_ROLE; revoked in _finalize
    }

    function _finalize(
        CornToken token,
        PredictionMarket market,
        TimelockController timelock,
        TokenHouse tokenHouse,
        HumanHouse humanHouse,
        Cfg memory cfg
    ) internal {
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(humanHouse));

        market.transferOwnership(address(timelock));
        token.transferOwnership(address(timelock));

        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), cfg.deployer);
    }
}
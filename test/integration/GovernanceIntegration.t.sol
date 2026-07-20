// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/CornToken.sol";
import "../../src/GovCrownToken.sol";
import "../../src/PredictionMarket.sol";
import "../../src/TokenHouse.sol";

contract GovernanceIntegrationTest is Test {
    CornToken corn;
    GovCrownToken govCorn;
    PredictionMarket market;
    TimelockController timelock;
    TokenHouse tokenHouse;

    address admin = address(0x100);
    address alice = address(0x1);
    address feeCollector = address(0x99);
    address newFeeCollector = address(0x98);

    function setUp() public {
        vm.startPrank(admin);

        corn = new CornToken();
        corn.transfer(alice, 1_000_000e18);

        govCorn = new GovCrownToken(corn);

        timelock = new TimelockController(
            2 days,
            new address[](0),
            new address[](0),
            admin
        );

        PredictionMarket impl = new PredictionMarket();
        bytes memory initData = abi.encodeWithSelector(
            PredictionMarket.initialize.selector,
            address(corn), feeCollector, admin
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        market = PredictionMarket(address(proxy));

        tokenHouse = new TokenHouse(IVotes(address(govCorn)), timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(tokenHouse));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        market.transferOwnership(address(timelock));

        vm.stopPrank();

        vm.prank(address(timelock));
        market.acceptOwnership();
    }

    function test_Governance_FullProposalFlow() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500_000e18);
        govCorn.depositFor(alice, 500_000e18);
        govCorn.delegate(alice);
        vm.stopPrank();

        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        targets[0] = address(market);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(market.setFeeCollector.selector, newFeeCollector);
        string memory description = "Change fee collector";
        bytes32 descriptionHash = keccak256(bytes(description));

        uint256 proposalId = tokenHouse.hashProposal(targets, values, calldatas, descriptionHash);

        vm.prank(alice);
        tokenHouse.propose(targets, values, calldatas, description);

        assertEq(uint8(tokenHouse.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        vm.roll(block.number + 2);
        assertEq(uint8(tokenHouse.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        vm.prank(alice);
        tokenHouse.castVote(proposalId, 1);

        vm.roll(block.number + 129600 + 1);
        assertEq(uint8(tokenHouse.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        tokenHouse.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint8(tokenHouse.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 2 days + 1);
        tokenHouse.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint8(tokenHouse.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

        assertEq(market.feeCollector(), newFeeCollector);
    }

    function test_DelegateChain() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(address(0x2));
        vm.stopPrank();

        assertEq(govCorn.getVotes(address(0x2)), 500e18);
        assertEq(govCorn.getVotes(alice), 0);
    }

    function test_ProposalThresholdSnapshot() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(alice);
        vm.stopPrank();

        uint256 totalSupply = govCorn.totalSupply();
        uint256 threshold = tokenHouse.proposalThreshold();
        assertEq(threshold, totalSupply / 100);
        assertTrue(govCorn.getVotes(alice) >= threshold);
    }
}

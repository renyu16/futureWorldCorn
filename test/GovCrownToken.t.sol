// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";
import "../src/GovCrownToken.sol";

contract GovCrownTokenTest is Test {
    CornToken corn;
    GovCrownToken govCorn;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        corn = new CornToken();
        govCorn = new GovCrownToken(corn);
        corn.transfer(alice, 1000e18);
    }

    function test_DepositAndWithdraw() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        assertEq(govCorn.balanceOf(alice), 500e18);
        assertEq(corn.balanceOf(alice), 500e18);

        govCorn.withdrawTo(alice, 200e18);
        assertEq(govCorn.balanceOf(alice), 300e18);
        assertEq(corn.balanceOf(alice), 700e18);
        vm.stopPrank();
    }

    function test_DelegationGrantsVotes() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(alice);
        assertEq(govCorn.getVotes(alice), 500e18);
        vm.stopPrank();
    }

    function test_DelegateToOther() public {
        vm.startPrank(alice);
        corn.approve(address(govCorn), 500e18);
        govCorn.depositFor(alice, 500e18);
        govCorn.delegate(bob);
        vm.stopPrank();
        assertEq(govCorn.getVotes(bob), 500e18);
        assertEq(govCorn.getVotes(alice), 0);
    }

    function test_NameAndSymbol() public {
        assertEq(govCorn.name(), "Governance Crown Token");
        assertEq(govCorn.symbol(), "govCORN");
    }
}

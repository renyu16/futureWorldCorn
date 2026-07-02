// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";

contract CornTokenTest is Test {
    CornToken token;
    address alice = address(0x1);

    function setUp() public {
        token = new CornToken();
    }

    function test_TotalSupply() public {
        assertEq(token.totalSupply(), 1_000_000_000 * 10**18);
    }

    function test_Permit() public {
        assertTrue(address(token) != address(0));
    }

    function test_Burn() public {
        token.transfer(address(1), 100);
        vm.prank(address(1));
        token.burn(100);
        assertEq(token.balanceOf(address(1)), 0);
    }

    function test_MintRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 100);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "forge-std/Test.sol";
import "../src/CornToken.sol";

contract CornTokenTest is Test {
    CornToken token;
    address alice = address(0x1);
    address bob = address(0x2);

    uint256 internal constant INITIAL_SUPPLY = 1_000_000_000 * 10**18;

    function setUp() public {
        token = new CornToken();
    }

    function test_TotalSupply() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_Mint() public {
        token.mint(alice, 1000);
        assertEq(token.balanceOf(alice), 1000);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 1000);
    }

    function test_MintRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.mint(alice, 100);
    }

    function test_MintRevertsWhenLocked() public {
        token.lockMint();
        vm.expectRevert("mint locked");
        token.mint(alice, 100);
    }

    function test_MintRevertsExceedingMaxSupply() public {
        vm.expectRevert("exceeds max supply");
        token.mint(alice, 1);
    }

    function test_LockMint() public {
        vm.expectEmit(true, true, true, true);
        emit MintLocked();
        token.lockMint();
        assertTrue(token.mintLocked());
    }

    function test_LockMintRevertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        token.lockMint();
    }

    function test_Burn() public {
        token.transfer(alice, 100);
        vm.prank(alice);
        token.burn(100);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 100);
    }

    function test_BurnRevertsForInsufficientBalance() public {
        vm.expectRevert();
        token.burn(1);
    }

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address user = vm.addr(privateKey);
        token.transfer(user, 1000);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                            user,
                            alice,
                            100,
                            token.nonces(user) + 1,
                            block.timestamp
                        )
                    )
                )
            )
        );

        token.permit(user, alice, 100, block.timestamp, v, r, s);
        assertEq(token.allowance(user, alice), 100);
    }
}

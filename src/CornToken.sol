// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CornToken is ERC20, ERC20Permit, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    bool public mintLocked;

    event MintLocked();

    constructor() ERC20("CornToken", "CORN") ERC20Permit("CornToken") Ownable(msg.sender) {
        _mint(msg.sender, MAX_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(!mintLocked, "mint locked");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds max supply");
        _mint(to, amount);
    }

    function lockMint() external onlyOwner {
        mintLocked = true;
        emit MintLocked();
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

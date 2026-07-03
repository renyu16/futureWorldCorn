// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Wrapper.sol";

contract GovCrownToken is ERC20Permit, ERC20Votes, ERC20Wrapper {
    constructor(IERC20 _underlying)
        ERC20("Governance Crown Token", "govCORN")
        ERC20Permit("Governance Crown Token")
        ERC20Wrapper(_underlying)
    {
        require(address(_underlying) != address(0), "invalid underlying");
    }

    function _update(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._update(from, to, amount);
    }

    function nonces(address owner)
        public view override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function decimals()
        public view override(ERC20, ERC20Wrapper)
        returns (uint8)
    {
        return ERC20Wrapper.decimals();
    }
}

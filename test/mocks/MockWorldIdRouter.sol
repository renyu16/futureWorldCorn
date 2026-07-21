// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MockWorldIdRouter {
    bool public shouldRevert;
    uint256 public lastNullifierHash;
    uint256 public lastSignalHash;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyProof(
        uint256,
        uint256,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256,
        uint256[8] calldata
    ) external {
        if (shouldRevert) revert("MockWorldId: invalid proof");
        lastNullifierHash = nullifierHash;
        lastSignalHash = signalHash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IWorldID.sol";
import "./interfaces/IPredictionMarket.sol";
import "./libraries/ByteHasher.sol";

contract HumanHouse is Ownable, Pausable {
    using SafeERC20 for IERC20;
    using ByteHasher for bytes;

    enum DisputeType { OracleResult, MarketContent }
    enum DisputeState { Active, Approved, Rejected }

    struct Dispute {
        uint256 marketId;
        DisputeType disputeType;
        DisputeState state;
        address initiator;
        uint256 deposit;
        uint256 deadline;
        string reason;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    IERC20 public cornToken;
    address public predictionMarket;
    uint256 public disputeDeposit;
    uint256 public votingPeriod = 5 days;
    uint256 public disputeCount;

    IWorldID public immutable worldIdRouter;
    uint256 public immutable externalNullifierHash;
    uint256 public constant groupId = 1;

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => mapping(uint256 => bool)) public nullifierUsed;

    event DisputeCreated(uint256 indexed disputeId, uint256 indexed marketId, DisputeType disputeType, string reason);
    event VoteCast(uint256 indexed disputeId, bool support);
    event DisputeExecuted(uint256 indexed disputeId, DisputeState outcome, uint256 votesFor, uint256 votesAgainst);

    constructor(
        address _cornToken,
        address _predictionMarket,
        uint256 _disputeDeposit,
        IWorldID _worldIdRouter,
        string memory _appId,
        string memory _actionId
    )
        Ownable(msg.sender)
    {
        require(_cornToken != address(0), "invalid token");
        require(_predictionMarket != address(0), "invalid market");
        require(address(_worldIdRouter) != address(0), "invalid worldId");
        cornToken = IERC20(_cornToken);
        predictionMarket = _predictionMarket;
        disputeDeposit = _disputeDeposit;
        worldIdRouter = _worldIdRouter;
        externalNullifierHash = abi.encodePacked(
            abi.encodePacked(_appId).hashToField(),
            _actionId
        ).hashToField();
    }

    function raiseDispute(
        uint256 marketId,
        DisputeType disputeType,
        string calldata reason
    ) external whenNotPaused {
        cornToken.safeTransferFrom(msg.sender, address(this), disputeDeposit);

        disputeCount++;
        disputes[disputeCount] = Dispute({
            marketId: marketId,
            disputeType: disputeType,
            state: DisputeState.Active,
            initiator: msg.sender,
            deposit: disputeDeposit,
            deadline: block.timestamp + votingPeriod,
            reason: reason,
            votesFor: 0,
            votesAgainst: 0
        });

        emit DisputeCreated(disputeCount, marketId, disputeType, reason);
    }

    function vote(
        uint256 disputeId,
        bool support,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external whenNotPaused {
        Dispute storage d = disputes[disputeId];
        require(d.state == DisputeState.Active, "not active");
        require(block.timestamp < d.deadline, "voting ended");
        require(!nullifierUsed[disputeId][nullifierHash], "already voted");

        worldIdRouter.verifyProof(
            root,
            groupId,
            abi.encodePacked(msg.sender).hashToField(),
            nullifierHash,
            externalNullifierHash,
            proof
        );

        nullifierUsed[disputeId][nullifierHash] = true;

        if (support) {
            d.votesFor++;
        } else {
            d.votesAgainst++;
        }

        emit VoteCast(disputeId, support);
    }

    function executeDispute(uint256 disputeId) external {
        Dispute storage d = disputes[disputeId];
        require(d.state == DisputeState.Active, "not active");
        require(block.timestamp >= d.deadline, "voting not ended");

        if (d.votesFor > d.votesAgainst) {
            d.state = DisputeState.Approved;
            cornToken.safeTransfer(d.initiator, d.deposit);

            if (d.disputeType == DisputeType.OracleResult) {
                (,,,,, bool currentResult,) = IPredictionMarket(predictionMarket).markets(d.marketId);
                IPredictionMarket(predictionMarket).disputeResolve(d.marketId, !currentResult);
            }
        } else {
            d.state = DisputeState.Rejected;
        }

        emit DisputeExecuted(disputeId, d.state, d.votesFor, d.votesAgainst);
    }

    function setDisputeDeposit(uint256 _deposit) external onlyOwner {
        disputeDeposit = _deposit;
    }

    function setVotingPeriod(uint256 _period) external onlyOwner {
        votingPeriod = _period;
    }

    /// @notice Withdraw forfeited deposits (rejected disputes)
    function withdrawFees() external onlyOwner {
        uint256 balance = cornToken.balanceOf(address(this));
        uint256 activeDeposits = _totalActiveDeposits();
        if (balance > activeDeposits) {
            cornToken.safeTransfer(owner(), balance - activeDeposits);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _totalActiveDeposits() internal view returns (uint256) {
        uint256 total;
        for (uint256 i = 1; i <= disputeCount; i++) {
            if (disputes[i].state == DisputeState.Active) {
                total += disputes[i].deposit;
            }
        }
        return total;
    }
}

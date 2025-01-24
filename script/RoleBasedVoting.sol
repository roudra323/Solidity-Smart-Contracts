// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SecureVoting
 * @author @roudra323
 * @notice This contract provides a secure and decentralized voting system.
 * @dev Implements role-based access control, reentrancy protection, and pausability using OpenZeppelin libraries.
 */
contract SecureVoting is AccessControl, ReentrancyGuard, Pausable {
    /// @notice Role assigned to administrators with special privileges
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role assigned to voters who are allowed to cast votes
    bytes32 private constant VOTER_ROLE = keccak256("VOTER_ROLE");

    /// @notice Role assigned to observers for read-only access
    bytes32 private constant OBSERVER_ROLE = keccak256("OBSERVER_ROLE");

    /**
     * @notice Structure to store proposal details
     */
    struct Proposal {
        string description;
        ///< Proposal description
        uint256 voteCount;
        ///< Number of votes received
        bool active;
    }
    ///< Status of proposal (active/inactive)

    /**
     * @notice Structure to track a voter's voting status
     */
    struct Vote {
        bool hasVoted;
        ///< Whether the voter has voted or not
        uint256 proposalIndex;
    }
    ///< Index of the proposal voted for

    /// @notice List of all proposals
    Proposal[] public proposals;

    /// @notice Mapping to store votes by address
    mapping(address => Vote) public votes;

    /// @notice Voting start timestamp
    uint256 public votingStart;

    /// @notice Voting end timestamp
    uint256 public votingEnd;

    /// @notice Indicates whether the voting has been initialized
    bool public votingInitialized;

    /// @notice Indicates whether there are any proposals
    /// that are pending to be voted on
    bool private isPendingProposals;

    // ========================
    // Events
    // ========================

    /**
     * @notice Emitted when a new proposal is created
     * @param proposalId ID of the created proposal
     * @param description Description of the proposal
     */
    event ProposalCreated(uint256 indexed proposalId, string description);

    /**
     * @notice Emitted when a vote is cast
     * @param voter Address of the voter
     * @param proposalId ID of the proposal voted for
     */
    event VoteCast(address indexed voter, uint256 indexed proposalId);

    /**
     * @notice Emitted when the voting period is set
     * @param start Start time of the voting period
     * @param end End time of the voting period
     */
    event VotingPeriodSet(uint256 start, uint256 end);

    /**
     * @notice Emitted when a voter is added
     * @param voter Address of the voter
     */
    event VoterAdded(address indexed voter);

    /**
     * @notice Emitted when a voter is removed
     * @param voter Address of the voter
     */
    event VoterRemoved(address indexed voter);

    // ========================
    // Modifiers
    // ========================

    /**
     * @dev Ensures that the function is called only during the voting period
     */
    modifier onlyDuringVoting() {
        require(votingInitialized, "Voting not initialized");
        require(block.timestamp >= votingStart, "Voting not started!");
        require(block.timestamp <= votingEnd, "Voting over!");
        _;
    }

    /**
     * @dev Ensures that the function is called only before the voting starts
     */
    modifier onlyBeforeVoting() {
        require(!votingInitialized || block.timestamp < votingStart, "Cannot modify voters after voting starts");
        _;
    }

    // ========================
    // Constructor
    // ========================

    /**
     * @notice Initializes the contract by granting the deployer the admin role
     */
    constructor() {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // ========================
    // External Functions
    // ========================

    /**
     * @notice Initializes the voting period
     * @dev Can only be called by an admin before voting starts
     * @param votingDuration_ Duration of the voting period in seconds
     */
    function initializeVoting(uint256 votingDuration_) external onlyRole(ADMIN_ROLE) {
        require(!isPendingProposals, "A proposal is already pending");
        require(!votingInitialized, "Voting already initialized");
        votingStart = block.timestamp;
        votingEnd = votingStart + votingDuration_;
        votingInitialized = true;
        emit VotingPeriodSet(votingStart, votingEnd);
    }

    /**
     * @notice Creates a new proposal
     * @dev Only callable by an admin
     * @param _description The description of the proposal
     */

    // @Bug admin can create a lot of proposals while other proposals are onborded or not
    function createProposal(string memory _description) external onlyRole(ADMIN_ROLE) {
        require(!isPendingProposals, "A proposal is already pending");
        require(!votingInitialized, "Can't create proposals after voting is initialised");
        proposals.push(Proposal({description: _description, voteCount: 0, active: true}));
        isPendingProposals = true;
        emit ProposalCreated(proposals.length - 1, _description);
    }

    /**
     * @notice Grants voter role to an address
     * @dev Only callable by an admin before voting starts
     * @param _voter Address to be granted voter role
     */
    function addVoter(address _voter) external onlyRole(ADMIN_ROLE) onlyBeforeVoting {
        grantRole(VOTER_ROLE, _voter);
        emit VoterAdded(_voter);
    }

    /**
     * @notice Revokes voter role from an address
     * @dev Only callable by an admin before voting starts
     * @param _voter Address to be revoked voter role
     */
    function removeVoter(address _voter) external onlyRole(ADMIN_ROLE) onlyBeforeVoting {
        revokeRole(VOTER_ROLE, _voter);
        emit VoterRemoved(_voter);
    }

    /**
     * @notice Allows a voter to cast their vote
     * @dev The function uses reentrancy protection and can be paused
     * @param _proposalIndex Index of the proposal to vote for
     */
    function castVote(uint256 _proposalIndex)
        external
        onlyRole(VOTER_ROLE)
        onlyDuringVoting
        whenNotPaused
        nonReentrant
    {
        require(!votes[msg.sender].hasVoted, "Already voted!");
        require(proposals.length > _proposalIndex, "Invalid proposal index");
        require(proposals[_proposalIndex].active, "Proposal not active");

        votes[msg.sender] = Vote({hasVoted: true, proposalIndex: _proposalIndex});

        proposals[_proposalIndex].voteCount++;
        emit VoteCast(msg.sender, _proposalIndex);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ========================
    // Public View Functions
    // ========================

    /**
     * @notice Retrieves the total number of proposals
     * @return The number of proposals
     */
    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    /**
     * @notice Retrieves the details of a specific proposal
     * @param _index Index of the proposal
     * @return description The description of the proposal
     * @return voteCount The number of votes the proposal has received
     * @return active Whether the proposal is active or not
     */
    function getProposal(uint256 _index)
        external
        view
        returns (string memory description, uint256 voteCount, bool active)
    {
        require(_index < proposals.length, "Invalid proposal index");
        Proposal storage proposal = proposals[_index];
        return (proposal.description, proposal.voteCount, proposal.active);
    }

    /**
     * @notice Checks the current voting status
     * @return initialized
     * @return start
     * @return end
     * @return isActive
     */
    function getVotingStatus() external view returns (bool initialized, uint256 start, uint256 end, bool isActive) {
        bool active = votingInitialized && block.timestamp >= votingStart && block.timestamp <= votingEnd;
        return (votingInitialized, votingStart, votingEnd, active);
    }
}

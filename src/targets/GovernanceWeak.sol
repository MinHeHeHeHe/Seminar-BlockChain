// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Weak Governance implementation
// VULNERABILITY: Voting power dựa trên balance tại thời điểm vote
// → Attacker có thể flash loan GOV token để có voting power trong 1 transaction

interface IGovToken {
    function getVotingPower(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract GovernanceWeak {
    IGovToken public govToken;
    
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant QUORUM = 1000000 * 1e18; // 1M tokens
    
    enum ProposalState { Pending, Active, Defeated, Succeeded, Executed, Cancelled }
    
    struct Proposal {
        uint256 id;
        address proposer;
        address target;
        bytes callData;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
    }
    
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, address target, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    constructor(address _govToken) {
        govToken = IGovToken(_govToken);
    }

    function propose(address target, bytes memory callData, string memory description) external returns (uint256) {
        require(govToken.balanceOf(msg.sender) >= 100000 * 1e18, "Insufficient tokens to propose");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.callData = callData;
        proposal.description = description;
        proposal.startBlock = block.number;
        proposal.endBlock = block.number + (VOTING_PERIOD / 12); // Assuming 12s per block
        
        emit ProposalCreated(proposalId, msg.sender, target, description);
        return proposalId;
    }

    // VULNERABILITY: Không check voting power tại thời điểm proposal được tạo
    // → User có thể borrow token trong cùng transaction để vote
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.number <= proposal.endBlock, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        // VULNERABILITY: Check voting power tại thời điểm hiện tại, không phải lúc proposal created
        uint256 votes = govToken.getVotingPower(msg.sender);
        require(votes > 0, "No voting power");
        
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votes);
    }

    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.number > proposal.endBlock, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        
        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Succeeded, "Proposal not succeeded");
        
        proposal.executed = true;
        
        (bool success,) = proposal.target.call(proposal.callData);
        require(success, "Execution failed");
        
        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(msg.sender == proposal.proposer, "Only proposer can cancel");
        require(!proposal.executed, "Already executed");
        
        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        
        if (proposal.cancelled) return ProposalState.Cancelled;
        if (proposal.executed) return ProposalState.Executed;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        
        if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < QUORUM) {
            return ProposalState.Defeated;
        }
        
        return ProposalState.Succeeded;
    }

    function getProposalVotes(uint256 proposalId) external view returns (uint256 forVotes, uint256 againstVotes) {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes);
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
}


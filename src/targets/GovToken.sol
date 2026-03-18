// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// ERC20 Governance Token with voting power based on balance
// Used for GovernanceWeak contract

contract GovToken {
    string public name = "Governance Token";
    string public symbol = "GOV";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Voting power snapshots
    mapping(address => mapping(uint256 => uint256)) public votingPowerAtBlock;
    mapping(address => uint256) public lastSnapshotBlock;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event VotingPowerChanged(address indexed account, uint256 newVotingPower, uint256 blockNumber);

    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");
        
        if (currentAllowance != type(uint256).max) {
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        
        return _transfer(from, to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        
        // Update voting power snapshots
        _updateVotingPower(from);
        _updateVotingPower(to);
        
        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");
        
        totalSupply += amount;
        balanceOf[to] += amount;
        
        _updateVotingPower(to);
        
        emit Transfer(address(0), to, amount);
    }

    function mint(address to, uint256 amount) external {
        // In production, should have access control
        _mint(to, amount);
    }

    function _updateVotingPower(address account) internal {
        votingPowerAtBlock[account][block.number] = balanceOf[account];
        lastSnapshotBlock[account] = block.number;
        emit VotingPowerChanged(account, balanceOf[account], block.number);
    }

    function getVotingPower(address account) external view returns (uint256) {
        return balanceOf[account];
    }

    function getVotingPowerAt(address account, uint256 blockNumber) external view returns (uint256) {
        require(blockNumber <= block.number, "Block not yet mined");
        
        // If no snapshot at exact block, return current balance (simplified)
        uint256 power = votingPowerAtBlock[account][blockNumber];
        if (power == 0 && blockNumber < block.number) {
            // Return balance at last known snapshot before this block
            return balanceOf[account];
        }
        return power;
    }
}


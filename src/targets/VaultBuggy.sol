// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Vault with buggy accounting
// VULNERABILITY: Incorrect share calculation allowing value extraction

import "../interfaces/CommonInterfaces.sol";

contract VaultBuggy {
    address public immutable asset;
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);

    constructor(address _asset) {
        asset = _asset;
    }

    // BUG: Incorrect share calculation on first deposit
    function deposit(uint256 assets) external returns (uint256 sharesAmount) {
        require(assets > 0, "Invalid amount");
        
        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        
        // BUG: Khi totalShares = 0, không mint đúng số shares
        // → Có thể inflate hoặc deflate giá trị shares
        if (totalShares == 0) {
            sharesAmount = assets; // BUG: Nên là assets - MINIMUM_SHARES
        } else {
            uint256 balance = IERC20(asset).balanceOf(address(this));
            // BUG: Sử dụng balance sau transfer, có thể bị manipulate bằng donation
            sharesAmount = (assets * totalShares) / (balance - assets);
        }
        
        shares[msg.sender] += sharesAmount;
        totalShares += sharesAmount;
        
        emit Deposit(msg.sender, assets, sharesAmount);
    }

    // BUG: Withdrawal không check minimum shares
    function withdraw(uint256 sharesAmount) external returns (uint256 assets) {
        require(sharesAmount > 0, "Invalid amount");
        require(shares[msg.sender] >= sharesAmount, "Insufficient shares");
        
        uint256 balance = IERC20(asset).balanceOf(address(this));
        
        // Calculate assets to return
        assets = (sharesAmount * balance) / totalShares;
        
        // BUG: Burn shares trước khi transfer → có thể bị reentrancy
        shares[msg.sender] -= sharesAmount;
        totalShares -= sharesAmount;
        
        IERC20(asset).transfer(msg.sender, assets);
        
        emit Withdraw(msg.sender, assets, sharesAmount);
    }

    // BUG: Ai cũng có thể donate để manipulate share price
    function donateToVault(uint256 amount) external {
        // Donate without getting shares → inflates share price
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function getShareValue(uint256 sharesAmount) external view returns (uint256) {
        if (totalShares == 0) return 0;
        uint256 balance = IERC20(asset).balanceOf(address(this));
        return (sharesAmount * balance) / totalShares;
    }

    function totalAssets() external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}

// Fixed version
contract VaultFixed {
    address public immutable asset;
    uint256 public totalShares;
    mapping(address => uint256) public shares;
    
    uint256 private constant MINIMUM_SHARES = 1000;
    uint256 private locked = 1;
    
    modifier nonReentrant() {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }
    
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);

    constructor(address _asset) {
        asset = _asset;
    }

    function deposit(uint256 assets) external nonReentrant returns (uint256 sharesAmount) {
        require(assets > 0, "Invalid amount");
        
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        
        IERC20(asset).transferFrom(msg.sender, address(this), assets);
        
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        uint256 actualDeposit = balanceAfter - balanceBefore;
        
        if (totalShares == 0) {
            sharesAmount = actualDeposit - MINIMUM_SHARES;
            // Burn minimum shares to dead address
            shares[address(0)] = MINIMUM_SHARES;
            totalShares = actualDeposit;
        } else {
            // Use balance before deposit for calculation
            sharesAmount = (actualDeposit * totalShares) / balanceBefore;
        }
        
        require(sharesAmount > 0, "Insufficient shares minted");
        
        shares[msg.sender] += sharesAmount;
        
        emit Deposit(msg.sender, actualDeposit, sharesAmount);
    }

    function withdraw(uint256 sharesAmount) external nonReentrant returns (uint256 assets) {
        require(sharesAmount > 0, "Invalid amount");
        require(shares[msg.sender] >= sharesAmount, "Insufficient shares");
        
        uint256 balance = IERC20(asset).balanceOf(address(this));
        assets = (sharesAmount * balance) / totalShares;
        
        require(assets > 0, "Insufficient assets");
        
        shares[msg.sender] -= sharesAmount;
        totalShares -= sharesAmount;
        
        IERC20(asset).transfer(msg.sender, assets);
        
        emit Withdraw(msg.sender, assets, sharesAmount);
    }

    function getShareValue(uint256 sharesAmount) external view returns (uint256) {
        if (totalShares == 0) return 0;
        uint256 balance = IERC20(asset).balanceOf(address(this));
        return (sharesAmount * balance) / totalShares;
    }

    function totalAssets() external view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }
}


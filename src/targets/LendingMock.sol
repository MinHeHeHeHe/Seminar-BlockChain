// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Simple Lending Protocol sử dụng Oracle để tính collateral
// VULNERABILITY: Nếu dùng OracleSpot → có thể bị manipulate để borrow quá nhiều

import "../interfaces/CommonInterfaces.sol";

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract LendingMock {
    IOracle public oracle;
    
    // Collateral factor: 150% (cần $150 collateral để borrow $100)
    uint256 public constant COLLATERAL_FACTOR = 8000; // 80%
    uint256 public constant FACTOR_DENOMINATOR = 10000;
    
    // Interest rate: 5% APR (simplified, no compounding in this demo)
    uint256 public constant INTEREST_RATE = 500; // 5%
    uint256 public constant RATE_DENOMINATOR = 10000;
    
    address public collateralToken;
    address public borrowToken;
    
    struct Position {
        uint256 collateral;
        uint256 borrowed;
        uint256 lastUpdate;
    }
    
    mapping(address => Position) public positions;
    
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 collateralSeized);

    constructor(address _oracle, address _collateralToken, address _borrowToken) {
        oracle = IOracle(_oracle);
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        
        Position storage pos = positions[msg.sender];
        pos.collateral += amount;
        pos.lastUpdate = block.timestamp;
        
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        Position storage pos = positions[msg.sender];
        require(pos.collateral >= amount, "Insufficient collateral");
        
        pos.collateral -= amount;
        
        // Check health factor after withdrawal
        require(_isHealthy(msg.sender), "Position unhealthy");
        
        IERC20(collateralToken).transfer(msg.sender, amount);
        
        emit Withdraw(msg.sender, amount);
    }

    // VULNERABILITY: Sử dụng oracle.getPrice() trong cùng transaction
    // → Nếu oracle là OracleSpot, có thể manipulate trong cùng tx
    function borrow(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        
        Position storage pos = positions[msg.sender];
        pos.borrowed += amount;
        pos.lastUpdate = block.timestamp;
        
        // Check if user can borrow this amount
        // require(_isHealthy(msg.sender), "Insufficient collateral");
        
        IERC20(borrowToken).transfer(msg.sender, amount);
        
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        Position storage pos = positions[msg.sender];
        require(pos.borrowed >= amount, "Repay too much");
        
        IERC20(borrowToken).transferFrom(msg.sender, address(this), amount);
        
        pos.borrowed -= amount;
        pos.lastUpdate = block.timestamp;
        
        emit Repay(msg.sender, amount);
    }

    function liquidate(address user) external {
        require(!_isHealthy(user), "Position is healthy");
        
        Position storage pos = positions[user];
        uint256 collateralToSeize = pos.collateral;
        uint256 debtToCover = pos.borrowed;
        
        // Transfer debt from liquidator
        IERC20(borrowToken).transferFrom(msg.sender, address(this), debtToCover);
        
        // Transfer collateral to liquidator (with liquidation bonus)
        IERC20(collateralToken).transfer(msg.sender, collateralToSeize);
        
        // Clear position
        pos.collateral = 0;
        pos.borrowed = 0;
        
        emit Liquidate(msg.sender, user, collateralToSeize);
    }

    function _isHealthy(address user) internal view returns (bool) {
        Position memory pos = positions[user];
        if (pos.borrowed == 0) return true;
        
        // Get collateral value in terms of borrow token
        uint256 collateralPrice = oracle.getPrice(collateralToken);
        uint256 collateralValue = (pos.collateral * collateralPrice) / 1e18;
        
        // Required collateral = borrowed * COLLATERAL_FACTOR / FACTOR_DENOMINATOR
        uint256 requiredCollateral = (pos.borrowed * COLLATERAL_FACTOR) / FACTOR_DENOMINATOR;
        
        return collateralValue >= requiredCollateral;
    }

    function getPosition(address user) external view returns (uint256 collateral, uint256 borrowed, bool healthy) {
        Position memory pos = positions[user];
        collateral = pos.collateral;
        borrowed = pos.borrowed;
        healthy = _isHealthy(user);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.borrowed == 0) return type(uint256).max;
        
        uint256 collateralPrice = oracle.getPrice(collateralToken);
        uint256 collateralValue = (pos.collateral * collateralPrice) / 1e18;
        
        // Health factor = collateralValue / borrowed (in percentage)
        return (collateralValue * FACTOR_DENOMINATOR) / pos.borrowed;
    }

    function updateOracle(address newOracle) external {
        // In production, this should have access control
        oracle = IOracle(newOracle);
    }

    // For testing: fund the lending pool
    function fundPool(uint256 amount) external {
        IERC20(borrowToken).transferFrom(msg.sender, address(this), amount);
    }
}


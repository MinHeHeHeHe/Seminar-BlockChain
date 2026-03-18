// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Curve-like StableSwap với tham số A (amplification coefficient)
// Version này có bug trong tính toán (để demo)

import "../interfaces/CommonInterfaces.sol";

contract StablePoolBuggy {
    uint256 public constant A = 100; // Amplification coefficient
    uint256 public constant FEE = 4; // 0.04%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    address public immutable token0;
    address public immutable token1;
    
    uint256 public balance0;
    uint256 public balance1;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    event AddLiquidity(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, address tokenIn);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    // BUG: Không cập nhật balances đúng cách → có thể bị exploit
    function addLiquidity(uint256 amount0, uint256 amount1) external returns (uint256 liquidity) {
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");
        
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        
        if (totalSupply == 0) {
            liquidity = amount0 + amount1; // Initial liquidity
        } else {
            // BUG: Không kiểm tra tỉ lệ đúng
            liquidity = (amount0 * totalSupply) / balance0;
        }
        
        // BUG: Cập nhật sau khi mint → có thể bị reentrancy
        balance0 += amount0;
        balance1 += amount1;
        totalSupply += liquidity;
        balanceOf[msg.sender] += liquidity;
        
        emit AddLiquidity(msg.sender, amount0, amount1, liquidity);
    }

    // BUG: Tính toán D (invariant) không chính xác
    function getD(uint256 _balance0, uint256 _balance1) public pure returns (uint256) {
        // Simplified Curve formula (buggy version)
        uint256 sum = _balance0 + _balance1;
        // BUG: Công thức sai → có thể bị manipulate
        return sum;
    }

    function getY(uint256 x, uint256 D) public pure returns (uint256) {
        // BUG: Simplified calculation, không theo đúng Curve formula
        return D - x;
    }

    // BUG: Swap không kiểm tra slippage đúng
    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");
        require(amountIn > 0, "Invalid amount");
        
        bool isToken0 = tokenIn == token0;
        address tokenOut = isToken0 ? token1 : token0;
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        uint256 D = getD(balance0, balance1);
        uint256 newBalanceIn = (isToken0 ? balance0 : balance1) + amountIn;
        uint256 newBalanceOut = getY(newBalanceIn, D);
        uint256 currentBalanceOut = isToken0 ? balance1 : balance0;
        
        // BUG: Tính toán amount out sai
        amountOut = currentBalanceOut - newBalanceOut;
        uint256 fee = (amountOut * FEE) / FEE_DENOMINATOR;
        amountOut -= fee;
        
        require(amountOut >= minAmountOut, "Slippage too high");
        
        // BUG: Cập nhật balances trước khi transfer → có thể bị reentrancy
        if (isToken0) {
            balance0 = newBalanceIn;
            balance1 = newBalanceOut;
        } else {
            balance1 = newBalanceIn;
            balance0 = newBalanceOut;
        }
        
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        emit Swap(msg.sender, amountIn, amountOut, tokenIn);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amount0, uint256 amount1) {
        require(liquidity > 0, "Invalid liquidity");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");
        
        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;
        
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        balance0 -= amount0;
        balance1 -= amount1;
        
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);
        
        emit RemoveLiquidity(msg.sender, amount0, amount1, liquidity);
    }
}

// Fixed version - Correct implementation
contract StablePoolFixed {
    uint256 public constant A = 100;
    uint256 public constant FEE = 4;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 private constant PRECISION = 1e18;
    
    address public immutable token0;
    address public immutable token1;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    uint256 private locked = 1;
    modifier nonReentrant() {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    event AddLiquidity(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed trader, uint256 amountIn, uint256 amountOut, address tokenIn);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function getBalances() public view returns (uint256, uint256) {
        return (IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function addLiquidity(uint256 amount0, uint256 amount1) external nonReentrant returns (uint256 liquidity) {
        require(amount0 > 0 && amount1 > 0, "Invalid amounts");
        
        (uint256 balance0Before, uint256 balance1Before) = getBalances();
        
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        
        (uint256 balance0After, uint256 balance1After) = getBalances();
        require(balance0After == balance0Before + amount0, "Transfer failed");
        require(balance1After == balance1Before + amount1, "Transfer failed");
        
        if (totalSupply == 0) {
            liquidity = amount0 + amount1;
        } else {
            uint256 liquidity0 = (amount0 * totalSupply) / balance0Before;
            uint256 liquidity1 = (amount1 * totalSupply) / balance1Before;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        totalSupply += liquidity;
        balanceOf[msg.sender] += liquidity;
        
        emit AddLiquidity(msg.sender, amount0, amount1, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");
        require(amountIn > 0, "Invalid amount");
        
        bool isToken0 = tokenIn == token0;
        address tokenOut = isToken0 ? token1 : token0;
        
        (uint256 balance0, uint256 balance1) = getBalances();
        
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Proper constant product formula with fee
        uint256 balanceIn = isToken0 ? balance0 : balance1;
        uint256 balanceOut = isToken0 ? balance1 : balance0;
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE);
        amountOut = (balanceOut * amountInWithFee) / (balanceIn * FEE_DENOMINATOR + amountInWithFee);
        
        require(amountOut >= minAmountOut, "Slippage too high");
        require(amountOut < balanceOut, "Insufficient liquidity");
        
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        emit Swap(msg.sender, amountIn, amountOut, tokenIn);
    }

    function removeLiquidity(uint256 liquidity) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        require(liquidity > 0, "Invalid liquidity");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");
        
        (uint256 balance0, uint256 balance1) = getBalances();
        
        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;
        
        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");
        
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);
        
        emit RemoveLiquidity(msg.sender, amount0, amount1, liquidity);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Oracle đơn giản đọc spot price từ reserves → DỄ BỊ THAO TÚNG

import "../dex/interfaces/IUniV2Pair.sol";

contract OracleSpot {
    address public immutable pair;
    address public immutable token0;
    address public immutable token1;
    
    event PriceUpdated(uint256 price0, uint256 price1);

    constructor(address _pair) {
        pair = _pair;
        token0 = IUniV2Pair(_pair).token0();
        token1 = IUniV2Pair(_pair).token1();
    }

    // VULNERABILITY: Đọc trực tiếp từ reserves trong cùng 1 transaction
    // → Attacker có thể manipulate price bằng flash loan/swap
    function getPrice(address token) external view returns (uint256) {
        require(token == token0 || token == token1, "Invalid token");
        
        (uint112 reserve0, uint112 reserve1,) = IUniV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "No liquidity");
        
        if (token == token0) {
            // Price of token0 in terms of token1
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            // Price of token1 in terms of token0
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }

    // Alternative: Get price with custom precision
    function getPriceWithPrecision(address token, uint256 precision) external view returns (uint256) {
        require(token == token0 || token == token1, "Invalid token");
        
        (uint112 reserve0, uint112 reserve1,) = IUniV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "No liquidity");
        
        if (token == token0) {
            return (uint256(reserve1) * precision) / uint256(reserve0);
        } else {
            return (uint256(reserve0) * precision) / uint256(reserve1);
        }
    }

    // Get both prices at once
    function getPrices() external view returns (uint256 price0, uint256 price1) {
        (uint112 reserve0, uint112 reserve1,) = IUniV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "No liquidity");
        
        price0 = (uint256(reserve1) * 1e18) / uint256(reserve0);
        price1 = (uint256(reserve0) * 1e18) / uint256(reserve1);
    }

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1) {
        (reserve0, reserve1,) = IUniV2Pair(pair).getReserves();
    }
}


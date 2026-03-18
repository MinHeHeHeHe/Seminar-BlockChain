// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Time-Weighted Average Price Oracle - Chống manipulate bằng cách tính trung bình theo thời gian

import "../dex/interfaces/IUniV2Pair.sol";

contract OracleTWAP {
    address public immutable pair;
    address public immutable token0;
    address public immutable token1;
    
    uint256 public price0Average;
    uint256 public price1Average;
    
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    
    uint256 public constant PERIOD = 10 minutes; // Minimum period for TWAP
    
    event PriceUpdated(uint256 price0Average, uint256 price1Average, uint32 timestamp);

    constructor(address _pair) {
        pair = _pair;
        IUniV2Pair pairContract = IUniV2Pair(_pair);
        token0 = pairContract.token0();
        token1 = pairContract.token1();
        
        price0CumulativeLast = pairContract.price0CumulativeLast();
        price1CumulativeLast = pairContract.price1CumulativeLast();
        (, , blockTimestampLast) = pairContract.getReserves();
    }

    function update() external {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // Ensure at least minimum period has passed
        require(timeElapsed >= PERIOD, "OracleTWAP: PERIOD_NOT_ELAPSED");

        // Calculate average price
        // Note: Price is in UQ112x112 format (fixed point with 112 fractional bits)
        price0Average = (price0Cumulative - price0CumulativeLast) / timeElapsed;
        price1Average = (price1Cumulative - price1CumulativeLast) / timeElapsed;

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
        
        emit PriceUpdated(price0Average, price1Average, blockTimestamp);
    }

    function currentCumulativePrices() public view returns (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) {
        IUniV2Pair pairContract = IUniV2Pair(pair);
        price0Cumulative = pairContract.price0CumulativeLast();
        price1Cumulative = pairContract.price1CumulativeLast();
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast_) = pairContract.getReserves();
        blockTimestamp = uint32(block.timestamp % 2**32);
        
        // If time has elapsed since the last update on the pair, calculate the cumulative price
        if (blockTimestampLast_ != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast_;
            // Price is reserve1/reserve0 (for token0) and reserve0/reserve1 (for token1)
            // UQ112x112 format: multiply by 2^112 before division
            price0Cumulative += uint256((uint224(reserve1) << 112) / reserve0) * timeElapsed;
            price1Cumulative += uint256((uint224(reserve0) << 112) / reserve1) * timeElapsed;
        }
    }

    function getPrice(address token) external view returns (uint256) {
        require(token == token0 || token == token1, "Invalid token");
        
        // Return TWAP in standard 18 decimal format
        // Convert from UQ112x112 to regular number
        if (token == token0) {
            // price0Average is in UQ112x112, divide by 2^112 and multiply by 1e18
            return (price0Average * 1e18) >> 112;
        } else {
            return (price1Average * 1e18) >> 112;
        }
    }

    function getPrices() external view returns (uint256 price0, uint256 price1) {
        price0 = (price0Average * 1e18) >> 112;
        price1 = (price1Average * 1e18) >> 112;
    }

    function canUpdate() public view returns (bool) {
        (, , uint32 blockTimestamp) = currentCumulativePrices();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        return timeElapsed >= PERIOD;
    }

    function timeUntilUpdate() external view returns (uint256) {
        (, , uint32 blockTimestamp) = currentCumulativePrices();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed >= PERIOD) return 0;
        return PERIOD - timeElapsed;
    }
}


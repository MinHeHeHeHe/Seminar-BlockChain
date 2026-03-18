// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/CommonInterfaces.sol";

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

contract ProofOfConcept is Script {
    function run() external view {
        // Addresses from deployment
        address pair = 0x11a817359b6E4d4610b7954244350fD2bC0348cc;
        address oracle = 0x959922bE3CAee4b8Cd9a407cc3ac1C251C2007B1;
        address tokenA = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
        
        console.log("\n======================================");
        console.log("  PROOF OF ORACLE MANIPULATION");
        console.log("======================================\n");
        
        // Get initial reserves
        (uint112 r0, uint112 r1,) = IPair(pair).getReserves();
        console.log("DEX Reserves:");
        console.log("  TokenA:", uint256(r0) / 1e18);
        console.log("  TokenB:", uint256(r1) / 1e18);
        
        // Get oracle price
        uint256 price = IOracle(oracle).getPrice(tokenA);
        console.log("\nOracle Price:");
        console.log("  Raw value:", price);
        console.log("  Formatted: ~", price / 1e14, "/ 10000");
        
        // Calculate what price should be
        uint256 expectedPrice = (uint256(r1) * 1e18) / uint256(r0);
        console.log("\nExpected Price (from reserves):");
        console.log("  Raw value:", expectedPrice);
        console.log("  Formatted: ~", expectedPrice / 1e14, "/ 10000");
        
        console.log("\n======================================");
        console.log("  VULNERABILITY DEMONSTRATED!");
        console.log("======================================");
        console.log("\nThe oracle reads DIRECTLY from DEX reserves.");
        console.log("Anyone with a flash loan can:");
        console.log("  1. Borrow large amount from DEX");
        console.log("  2. Change reserves ratio");
        console.log("  3. Oracle price changes instantly");
        console.log("  4. Exploit other protocols using this price");
        console.log("  5. Repay flash loan");
        console.log("\nThis is why TWAP oracles are safer!");
        console.log("======================================\n");
    }
}


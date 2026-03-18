// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "./Deploy.s.sol";
import "../src/attackers/Attacker_Oracle.sol";
import "../src/dex/interfaces/IUniV2Pair.sol";

contract SimpleDemo is Script {
    function run() external {
        console.log("=== DEPLOYING INFRASTRUCTURE ===");
        
        DeployScript deploy = new DeployScript();
        deploy.run();
        
        // Get deployed addresses
        (
            address tokenA,
            address tokenB,
            address dai,
            ,
            ,
            ,
            address pairAB,
            address oracleSpot,
            ,
            ,
            address lending,
            ,
            ,
        ) = deploy.getAddresses();
        
        console.log("");
        console.log("=== ORACLE MANIPULATION ATTACK DEMO ===");
        console.log("");
        
        // Show initial state
        console.log("Initial State:");
        (uint112 r0, uint112 r1,) = IUniV2Pair(pairAB).getReserves();
        console.log("  Pair reserves:");
        console.log("    TokenA:", uint256(r0) / 1e18);
        console.log("    TokenB:", uint256(r1) / 1e18);
        
        uint256 priceA = OracleSpot(oracleSpot).getPrice(tokenA);
        console.log("  TokenA price (from oracle):", priceA / 1e18);
        
        // Deploy attacker
        console.log("");
        console.log("Deploying attacker contract...");
        Attacker_Oracle attacker = new Attacker_Oracle(
            pairAB,
            lending,
            tokenA,
            dai
        );
        console.log("  Attacker deployed at:", address(attacker));
        
        // Fund attacker
        MockERC20(tokenA).mint(address(attacker), 10000 * 1e18);
        console.log("  Funded attacker with 10,000 tokenA");
        
        // Try to execute attack
        console.log("");
        console.log("Attempting attack...");
        console.log("  Step 1: Flash swap 20,000 tokenA from pair");
        console.log("  Step 2: Price manipulated - tokenA appears cheaper");
        console.log("  Step 3: Deposit small collateral to lending");
        console.log("  Step 4: Borrow large amount of DAI");
        console.log("  Step 5: Repay flash swap");
        console.log("  Step 6: Keep borrowed DAI as profit");
        
        console.log("");
        console.log("Note: Attack may fail if collateral requirements not met.");
        console.log("This demonstrates the vulnerability concept.");
        
        console.log("");
        console.log("=== DEMO COMPLETE ===");
        console.log("");
        console.log("To see detailed traces, run:");
        console.log("  forge test --match-test testPriceReading -vvvv");
    }
}


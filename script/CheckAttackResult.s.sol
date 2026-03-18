// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/CommonInterfaces.sol";

interface ILendingCheck {
    function getPosition(address user) external view returns (uint256 collateral, uint256 borrowed, bool healthy);
}

contract CheckAttackResult is Script {
    function run() external view {
        // Addresses from deployment
        address attacker = 0x09635F643e140090A9A8Dcd712eD6285858ceBef;
        address dai = 0xc3e53F4d16Ae77Db1c982e75a937B9f60FE63690;
        address lending = 0xb7278A61aa25c888815aFC32Ad3cC52fF24fE575;
        address tokenA = 0x67d269191c92Caf3cD7723F116c85e6E9bf55933;
        address tokenB = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        console.log("\n=== ATTACK RESULT VERIFICATION ===\n");
        
        // Check attacker's DAI balance (the profit)
        uint256 attackerDAI = IERC20(dai).balanceOf(attacker);
        console.log("Attacker's DAI Balance (PROFIT):", attackerDAI / 1e18, "DAI");
        
        // Check attacker's initial tokenA
        uint256 attackerTokenA = IERC20(tokenA).balanceOf(attacker);
        console.log("Attacker's TokenA Balance:", attackerTokenA / 1e18, "TokenA");
        
        // Check lending protocol's DAI (should be drained)
        uint256 lendingDAI = IERC20(dai).balanceOf(lending);
        console.log("\nLending Protocol's Remaining DAI:", lendingDAI / 1e18, "DAI");
        
        // Get borrow info from lending
        try ILendingCheck(lending).getPosition(attacker) returns (uint256 collateral, uint256 borrowed, bool healthy) {
            console.log("Attacker's Debt:", borrowed / 1e18, "DAI");
            console.log("Attacker's Collateral:", collateral / 1e18, "TokenA");
            console.log("Position Healthy:", healthy);
        } catch {
            console.log("Could not fetch position information");
        }
        
        console.log("\n=== PROOF OF SUCCESS ===");
        if (attackerDAI > 0) {
            console.log("SUCCESS! Attacker gained", attackerDAI / 1e18, "DAI");
            console.log("This proves the oracle manipulation attack worked!");
        } else {
            console.log("Attack did not succeed or profit was returned");
        }
        
        console.log("\n=== HOW IT WORKED ===");
        console.log("1. Attacker flash borrowed 20,000 TokenA");
        console.log("2. This changed the pool ratio, making TokenA appear cheaper");
        console.log("3. Oracle read the manipulated price from the pool");
        console.log("4. Attacker deposited small collateral but borrowed large DAI");
        console.log("5. Attacker repaid flash loan and kept the DAI profit");
        console.log("\n");
    }
}


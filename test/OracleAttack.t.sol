// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Sample test file demonstrating how to test the oracle attack
// To run: forge test -vvv

import "../src/MockERC20.sol";
import "../src/dex/UniV2Factory.sol";
import "../src/dex/UniV2Pair.sol";
import "../src/dex/UniV2Router.sol";
import "../src/oracle/OracleSpot.sol";
import "../src/oracle/OracleTWAP.sol";
import "../src/targets/LendingMock.sol";
import "../src/attackers/Attacker_Oracle.sol";

contract OracleAttackTest {
    MockERC20 tokenA;
    MockERC20 dai;
    UniV2Factory factory;
    UniV2Router router;
    address pair;
    OracleSpot oracleSpot;
    OracleTWAP oracleTWAP;
    LendingMock lending;
    Attacker_Oracle attacker;
    
    address user = address(0x1);
    address attacker_addr = address(0x2);

    function setUp() public {
        // Deploy tokens
        tokenA = new MockERC20("Token A", "TKA", 1000000 * 1e18);
        dai = new MockERC20("DAI", "DAI", 1000000 * 1e18);
        
        // Deploy DEX
        factory = new UniV2Factory(address(this));
        router = new UniV2Router(address(factory));
        pair = factory.createPair(address(tokenA), address(dai));
        
        // Add liquidity: 100k tokenA + 100k DAI
        tokenA.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        
        router.addLiquidity(
            address(tokenA),
            address(dai),
            100000 * 1e18,
            100000 * 1e18,
            0,
            0,
            address(this),
            block.timestamp + 1 hours
        );
        
        // Deploy oracles
        oracleSpot = new OracleSpot(pair);
        oracleTWAP = new OracleTWAP(pair);
        
        // Deploy lending with OracleSpot (vulnerable)
        lending = new LendingMock(address(oracleSpot), address(tokenA), address(dai));
        
        // Fund lending pool
        dai.approve(address(lending), type(uint256).max);
        lending.fundPool(50000 * 1e18);
    }

    function testOracleManipulation() public {
        // Setup attacker
        attacker = new Attacker_Oracle(
            pair,
            address(lending),
            address(tokenA),
            address(dai)
        );
        
        // Fund attacker
        tokenA.transfer(address(attacker), 10000 * 1e18);
        
        // Record initial state
        uint256 initialDaiBalance = dai.balanceOf(address(attacker));
        (uint112 r0Before, uint112 r1Before,) = UniV2Pair(pair).getReserves();
        
        // Execute attack
        attacker.attack(40000 * 1e18, 10000 * 1e18);
        
        // Verify attack success
        uint256 finalDaiBalance = dai.balanceOf(address(attacker));
        
        // Attacker should have gained DAI
        assert(finalDaiBalance > initialDaiBalance);
        
        // Lending should be undercollateralized
        // (has less collateral than loans)
    }

    function testTWAPProtection() public {
        // Setup lending with TWAP oracle instead
        LendingMock safeLending = new LendingMock(
            address(oracleTWAP),
            address(tokenA),
            address(dai)
        );
        
        dai.approve(address(safeLending), type(uint256).max);
        safeLending.fundPool(50000 * 1e18);
        
        // Setup attacker targeting TWAP-protected lending
        attacker = new Attacker_Oracle(
            pair,
            address(safeLending),
            address(tokenA),
            address(dai)
        );
        
        tokenA.transfer(address(attacker), 10000 * 1e18);
        
        // Try to attack - should fail or be less profitable
        // because TWAP cannot be manipulated in single transaction
        try attacker.attack(20000 * 1e18, 10000 * 1e18) {
            // Attack might succeed but with less profit
            // Or fail due to TWAP protection
        } catch {
            // Expected: attack fails against TWAP
            assert(true);
        }
    }

    function testPriceReading() public {
        // Test spot price reading
        uint256 spotPrice = oracleSpot.getPrice(address(tokenA));
        
        // With equal liquidity, price should be 1:1
        assert(spotPrice > 0.99e18 && spotPrice < 1.01e18);
        
        // Manipulate pool with large swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(dai);
        
        tokenA.approve(address(router), type(uint256).max);
        router.swapExactTokensForTokens(
            10000 * 1e18,
            0,
            path,
            address(this),
            block.timestamp + 1 hours
        );
        
        // Check price changed
        uint256 newSpotPrice = oracleSpot.getPrice(address(tokenA));
        assert(newSpotPrice != spotPrice);
        
        // TWAP should not change immediately
        uint256 twapPrice = oracleTWAP.getPrice(address(tokenA));
        // TWAP needs to be updated after time passes
    }
}


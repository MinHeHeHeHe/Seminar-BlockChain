// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MockERC20.sol";
import "../src/dex/UniV2Factory.sol";
import "../src/dex/UniV2Router.sol";
import "../src/dex/UniV2Pair.sol";
import "../src/dex/StablePoolMock.sol";
import "../src/oracle/OracleSpot.sol";
import "../src/oracle/OracleTWAP.sol";
import "../src/credit/FlashLender.sol";
import "../src/targets/LendingMock.sol";
import "../src/targets/GovToken.sol";
import "../src/targets/GovernanceWeak.sol";
import "../src/targets/VaultBuggy.sol";

contract DeployScript is Script {
    // Tokens
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public dai;
    GovToken public govToken;
    
    // DEX
    UniV2Factory public factory;
    UniV2Router public router;
    address public pairAB;
    StablePoolBuggy public stablePoolBuggy;
    StablePoolFixed public stablePoolFixed;
    
    // Oracle
    OracleSpot public oracleSpot;
    OracleTWAP public oracleTWAP;
    
    // Credit
    FlashLender public flashLender;
    
    // Targets
    LendingMock public lending;
    GovernanceWeak public governance;
    VaultBuggy public vaultBuggy;
    VaultFixed public vaultFixed;
    
    address public deployer;

    function run() external {
        vm.startBroadcast();
        
        deployer = msg.sender;
        
        // 1. Deploy tokens
        deployTokens();
        
        // 2. Deploy DEX
        deployDEX();
        
        // 3. Seed liquidity
        seedLiquidity();
        
        // 4. Deploy oracles
        deployOracles();
        
        // 5. Deploy credit layer
        deployCreditLayer();
        
        // 6. Deploy target protocols
        deployTargets();
        
        vm.stopBroadcast();
        
        // 7. Print deployment info
        printDeploymentInfo();
    }

    function deployTokens() internal {
        tokenA = new MockERC20("Token A", "TKA", 1000000 * 1e18);
        tokenB = new MockERC20("Token B", "TKB", 1000000 * 1e18);
        dai = new MockERC20("DAI Stablecoin", "DAI", 10000000 * 1e18);
        govToken = new GovToken(10000000 * 1e18);
    }

    function deployDEX() internal {
        factory = new UniV2Factory(deployer);
        router = new UniV2Router(address(factory));
        
        // Create pair for tokenA/tokenB
        pairAB = factory.createPair(address(tokenA), address(tokenB));
        
        // Deploy stable pools
        stablePoolBuggy = new StablePoolBuggy(address(tokenA), address(dai));
        stablePoolFixed = new StablePoolFixed(address(tokenA), address(dai));
    }

    function seedLiquidity() internal {
        // Approve router
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        dai.approve(address(router), type(uint256).max);
        
        // Add liquidity to UniV2 pair: 100k tokenA + 100k tokenB
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100000 * 1e18,
            100000 * 1e18,
            0,
            0,
            deployer,
            block.timestamp + 1 hours
        );
        
        // Add liquidity to stable pool (fixed version for demo)
        tokenA.approve(address(stablePoolFixed), type(uint256).max);
        dai.approve(address(stablePoolFixed), type(uint256).max);
        stablePoolFixed.addLiquidity(50000 * 1e18, 50000 * 1e18);
    }

    function deployOracles() internal {
        oracleSpot = new OracleSpot(pairAB);
        oracleTWAP = new OracleTWAP(pairAB);
    }

    function deployCreditLayer() internal {
        address[] memory tokens = new address[](4);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(dai);
        tokens[3] = address(govToken);
        
        flashLender = new FlashLender(tokens);
        
        // Fund flash lender
        tokenA.transfer(address(flashLender), 100000 * 1e18);
        tokenB.transfer(address(flashLender), 100000 * 1e18);
        dai.transfer(address(flashLender), 100000 * 1e18);
        govToken.transfer(address(flashLender), 1000000 * 1e18);
    }

    function deployTargets() internal {
        // Deploy lending protocol using OracleSpot (vulnerable)
        lending = new LendingMock(
            address(oracleSpot),
            address(tokenA), // collateral
            address(dai)      // borrow token
        );
        
        // Fund lending pool
        dai.approve(address(lending), type(uint256).max);
        lending.fundPool(100000 * 1e18);
        
        // Deploy governance
        governance = new GovernanceWeak(address(govToken));
        
        // Deploy vaults
        vaultBuggy = new VaultBuggy(address(tokenA));
        vaultFixed = new VaultFixed(address(tokenA));
    }

    function printDeploymentInfo() internal view {
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("");
        console.log("Tokens:");
        console.log("  TokenA:", address(tokenA));
        console.log("  TokenB:", address(tokenB));
        console.log("  DAI:", address(dai));
        console.log("  GovToken:", address(govToken));
        console.log("");
        console.log("DEX:");
        console.log("  Factory:", address(factory));
        console.log("  Router:", address(router));
        console.log("  PairAB:", pairAB);
        console.log("");
        console.log("Oracles:");
        console.log("  OracleSpot:", address(oracleSpot));
        console.log("  OracleTWAP:", address(oracleTWAP));
        console.log("");
        console.log("Credit:");
        console.log("  FlashLender:", address(flashLender));
        console.log("");
        console.log("Vulnerable Targets:");
        console.log("  LendingMock:", address(lending));
        console.log("  GovernanceWeak:", address(governance));
        console.log("  VaultBuggy:", address(vaultBuggy));
        console.log("");
    }

    // Helper function to get all addresses
    function getAddresses() external view returns (
        address _tokenA,
        address _tokenB,
        address _dai,
        address _govToken,
        address _factory,
        address _router,
        address _pairAB,
        address _oracleSpot,
        address _oracleTWAP,
        address _flashLender,
        address _lending,
        address _governance,
        address _vaultBuggy,
        address _vaultFixed
    ) {
        return (
            address(tokenA),
            address(tokenB),
            address(dai),
            address(govToken),
            address(factory),
            address(router),
            pairAB,
            address(oracleSpot),
            address(oracleTWAP),
            address(flashLender),
            address(lending),
            address(governance),
            address(vaultBuggy),
            address(vaultFixed)
        );
    }
}


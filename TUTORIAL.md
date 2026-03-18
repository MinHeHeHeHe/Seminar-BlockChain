# Tutorial: Hiểu Và Thực Hành DeFi Security

Hướng dẫn chi tiết từng bước để hiểu các attack vectors trong DeFi.

## Phần 1: Oracle Price Manipulation

### 🎓 Kiến Thức Nền

**Oracle là gì?**
- Oracle cung cấp giá token cho smart contracts
- Lending protocols dùng oracle để xác định giá trị collateral
- Nếu oracle bị manipulate → protocol có thể bị exploit

**Spot Price vs TWAP:**
- **Spot Price**: Giá hiện tại từ reserves (`reserve1 / reserve0`)
  - ❌ Có thể bị manipulate trong 1 transaction
  - ❌ Attacker dùng flash loan/swap để skew reserves
  
- **TWAP (Time-Weighted Average Price)**: Giá trung bình theo thời gian
  - ✅ Khó manipulate vì cần thời gian
  - ✅ Bảo vệ chống flash loan attacks

### 📖 Attack Flow Chi Tiết

**Setup:**
- DEX pair: 100,000 TKA / 100,000 TKB (giá 1:1)
- Lending protocol: collateral = TKA, borrow = DAI
- Oracle: đọc spot price từ DEX
- Collateral factor: 150% (need $150 collateral to borrow $100)

**Attack Steps:**

1. **Initial State**
   ```
   DEX Reserves: 100,000 TKA / 100,000 TKB
   TKA Price: 1 TKB (từ oracle)
   Attacker có: 10,000 TKA
   ```

2. **Flash Swap 20,000 TKA từ DEX**
   ```
   Callback được gọi, attacker nhận 20,000 TKA
   DEX Reserves: 80,000 TKA / 100,000 TKB
   TKA Price giờ là: 100,000/80,000 = 1.25 TKB
   → TKA appears MORE VALUABLE!
   ```

3. **Deposit nhỏ vào Lending (2,000 TKA)**
   ```
   Oracle đọc giá: 1 TKA = 1.25 TKB
   Collateral value: 2,000 * 1.25 = 2,500 TKB
   Max borrow (at 150%): 2,500 / 1.5 = 1,666 TKB
   → Attacker borrow 1,500 DAI
   ```

4. **Repay Flash Swap**
   ```
   Repay: 20,000 * 1.003 = 20,060 TKA
   Attacker dùng: 2,000 (deposited) + 20,060 (repay) = 22,060 TKA
   Cost: 22,060 TKA
   Gain: 1,500 DAI
   ```

5. **Kết quả**
   ```
   Nếu TKA = DAI về giá trị thật:
   - Attacker còn: 1,500 DAI - (22,060 - 10,000) = LOSS
   
   NHƯNG: Lending protocol giờ undercollateralized!
   - Có 2,000 TKA collateral (worth ~2,000)
   - Đã cho vay 1,500 DAI
   - Nếu TKA giá giảm → bad debt!
   ```

### 💻 Code Walkthrough

**OracleSpot.sol** (Vulnerable):
```solidity
function getPrice(address token) external view returns (uint256) {
    (uint112 reserve0, uint112 reserve1,) = IUniV2Pair(pair).getReserves();
    // ❌ ĐỌC TRỰC TIẾP từ reserves
    // Attacker có thể manipulate trong cùng transaction!
    return (uint256(reserve1) * 1e18) / uint256(reserve0);
}
```

**OracleTWAP.sol** (Secure):
```solidity
function update() external {
    // Tính average price qua thời gian
    uint32 timeElapsed = blockTimestamp - blockTimestampLast;
    require(timeElapsed >= PERIOD, "PERIOD_NOT_ELAPSED");
    
    // ✅ Giá average, không thể manipulate trong 1 tx
    price0Average = (price0Cumulative - price0CumulativeLast) / timeElapsed;
}
```

**Attacker_Oracle.sol**:
```solidity
function attack(uint256 flashAmount, uint256 borrowAmount) external {
    // Flash swap từ pair
    pair.swap(flashAmount, 0, address(this), abi.encode(flashAmount));
}

function uniswapV2Call(...) external {
    // 1. Giá giờ bị skewed
    // 2. Deposit collateral
    lending.deposit(depositAmount);
    // 3. Borrow với giá manipulated
    lending.borrow(borrowAmount);
    // 4. Repay flash swap
    // 5. Keep profit!
}
```

### 🛡️ Phòng Chống

1. **Dùng TWAP thay vì Spot**
   ```solidity
   // ✅ GOOD
   oracle = new OracleTWAP(pair);
   oracle.update(); // Update định kỳ
   uint256 price = oracle.getPrice(token);
   
   // ❌ BAD
   oracle = new OracleSpot(pair);
   uint256 price = oracle.getPrice(token); // Có thể bị manipulate!
   ```

2. **Multiple Oracle Sources**
   ```solidity
   uint256 price1 = oracleA.getPrice(token);
   uint256 price2 = oracleB.getPrice(token);
   require(abs(price1 - price2) < THRESHOLD, "Price deviation too high");
   ```

3. **Circuit Breakers**
   ```solidity
   uint256 newPrice = oracle.getPrice(token);
   uint256 priceDiff = abs(newPrice - lastPrice);
   require(priceDiff < maxDeviation, "Price change too rapid");
   ```

---

## Phần 2: Governance Attack

### 🎓 Kiến Thức Nền

**Governance trong DeFi:**
- Token holders vote trên proposals
- Proposals thay đổi protocol parameters, upgrade contracts, etc.
- Cần quorum (minimum votes) để pass

**Vulnerability:**
- Nếu check voting power tại **vote time** → có thể flash loan!
- Should check tại **proposal creation time** (snapshot)

### 📖 Attack Flow Chi Tiết

**Setup:**
- Governance quorum: 1,000,000 GOV tokens
- Attacker có: 100,000 GOV (không đủ)
- Flash lender có: 2,000,000 GOV available

**Attack Steps:**

1. **Tạo Malicious Proposal**
   ```solidity
   // Proposal: Transfer ownership of TreasuryContract to attacker
   bytes memory maliciousCall = abi.encodeWithSignature(
       "transferOwnership(address)",
       attackerAddress
   );
   governance.propose(treasuryAddress, maliciousCall, "Upgrade treasury");
   ```

2. **Flash Loan 2M GOV Tokens**
   ```
   Before: Attacker có 100k GOV
   After flash loan: Attacker có 2.1M GOV (borrowed 2M)
   ```

3. **Vote Trong Callback**
   ```solidity
   function onFlashLoan(...) external {
       // Bây giờ có 2.1M voting power!
       governance.vote(proposalId, true); // Vote YES
       
       // Repay loan
       token.approve(lender, amount + fee);
   }
   ```

4. **Repay Flash Loan**
   ```
   Repay: 2M + 0.09% fee = 2,001,800 GOV
   After repay: Attacker còn 100k GOV
   
   NHƯNG: Vote đã được record!
   Proposal có 2.1M votes → PASSED quorum!
   ```

5. **Execute Proposal**
   ```
   // Wait 3 days cho voting period
   // Execute malicious proposal
   governance.execute(proposalId);
   // → Treasury ownership transferred to attacker!
   ```

### 💻 Code Walkthrough

**GovernanceWeak.sol** (Vulnerable):
```solidity
function vote(uint256 proposalId, bool support) external {
    // ❌ Check voting power TẠI THỜI ĐIỂM VOTE
    uint256 votes = govToken.getVotingPower(msg.sender);
    
    if (support) {
        proposal.forVotes += votes;
    }
    // User có thể flash loan tokens → vote → repay!
}
```

**GovernanceSecure.sol** (Correct way):
```solidity
struct Proposal {
    uint256 startBlock; // Snapshot block
    mapping(address => uint256) votingPowerSnapshot;
}

function propose(...) external {
    proposal.startBlock = block.number;
    // Snapshot voting power at proposal creation
}

function vote(uint256 proposalId, bool support) external {
    // ✅ Check voting power at SNAPSHOT time
    uint256 votes = votingPowerAtBlock[msg.sender][proposal.startBlock];
    // Flash loan không giúp vì voting power đã được snapshot!
}
```

### 🛡️ Phòng Chống

1. **Snapshot-Based Voting**
   ```solidity
   // Record balance tại block proposal được tạo
   mapping(address => mapping(uint256 => uint256)) public balanceAtBlock;
   ```

2. **Time-Locked Tokens**
   ```solidity
   // Require tokens phải hold >= 7 days trước khi vote
   require(block.timestamp - userDeposit[msg.sender] >= 7 days);
   ```

3. **Delegation With Delay**
   ```solidity
   // Delegation có delay, không thể flash loan
   function delegate(address to) external {
       delegationDelay[msg.sender] = block.timestamp + 2 days;
   }
   ```

---

## Phần 3: Vault Share Inflation

### 🎓 Kiến Thức Nền

**Vault là gì?**
- User deposit tokens → nhận shares
- Shares represent ownership của pool
- Khi withdraw: redeem shares cho tokens

**Formula:**
```
shares = (assets * totalShares) / totalAssets

Ví dụ:
- Pool có: 100 tokens, 100 shares
- User deposit 10 tokens
- Shares received: 10 * 100 / 100 = 10 shares ✅

- Pool có: 1 token, 1 share
- User deposit 10 tokens  
- Shares received: 10 * 1 / 1 = 10 shares ✅

- Pool có: 100 tokens, 1 share (INFLATED!)
- User deposit 10 tokens
- Shares received: 10 * 1 / 100 = 0.1 → ROUNDS TO 0 ❌
```

### 📖 Attack Flow Chi Tiết

**Attack Steps:**

1. **Attacker là First Depositor**
   ```solidity
   // Deposit 1 wei
   vault.deposit(1);
   // Attacker nhận: 1 share
   // Vault state: 1 wei asset, 1 share
   ```

2. **Donate to Inflate Share Price**
   ```solidity
   // Donate 50,000 tokens directly
   token.transfer(address(vault), 50_000e18);
   // Vault state: 50,000e18 + 1 assets, 1 share
   // Share price: 50,000e18 per share!
   ```

3. **Victim Deposits**
   ```solidity
   // Victim deposits 25,000 tokens
   vault.deposit(25_000e18);
   
   // Calculate shares:
   shares = 25_000e18 * 1 / (50_000e18 + 1)
          = 25_000e18 / 50_000e18
          = 0.5 shares
          = 0 (rounds down!) ❌
   
   // Victim receives 0 shares!
   // 25,000 tokens trapped in vault!
   ```

4. **Attacker Withdraws**
   ```solidity
   // Attacker has 1 share
   // Vault has: 50,000e18 + 1 + 25,000e18 = 75,000e18 tokens
   vault.withdraw(1);
   
   // Receives: 1 * 75,000e18 / 1 = 75,000 tokens
   // Profit: 75,000 - 50,000 - 0.000001 = 25,000 tokens! 💰
   ```

### 💻 Code Walkthrough

**VaultBuggy.sol** (Vulnerable):
```solidity
function deposit(uint256 assets) external returns (uint256 shares) {
    if (totalShares == 0) {
        shares = assets; // ❌ Không burn minimum shares
    } else {
        // ❌ Sử dụng balance AFTER transfer
        uint256 balance = token.balanceOf(address(this));
        shares = (assets * totalShares) / (balance - assets);
    }
    // Có thể round down to 0!
}
```

**VaultFixed.sol** (Secure):
```solidity
uint256 private constant MINIMUM_SHARES = 1000;

function deposit(uint256 assets) external returns (uint256 shares) {
    if (totalShares == 0) {
        shares = assets - MINIMUM_SHARES; // ✅ Burn minimum shares
        shares[address(0)] = MINIMUM_SHARES; // Send to dead address
        totalShares = assets;
    } else {
        // ✅ Use balance BEFORE transfer
        shares = (assets * totalShares) / balanceBefore;
    }
    require(shares > 0, "Insufficient shares"); // ✅ Check not 0
}
```

### 🛡️ Phòng Chống

1. **Burn Minimum Shares (Uniswap V2 Style)**
   ```solidity
   if (totalShares == 0) {
       liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
       _mint(address(0), MINIMUM_LIQUIDITY); // Burn to 0 address
   }
   ```

2. **Virtual Shares/Assets (ERC4626)**
   ```solidity
   uint256 private constant OFFSET = 1e8;
   
   function convertToShares(uint256 assets) public view returns (uint256) {
       return (assets * (totalShares + OFFSET)) / (totalAssets + OFFSET);
   }
   ```

3. **Check Balance Before/After**
   ```solidity
   uint256 balanceBefore = token.balanceOf(address(this));
   token.transferFrom(msg.sender, address(this), amount);
   uint256 balanceAfter = token.balanceOf(address(this));
   uint256 actualDeposit = balanceAfter - balanceBefore;
   ```

---

## 🔬 Lab Exercises

### Exercise 1: Test Oracle Attack
```bash
# Terminal 1: Start node
anvil

# Terminal 2: Deploy và attack
forge script script/Demo_OracleAttack.s.sol --rpc-url http://localhost:8545 --broadcast

# Quan sát:
# - Reserves thay đổi thế nào
# - Lending protocol bị undercollateralized như thế nào
```

### Exercise 2: Modify Attack
Thử modify attacker để:
1. Tối đa hóa profit
2. Minimize gas cost
3. Attack multiple times

### Exercise 3: Implement Fixes
1. Deploy OracleTWAP thay vì OracleSpot
2. Update LendingMock để dùng TWAP
3. Thử attack lại → should fail!

---

## 📚 Further Learning

- **Secureum Bootcamp**: https://secureum.substack.com/
- **Damn Vulnerable DeFi**: https://www.damnvulnerabledefi.xyz/
- **Ethernaut**: https://ethernaut.openzeppelin.com/
- **Smart Contract Security Field Guide**: https://scsfg.io/

---

**Happy Hacking (Ethically)! 🔒**


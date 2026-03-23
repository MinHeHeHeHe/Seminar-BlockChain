# DeFi Security Demo

Dự án demo các loại tấn công phổ biến trong DeFi (Oracle Manipulation, Governance Attack, Pool Exploits) với kiến trúc đầy đủ từ DEX, Oracle, Lending đến các attack vectors.


## 📋 Mục Lục

- [Kiến Trúc](#kiến-trúc)
- [Cài Đặt](#cài-đặt)
- [Các Attack Vectors](#các-attack-vectors)
- [Các Lỗ Hổng Và Cách Khắc Phục](#các-lỗ-hổng-và-cách-khắc-phục)

## 🏗️ Kiến Trúc

```
┌───────────────────────────────────────────────────────────────────┐
│                       ENV & TOOLING LAYER                         │
│  Anvil/Hardhat Node  ·  Foundry Runner  ·  (Tenderly optional)    │
└───────────────────────────────────────────────────────────────────┘
                              │ RPC
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│                       PROTOCOL SIMULATION LAYER                   │
│  A. DEX Layer (AMM)                                               │
│     • UniV2-like: Factory, Pair, Router (có Flash-Swap)          │
│     • StablePoolMock (Curve-like, bản Buggy/Fixed)               │
│                                                                   │
│  B. Oracle Layer                                                  │
│     • OracleSpot  (đọc reserves → dễ thao túng)                  │
│     • OracleTWAP  (time-weighted, bản vá)                        │
│                                                                   │
│  C. Credit Layer                                                  │
│     • FlashLender (kiểu Aave flash loan)                         │
│                                                                   │
│  D. Target Protocols                                              │
│     • LendingMock (dùng OracleSpot - vulnerable)                 │
│     • GovernanceWeak + GovToken (vote-time checking)             │
│     • VaultBuggy (kế toán lỗi)                                   │
└───────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────────────┐
│                       ATTACKER / DEMO LAYER                       │
│  • Attacker_Oracle.sol        (manipulate oracle → overborrow)    │
│  • Attacker_Governance.sol    (flash loan GOV → vote)             │
│  • Attacker_PoolImbalance.sol (exploit vault bugs)                │
│  • Scripts: Deploy, Demo_Oracle, Demo_Governance, Demo_Pool      │
└───────────────────────────────────────────────────────────────────┘
```

## 🛠️ Cài Đặt

### Yêu Cầu

- Foundry
- Node.js

### Cài Đặt Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Clone và Build

```bash
cd defi-security-demo
forge build
```

## 🎯 Các Attack Vectors

### 1. Oracle Price Manipulation

**Lỗ hổng**: Oracle đọc spot price trực tiếp từ reserves của DEX

**Attack Flow**:
1. Flash swap token từ DEX → manipulate reserves
2. Oracle đọc giá sai → collateral appears more valuable
3. Borrow nhiều hơn giá trị collateral thực
4. Repay flash swap
5. Profit! (Protocol bị undercollateralized)

**Target**: `LendingMock` với `OracleSpot`


**Mitigation**:
- ✅ Dùng TWAP (Time-Weighted Average Price) thay vì spot price
- ✅ Require giá từ nhiều nguồn (multiple oracles)
- ✅ Circuit breakers khi giá thay đổi quá nhanh

### 2. Governance Takeover

**Lỗ hổng**: Governance check voting power tại thời điểm vote, không phải lúc proposal tạo

**Attack Flow**:
1. Flash loan massive amount GOV tokens
2. Vote trên malicious proposal với borrowed power
3. Repay flash loan trong cùng transaction
4. Wait cho voting period kết thúc
5. Execute malicious proposal
6. Profit! (Control entire protocol)

**Target**: `GovernanceWeak` với `GovToken`


**Mitigation**:
- ✅ Snapshot-based voting (check power at proposal creation time)
- ✅ Vote delegation với time lock
- ✅ Require minimum holding period

### 3. Vault Share Inflation

**Lỗ hổng**: Vault không burn minimum shares hoặc có accounting bugs

**Attack Flow**:
1. Attacker là first depositor với 1 wei
2. Donate large amount tokens → inflate share price
3. Victim deposit → nhận 0 shares do rounding
4. Attacker withdraw với 1 share → steal tất cả funds!

**Target**: `VaultBuggy`


**Mitigation**:
- ✅ Burn minimum shares on first deposit (Uniswap V2 style)
- ✅ Use virtual shares/assets
- ✅ Check balance before/after transfers
- ✅ Reentrancy guards


## 🔒 Các Lỗ Hổng Và Cách Khắc Phục

| Lỗ Hổng | Contract | Issue | Fix |
|---------|----------|-------|-----|
| **Oracle Manipulation** | `OracleSpot` | Đọc spot price trong cùng transaction | Dùng `OracleTWAP` |
| **Flash Loan Governance** | `GovernanceWeak` | Check voting power tại vote time | Snapshot-based voting |
| **Vault Inflation** | `VaultBuggy` | Không burn minimum shares | Burn minimum shares như UniV2 |
| **Reentrancy** | `StablePoolBuggy`, `VaultBuggy` | Cập nhật state sau transfer | Use reentrancy guard + checks-effects-interactions |
| **Accounting Bugs** | `StablePoolBuggy` | Sai công thức tính shares | Use proper Curve formula |
| **Donation Attack** | `VaultBuggy` | Ai cũng donate được | Virtual shares hoặc check balance |

# DeFi Security Demo

Dự án demo các loại tấn công phổ biến trong DeFi (Oracle Manipulation, Governance Attack, Pool Exploits) với kiến trúc đầy đủ từ DEX, Oracle, Lending đến các attack vectors.

> ⚠️ **CHỈ DÙNG ĐỂ HỌC TẬP VÀ NGHIÊN CỨU**  
> Đừng sử dụng code này trên mainnet hoặc với tiền thật!

## 📋 Mục Lục

- [Kiến Trúc](#kiến-trúc)
- [Cài Đặt](#cài-đặt)
- [Các Attack Vectors](#các-attack-vectors)
- [Cấu Trúc Dự Án](#cấu-trúc-dự-án)
- [Hướng Dẫn Sử Dụng](#hướng-dẫn-sử-dụng)
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

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil)
- Node.js 16+ (optional, cho hardhat)

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

### Chạy Tests

```bash
forge test -vvv
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

**Demo**:
```bash
forge script script/Demo_OracleAttack.s.sol --rpc-url http://localhost:8545 --broadcast
```

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

**Demo**:
```bash
forge script script/Demo_GovernanceAttack.s.sol --rpc-url http://localhost:8545 --broadcast
```

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

**Demo**:
```bash
forge script script/Demo_PoolAttack.s.sol --rpc-url http://localhost:8545 --broadcast
```

**Mitigation**:
- ✅ Burn minimum shares on first deposit (Uniswap V2 style)
- ✅ Use virtual shares/assets
- ✅ Check balance before/after transfers
- ✅ Reentrancy guards

## 📁 Cấu Trúc Dự Án

```
defi-security-demo/
├── src/
│   ├── dex/
│   │   ├── UniV2Factory.sol        # DEX Factory
│   │   ├── UniV2Pair.sol           # DEX Pair với flash swap
│   │   ├── UniV2Router.sol         # DEX Router
│   │   ├── StablePoolMock.sol      # Curve-like pool (buggy + fixed)
│   │   ├── interfaces/
│   │   │   └── IUniV2Pair.sol
│   │   └── libraries/
│   │       ├── Math.sol
│   │       └── UQ112x112.sol
│   │
│   ├── oracle/
│   │   ├── OracleSpot.sol          # Vulnerable spot price oracle
│   │   └── OracleTWAP.sol          # Secure TWAP oracle
│   │
│   ├── credit/
│   │   └── FlashLender.sol         # Flash loan provider
│   │
│   ├── targets/
│   │   ├── LendingMock.sol         # Vulnerable lending protocol
│   │   ├── GovToken.sol            # Governance token
│   │   ├── GovernanceWeak.sol      # Vulnerable governance
│   │   └── VaultBuggy.sol          # Vulnerable vault
│   │
│   ├── attackers/
│   │   ├── Attacker_Oracle.sol     # Oracle manipulation attack
│   │   ├── Attacker_Governance.sol # Governance attack
│   │   └── Attacker_PoolImbalance.sol # Vault/Pool attacks
│   │
│   └── MockERC20.sol               # Mock ERC20 token
│
├── script/
│   ├── Deploy.s.sol                # Main deployment script
│   ├── Demo_OracleAttack.s.sol     # Oracle attack demo
│   ├── Demo_GovernanceAttack.s.sol # Governance attack demo
│   └── Demo_PoolAttack.s.sol       # Pool attack demo
│
├── test/                           # Tests (tạo nếu cần)
├── foundry.toml                    # Foundry config
├── package.json                    # NPM scripts
└── README.md                       # Documentation
```

## 🚀 Hướng Dẫn Sử Dụng

### 1. Start Local Node

#### Sử dụng Anvil (Foundry)

```bash
anvil
```

#### Hoặc Hardhat

```bash
npx hardhat node
```

### 2. Deploy Contracts

```bash
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <YOUR_PRIVATE_KEY>
```

### 3. Run Attack Demos

#### Oracle Manipulation Attack

```bash
forge script script/Demo_OracleAttack.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <YOUR_PRIVATE_KEY>
```

#### Governance Attack

```bash
forge script script/Demo_GovernanceAttack.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <YOUR_PRIVATE_KEY>
```

#### Vault Inflation Attack

```bash
forge script script/Demo_PoolAttack.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <YOUR_PRIVATE_KEY>
```

### 4. Run Tests (nếu có)

```bash
forge test -vvv
```

## 🔒 Các Lỗ Hổng Và Cách Khắc Phục

| Lỗ Hổng | Contract | Issue | Fix |
|---------|----------|-------|-----|
| **Oracle Manipulation** | `OracleSpot` | Đọc spot price trong cùng transaction | Dùng `OracleTWAP` |
| **Flash Loan Governance** | `GovernanceWeak` | Check voting power tại vote time | Snapshot-based voting |
| **Vault Inflation** | `VaultBuggy` | Không burn minimum shares | Burn minimum shares như UniV2 |
| **Reentrancy** | `StablePoolBuggy`, `VaultBuggy` | Cập nhật state sau transfer | Use reentrancy guard + checks-effects-interactions |
| **Accounting Bugs** | `StablePoolBuggy` | Sai công thức tính shares | Use proper Curve formula |
| **Donation Attack** | `VaultBuggy` | Ai cũng donate được | Virtual shares hoặc check balance |

## 📚 Tài Liệu Tham Khảo

### Oracle Attacks
- [Oracle Manipulation: The Breakdown](https://0xmacro.com/blog/oracle-manipulation/)
- [Flash Loan Attack on bZx](https://peckshield.medium.com/bzx-hack-full-disclosure-with-detailed-profit-analysis-e6b1fa9b18fc)

### Governance Attacks
- [Flash Loan Governance Attack](https://blog.openzeppelin.com/flash-loan-governance-attack)
- [Compound Governance Attack](https://www.coindesk.com/tech/2020/10/12/compound-passes-vote-to-patch-dai-collateral-bug/)

### Vault Attacks
- [ERC4626 Inflation Attack](https://mixbytes.io/blog/overview-of-the-inflation-attack)
- [First Depositor Sandwich Attack](https://blog.openzeppelin.com/a-novel-defense-against-erc4626-inflation-attacks)

### General DeFi Security
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [DeFi Security Summit](https://defisecuritysummit.org/)

## ⚖️ License

MIT License - Chỉ dùng cho mục đích học tập và nghiên cứu.

## ⚠️ Disclaimer

Dự án này chỉ dùng để:
- Học tập về DeFi security
- Nghiên cứu attack vectors
- Testing và auditing

**KHÔNG** sử dụng để:
- Tấn công protocols thật
- Deploy lên mainnet
- Bất kỳ mục đích phi pháp nào

---

**Built with ❤️ for DeFi Security Education**


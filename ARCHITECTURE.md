# 🏛️ Architecture Deep Dive

## Kiến Trúc Tổng Quan

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER / USER LAYER                          │
│                   Foundry Scripts, Anvil Node, Tests                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓ RPC
┌─────────────────────────────────────────────────────────────────────────┐
│                            DEMO / ATTACKER LAYER                        │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────┐ │
│  │  Attacker_Oracle     │  │ Attacker_Governance  │  │Attacker_Pool │ │
│  │  • Flash swap        │  │ • Flash loan GOV     │  │• Inflation   │ │
│  │  • Manipulate price  │  │ • Vote attack        │  │• Donation    │ │
│  │  • Over-borrow       │  │ • Execute malicious  │  │• Reentrancy  │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓ Calls
┌─────────────────────────────────────────────────────────────────────────┐
│                          TARGET PROTOCOLS LAYER                         │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────┐ │
│  │   LendingMock        │  │  GovernanceWeak      │  │ VaultBuggy   │ │
│  │  • Deposit           │  │ • Propose            │  │• Deposit     │ │
│  │  • Borrow            │  │ • Vote (vulnerable)  │  │• Withdraw    │ │
│  │  • Uses Oracle ❌    │  │ • Execute            │  │• Bugs ❌     │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                    ↓                    ↓                    ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE LAYER                             │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐       │
│  │  Oracle Layer  │    │  Credit Layer  │    │   DEX Layer    │       │
│  │ • OracleSpot❌ │    │ • FlashLender  │    │ • UniV2Factory │       │
│  │ • OracleTWAP✅ │    │ • Flash loans  │    │ • UniV2Pair    │       │
│  │                │    │ • ERC3156      │    │ • UniV2Router  │       │
│  │                │    │                │    │ • StablePool   │       │
│  └────────────────┘    └────────────────┘    └────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓ Uses
┌─────────────────────────────────────────────────────────────────────────┐
│                            TOKEN LAYER                                  │
│        MockERC20 (TKA, TKB, DAI)    +    GovToken (GOV)                │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Component Interactions

### 1. Oracle Manipulation Attack Flow

```
┌──────────────┐                    ┌──────────────┐
│              │  1. Flash Swap     │              │
│  Attacker    │───────────────────>│  UniV2Pair   │
│   _Oracle    │                    │              │
│              │<───────────────────│              │
│              │  2. Callback       └──────────────┘
│              │                           │
│              │  3. Check Price           │ Reserves
│              │     (manipulated)         │ Changed
│              │           │               ↓
│              │           ↓        ┌──────────────┐
│              │    ┌──────────────┐│              │
│              │───>│ OracleSpot   ││  Reads       │
│              │    │ (vulnerable) │└──────────────┘
│              │    └──────────────┘
│              │           │
│              │           │ Returns wrong price
│              │           ↓
│              │    ┌──────────────┐
│              │───>│ LendingMock  │
│              │  4.│ Borrow with  │
│              │    │ inflated     │
│              │<───│ collateral   │
│              │    └──────────────┘
│              │  5. Borrowed funds
│              │
│              │    ┌──────────────┐
│              │───>│  UniV2Pair   │
│              │  6.│ Repay flash  │
│              │    │ swap         │
└──────────────┘    └──────────────┘
       │
       └─> Keep profit!
```

### 2. Governance Attack Flow

```
┌──────────────┐                    ┌──────────────┐
│              │  1. Create         │              │
│  Attacker    │───────────────────>│ Governance   │
│  _Governance │    Proposal        │   Weak       │
│              │                    └──────────────┘
│              │
│              │    ┌──────────────┐
│              │  2.│ FlashLender  │
│              │───>│ Borrow GOV   │
│              │    │ tokens       │
│              │<───│              │
│              │  3.└──────────────┘
│              │    Callback
│              │       │
│              │       │ Have massive
│              │       │ voting power
│              │       ↓
│              │    ┌──────────────┐
│              │  4.│ Governance   │
│              │───>│ Vote YES     │
│              │    │ (with 2M GOV)│
│              │    └──────────────┘
│              │       │
│              │       │ Proposal passed!
│              │       ↓
│              │    ┌──────────────┐
│              │  5.│ FlashLender  │
│              │───>│ Repay loan   │
│              │    └──────────────┘
│              │
│    Wait 3 days for voting period...
│              │
│              │    ┌──────────────┐
│              │  6.│ Governance   │
│              │───>│ Execute      │
│              │    │ Malicious    │
└──────────────┘    └──────────────┘
                           │
                           └─> Attacker gains control!
```

### 3. Vault Inflation Attack Flow

```
Step 1: First Deposit
┌──────────────┐                    ┌──────────────┐
│              │  deposit(1 wei)    │              │
│  Attacker    │───────────────────>│  VaultBuggy  │
│              │                    │              │
│              │<───────────────────│ 1 share      │
└──────────────┘                    └──────────────┘
                                    State: 1 wei, 1 share

Step 2: Donate
┌──────────────┐                    ┌──────────────┐
│              │  donate(50k)       │              │
│  Attacker    │───────────────────>│  VaultBuggy  │
└──────────────┘                    └──────────────┘
                                    State: 50k+1 wei, 1 share
                                    Share price: 50k per share!

Step 3: Victim Deposits
┌──────────────┐                    ┌──────────────┐
│              │  deposit(25k)      │              │
│    Victim    │───────────────────>│  VaultBuggy  │
│              │                    │              │
│              │<───────────────────│ 0 shares ❌  │
└──────────────┘                    └──────────────┘
                                    State: 75k+1 wei, 1 share
                                    Victim's 25k stuck!

Step 4: Attacker Withdraws
┌──────────────┐                    ┌──────────────┐
│              │  withdraw(1)       │              │
│  Attacker    │───────────────────>│  VaultBuggy  │
│              │                    │              │
│              │<───────────────────│ 75k tokens ✅│
└──────────────┘                    └──────────────┘
                                    Attacker steals victim's funds!
```

---

## Contract Dependencies

### DEX Layer Dependencies

```
UniV2Factory
    └─> creates ──> UniV2Pair
                        ├─> uses Math library
                        └─> uses UQ112x112 library

UniV2Router
    ├─> reads from ──> UniV2Factory
    └─> calls ──────> UniV2Pair

StablePoolMock
    └─> standalone (Curve-like)
```

### Oracle Layer Dependencies

```
OracleSpot
    └─> reads from ──> UniV2Pair (getReserves)

OracleTWAP
    └─> reads from ──> UniV2Pair (price cumulatives)
```

### Target Protocols Dependencies

```
LendingMock
    ├─> uses ──> IOracle (can be OracleSpot or TWAP)
    └─> holds ──> ERC20 tokens

GovernanceWeak
    └─> uses ──> GovToken (for voting power)

VaultBuggy/Fixed
    └─> holds ──> ERC20 tokens
```

### Attacker Dependencies

```
Attacker_Oracle
    ├─> interacts ──> UniV2Pair (flash swap)
    ├─> reads ─────> Oracle (manipulated)
    └─> exploits ──> LendingMock

Attacker_Governance
    ├─> borrows ────> FlashLender (GOV tokens)
    └─> exploits ──> GovernanceWeak

Attacker_PoolImbalance
    └─> exploits ──> VaultBuggy / StablePoolBuggy
```

---

## Data Flow Examples

### Example 1: Normal Lending Flow (No Attack)

```
User
  │
  ├─> 1. Deposit 100 tokenA as collateral
  │         │
  │         ↓
  │   LendingMock
  │         ├─> Ask oracle: "What's tokenA price?"
  │         │         │
  │         │         ↓
  │         │   OracleTWAP: "1 tokenA = 1 DAI"
  │         │
  │         ├─> Calculate: 100 tokenA * 1 = 100 DAI value
  │         │             100 / 1.5 (collateral factor) = 66 DAI max
  │         │
  │         └─> Allow borrow up to 66 DAI
  │
  └─> 2. Borrow 50 DAI ✅ (Healthy position)
```

### Example 2: Oracle Attack Flow (Vulnerable)

```
Attacker
  │
  ├─> 1. Flash swap 20k tokenA from DEX
  │         │
  │         ↓ Reserves change: 100k→80k tokenA, 100k DAI
  │         │ Price changes: 1→1.25 (tokenA appears more valuable)
  │         │
  │         ↓ Callback:
  │         │
  │   ├─> 2. Deposit 2k tokenA
  │   │         │
  │   │         ↓
  │   │   LendingMock
  │   │         ├─> Ask oracle: "What's tokenA price?"
  │   │         │         │
  │   │         │         ↓
  │   │         │   OracleSpot: "1 tokenA = 1.25 DAI" ❌
  │   │         │
  │   │         ├─> Calculate: 2k * 1.25 = 2500 DAI value
  │   │         │             2500 / 1.5 = 1666 DAI max
  │   │         │
  │   │         └─> Allow borrow up to 1666 DAI
  │   │
  │   └─> 3. Borrow 1500 DAI ✅ (Appears healthy but NOT!)
  │
  └─> 4. Repay flash swap
        │
        ↓ Price returns to normal: 1 tokenA = 1 DAI
        │ But attacker already borrowed 1500 DAI
        │ With only 2k tokenA collateral (worth 2k DAI)
        │
        └─> Protocol is UNDERCOLLATERALIZED! ❌
```

---

## Security Comparison

### Vulnerable vs Secure

| Component | Vulnerable Version | Secure Version | Key Difference |
|-----------|-------------------|----------------|----------------|
| **Oracle** | `OracleSpot` | `OracleTWAP` | Spot price vs time-weighted |
| **Governance** | `GovernanceWeak` | N/A (see mitigation) | Vote-time vs snapshot |
| **Vault** | `VaultBuggy` | `VaultFixed` | No min shares vs burn min shares |
| **Pool** | `StablePoolBuggy` | `StablePoolFixed` | Buggy math vs correct formula |

### Mitigation Patterns

```
Pattern 1: Time-Based Protection
├─ TWAP: Average price over time
├─ Snapshot: Record state at specific time
└─ Time locks: Delay between action and effect

Pattern 2: Accounting Protection
├─ Burn minimum shares (Uniswap V2)
├─ Virtual shares/assets (ERC4626)
└─ Check balance before/after

Pattern 3: Reentrancy Protection
├─ Checks-Effects-Interactions pattern
├─ Reentrancy guard (modifier)
└─ State updates before external calls

Pattern 4: Price Validation
├─ Multiple oracle sources
├─ Circuit breakers
└─ Maximum deviation checks
```

---

## File Organization Logic

```
src/
│
├── dex/              # DEX primitives (building blocks)
│   ├── Core contracts (Factory, Pair, Router)
│   ├── interfaces/   # Contract interfaces
│   └── libraries/    # Shared math libraries
│
├── oracle/           # Price feeds
│   ├── Vulnerable version (OracleSpot)
│   └── Secure version (OracleTWAP)
│
├── credit/           # Flash loan providers
│   └── FlashLender (ERC3156)
│
├── targets/          # Protocols to be attacked
│   ├── Lending protocol
│   ├── Governance system
│   └── Vault system
│
├── attackers/        # Attack implementations
│   ├── Oracle manipulation
│   ├── Governance takeover
│   └── Pool/Vault exploits
│
└── MockERC20.sol     # Token implementation

script/               # Deployment and demos
├── Deploy.s.sol      # Deploy all infrastructure
└── Demo_*.s.sol      # Individual attack demos



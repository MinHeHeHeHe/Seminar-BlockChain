# Quick Start Guide

## Setup & Demo

### Bước 1: Cài Foundry

```bash
curl -L https://foundry.paradigm.xyz
foundryup
```

### Bước 2: Build Project

```bash
cd defi-security-demo
forge build
```

### Bước 3: Start Local Node

Mở terminal mới và chạy:

```bash
anvil
```

Để anvil chạy, copy một private key từ output (dùng cho bước 4).

### Bước 4: Run Attack Demos

Trong terminal khác: lưu ý thay đổi private key tương ứng khi anvil hiện ra.

```bash
# Demo 1: Oracle Manipulation Attack
forge script script/OracleAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

# Demo 2: Governance Attack  
forge script script/GovernanceAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

# Demo 3: Vault Inflation Attack
forge script script/PoolAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
```

---

## 🎯 Hiểu Từng Attack

### 1️⃣ Oracle Manipulation

**Xem file**: 
- `src/oracle/OracleSpot.sol` - Vulnerable oracle
- `src/attackers/Attacker_Oracle.sol` - Attack implementation

**Key Concept**: 
- Flash swap token từ DEX
- Manipulate reserves → oracle đọc giá sai
- Over-borrow từ lending protocol

### 2️⃣ Governance Takeover

**Xem file**:
- `src/targets/GovernanceWeak.sol` - Vulnerable governance
- `src/attackers/Attacker_Governance.sol` - Attack implementation

**Key Concept**:
- Flash loan governance tokens
- Vote với borrowed power trong cùng transaction
- Execute malicious proposal sau voting period

### 3️⃣ Vault Share Inflation

**Xem file**:
- `src/targets/VaultBuggy.sol` - Vulnerable vault
- `src/attackers/Attacker_PoolImbalance.sol` - Attack implementation

**Key Concept**:
- First depositor với 1 wei
- Donate large amount để inflate share price
- Victim deposit → receive 0 shares → funds trapped


## 🔧 Troubleshooting

### Muốn xem logs chi tiết
```bash
# Thêm -vvvv để xem full logs
forge script script/OracleAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vvvv
```



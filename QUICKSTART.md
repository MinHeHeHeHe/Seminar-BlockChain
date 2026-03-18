# Quick Start Guide

## ⚡ 5 Phút Setup & Demo

### Bước 1: Cài Foundry (nếu chưa có)

```bash
curl -L https://foundry.paradigm.xyz | bash
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

Trong terminal khác:

```bash
# Demo 1: Oracle Manipulation Attack
forge script script/Demo_OracleAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Demo 2: Governance Attack  
forge script script/Demo_GovernanceAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Demo 3: Vault Inflation Attack
forge script script/Demo_PoolAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Note**: Private key trên là test key mặc định của Anvil, an toàn để dùng cho local testing.

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

---

## 📖 Đọc Thêm

- **README.md** - Overview đầy đủ về project
- **TUTORIAL.md** - Hướng dẫn chi tiết từng attack với code explanation
- **src/** - Source code với comments giải thích vulnerabilities

---

## 🔧 Troubleshooting

### Lỗi "forge: command not found"
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Lỗi "connection refused"
```bash
# Đảm bảo anvil đang chạy
anvil
```

### Build errors
```bash
# Clean và rebuild
forge clean
forge build
```

### Muốn xem logs chi tiết
```bash
# Thêm -vvvv để xem full logs
forge script script/Demo_OracleAttack.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vvvv
```

---

## 🎓 Next Steps

1. Đọc code trong `src/` để hiểu vulnerabilities
2. Chạy các demos và quan sát output
3. Thử modify attackers để optimize
4. Implement fixes và test lại
5. Đọc TUTORIAL.md để hiểu sâu hơn

---

**Happy Learning! 🚀**

